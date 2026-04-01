import SwiftUI

struct MailComposeView: View {
    let onSend: (([String], String, String) async -> Void)

    @Environment(\.ireneTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var recipientField: String = ""
    @State private var subjectField: String = ""
    @State private var bodyField: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Compose")
                    .font(Typography.bodySemiBold(size: 16))
                    .foregroundStyle(theme.primaryText)
                Spacer()
                Button("Send") { send() }
                    .font(Typography.bodySemiBold(size: 13))
                    .foregroundStyle(theme.accent)
                    .disabled(recipientField.isEmpty || subjectField.isEmpty)
            }
            .padding(16)

            Divider().overlay(theme.border.opacity(0.3))

            VStack(alignment: .leading, spacing: 12) {
                textField("TO", text: $recipientField, placeholder: "recipient@example.com")
                textField("SUBJECT", text: $subjectField, placeholder: "Email subject")

                VStack(alignment: .leading, spacing: 4) {
                    Text("BODY")
                        .font(Typography.label())
                        .tracking(2)
                        .foregroundStyle(theme.secondaryText)

                    TextEditor(text: $bodyField)
                        .font(Typography.body(size: 13))
                        .foregroundStyle(theme.primaryText)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 150)
                        .padding(8)
                        .background(theme.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(16)

            Spacer()
        }
        .background(theme.background)
        .frame(minWidth: 420, minHeight: 400)
    }

    private func textField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Typography.label())
                .tracking(2)
                .foregroundStyle(theme.secondaryText)

            TextField(placeholder, text: text)
                .font(Typography.body(size: 13))
                .textFieldStyle(.plain)
                .foregroundStyle(theme.primaryText)
                .padding(10)
                .background(theme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func send() {
        let recipients = recipientField.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        Task {
            await onSend(recipients, subjectField, bodyField)
            dismiss()
        }
    }
}
