#if os(macOS)
import Foundation

struct CursorSelection: Hashable {
    var range: NSRange

    var isCaret: Bool { range.length == 0 }
    var insertionPoint: Int { range.location + range.length }
}

struct MultiCursorState {
    var selections: [CursorSelection] = []

    var isSingleCursor: Bool { selections.count <= 1 }

    var primarySelection: CursorSelection? { selections.first }

    /// Sort by location and merge overlapping ranges
    mutating func normalize() {
        guard selections.count > 1 else { return }

        selections.sort { $0.range.location < $1.range.location }

        var merged: [CursorSelection] = [selections[0]]
        for i in 1..<selections.count {
            let current = selections[i]
            let last = merged[merged.count - 1]

            if current.range.location <= NSMaxRange(last.range) {
                // Overlapping or adjacent — merge
                let newEnd = max(NSMaxRange(last.range), NSMaxRange(current.range))
                merged[merged.count - 1] = CursorSelection(
                    range: NSRange(location: last.range.location, length: newEnd - last.range.location)
                )
            } else {
                merged.append(current)
            }
        }
        selections = merged
    }

    /// The currently selected text (for Cmd+D matching). Uses the first selection with length > 0.
    func selectedText(in string: NSString) -> String? {
        for sel in selections {
            if sel.range.length > 0 && NSMaxRange(sel.range) <= string.length {
                return string.substring(with: sel.range)
            }
        }
        return nil
    }
}
#endif
