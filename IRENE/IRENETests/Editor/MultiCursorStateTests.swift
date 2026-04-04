#if os(macOS)
import Testing
import Foundation
@testable import IRENE

@Suite("MultiCursorState Tests")
struct MultiCursorStateTests {

    // MARK: - Basic Properties

    @Test("Empty state is single cursor")
    func emptyIsSingle() {
        let state = MultiCursorState()
        #expect(state.isSingleCursor)
        #expect(state.primarySelection == nil)
    }

    @Test("Single cursor is single")
    func singleCursor() {
        var state = MultiCursorState()
        state.selections = [CursorSelection(range: NSRange(location: 5, length: 0))]
        #expect(state.isSingleCursor)
        #expect(state.primarySelection?.range.location == 5)
    }

    @Test("Two cursors is not single")
    func multipleCursors() {
        var state = MultiCursorState()
        state.selections = [
            CursorSelection(range: NSRange(location: 5, length: 0)),
            CursorSelection(range: NSRange(location: 10, length: 0))
        ]
        #expect(!state.isSingleCursor)
    }

    // MARK: - Caret vs Selection

    @Test("Zero-length range is caret")
    func caretDetection() {
        let sel = CursorSelection(range: NSRange(location: 5, length: 0))
        #expect(sel.isCaret)
        #expect(sel.insertionPoint == 5)
    }

    @Test("Non-zero length range is selection")
    func selectionDetection() {
        let sel = CursorSelection(range: NSRange(location: 5, length: 3))
        #expect(!sel.isCaret)
        #expect(sel.insertionPoint == 8)
    }

    // MARK: - Normalize

    @Test("Normalize sorts by location")
    func normalizeSorts() {
        var state = MultiCursorState()
        state.selections = [
            CursorSelection(range: NSRange(location: 20, length: 0)),
            CursorSelection(range: NSRange(location: 5, length: 0)),
            CursorSelection(range: NSRange(location: 10, length: 0))
        ]
        state.normalize()
        #expect(state.selections[0].range.location == 5)
        #expect(state.selections[1].range.location == 10)
        #expect(state.selections[2].range.location == 20)
    }

    @Test("Normalize merges overlapping selections")
    func normalizeMergesOverlapping() {
        var state = MultiCursorState()
        state.selections = [
            CursorSelection(range: NSRange(location: 5, length: 5)),  // 5-10
            CursorSelection(range: NSRange(location: 8, length: 5))   // 8-13
        ]
        state.normalize()
        #expect(state.selections.count == 1)
        #expect(state.selections[0].range.location == 5)
        #expect(state.selections[0].range.length == 8) // 5 to 13
    }

    @Test("Normalize merges adjacent selections")
    func normalizeMergesAdjacent() {
        var state = MultiCursorState()
        state.selections = [
            CursorSelection(range: NSRange(location: 5, length: 5)),  // 5-10
            CursorSelection(range: NSRange(location: 10, length: 5))  // 10-15
        ]
        state.normalize()
        #expect(state.selections.count == 1)
        #expect(state.selections[0].range.location == 5)
        #expect(state.selections[0].range.length == 10)
    }

    @Test("Normalize keeps non-overlapping separate")
    func normalizeKeepsSeparate() {
        var state = MultiCursorState()
        state.selections = [
            CursorSelection(range: NSRange(location: 5, length: 2)),
            CursorSelection(range: NSRange(location: 20, length: 3))
        ]
        state.normalize()
        #expect(state.selections.count == 2)
    }

    @Test("Normalize handles single selection")
    func normalizeSingle() {
        var state = MultiCursorState()
        state.selections = [CursorSelection(range: NSRange(location: 5, length: 0))]
        state.normalize()
        #expect(state.selections.count == 1)
    }

    @Test("Normalize handles empty")
    func normalizeEmpty() {
        var state = MultiCursorState()
        state.normalize()
        #expect(state.selections.isEmpty)
    }

    // MARK: - Selected Text

