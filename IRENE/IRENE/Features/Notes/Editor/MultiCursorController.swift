#if os(macOS)
import AppKit

class MultiCursorController {
    var state = MultiCursorState()
    weak var textView: SublimeTextView?

    // MARK: - Sync from NSTextView

    func syncFromTextView() {
        guard let textView else { return }
        state.selections = textView.selectedRanges.map {
            CursorSelection(range: $0.rangeValue)
        }
    }

    func syncToTextView() {
        guard let textView, !state.selections.isEmpty else { return }
        let ranges = state.selections.map { NSValue(range: $0.range) }
        textView.setSelectedRanges(ranges, affinity: .upstream, stillSelecting: false)
    }

    // MARK: - Cmd+D: Select next occurrence

    func selectNextOccurrence() {
        guard let textView else { return }
        let nsString = textView.string as NSString

        if state.selections.isEmpty {
            syncFromTextView()
        }

        // If current selection is a caret, select the word under it
        if let primary = state.selections.first, primary.isCaret {
            let wordRange = textView.selectionRange(
                forProposedRange: primary.range,
                granularity: .selectByWord
            )
            if wordRange.length > 0 {
                state.selections = [CursorSelection(range: wordRange)]
                syncToTextView()
                return
            }
        }

        // Find the selected text to search for
        guard let searchText = state.selectedText(in: nsString) else { return }

        // Search forward from the last selection
        let lastSelection = state.selections.last!
        let searchStart = NSMaxRange(lastSelection.range)

        // Search from last selection to end
        var searchRange = NSRange(location: searchStart, length: nsString.length - searchStart)
        var found = nsString.range(of: searchText, options: [], range: searchRange)

        // Wrap around if not found
        if found.location == NSNotFound {
            searchRange = NSRange(location: 0, length: state.selections.first!.range.location)
            found = nsString.range(of: searchText, options: [], range: searchRange)
        }

        if found.location != NSNotFound {
            // Check we don't already have this selection
            let alreadySelected = state.selections.contains { $0.range == found }
            if !alreadySelected {
                state.selections.append(CursorSelection(range: found))
                state.normalize()
                syncToTextView()
                // Scroll to the new selection
                textView.scrollRangeToVisible(found)
            }
        }
    }

    // MARK: - Cmd+click: Add cursor

    func addCursor(at characterIndex: Int) {
        syncFromTextView()
        state.selections.append(CursorSelection(range: NSRange(location: characterIndex, length: 0)))
        state.normalize()
        syncToTextView()
    }

    // MARK: - Ctrl+Shift+Up/Down: Add cursor above/below

    func addCursorAbove() {
        guard let textView else { return }
        syncFromTextView()
        guard let primary = state.selections.first else { return }

        let nsString = textView.string as NSString
        let lineRange = nsString.lineRange(for: NSRange(location: primary.range.location, length: 0))
        guard lineRange.location > 0 else { return }

        let col = primary.range.location - lineRange.location
        let prevLineRange = nsString.lineRange(for: NSRange(location: lineRange.location - 1, length: 0))
        let newLocation = prevLineRange.location + min(col, prevLineRange.length - 1)

        state.selections.insert(CursorSelection(range: NSRange(location: newLocation, length: 0)), at: 0)
        state.normalize()
        syncToTextView()
    }

    func addCursorBelow() {
        guard let textView else { return }
        syncFromTextView()
        guard let primary = state.selections.last else { return }

        let nsString = textView.string as NSString
        let lineRange = nsString.lineRange(for: NSRange(location: primary.range.location, length: 0))
        let nextLineStart = NSMaxRange(lineRange)
        guard nextLineStart < nsString.length else { return }

        let col = primary.range.location - lineRange.location
        let nextLineRange = nsString.lineRange(for: NSRange(location: nextLineStart, length: 0))
        let newLocation = nextLineRange.location + min(col, max(nextLineRange.length - 1, 0))

        state.selections.append(CursorSelection(range: NSRange(location: newLocation, length: 0)))
        state.normalize()
        syncToTextView()
    }

    // MARK: - Cmd+Shift+L: Split selection into lines

    func splitSelectionIntoLines() {
        guard let textView else { return }
        syncFromTextView()

        var newSelections: [CursorSelection] = []
        let nsString = textView.string as NSString

        for sel in state.selections {
            if sel.range.length == 0 {
                newSelections.append(sel)
                continue
            }

            // Split this selection into one cursor per line
            var pos = sel.range.location
            while pos < NSMaxRange(sel.range) {
                let lineRange = nsString.lineRange(for: NSRange(location: pos, length: 0))
                let lineEnd = min(NSMaxRange(lineRange) - 1, NSMaxRange(sel.range))
                let cursorPos = min(lineEnd, nsString.length)
                newSelections.append(CursorSelection(range: NSRange(location: cursorPos, length: 0)))
                pos = NSMaxRange(lineRange)
            }
        }

        state.selections = newSelections
        state.normalize()
        syncToTextView()
    }

    // MARK: - Select all occurrences

