import SwiftUI

struct StickyQuickCaptureView: View {
    let onSave: (String) -> Void

    @Environment(\.ireneTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var content: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Quick Sticky")
                    .font(Typography.bodySemiBold(size: 14))
                    .foregroundStyle(theme.primaryText)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.secondaryText.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            TextEditor(text: $content)
                .font(Typography.body(size: 14))
                .foregroundStyle(theme.primaryText)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(8)
                .background(theme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .focused($isFocused)

            HStack {
                Spacer()
                Button {
                    guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    onSave(content)
                    dismiss()
                } label: {
                    Text("Save")
                        .font(Typography.button(size: 12))
                        .textCase(.uppercase)
                        .tracking(1)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(theme.accent)
                        .foregroundStyle(theme.isDark ? Color.black : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(16)
        .background(theme.background)
        .frame(width: 320)
        .onAppear {
            isFocused = true
        }
    }
}
