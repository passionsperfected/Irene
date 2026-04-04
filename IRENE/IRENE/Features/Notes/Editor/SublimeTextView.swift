#if os(macOS)
import AppKit

class SublimeTextView: NSTextView {

    var editorTheme: EditorThemeAdapter? {
        didSet { applyTheme() }
    }

    lazy var multiCursor: MultiCursorController = {
        let controller = MultiCursorController()
        controller.textView = self
        return controller
    }()

    var isMultiCursorActive: Bool {
        multiCursor.state.selections.count > 1
    }

    // MARK: - Initialization

    static func create(frame: NSRect) -> (NSScrollView, SublimeTextView) {
        // Build TextKit 1 stack manually for full control
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)

        let textView = SublimeTextView(frame: frame, textContainer: textContainer)

        // Plain text editor config
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true

        // Layout
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)

        // Scroll view
        let scrollView = NSScrollView(frame: frame)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        scrollView.drawsBackground = false

        return (scrollView, textView)
    }

    // MARK: - Lifecycle

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        disableSmartEditing()
    }

    private func disableSmartEditing() {
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        smartInsertDeleteEnabled = false
        isAutomaticTextCompletionEnabled = false
    }

    // MARK: - Theme

    func applyTheme() {
        guard let theme = editorTheme else { return }

        backgroundColor = theme.backgroundColor
        insertionPointColor = theme.cursorColor
        selectedTextAttributes = [.backgroundColor: theme.selectionColor]
        typingAttributes = [
            .font: theme.font,
            .foregroundColor: theme.textColor
        ]
    }

    // MARK: - Current Line Highlight

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard let theme = editorTheme,
              let layoutManager = layoutManager,
              let textStorage = textStorage,
              textStorage.length > 0 else { return }

        theme.currentLineHighlight.setFill()

        for rangeValue in selectedRanges {
            let range = rangeValue.rangeValue
            if range.length == 0 && range.location <= textStorage.length {
                let charIndex = min(range.location, textStorage.length - 1)
                let glyphIndex = layoutManager.glyphIndexForCharacter(at: charIndex)
                guard glyphIndex != NSNotFound else { continue }
                var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
                lineRect.origin.x = 0
                lineRect.origin.y += textContainerOrigin.y
                lineRect.size.width = bounds.width
                lineRect.fill()
            }
        }
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelectingFlag)
        // Redraw to update current line highlight
        needsDisplay = true
    }

    // MARK: - Tab inserts spaces

    override func insertTab(_ sender: Any?) {
        if selectedRange().length > 0 {
            indentSelectedLines()
        } else {
            insertText("    ", replacementRange: selectedRange())
        }
    }

    override func insertBacktab(_ sender: Any?) {
        outdentSelectedLines()
    }

    // MARK: - Auto-indent on Enter

    override func insertNewline(_ sender: Any?) {
        // Capture leading whitespace of current line
        let nsString = (string as NSString)
        let lineRange = nsString.lineRange(for: selectedRange())
        let lineText = nsString.substring(with: lineRange)

        var leadingWhitespace = ""
        for char in lineText {
            if char == " " || char == "\t" {
                leadingWhitespace.append(char)
            } else {
                break
            }
        }

        super.insertNewline(sender)

        if !leadingWhitespace.isEmpty {
            insertText(leadingWhitespace, replacementRange: selectedRange())
        }
    }

    // MARK: - Line Operations

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers ?? ""

        // MARK: Multi-cursor shortcuts

        // Cmd+D — Select next occurrence
        if key == "d" && flags == .command {
            multiCursor.selectNextOccurrence()
            return
        }

        // Ctrl+Shift+Up — Add cursor above
        if event.keyCode == 126 && flags == [.control, .shift] {
            multiCursor.addCursorAbove()
            return
        }

        // Ctrl+Shift+Down — Add cursor below
        if event.keyCode == 125 && flags == [.control, .shift] {
            multiCursor.addCursorBelow()
            return
        }

        // Cmd+Shift+L — Split selection into lines
        if key == "l" && flags == [.command, .shift] {
            multiCursor.splitSelectionIntoLines()
            return
        }

        // Escape — Collapse to single cursor (if multi)
        if event.keyCode == 53 && isMultiCursorActive {
            multiCursor.collapseToSingleCursor()
            return
        }

        // MARK: Line operation shortcuts

        // Cmd+Shift+D — Duplicate line
        if key == "d" && flags == [.command, .shift] {
            duplicateLine()
            return
        }

        // Cmd+Shift+K — Delete line
        if key == "k" && flags == [.command, .shift] {
            deleteLine()
            return
        }

        // Cmd+/ — Toggle comment
        if key == "/" && flags == .command {
            toggleLineComment()
            return
        }

        // Cmd+L — Select line
        if key == "l" && flags == .command {
            selectEntireLine()
            return
        }

        // Cmd+] — Indent
        if key == "]" && flags == .command {
            indentSelectedLines()
            return
        }

        // Cmd+[ — Outdent
        if key == "[" && flags == .command {
            outdentSelectedLines()
            return
        }

        // Cmd+Shift+Up — Move line up
        if event.keyCode == 126 && flags == [.command, .shift] { // up arrow
            moveLineUp()
            return
        }

        // Cmd+Shift+Down — Move line down
        if event.keyCode == 125 && flags == [.command, .shift] { // down arrow
            moveLineDown()
            return
        }

        super.keyDown(with: event)
    }

    // MARK: - Indent / Outdent

    func indentSelectedLines() {
        let nsString = (string as NSString)
        let lineRange = nsString.lineRange(for: selectedRange())

        undoManager?.beginUndoGrouping()
        textStorage?.beginEditing()

        // Collect line starts in reverse order
        var lineStarts: [Int] = []
        var pos = lineRange.location
        while pos < NSMaxRange(lineRange) {
            lineStarts.append(pos)
            let thisLineRange = nsString.lineRange(for: NSRange(location: pos, length: 0))
            pos = NSMaxRange(thisLineRange)
        }

        // Insert 4 spaces at each line start, reverse to preserve offsets
        for start in lineStarts.reversed() {
            let insertRange = NSRange(location: start, length: 0)
            if shouldChangeText(in: insertRange, replacementString: "    ") {
                textStorage?.replaceCharacters(in: insertRange, with: "    ")
            }
        }

        textStorage?.endEditing()
        didChangeText()
        undoManager?.endUndoGrouping()

        // Expand selection to cover indented lines
        let newLineRange = nsString.lineRange(for: NSRange(location: lineRange.location, length: 0))
        setSelectedRange(NSRange(location: newLineRange.location, length: nsString.lineRange(for: NSRange(location: NSMaxRange(lineRange) + lineStarts.count * 4 - 1, length: 0)).location + nsString.lineRange(for: NSRange(location: NSMaxRange(lineRange) + lineStarts.count * 4 - 1, length: 0)).length - newLineRange.location))
    }

    func outdentSelectedLines() {
        let nsString = (string as NSString)
        let lineRange = nsString.lineRange(for: selectedRange())

        undoManager?.beginUndoGrouping()
        textStorage?.beginEditing()

        var pos = NSMaxRange(lineRange)
        while pos > lineRange.location {
            let thisLineRange = nsString.lineRange(for: NSRange(location: max(pos - 1, lineRange.location), length: 0))
            let lineText = nsString.substring(with: thisLineRange)

            // Count leading spaces to remove (up to 4)
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
                if shouldChangeText(in: removeRange, replacementString: "") {
                    textStorage?.replaceCharacters(in: removeRange, with: "")
                }
            }

            pos = thisLineRange.location
            if pos == 0 { break }
        }

        textStorage?.endEditing()
        didChangeText()
        undoManager?.endUndoGrouping()
    }

    // MARK: - Duplicate Line

    func duplicateLine() {
        let nsString = (string as NSString)
        let lineRange = nsString.lineRange(for: selectedRange())
        let lineText = nsString.substring(with: lineRange)

        let insertionPoint = NSMaxRange(lineRange)
        let textToInsert = lineText.hasSuffix("\n") ? lineText : lineText + "\n"

        undoManager?.beginUndoGrouping()
        if shouldChangeText(in: NSRange(location: insertionPoint, length: 0), replacementString: textToInsert) {
            textStorage?.replaceCharacters(in: NSRange(location: insertionPoint, length: 0), with: textToInsert)
            didChangeText()
        }
        undoManager?.endUndoGrouping()

        // Move cursor to duplicated line
        setSelectedRange(NSRange(location: insertionPoint + lineText.count - (lineText.hasSuffix("\n") ? lineText.count : 0), length: 0))
    }

    // MARK: - Delete Line

    func deleteLine() {
        let nsString = (string as NSString)
        let lineRange = nsString.lineRange(for: selectedRange())

        undoManager?.beginUndoGrouping()
        if shouldChangeText(in: lineRange, replacementString: "") {
            textStorage?.replaceCharacters(in: lineRange, with: "")
            didChangeText()
        }
        undoManager?.endUndoGrouping()

        setSelectedRange(NSRange(location: min(lineRange.location, (textStorage?.length ?? 0)), length: 0))
    }

    // MARK: - Toggle Comment

    func toggleLineComment() {
        let nsString = (string as NSString)
        let lineRange = nsString.lineRange(for: selectedRange())

        // Collect lines
        var lines: [(range: NSRange, text: String)] = []
        var pos = lineRange.location
        while pos < NSMaxRange(lineRange) {
            let thisLineRange = nsString.lineRange(for: NSRange(location: pos, length: 0))
            lines.append((thisLineRange, nsString.substring(with: thisLineRange)))
            pos = NSMaxRange(thisLineRange)
        }

        // Check if all lines are commented
        let allCommented = lines.allSatisfy { line in
            line.text.trimmingCharacters(in: .whitespaces).hasPrefix("// ") ||
            line.text.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }

        undoManager?.beginUndoGrouping()
        textStorage?.beginEditing()

        if allCommented {
            // Remove comments (reverse order)
            for line in lines.reversed() {
                if let commentRange = line.text.range(of: "// ") ?? line.text.range(of: "//") {
                    let nsCommentStart = (line.text as NSString).range(of: line.text[commentRange].description)
                    let removeRange = NSRange(location: line.range.location + nsCommentStart.location, length: nsCommentStart.length)
                    if shouldChangeText(in: removeRange, replacementString: "") {
                        textStorage?.replaceCharacters(in: removeRange, with: "")
                    }
                }
            }
        } else {
            // Add comments (reverse order)
            for line in lines.reversed() {
                // Find first non-space character
                let trimmed = line.text.prefix(while: { $0 == " " || $0 == "\t" })
                let insertOffset = line.range.location + trimmed.count
                let insertRange = NSRange(location: insertOffset, length: 0)
                if shouldChangeText(in: insertRange, replacementString: "// ") {
                    textStorage?.replaceCharacters(in: insertRange, with: "// ")
                }
            }
        }

        textStorage?.endEditing()
        didChangeText()
        undoManager?.endUndoGrouping()
    }

    // MARK: - Select Entire Line

    func selectEntireLine() {
        let nsString = (string as NSString)
        let lineRange = nsString.lineRange(for: selectedRange())
        setSelectedRange(lineRange)
    }

    // MARK: - Move Line Up/Down

    func moveLineUp() {
        let nsString = (string as NSString)
        let lineRange = nsString.lineRange(for: selectedRange())
        guard lineRange.location > 0 else { return }

        let prevLineRange = nsString.lineRange(for: NSRange(location: lineRange.location - 1, length: 0))
        let lineText = nsString.substring(with: lineRange)
        let prevLineText = nsString.substring(with: prevLineRange)

        undoManager?.beginUndoGrouping()
        textStorage?.beginEditing()

        let combinedRange = NSRange(location: prevLineRange.location, length: prevLineRange.length + lineRange.length)
        let ensureNewline = lineText.hasSuffix("\n") ? "" : "\n"
        let newText = lineText + ensureNewline + prevLineText.trimmingCharacters(in: .newlines) + (prevLineText.hasSuffix("\n") ? "\n" : "")

        if shouldChangeText(in: combinedRange, replacementString: newText) {
            textStorage?.replaceCharacters(in: combinedRange, with: newText)
            didChangeText()
        }

        textStorage?.endEditing()
        undoManager?.endUndoGrouping()

        setSelectedRange(NSRange(location: prevLineRange.location, length: 0))
    }

    func moveLineDown() {
        let nsString = (string as NSString)
        let lineRange = nsString.lineRange(for: selectedRange())
        guard NSMaxRange(lineRange) < nsString.length else { return }

        let nextLineRange = nsString.lineRange(for: NSRange(location: NSMaxRange(lineRange), length: 0))
        let lineText = nsString.substring(with: lineRange)
        let nextLineText = nsString.substring(with: nextLineRange)

        undoManager?.beginUndoGrouping()
        textStorage?.beginEditing()

        let combinedRange = NSRange(location: lineRange.location, length: lineRange.length + nextLineRange.length)
        let ensureNewline = nextLineText.hasSuffix("\n") ? "" : "\n"
        let newText = nextLineText.trimmingCharacters(in: .newlines) + "\n" + lineText + ensureNewline

        if shouldChangeText(in: combinedRange, replacementString: newText) {
            textStorage?.replaceCharacters(in: combinedRange, with: newText)
            didChangeText()
        }

        textStorage?.endEditing()
        undoManager?.endUndoGrouping()

        // Position cursor on the moved line
        let newLineStart = lineRange.location + nextLineRange.length
        setSelectedRange(NSRange(location: min(newLineStart, nsString.length), length: 0))
    }

    // MARK: - Multi-cursor text input overrides

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        if isMultiCursorActive, let str = insertString as? String {
            multiCursor.insertText(str)
        } else {
            super.insertText(insertString, replacementRange: replacementRange)
        }
    }

    override func deleteBackward(_ sender: Any?) {
        if isMultiCursorActive {
            multiCursor.deleteBackward()
        } else {
            super.deleteBackward(sender)
        }
    }

    override func deleteForward(_ sender: Any?) {
        if isMultiCursorActive {
            multiCursor.deleteForward()
        } else {
            super.deleteForward(sender)
        }
    }

    // MARK: - Multi-cursor mouse handling

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            // Cmd+click — add cursor
            let point = convert(event.locationInWindow, from: nil)
            let charIndex = characterIndexForInsertion(at: point)
            multiCursor.addCursor(at: charIndex)
            return
        }

        // Single click collapses multi-cursor
        if isMultiCursorActive {
            multiCursor.state.selections = []
        }

        super.mouseDown(with: event)
    }
}
#endif
