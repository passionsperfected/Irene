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

    /// Callback to force-sync content after direct NSTextView manipulation
    var onContentChanged: ((String) -> Void)?

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
        guard let textView, !matches.isEmpty else { return }
        clearHighlights()
        let nsValues = matches.map { NSValue(range: $0) }
        textView.setSelectedRanges(nsValues, affinity: .upstream, stillSelecting: false)
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
            guard textView.window?.firstResponder === textView else { return event }

            let keyCode = event.keyCode
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Tab (keyCode 48)
            if keyCode == 48 && flags.isEmpty {
                let selection = textView.selectedRange()
                if selection.length > 0 {
                    // Multi-line selection: indent
                    self.indentLines(in: textView)
                } else {
                    // Insert 4 spaces
                    textView.insertText("    ", replacementRange: textView.selectedRange())
                    self.syncContent()
                }
                return nil // consume
            }

            // Shift+Tab
            if keyCode == 48 && flags == .shift {
                self.outdentLines(in: textView)
                return nil // consume
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