    func selectAllOccurrences(of text: String) {
        guard let textView else { return }
        let nsString = textView.string as NSString
        var selections: [CursorSelection] = []

        var searchStart = 0
        while searchStart < nsString.length {
            let range = nsString.range(of: text, options: [], range: NSRange(location: searchStart, length: nsString.length - searchStart))
            if range.location == NSNotFound { break }
            selections.append(CursorSelection(range: range))
            searchStart = NSMaxRange(range)
        }

        if !selections.isEmpty {
            state.selections = selections
            syncToTextView()
        }
    }

    // MARK: - Escape: Collapse to single cursor

    func collapseToSingleCursor() {
        guard let primary = state.selections.first else { return }
        let loc = primary.range.location + primary.range.length
        state.selections = [CursorSelection(range: NSRange(location: loc, length: 0))]
        syncToTextView()
    }

    // MARK: - Multi-cursor text operations

    func insertText(_ string: String) {
        guard let textView, let textStorage = textView.textStorage else { return }
        guard !state.selections.isEmpty else { return }

        textStorage.beginEditing()
        textView.undoManager?.beginUndoGrouping()

        // Process last-to-first to preserve offsets
        let sorted = state.selections.sorted { $0.range.location > $1.range.location }
        for cursor in sorted {
            let range = cursor.range
            if textView.shouldChangeText(in: range, replacementString: string) {
                textStorage.replaceCharacters(in: range, with: string)
            }
        }

        textView.undoManager?.endUndoGrouping()
        textStorage.endEditing()
        textView.didChangeText()

        // Recalculate cursor positions (first-to-last, accumulating delta)
        var delta = 0
        var newSelections: [CursorSelection] = []
        let sortedForward = state.selections.sorted { $0.range.location < $1.range.location }
        let insertLength = (string as NSString).length

        for cursor in sortedForward {
            let newLocation = cursor.range.location + delta + insertLength
            delta += insertLength - cursor.range.length
            newSelections.append(CursorSelection(range: NSRange(location: newLocation, length: 0)))
        }

        state.selections = newSelections
        state.normalize()
        syncToTextView()
    }

    func deleteBackward() {
        guard let textView, let textStorage = textView.textStorage else { return }
        guard !state.selections.isEmpty else { return }

        textStorage.beginEditing()
        textView.undoManager?.beginUndoGrouping()

        let sorted = state.selections.sorted { $0.range.location > $1.range.location }
        for cursor in sorted {
            let range: NSRange
            if cursor.range.length > 0 {
                range = cursor.range
            } else if cursor.range.location > 0 {
                range = NSRange(location: cursor.range.location - 1, length: 1)
            } else {
                continue
            }
            if textView.shouldChangeText(in: range, replacementString: "") {
                textStorage.replaceCharacters(in: range, with: "")
            }
        }

        textView.undoManager?.endUndoGrouping()
        textStorage.endEditing()
        textView.didChangeText()

        // Recalculate
        var delta = 0
        var newSelections: [CursorSelection] = []
        let sortedForward = state.selections.sorted { $0.range.location < $1.range.location }

        for cursor in sortedForward {
            let deleteLen = cursor.range.length > 0 ? cursor.range.length : (cursor.range.location > 0 ? 1 : 0)
            let newLocation = max(0, cursor.range.location + delta - (cursor.range.length > 0 ? cursor.range.length : 1) + cursor.range.length)
            let loc = cursor.range.location + delta
            let adjustedLoc = cursor.range.length > 0 ? cursor.range.location + delta : max(0, cursor.range.location + delta - 1)
            delta -= deleteLen
            newSelections.append(CursorSelection(range: NSRange(location: adjustedLoc, length: 0)))
        }

        state.selections = newSelections
        state.normalize()
        syncToTextView()
    }

    func deleteForward() {
        guard let textView, let textStorage = textView.textStorage else { return }
        guard !state.selections.isEmpty else { return }

        textStorage.beginEditing()
        textView.undoManager?.beginUndoGrouping()

        let sorted = state.selections.sorted { $0.range.location > $1.range.location }
        for cursor in sorted {
            let range: NSRange
            if cursor.range.length > 0 {
                range = cursor.range
            } else if cursor.range.location < textStorage.length {
                range = NSRange(location: cursor.range.location, length: 1)
            } else {
                continue
            }
            if textView.shouldChangeText(in: range, replacementString: "") {
                textStorage.replaceCharacters(in: range, with: "")
            }
        }

        textView.undoManager?.endUndoGrouping()
        textStorage.endEditing()
        textView.didChangeText()

        // Recalculate — cursors stay at same position for forward delete
        var delta = 0
        var newSelections: [CursorSelection] = []
        let sortedForward = state.selections.sorted { $0.range.location < $1.range.location }

        for cursor in sortedForward {
            let loc = cursor.range.location + delta
            let deleteLen = cursor.range.length > 0 ? cursor.range.length : 1
            delta -= deleteLen
            newSelections.append(CursorSelection(range: NSRange(location: loc, length: 0)))
        }

        state.selections = newSelections
        state.normalize()
        syncToTextView()
    }
}
#endif
