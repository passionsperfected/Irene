#if os(macOS)
import AppKit
import SwiftUI

/// Bridge to access the NSTextView underlying SwiftUI's TextEditor.
/// Provides find highlighting, tab indent/outdent, multi-selection, and column selection.
@MainActor
final class NSTextViewBridge: EditorFindDelegate {
    private(set) weak var textView: NSTextView?
    private var eventMonitor: Any?
    private var themeAdapter: EditorThemeAdapter?
    private var columnSelectRecognizer: ColumnSelectGestureRecognizer?
    private var cursorOverlays: [NSView] = []
    private var cursorBlinkTimer: Timer?
    private var cursorVisible: Bool = true
    private var savedCursorColor: NSColor?

    /// Callback to force-sync content after direct NSTextView manipulation
    var onContentChanged: ((String) -> Void)?

    // Multi-edit mode: tracks match ranges for simultaneous editing
    private(set) var multiEditRanges: [NSRange] = []
    private(set) var isMultiEditing: Bool = false
    private var multiEditOriginalText: String = ""

    // MARK: - Discovery

    /// Find the NSTextView in the window and set up the bridge
    func attach(to window: NSWindow?, theme: ThemeDefinition) {
        guard let contentView = window?.contentView else { return }
        textView = findTextView(in: contentView)
        themeAdapter = EditorThemeAdapter(theme: theme)

        if let textView {
            disableSmartEditing(textView)
            installEventMonitor()
            installColumnSelection(on: textView)
        }
    }

    /// Re-attach after view recreation (file switch)
    func reattach(window: NSWindow?, theme: ThemeDefinition) {
        removeEventMonitor()
        attach(to: window, theme: theme)
    }

    func updateTheme(_ theme: ThemeDefinition) {
        themeAdapter = EditorThemeAdapter(theme: theme)
    }

    // MARK: - NSTextView Discovery

    private func findTextView(in view: NSView) -> NSTextView? {
        if let tv = view as? NSTextView, tv.isEditable {
            return tv
        }
        for subview in view.subviews {
            if let found = findTextView(in: subview) {
                return found
            }
        }
        return nil
    }

    // MARK: - Smart Editing

    private func disableSmartEditing(_ textView: NSTextView) {
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.smartInsertDeleteEnabled = false
    }

    // MARK: - EditorFindDelegate

    func highlightMatches(_ matches: [NSRange], currentIndex: Int) {
        guard let textView, let layoutManager = textView.layoutManager,
              let textStorage = textView.textStorage, let theme = themeAdapter else { return }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)

