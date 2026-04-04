#if os(macOS)
import Testing
import Foundation
import AppKit
@testable import IRENE

@Suite("SublimeTextView Line Operations Tests")
struct SublimeTextViewLineOpsTests {

    @MainActor
    private func makeTextView(_ content: String) -> SublimeTextView {
        let (_, textView) = SublimeTextView.create(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        textView.string = content
        return textView
    }

    // MARK: - Indent / Outdent

    @MainActor @Test("indentSelectedLines adds 4 spaces to each line")
    func indent() {
        let textView = makeTextView("line1\nline2\nline3")
        // Select all 3 lines
        textView.setSelectedRange(NSRange(location: 0, length: 17))
        textView.indentSelectedLines()

        let lines = textView.string.components(separatedBy: "\n")
        #expect(lines[0].hasPrefix("    "))
        #expect(lines[1].hasPrefix("    "))
        #expect(lines[2].hasPrefix("    "))
    }

    @MainActor @Test("outdentSelectedLines removes up to 4 spaces")
    func outdent() {
        let textView = makeTextView("    line1\n    line2\n    line3")
        textView.setSelectedRange(NSRange(location: 0, length: textView.string.count))
        textView.outdentSelectedLines()

        let lines = textView.string.components(separatedBy: "\n")
        #expect(lines[0] == "line1")
        #expect(lines[1] == "line2")
        #expect(lines[2] == "line3")
    }

    @MainActor @Test("outdent removes partial indent (less than 4 spaces)")
    func outdentPartial() {
        let textView = makeTextView("  line1")
        textView.setSelectedRange(NSRange(location: 0, length: textView.string.count))
        textView.outdentSelectedLines()

        #expect(textView.string == "line1")
    }

    @MainActor @Test("indent then outdent is identity")
    func indentOutdentRoundtrip() {
        let original = "line1\nline2"
        let textView = makeTextView(original)
        textView.setSelectedRange(NSRange(location: 0, length: textView.string.count))
        textView.indentSelectedLines()
        textView.setSelectedRange(NSRange(location: 0, length: textView.string.count))
        textView.outdentSelectedLines()

        #expect(textView.string == original)
    }

    // MARK: - Duplicate Line

    @MainActor @Test("duplicateLine duplicates the current line")
    func duplicateLine() {
        let textView = makeTextView("hello\nworld")
        textView.setSelectedRange(NSRange(location: 1, length: 0)) // in "hello"
        textView.duplicateLine()

        let lines = textView.string.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "hello")
        #expect(lines[1] == "hello")
        #expect(lines[2] == "world")
    }

    // MARK: - Delete Line

    @MainActor @Test("deleteLine removes the current line")
    func deleteCurrentLine() {
        let textView = makeTextView("hello\nworld\ntest")
        textView.setSelectedRange(NSRange(location: 7, length: 0)) // in "world"
        textView.deleteLine()

        let lines = textView.string.components(separatedBy: "\n")
        #expect(lines.count == 2)
        #expect(lines[0] == "hello")
        #expect(lines[1] == "test")
    }

    @MainActor @Test("deleteLine on single line clears content")
    func deleteOnlyLine() {
        let textView = makeTextView("hello")
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.deleteLine()

        #expect(textView.string == "")
    }

    // MARK: - Toggle Comment

    @MainActor @Test("toggleLineComment adds // to uncommented line")
    func commentLine() {
        let textView = makeTextView("hello\nworld")
        textView.setSelectedRange(NSRange(location: 1, length: 0)) // in "hello"
        textView.toggleLineComment()

        let lines = textView.string.components(separatedBy: "\n")
        #expect(lines[0] == "// hello")
        #expect(lines[1] == "world") // unchanged
    }

    @MainActor @Test("toggleLineComment removes // from commented line")
    func uncommentLine() {
        let textView = makeTextView("// hello\nworld")
        textView.setSelectedRange(NSRange(location: 1, length: 0))
        textView.toggleLineComment()

        let lines = textView.string.components(separatedBy: "\n")
        #expect(lines[0] == "hello")
    }

    @MainActor @Test("toggleLineComment on multiple selected lines")
    func commentMultipleLines() {
        let textView = makeTextView("aaa\nbbb\nccc")
        textView.setSelectedRange(NSRange(location: 0, length: 11))
        textView.toggleLineComment()

        let lines = textView.string.components(separatedBy: "\n")
        #expect(lines[0].hasPrefix("// "))
        #expect(lines[1].hasPrefix("// "))
        #expect(lines[2].hasPrefix("// "))
    }