    @Test("selectedText returns first selection with length")
    func selectedTextReturnsFirstSelection() {
        var state = MultiCursorState()
        state.selections = [
            CursorSelection(range: NSRange(location: 0, length: 0)),  // caret
            CursorSelection(range: NSRange(location: 6, length: 5))   // "world"
        ]
        let nsString = NSString(string: "hello world test")
        let text = state.selectedText(in: nsString)
        #expect(text == "world")
    }

    @Test("selectedText returns nil for all carets")
    func selectedTextNilForCarets() {
        var state = MultiCursorState()
        state.selections = [
            CursorSelection(range: NSRange(location: 0, length: 0)),
            CursorSelection(range: NSRange(location: 5, length: 0))
        ]
        let nsString = NSString(string: "hello world")
        #expect(state.selectedText(in: nsString) == nil)
    }

    @Test("selectedText guards against out-of-bounds")
    func selectedTextOutOfBounds() {
        var state = MultiCursorState()
        state.selections = [
            CursorSelection(range: NSRange(location: 50, length: 5))
        ]
        let nsString = NSString(string: "short")
        #expect(state.selectedText(in: nsString) == nil)
    }
}

@Suite("MultiCursorController Tests")
struct MultiCursorControllerTests {

    // Helper to create a text view with content
    @MainActor
    private func makeTextView(_ content: String) -> SublimeTextView {
        let (_, textView) = SublimeTextView.create(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        textView.string = content
        return textView
    }

    // MARK: - Select Next Occurrence (Cmd+D)

    @MainActor @Test("selectNextOccurrence selects word under caret")
    func selectNextOccurrenceWord() {
        let textView = makeTextView("hello world hello")
        textView.setSelectedRange(NSRange(location: 1, length: 0)) // inside "hello"

        let controller = textView.multiCursor
        controller.syncFromTextView()
        controller.selectNextOccurrence()

        // Should have selected "hello" (the word under cursor)
        #expect(controller.state.selections.count == 1)
        #expect(controller.state.selections[0].range.length > 0)
    }

    @MainActor @Test("selectNextOccurrence adds second occurrence")
    func selectNextOccurrenceAddsSecond() {
        let textView = makeTextView("hello world hello")
        // Select the first "hello"
        textView.setSelectedRange(NSRange(location: 0, length: 5))

        let controller = textView.multiCursor
        controller.syncFromTextView()
        controller.selectNextOccurrence()

        // Should now have 2 selections: both "hello"
        #expect(controller.state.selections.count == 2)
        #expect(controller.state.selections[0].range == NSRange(location: 0, length: 5))
        #expect(controller.state.selections[1].range == NSRange(location: 12, length: 5))
    }

    // MARK: - Add Cursor (Cmd+click)

    @MainActor @Test("addCursor adds cursor at location")
    func addCursorAtLocation() {
        let textView = makeTextView("hello world")
        textView.setSelectedRange(NSRange(location: 0, length: 0))

        let controller = textView.multiCursor
        controller.addCursor(at: 6)

        #expect(controller.state.selections.count == 2)
    }

    // MARK: - Add Cursor Above/Below

    @MainActor @Test("addCursorBelow adds cursor on next line")
    func addCursorBelow() {
        let textView = makeTextView("hello\nworld\ntest")
        textView.setSelectedRange(NSRange(location: 2, length: 0)) // line 1, col 2

        let controller = textView.multiCursor
        controller.syncFromTextView()
        controller.addCursorBelow()

        #expect(controller.state.selections.count == 2)
        // Second cursor should be on line 2 at similar column
        let secondLoc = controller.state.selections[1].range.location
        #expect(secondLoc >= 6) // at least at start of "world"
        #expect(secondLoc <= 11) // within "world\n"
    }

    @MainActor @Test("addCursorAbove adds cursor on previous line")
    func addCursorAbove() {
        let textView = makeTextView("hello\nworld\ntest")
        textView.setSelectedRange(NSRange(location: 8, length: 0)) // line 2, col 2

        let controller = textView.multiCursor
        controller.syncFromTextView()
        controller.addCursorAbove()

        #expect(controller.state.selections.count == 2)
        // First cursor should be on line 1
        let firstLoc = controller.state.selections[0].range.location
        #expect(firstLoc < 6) // within "hello\n"
    }

    // MARK: - Split Selection Into Lines

    @MainActor @Test("splitSelectionIntoLines creates cursor per line")
    func splitIntoLines() {
        let textView = makeTextView("aaa\nbbb\nccc\nddd")
        // Select lines 2-3 ("bbb\nccc\n")
        textView.setSelectedRange(NSRange(location: 4, length: 8))

        let controller = textView.multiCursor
        controller.syncFromTextView()
        controller.splitSelectionIntoLines()

        #expect(controller.state.selections.count >= 2)
        // All should be carets
        for sel in controller.state.selections {
            #expect(sel.isCaret)
        }
    }

    // MARK: - Collapse

    @MainActor @Test("collapseToSingleCursor reduces to one")
    func collapse() {
        let textView = makeTextView("hello world hello")
        let controller = textView.multiCursor
        controller.state.selections = [
            CursorSelection(range: NSRange(location: 0, length: 5)),
            CursorSelection(range: NSRange(location: 12, length: 5))
        ]
        controller.syncToTextView()

        controller.collapseToSingleCursor()

        #expect(controller.state.selections.count == 1)
        #expect(controller.state.selections[0].isCaret)
    }

    // MARK: - Multi-cursor Insert

    @MainActor @Test("insertText at multiple cursors")
    func multiInsert() {
        let textView = makeTextView("aa bb aa")
        let controller = textView.multiCursor
        // Place cursors at position 0 and position 6 (before each "aa")
        controller.state.selections = [
            CursorSelection(range: NSRange(location: 0, length: 2)), // select first "aa"
            CursorSelection(range: NSRange(location: 6, length: 2))  // select second "aa"
        ]
        controller.syncToTextView()

        controller.insertText("XX")

        // Both "aa" should be replaced with "XX"
        #expect(textView.string == "XX bb XX")
    }

    @MainActor @Test("insertText at carets inserts at each position")
    func multiInsertAtCarets() {
        let textView = makeTextView("hello world")
        let controller = textView.multiCursor
        controller.state.selections = [
            CursorSelection(range: NSRange(location: 5, length: 0)),  // after "hello"
            CursorSelection(range: NSRange(location: 11, length: 0))  // after "world"
        ]
        controller.syncToTextView()

        controller.insertText("!")

        #expect(textView.string == "hello! world!")
    }

    // MARK: - Multi-cursor Delete

    @MainActor @Test("deleteBackward at multiple cursors")
    func multiDeleteBackward() {
        let textView = makeTextView("aXb cXd")
        let controller = textView.multiCursor
        // Place cursors after each "X" (positions 2 and 6)
        controller.state.selections = [
            CursorSelection(range: NSRange(location: 2, length: 0)),
            CursorSelection(range: NSRange(location: 6, length: 0))
        ]
        controller.syncToTextView()

        controller.deleteBackward()

        // Should delete the "X" before each cursor
        #expect(textView.string == "ab cd")
    }

    // MARK: - Select All Occurrences

    @MainActor @Test("selectAllOccurrences finds all matches")
    func selectAll() {
        let textView = makeTextView("foo bar foo baz foo")
        let controller = textView.multiCursor

        controller.selectAllOccurrences(of: "foo")

        #expect(controller.state.selections.count == 3)
        #expect(controller.state.selections[0].range == NSRange(location: 0, length: 3))
        #expect(controller.state.selections[1].range == NSRange(location: 8, length: 3))
        #expect(controller.state.selections[2].range == NSRange(location: 16, length: 3))
    }

    @MainActor @Test("selectAllOccurrences with no matches is empty")
    func selectAllNoMatch() {
        let textView = makeTextView("hello world")
        let controller = textView.multiCursor

        controller.selectAllOccurrences(of: "xyz")

        #expect(controller.state.selections.isEmpty)
    }
}
#endif
