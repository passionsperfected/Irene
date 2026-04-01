import SwiftUI

struct ReminderQuickCaptureView: View {
    let onSave: (String, Date) -> Void

    @Environment(\.ireneTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var date: Date = Date().addingTimeInterval(3600)
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Quick Reminder")
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

            TextField("Remind me to...", text: $title)
                .font(Typography.body(size: 14))
                .textFieldStyle(.plain)
                .foregroundStyle(theme.primaryText)
                .focused($isFocused)
                .padding(10)
                .background(theme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onSubmit { save() }

            DatePicker(
                "When",
                selection: $date,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(Typography.body(size: 12))
            .foregroundStyle(theme.primaryText)

            HStack {
                // Quick time buttons
                ForEach([
                    ("1h", TimeInterval(3600)),
                    ("3h", TimeInterval(10800)),
                    ("Tomorrow", TimeInterval(86400))
                ], id: \.0) { label, offset in
                    Button {
                        date = Date().addingTimeInterval(offset)
                    } label: {
                        Text(label)
                            .font(Typography.caption(size: 9))
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.accent.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button(action: save) {
                    Text("Set")
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
        .frame(width: 340)
        .onAppear { isFocused = true }
    }

    private func save() {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        onSave(cleaned, date)
        dismiss()
    }
}