    @MainActor @Test("toggleLineComment uncomments all if all commented")
    func uncommentMultiple() {
        let textView = makeTextView("// aaa\n// bbb\n// ccc")
        textView.setSelectedRange(NSRange(location: 0, length: textView.string.count))
        textView.toggleLineComment()

        let lines = textView.string.components(separatedBy: "\n")
        #expect(!lines[0].hasPrefix("//"))
        #expect(!lines[1].hasPrefix("//"))
        #expect(!lines[2].hasPrefix("//"))
    }

    // MARK: - Select Entire Line

    @MainActor @Test("selectEntireLine selects the full line")
    func selectLine() {
        let textView = makeTextView("hello\nworld\ntest")
        textView.setSelectedRange(NSRange(location: 7, length: 0)) // in "world"
        textView.selectEntireLine()

        let range = textView.selectedRange()
        let selected = (textView.string as NSString).substring(with: range)
        #expect(selected == "world\n")
    }

    // MARK: - Move Line Up/Down

    @MainActor @Test("moveLineDown swaps line with next")
    func moveDown() {
        let textView = makeTextView("aaa\nbbb\nccc")
        textView.setSelectedRange(NSRange(location: 1, length: 0)) // in "aaa"
        textView.moveLineDown()

        let lines = textView.string.components(separatedBy: "\n")
        #expect(lines[0] == "bbb")
        #expect(lines[1] == "aaa")
        #expect(lines[2] == "ccc")
    }

    @MainActor @Test("moveLineUp swaps line with previous")
    func moveUp() {
        let textView = makeTextView("aaa\nbbb\nccc")
        textView.setSelectedRange(NSRange(location: 5, length: 0)) // in "bbb"
        textView.moveLineUp()

        let lines = textView.string.components(separatedBy: "\n")
        #expect(lines[0] == "bbb")
        #expect(lines[1] == "aaa")
        #expect(lines[2] == "ccc")
    }

    @MainActor @Test("moveLineUp on first line does nothing")
    func moveUpFirstLine() {
        let original = "aaa\nbbb"
        let textView = makeTextView(original)
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.moveLineUp()

        #expect(textView.string == original)
    }

    @MainActor @Test("moveLineDown on last line does nothing")
    func moveDownLastLine() {
        let original = "aaa\nbbb"
        let textView = makeTextView(original)
        textView.setSelectedRange(NSRange(location: 5, length: 0)) // in "bbb"
        textView.moveLineDown()

        #expect(textView.string == original)
    }
}

@Suite("SublimeTextView Tab/Newline Tests")
struct SublimeTextViewTabTests {

    @MainActor
    private func makeTextView(_ content: String) -> SublimeTextView {
        let (_, textView) = SublimeTextView.create(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        textView.string = content
        return textView
    }

    @MainActor @Test("insertTab with no selection inserts 4 spaces")
    func tabInsertsSpaces() {
        let textView = makeTextView("hello")
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.insertTab(nil)

        #expect(textView.string.hasPrefix("    hello"))
    }

    @MainActor @Test("insertTab with selection indents lines")
    func tabWithSelectionIndents() {
        let textView = makeTextView("line1\nline2")
        textView.setSelectedRange(NSRange(location: 0, length: 11))
        textView.insertTab(nil)

        #expect(textView.string.hasPrefix("    line1"))
    }
}

@Suite("EditorThemeAdapter Tests")
struct EditorThemeAdapterTests {

    @Test("EditorThemeAdapter creates colors from theme")
    func createsColors() {
        let theme = ThemeManager.fallbackTheme
        let adapter = EditorThemeAdapter(theme: theme)

        // Just verify they're not nil/crash
        #expect(adapter.backgroundColor != NSColor.clear)
        #expect(adapter.textColor != NSColor.clear)
        #expect(adapter.cursorColor != NSColor.clear)
        #expect(adapter.selectionColor != NSColor.clear)
        #expect(adapter.font.pointSize == 14)
    }

    @Test("EditorThemeAdapter font is monospaced")
    func fontIsMonospaced() {
        let theme = ThemeManager.fallbackTheme
        let adapter = EditorThemeAdapter(theme: theme)

        #expect(adapter.font.isFixedPitch)
    }
}
#endif
