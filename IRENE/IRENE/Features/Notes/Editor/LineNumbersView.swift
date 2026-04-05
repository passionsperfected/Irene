import SwiftUI

/// Pure SwiftUI line numbers gutter that sits alongside a TextEditor.
/// Derives line count from the content string — no NSTextView interaction.
struct LineNumbersView: View {
    let content: String
    let fontSize: CGFloat

    @Environment(\.ireneTheme) private var theme

    private var lineCount: Int {
        max(content.components(separatedBy: "\n").count, 1)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(1...lineCount, id: \.self) { number in
                    Text("\(number)")
                        .font(.system(size: fontSize - 2, design: .monospaced))
                        .foregroundStyle(theme.secondaryText.opacity(0.35))
                        .frame(height: fontSize * 1.53) // match TextEditor line height
                        .frame(minWidth: gutterWidth, alignment: .trailing)
                }
            }
            .padding(.top, 9) // align with TextEditor's top padding
        }
        .scrollDisabled(true) // will be synced by parent if needed
        .frame(width: gutterWidth + 8)
        .background(theme.secondaryBackground.opacity(0.3))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(theme.border.opacity(0.15))
                .frame(width: 1)
        }
    }

    private var gutterWidth: CGFloat {
        let digits = max(String(lineCount).count, 2)
        return CGFloat(digits) * (fontSize * 0.62) + 8
    }
}
