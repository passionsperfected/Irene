#if os(macOS)
import AppKit
import SwiftUI

// MARK: - Find Delegate Protocol

@MainActor
protocol EditorFindDelegate: AnyObject {
    func highlightMatches(_ matches: [NSRange], currentIndex: Int)
    func selectAllMatches(_ matches: [NSRange])
    func scrollToMatch(at range: NSRange)
    func clearHighlights()
}

// MARK: - Coordinator

class SublimeEditorCoordinator: NSObject, NSTextViewDelegate {
    @MainActor var contentBinding: Binding<String>
    @MainActor var isUpdating: Bool = false
    @MainActor var onCursorChange: ((Int, Int) -> Void)?
    @MainActor weak var textView: SublimeTextView?

    @MainActor
    init(contentBinding: Binding<String>) {
        self.contentBinding = contentBinding
    }

    // MARK: - Content sync

    @MainActor
    func syncContent(_ newContent: String) {
        guard !isUpdating else { return }
        contentBinding.wrappedValue = newContent
    }

    // MARK: - NSTextViewDelegate

    func textViewDidChangeSelection(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        let selectedRange = textView.selectedRange()
        let content = textView.string
        let nsString = content as NSString
        let location = min(selectedRange.location, nsString.length)
        let upToLocation = nsString.substring(to: location)
        let line = upToLocation.components(separatedBy: "\n").count
        var col = location + 1
        if let lastNewline = upToLocation.lastIndex(of: "\n") {
            col = upToLocation.distance(from: upToLocation.index(after: lastNewline), to: upToLocation.endIndex) + 1
        }

        let capturedLine = line
        let capturedCol = col

        Task { @MainActor [weak self] in
            self?.onCursorChange?(capturedLine, capturedCol)
            if let tv = self?.textView,
               let rulerView = tv.enclosingScrollView?.verticalRulerView {
                rulerView.needsDisplay = true
            }
        }
    }

    @objc func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        let newContent = String(textView.string)

        Task { @MainActor [weak self] in
            self?.syncContent(newContent)
        }
    }
}

// MARK: - EditorFindDelegate conformance on SublimeTextView

extension SublimeTextView: @preconcurrency EditorFindDelegate {
    func highlightMatches(_ matches: [NSRange], currentIndex: Int) {
        guard let layoutManager = layoutManager, let textStorage = textStorage else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)

        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)

        guard !matches.isEmpty, let theme = editorTheme else { return }

        for (i, range) in matches.enumerated() {
            guard range.location + range.length <= textStorage.length else { continue }
            let color = (i == currentIndex || currentIndex == -1)
                ? theme.currentMatchHighlight
                : theme.matchHighlight
            layoutManager.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: range)
        }

        if currentIndex >= 0, currentIndex < matches.count {
            scrollRangeToVisible(matches[currentIndex])
        }
    }

    func selectAllMatches(_ matches: [NSRange]) {
        guard !matches.isEmpty else { return }
        clearHighlights()
        let nsValues = matches.map { NSValue(range: $0) }
        setSelectedRanges(nsValues, affinity: .upstream, stillSelecting: false)
    }

    func scrollToMatch(at range: NSRange) {
        scrollRangeToVisible(range)
    }

    func clearHighlights() {
        guard let layoutManager = layoutManager, let textStorage = textStorage else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
    }
}
#endif