        for (i, range) in matches.enumerated() {
            guard range.location + range.length <= textStorage.length else { continue }
            let color = (i == currentIndex || currentIndex == -1)
                ? theme.currentMatchHighlight
                : theme.matchHighlight
            layoutManager.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: range)
        }

        if currentIndex >= 0, currentIndex < matches.count {
            textView.scrollRangeToVisible(matches[currentIndex])
        }
    }

    func selectAllMatches(_ matches: [NSRange]) {
        guard let textView, !matches.isEmpty else {
            print("[BRIDGE] selectAllMatches: no textView or empty matches")
            return
        }
        clearHighlights()

        multiEditRanges = matches.sorted { $0.location < $1.location }
        isMultiEditing = true
        savedCursorColor = textView.insertionPointColor

        let nsString = textView.string as NSString
        if let first = multiEditRanges.first, first.location + first.length <= nsString.length {
            multiEditOriginalText = nsString.substring(with: first)
        }

        print("[BRIDGE] selectAllMatches: entered multi-edit with \(multiEditRanges.count) ranges: \(multiEditRanges)")

        highlightMultiEditRanges()

        textView.window?.makeFirstResponder(textView)
        textView.setSelectedRange(multiEditRanges[0])
    }

    func exitMultiEdit() {
        isMultiEditing = false
        multiEditRanges = []
        multiEditOriginalText = ""
        removeCursorOverlays()
        clearHighlights()

        // Restore native cursor color
        if let textView {
            textView.insertionPointColor = savedCursorColor ?? themeAdapter?.cursorColor ?? .systemBlue
        }
        savedCursorColor = nil
    }

    private func highlightMultiEditRanges() {
        guard let textView, let layoutManager = textView.layoutManager,
              let textStorage = textView.textStorage, let theme = themeAdapter else { return }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)

        // Highlight selections with background color
        for range in multiEditRanges where range.length > 0 {
            guard range.location + range.length <= textStorage.length else { continue }
            layoutManager.addTemporaryAttribute(.backgroundColor, value: theme.currentMatchHighlight, forCharacterRange: range)
        }

        // Draw cursor overlays for all positions
        updateCursorOverlays()
    }

    private func updateCursorOverlays() {
        // Remove old overlays
        for overlay in cursorOverlays {
            overlay.removeFromSuperview()
        }
        cursorOverlays.removeAll()

        guard let textView, let layoutManager = textView.layoutManager,
              let textStorage = textView.textStorage, let theme = themeAdapter else { return }

        let containerOrigin = textView.textContainerOrigin

        for range in multiEditRanges {
            // Get the cursor position rect
            let charIndex = range.length > 0
                ? range.location + range.length  // end of selection
                : range.location                  // caret position

            let safeIndex = min(charIndex, textStorage.length)
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: max(safeIndex - (safeIndex == textStorage.length ? 1 : 0), 0))
            guard glyphIndex != NSNotFound else { continue }

            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let glyphLocation = layoutManager.location(forGlyphAt: glyphIndex)

            var cursorX = lineRect.origin.x + glyphLocation.x + containerOrigin.x
            // If cursor is at end of text or at the position after a character, offset right
            if safeIndex == charIndex && range.length == 0 && charIndex < textStorage.length {
                // Cursor is between characters — position is correct
            } else if charIndex == textStorage.length {
                // At very end of text — use the glyph's right edge
                let lastGlyph = layoutManager.glyphIndexForCharacter(at: max(textStorage.length - 1, 0))
                let lastRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: lastGlyph, length: 1), in: textView.textContainer!)
                cursorX = lastRect.maxX + containerOrigin.x
            }

            let cursorY = lineRect.origin.y + containerOrigin.y
            let cursorHeight = lineRect.height

            let cursorColor = savedCursorColor ?? themeAdapter?.cursorColor ?? NSColor.systemBlue

            let cursorView = NSView(frame: NSRect(x: cursorX, y: cursorY, width: 1, height: cursorHeight))
            cursorView.wantsLayer = true
            cursorView.layer?.backgroundColor = cursorColor.cgColor
            textView.addSubview(cursorView)
            cursorOverlays.append(cursorView)
        }

        // Hide the native insertion point so we control ALL cursors
        // (set to transparent — we draw our own at the primary position too)
        textView.insertionPointColor = .clear

        startCursorBlink()
    }

    private func startCursorBlink() {
        cursorBlinkTimer?.invalidate()
        cursorVisible = true

        // All overlays blink together on a single timer — perfectly in sync
        cursorBlinkTimer = Timer.scheduledTimer(withTimeInterval: 0.56, repeats: true) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                guard self.isMultiEditing else {
                    self.cursorBlinkTimer?.invalidate()
                    self.cursorBlinkTimer = nil
                    return
                }
                self.cursorVisible.toggle()
                for overlay in self.cursorOverlays {
                    overlay.isHidden = !self.cursorVisible
                }
            }
        }
    }

    private func removeCursorOverlays() {
        cursorBlinkTimer?.invalidate()
        cursorBlinkTimer = nil
        for overlay in cursorOverlays {
            overlay.removeFromSuperview()
        }
        cursorOverlays.removeAll()
    }

    /// Handle a character insertion across all multi-edit ranges
    private func multiEditInsert(_ string: String) {
        guard let textView, let textStorage = textView.textStorage else { return }

        textView.undoManager?.beginUndoGrouping()
        textStorage.beginEditing()

        let insertLength = (string as NSString).length

        // Replace each range from last to first to preserve offsets
        for range in multiEditRanges.reversed() {
            guard range.location + range.length <= textStorage.length else { continue }
            textStorage.replaceCharacters(in: range, with: string)
        }

        textStorage.endEditing()
        textView.didChangeText()
        textView.undoManager?.endUndoGrouping()

        // Recalculate: cursors positioned AFTER the inserted text (zero-length)
        var newRanges: [NSRange] = []
        var delta = 0
        for range in multiEditRanges {
            let newLocation = range.location + delta + insertLength
            newRanges.append(NSRange(location: newLocation, length: 0))
            delta += insertLength - range.length
        }
        multiEditRanges = newRanges

        // Sync content (debounced — don't let SwiftUI interfere immediately)
        let content = textView.string
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            self?.onContentChanged?(content)
        }

        // Update cursor overlays and reset blink (stay solid while typing)
        highlightMultiEditRanges()
        resetCursorBlink()

        // Place SwiftUI's cursor at first position
        if let first = multiEditRanges.first {
            textView.setSelectedRange(first)
        }
    }

    /// Handle backspace across all multi-edit ranges
    private func multiEditDeleteBackward() {
        guard let textView, let textStorage = textView.textStorage else { return }

        // Each range should shrink by 1 char from the end (or delete if already 0 length)
        var deleteRanges: [NSRange] = []
        for range in multiEditRanges {
            if range.length > 0 {
                // Delete last char of range
                deleteRanges.append(NSRange(location: range.location + range.length - 1, length: 1))
            } else if range.location > 0 {
                // Range is a cursor, delete char before it
                deleteRanges.append(NSRange(location: range.location - 1, length: 1))
            }
        }

        guard !deleteRanges.isEmpty else { return }

        textView.undoManager?.beginUndoGrouping()
        textStorage.beginEditing()

        for range in deleteRanges.reversed() {
            guard range.location + range.length <= textStorage.length else { continue }
            textStorage.replaceCharacters(in: range, with: "")
        }

        textStorage.endEditing()
        textView.didChangeText()
        textView.undoManager?.endUndoGrouping()

        // Recalculate ranges
        var newRanges: [NSRange] = []
        var delta = 0
        for (i, range) in multiEditRanges.enumerated() {
            let deleteRange = deleteRanges[i]
            let newLocation = range.location + delta
            let newLength = max(0, range.length - 1)
            if deleteRange.length > 0 && range.length == 0 {
                // Was a cursor delete
                newRanges.append(NSRange(location: max(0, newLocation - 1), length: 0))
                delta -= 1
            } else {
                newRanges.append(NSRange(location: newLocation, length: newLength))
                delta -= 1
            }
        }
        multiEditRanges = newRanges

        let content = textView.string
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            self?.onContentChanged?(content)
        }

        highlightMultiEditRanges()
        resetCursorBlink()

        if let first = multiEditRanges.first {
            textView.setSelectedRange(first)
        }
    }

    enum CursorDirection { case left, right }

    private func multiEditMoveCursors(direction: CursorDirection) {
        guard let textView, let textStorage = textView.textStorage else { return }
        let maxLen = textStorage.length

        multiEditRanges = multiEditRanges.map { range in
            switch direction {
            case .left:
                // Collapse to left edge, then move left 1
                let pos = max(0, range.location - (range.length == 0 ? 1 : 0))
                return NSRange(location: pos, length: 0)
            case .right:
                // Collapse to right edge, then move right 1
                let edge = range.location + range.length
                let pos = min(maxLen, edge + (range.length == 0 ? 1 : 0))
                return NSRange(location: pos, length: 0)
            }
        }

        highlightMultiEditRanges()
        resetCursorBlink()

        if let first = multiEditRanges.first {
            textView.setSelectedRange(first)
        }
    }

    /// Reset blink so cursors stay solid during active interaction
    private func resetCursorBlink() {
        cursorVisible = true
        for overlay in cursorOverlays {
            overlay.isHidden = false
        }
        // Restart the blink timer from scratch
        startCursorBlink()
    }

    func scrollToMatch(at range: NSRange) {
        textView?.scrollRangeToVisible(range)
    }

    func clearHighlights() {
        guard let textView, let layoutManager = textView.layoutManager,
              let textStorage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
    }

    // MARK: - Scroll to Line

    func scrollToLine(_ lineNumber: Int) {
        guard let textView else { return }
        let nsString = textView.string as NSString
        var currentLine = 1
        var charIndex = 0

        while currentLine < lineNumber && charIndex < nsString.length {
            let lineRange = nsString.lineRange(for: NSRange(location: charIndex, length: 0))
            charIndex = NSMaxRange(lineRange)
            currentLine += 1
        }

        textView.setSelectedRange(NSRange(location: charIndex, length: 0))
        textView.scrollRangeToVisible(NSRange(location: charIndex, length: 0))
    }

    // MARK: - Tab Indent / Outdent (Event Monitor)

    private func installEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let textView = self.textView else { return event }

            // Only intercept when our textView is first responder
            guard textView.window?.firstResponder === textView else {
                // If we lose focus during multi-edit, exit
                if self.isMultiEditing {
                    self.exitMultiEdit()
                }
                return event
            }

            let keyCode = event.keyCode
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // MARK: Multi-edit mode key handling
            if self.isMultiEditing {
                print("[BRIDGE] multi-edit key: keyCode=\(keyCode), chars='\(event.characters ?? "")', flags=\(flags)")
                // Escape exits multi-edit
                if keyCode == 53 {
                    self.exitMultiEdit()
                    return nil
                }

                // Arrow keys FIRST (they have .numericPad/.function flags)
                if keyCode == 123 { // left
                    self.multiEditMoveCursors(direction: .left)
                    return nil
                }
                if keyCode == 124 { // right
                    self.multiEditMoveCursors(direction: .right)
                    return nil
                }
                if keyCode == 125 || keyCode == 126 { // up/down — exit
                    self.exitMultiEdit()
                    return event
                }

                // Enter — exit multi-edit
                if keyCode == 36 {
                    self.exitMultiEdit()
                    return event
                }

                // Backspace
                if keyCode == 51 {
                    self.multiEditDeleteBackward()
                    return nil
                }

                // Regular character input (no command/control modifiers)
                if flags.isEmpty || flags == .shift {
                    if let chars = event.characters, !chars.isEmpty {
                        self.multiEditInsert(chars)
                        return nil
                    }
                }

                // Any command-key combo — exit multi-edit, let through
                if flags.contains(.command) {
                    self.exitMultiEdit()
                    return event
                }

                return nil // consume unknown keys in multi-edit
            }

            // MARK: Normal mode key handling

            // Tab (keyCode 48)
            if keyCode == 48 && flags.isEmpty {
                let selection = textView.selectedRange()
                if selection.length > 0 {
                    self.indentLines(in: textView)
                } else {
                    textView.insertText("    ", replacementRange: textView.selectedRange())
                    self.syncContent()
                }
                return nil
            }

            // Shift+Tab
            if keyCode == 48 && flags == .shift {
                self.outdentLines(in: textView)
                return nil
            }

            return event
        }
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - Indent / Outdent Logic

    private func indentLines(in textView: NSTextView) {
        let nsString = textView.string as NSString
        let lineRange = nsString.lineRange(for: textView.selectedRange())

        textView.undoManager?.beginUndoGrouping()

        // Collect line starts
        var lineStarts: [Int] = []
        var pos = lineRange.location
        while pos < NSMaxRange(lineRange) {
            lineStarts.append(pos)
            let thisLineRange = nsString.lineRange(for: NSRange(location: pos, length: 0))
            pos = NSMaxRange(thisLineRange)
        }

        // Insert 4 spaces at each line start, reverse order
        for start in lineStarts.reversed() {
            let insertRange = NSRange(location: start, length: 0)
            if textView.shouldChangeText(in: insertRange, replacementString: "    ") {
                textView.textStorage?.replaceCharacters(in: insertRange, with: "    ")
            }
        }

        textView.didChangeText()
        textView.undoManager?.endUndoGrouping()
        syncContent()
    }

    private func outdentLines(in textView: NSTextView) {
        let nsString = textView.string as NSString
        let lineRange = nsString.lineRange(for: textView.selectedRange())

        textView.undoManager?.beginUndoGrouping()

        var pos = NSMaxRange(lineRange)
        while pos > lineRange.location {
            let thisLineRange = nsString.lineRange(for: NSRange(location: max(pos - 1, lineRange.location), length: 0))
            let lineText = nsString.substring(with: thisLineRange)

            var spacesToRemove = 0
            for char in lineText {
                if char == " " && spacesToRemove < 4 {
                    spacesToRemove += 1
                } else if char == "\t" && spacesToRemove == 0 {
                    spacesToRemove = 1
                    break
                } else {
                    break
                }
            }

            if spacesToRemove > 0 {
                let removeRange = NSRange(location: thisLineRange.location, length: spacesToRemove)
                if textView.shouldChangeText(in: removeRange, replacementString: "") {
                    textView.textStorage?.replaceCharacters(in: removeRange, with: "")
                }
            }

            pos = thisLineRange.location
            if pos == 0 { break }
        }

        textView.didChangeText()
        textView.undoManager?.endUndoGrouping()
        syncContent()
    }

    // MARK: - Content Sync

    private func syncContent() {
        guard let textView else { return }
        onContentChanged?(textView.string)
    }

    // MARK: - Column Selection (Option+Drag)

    private func installColumnSelection(on textView: NSTextView) {
        // Remove old recognizer if any
        if let old = columnSelectRecognizer {
            textView.removeGestureRecognizer(old)
        }
        let recognizer = ColumnSelectGestureRecognizer(bridge: self)
        textView.addGestureRecognizer(recognizer)
        columnSelectRecognizer = recognizer
    }

    func applyColumnSelection(from startPoint: NSPoint, to endPoint: NSPoint) {
        guard let textView, let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let nsString = textView.string as NSString
        let containerOrigin = textView.textContainerOrigin

        // Convert points to text container coordinates
        let startTC = NSPoint(x: startPoint.x - containerOrigin.x, y: startPoint.y - containerOrigin.y)
        let endTC = NSPoint(x: endPoint.x - containerOrigin.x, y: endPoint.y - containerOrigin.y)

        // Get glyph indices for start and end
        let startGlyph = layoutManager.glyphIndex(for: startTC, in: textContainer)
        let endGlyph = layoutManager.glyphIndex(for: endTC, in: textContainer)

        let startChar = layoutManager.characterIndexForGlyph(at: startGlyph)
        let endChar = layoutManager.characterIndexForGlyph(at: endGlyph)

        // Get line ranges
        let startLineRange = nsString.lineRange(for: NSRange(location: startChar, length: 0))
        let endLineRange = nsString.lineRange(for: NSRange(location: endChar, length: 0))

        let firstLine = min(startLineRange.location, endLineRange.location)
        let lastLineEnd = max(NSMaxRange(startLineRange), NSMaxRange(endLineRange))

        // Column offset from the start click
        let startCol = startChar - startLineRange.location

        // Build one cursor per line at the target column
        var selections: [NSValue] = []
        var pos = firstLine
        while pos < lastLineEnd && pos < nsString.length {
            let lineRange = nsString.lineRange(for: NSRange(location: pos, length: 0))
            let lineLength = lineRange.length - (nsString.substring(with: lineRange).hasSuffix("\n") ? 1 : 0)
            let col = min(startCol, lineLength)
            let cursorPos = lineRange.location + col
            selections.append(NSValue(range: NSRange(location: cursorPos, length: 0)))
            pos = NSMaxRange(lineRange)
        }

        if !selections.isEmpty {
            textView.setSelectedRanges(selections, affinity: .upstream, stillSelecting: false)
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        removeCursorOverlays()
        removeEventMonitor()
        if let textView, let recognizer = columnSelectRecognizer {
            textView.removeGestureRecognizer(recognizer)
        }
        columnSelectRecognizer = nil
        textView = nil
    }

    nonisolated deinit {
    }
}

// MARK: - Column Select Gesture Recognizer

class ColumnSelectGestureRecognizer: NSGestureRecognizer {
    private weak var bridge: NSTextViewBridge?
    private var startPoint: NSPoint = .zero

    init(bridge: NSTextViewBridge) {
        self.bridge = bridge
        super.init(target: nil, action: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    override func mouseDown(with event: NSEvent) {
        guard event.modifierFlags.contains(.option),
              let textView = self.view as? NSTextView else {
            state = .failed
            return
        }
        startPoint = textView.convert(event.locationInWindow, from: nil)
        state = .began
    }

    override func mouseDragged(with event: NSEvent) {
        guard state == .began || state == .changed,
              let textView = self.view as? NSTextView else { return }
        let currentPoint = textView.convert(event.locationInWindow, from: nil)

        Task { @MainActor [weak self] in
            self?.bridge?.applyColumnSelection(from: self?.startPoint ?? .zero, to: currentPoint)
        }

        state = .changed
    }

    override func mouseUp(with event: NSEvent) {
        if state == .changed || state == .began {
            state = .ended
        } else {
            state = .failed
        }
    }
}
#endif
