#if os(macOS)
import SwiftUI
import AppKit

struct SublimeEditorRepresentable: NSViewRepresentable {
    @Binding var content: String
    var theme: ThemeDefinition
    var onCursorChange: ((Int, Int) -> Void)?
    @Binding var coordinatorRef: SublimeEditorCoordinator?

    func makeNSView(context: Context) -> NSScrollView {
        let (scrollView, textView) = SublimeTextView.create(frame: .zero)

        let coordinator = context.coordinator
        coordinator.textView = textView

        // Use NSTextView delegate for selection changes
        textView.delegate = coordinator

        // Listen for text changes via notification
        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(SublimeEditorCoordinator.textDidChange(_:)),
            name: NSText.didChangeNotification,
            object: textView
        )

        coordinator.onCursorChange = onCursorChange

        // Apply theme (sets background, cursor, typing attributes)
        let adapter = EditorThemeAdapter(theme: theme)
        configureTheme(textView: textView, scrollView: scrollView, adapter: adapter)

        // Line number gutter
        let gutterView = LineNumberGutterView(textView: textView)
        gutterView.editorTheme = adapter
        scrollView.hasVerticalRuler = true
        scrollView.verticalRulerView = gutterView
        scrollView.rulersVisible = true

        // Set initial content with proper attributes
        coordinator.isUpdating = true
        setTextContent(textView: textView, text: content, adapter: adapter)
        coordinator.isUpdating = false

        // Expose coordinator reference to parent
        DispatchQueue.main.async {
            self.coordinatorRef = coordinator
        }

        // Make first responder
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? SublimeTextView else { return }
        let coordinator = context.coordinator
        let adapter = EditorThemeAdapter(theme: theme)

        // Always keep theme config up to date (lightweight — just sets colors, no text mutation)
        configureTheme(textView: textView, scrollView: scrollView, adapter: adapter)

        if let gutterView = scrollView.verticalRulerView as? LineNumberGutterView {
            gutterView.editorTheme = adapter
            gutterView.needsDisplay = true
        }

        // Update content if changed externally (not from user typing)
        if textView.string != content {
            coordinator.isUpdating = true
            let selectedRanges = textView.selectedRanges
            setTextContent(textView: textView, text: content, adapter: adapter)

            // Restore cursor position, clamped to new length
            let maxLocation = textView.textStorage?.length ?? 0
            let clampedRanges = selectedRanges.map { nsValue -> NSValue in
                let range = nsValue.rangeValue
                let clampedLoc = min(range.location, maxLocation)
                let clampedLen = min(range.length, maxLocation - clampedLoc)
                return NSValue(range: NSRange(location: clampedLoc, length: clampedLen))
            }
            if !clampedRanges.isEmpty {
                textView.selectedRanges = clampedRanges
            }
            coordinator.isUpdating = false
        }

        coordinator.onCursorChange = onCursorChange
    }

    func makeCoordinator() -> SublimeEditorCoordinator {
        SublimeEditorCoordinator(contentBinding: $content)
    }

    // MARK: - Helpers

    /// Configure theme properties that don't touch textStorage (safe to call repeatedly)
    private func configureTheme(textView: SublimeTextView, scrollView: NSScrollView, adapter: EditorThemeAdapter) {
        textView.backgroundColor = adapter.backgroundColor
        textView.textColor = adapter.textColor
        textView.font = adapter.font
        textView.insertionPointColor = adapter.cursorColor
        textView.selectedTextAttributes = [.backgroundColor: adapter.selectionColor]
        textView.typingAttributes = [
            .font: adapter.font,
            .foregroundColor: adapter.textColor
        ]
        textView.editorTheme = adapter
        scrollView.backgroundColor = adapter.backgroundColor
    }

    /// Set text content
    private func setTextContent(textView: SublimeTextView, text: String, adapter: EditorThemeAdapter) {
        textView.string = text
        textView.textColor = adapter.textColor
        textView.font = adapter.font
    }
}
#endif
