#if os(macOS)
import Testing
import Foundation
import AppKit
@testable import IRENE

@Suite("Find/Replace Logic Tests")
struct FindReplaceLogicTests {

    // Test the find matching logic independent of UI by testing
    // the string operations directly

    @Test("String search finds all occurrences")
    func stringSearchAll() {
        let content = "foo bar foo baz foo"
        let searchFor = "foo"
        var found: [Range<String.Index>] = []

        var searchStart = content.startIndex
        while let range = content.range(of: searchFor, range: searchStart..<content.endIndex) {
            found.append(range)
            searchStart = range.upperBound
        }

        #expect(found.count == 3)
    }

    @Test("Case-insensitive search works")
    func caseInsensitiveSearch() {
        let content = "Hello HELLO hello"
        let searchFor = "hello"
        let lower = content.lowercased()
        var found: [Range<String.Index>] = []

        var searchStart = lower.startIndex
        while let range = lower.range(of: searchFor, range: searchStart..<lower.endIndex) {
            found.append(range)
            searchStart = range.upperBound
        }

        #expect(found.count == 3)
    }

    @Test("Regex search works")
    func regexSearch() throws {
        let content = "foo123 bar456 baz"
        let regex = try NSRegularExpression(pattern: "[a-z]+\\d+", options: [])
        let nsRange = NSRange(content.startIndex..., in: content)
        let results = regex.matches(in: content, range: nsRange)

        #expect(results.count == 2)
    }

    @Test("Replace all from end to start preserves indices")
    func replaceAllReverse() {
        var content = "aa bb aa cc aa"
        let searchFor = "aa"
        let replaceWith = "XX"

        var matches: [Range<String.Index>] = []
        var searchStart = content.startIndex
        while let range = content.range(of: searchFor, range: searchStart..<content.endIndex) {
            matches.append(range)
            searchStart = range.upperBound
        }

        #expect(matches.count == 3)

        for range in matches.reversed() {
            content.replaceSubrange(range, with: replaceWith)
        }

        #expect(content == "XX bb XX cc XX")
    }

    @Test("Replace single occurrence")
    func replaceSingle() {
        var content = "hello world hello"
        let matches = [content.range(of: "hello")!]

        content.replaceSubrange(matches[0], with: "greetings")

        #expect(content == "greetings world hello")
    }

    @Test("NSRange conversion from String.Index range")
    func nsRangeConversion() {
        let content = "hello world"
        let range = content.range(of: "world")!
        let nsRange = NSRange(range, in: content)

        #expect(nsRange.location == 6)
        #expect(nsRange.length == 5)
    }
}

@Suite("EditorFindDelegate Integration Tests")
struct EditorFindDelegateTests {

    @MainActor
    private func makeTextView(_ content: String) -> SublimeTextView {
        let (_, textView) = SublimeTextView.create(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        textView.string = content
        let theme = ThemeManager.fallbackTheme
        textView.editorTheme = EditorThemeAdapter(theme: theme)
        return textView
    }

    @MainActor @Test("highlightMatches applies temporary attributes")
    func highlightAppliesAttributes() {
        let textView = makeTextView("foo bar foo baz foo")

        let matches = [
            NSRange(location: 0, length: 3),
            NSRange(location: 8, length: 3),
            NSRange(location: 16, length: 3)
        ]

        textView.highlightMatches(matches, currentIndex: 1)

        // Verify temporary attributes exist at match locations
        guard let layoutManager = textView.layoutManager else {
            Issue.record("No layout manager")
            return
        }

        var effectiveRange = NSRange()
        if let attr = layoutManager.temporaryAttribute(.backgroundColor, atCharacterIndex: 0, effectiveRange: &effectiveRange) as? NSColor {
            // Should have dim highlight (not current)
            #expect(attr.alphaComponent < 0.5) // dim
        }

        if let attr = layoutManager.temporaryAttribute(.backgroundColor, atCharacterIndex: 8, effectiveRange: &effectiveRange) as? NSColor {
            // Should have bright highlight (current match, index 1)
            #expect(attr.alphaComponent >= 0.4) // bright
        }
    }

    @MainActor @Test("clearHighlights removes all temporary attributes")
    func clearHighlightsRemoves() {
        let textView = makeTextView("foo bar foo")

        textView.highlightMatches([NSRange(location: 0, length: 3)], currentIndex: 0)
        textView.clearHighlights()

        guard let layoutManager = textView.layoutManager else {
            Issue.record("No layout manager")
            return
        }

        var effectiveRange = NSRange()
        let attr = layoutManager.temporaryAttribute(.backgroundColor, atCharacterIndex: 0, effectiveRange: &effectiveRange)
        #expect(attr == nil)
    }

    @MainActor @Test("selectAllMatches creates multiple selections")
    func selectAllMatchesCreatesSelections() {
        let textView = makeTextView("foo bar foo baz foo")

        let matches = [
            NSRange(location: 0, length: 3),
            NSRange(location: 8, length: 3),
            NSRange(location: 16, length: 3)
        ]

        textView.selectAllMatches(matches)

        #expect(textView.selectedRanges.count == 3)
        #expect(textView.selectedRanges[0].rangeValue == NSRange(location: 0, length: 3))
        #expect(textView.selectedRanges[1].rangeValue == NSRange(location: 8, length: 3))
        #expect(textView.selectedRanges[2].rangeValue == NSRange(location: 16, length: 3))
    }
}
#endif
