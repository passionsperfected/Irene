import SwiftUI

struct ToDoQuickCaptureView: View {
    let onSave: (String) -> Void

    @Environment(\.ireneTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Quick Task")
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

            TextField("What needs to be done?", text: $title)
                .font(Typography.body(size: 14))
                .textFieldStyle(.plain)
                .foregroundStyle(theme.primaryText)
                .focused($isFocused)
                .padding(10)
                .background(theme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onSubmit {
                    save()
                }

            HStack {
                Text("Added to Inbox")
                    .font(Typography.caption(size: 10))
                    .foregroundStyle(theme.secondaryText.opacity(0.5))
                Spacer()
                Button(action: save) {
                    Text("Add")
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
        .onAppear { isFocused = true }
    }

    private func save() {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        onSave(cleaned)
        dismiss()
    }
}
