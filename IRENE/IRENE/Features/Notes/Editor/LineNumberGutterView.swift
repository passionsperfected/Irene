#if os(macOS)
import AppKit

class LineNumberGutterView: NSRulerView {

    var editorTheme: EditorThemeAdapter?

    private var lineCount: Int = 0

    init(textView: NSTextView) {
        super.init(scrollView: textView.enclosingScrollView!, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 40

        // Listen for text and selection changes
        NotificationCenter.default.addObserver(
            self, selector: #selector(textDidChange),
            name: NSText.didChangeNotification, object: textView
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(textDidChange),
            name: NSTextView.didChangeSelectionNotification, object: textView
        )
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func textDidChange() {
        needsDisplay = true
        // Recalculate thickness if line count changed digits
        let newLineCount = (clientView as? NSTextView)?.string.components(separatedBy: "\n").count ?? 0
        if String(newLineCount).count != String(lineCount).count {
            lineCount = newLineCount
            let digits = max(3, String(lineCount).count)
            ruleThickness = CGFloat(digits) * 8.5 + 16
        }
        lineCount = newLineCount
    }

    override var requiredThickness: CGFloat {
        ruleThickness
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let theme = editorTheme else { return }

        // Fill gutter background
        theme.gutterBackground.setFill()
        rect.fill()

        // Draw right edge separator
        let separatorRect = NSRect(x: rect.maxX - 1, y: rect.minY, width: 1, height: rect.height)
        theme.gutterText.withAlphaComponent(0.3).setFill()
        separatorRect.fill()

        // Attributes
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right

        let normalAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: theme.gutterText,
            .paragraphStyle: paragraphStyle
        ]

        let activeAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: theme.gutterActiveText,
            .paragraphStyle: paragraphStyle
        ]

        // Handle empty file
        let textLength = textView.textStorage?.length ?? 0
        guard textLength > 0 else {
            let numberString = NSAttributedString(string: "1", attributes: normalAttrs)
            let drawRect = NSRect(x: 0, y: textView.textContainerOrigin.y, width: ruleThickness - 8, height: 16)
            numberString.draw(in: drawRect)
            return
        }

        // Get visible glyph range
        let visibleRect = scrollView!.contentView.bounds
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let visibleCharRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)

        // Determine which lines have cursors
        let cursorLines = Set(textView.selectedRanges.map { rangeValue -> Int in
            let range = rangeValue.rangeValue
            let loc = min(range.location, max(textLength - 1, 0))
            let upTo = (textView.string as NSString).substring(to: loc)
            return upTo.components(separatedBy: "\n").count
        })

        // Draw line numbers
        let nsString = textView.string as NSString
        var lineNumber = 1

        // Count lines before visible range
        if visibleCharRange.location > 0 {
            lineNumber = nsString.substring(to: visibleCharRange.location).components(separatedBy: "\n").count
        }

        let textContainerOrigin = textView.textContainerOrigin

        var charIndex = visibleCharRange.location
        while charIndex < NSMaxRange(visibleCharRange) {
            let lineRange = nsString.lineRange(for: NSRange(location: charIndex, length: 0))
            let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)

            if glyphRange.location != NSNotFound {
                let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)

                let y = lineRect.origin.y + textContainerOrigin.y - visibleRect.origin.y
                let drawRect = NSRect(x: 0, y: y, width: ruleThickness - 8, height: lineRect.height)

                let attrs = cursorLines.contains(lineNumber) ? activeAttrs : normalAttrs
                let numberString = NSAttributedString(string: "\(lineNumber)", attributes: attrs)
                numberString.draw(in: drawRect)
            }

            lineNumber += 1
            charIndex = NSMaxRange(lineRange)
        }
    }
}
#endif
