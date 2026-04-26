import SwiftUI

struct MailReplyView: View {
    let originalMessage: MailMessage
    let onSend: ((String) async -> Void)

    @Environment(\.ireneTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var replyBody: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Reply")
                    .font(Typography.bodySemiBold(size: 16))
                    .foregroundStyle(theme.primaryText)
                Spacer()
                Button("Send") { send() }
                    .font(Typography.bodySemiBold(size: 13))
                    .foregroundStyle(theme.accent)
                    .disabled(replyBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)

            Divider().overlay(theme.border.opacity(0.3))

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("TO")
                        .font(Typography.label())
                        .tracking(2)
                        .foregroundStyle(theme.secondaryText)
                    Text(originalMessage.displayFrom)
                        .font(Typography.body(size: 13))
                        .foregroundStyle(theme.primaryText)
                }

                HStack(spacing: 8) {
                    Text("SUBJECT")
                        .font(Typography.label())
                        .tracking(2)
                        .foregroundStyle(theme.secondaryText)
                    let subject = originalMessage.subject.hasPrefix("Re: ") ? originalMessage.subject : "Re: \(originalMessage.subject)"
                    Text(subject)
                        .font(Typography.body(size: 13))
                        .foregroundStyle(theme.primaryText)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("REPLY")
                        .font(Typography.label())
                        .tracking(2)
                        .foregroundStyle(theme.secondaryText)

                    TextEditor(text: $replyBody)
                        .font(Typography.body(size: 13))
                        .foregroundStyle(theme.primaryText)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(theme.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Quoted original message
                VStack(alignment: .leading, spacing: 4) {
                    Text("ORIGINAL MESSAGE")
                        .font(Typography.label())
                        .tracking(2)
                        .foregroundStyle(theme.secondaryText)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("On \(originalMessage.date.formatted()), \(originalMessage.from) wrote:")
                                .font(Typography.caption(size: 11))
                                .foregroundStyle(theme.secondaryText.opacity(0.7))

                            Text(originalMessage.body ?? originalMessage.bodyPreview)
                                .font(Typography.body(size: 12))
                                .foregroundStyle(theme.secondaryText.opacity(0.6))
                        }
                        .padding(10)
                    }
                    .frame(maxHeight: 150)
                    .background(theme.secondaryBackground.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(16)

            Spacer()
        }
        .background(theme.background)
        .frame(minWidth: 420, minHeight: 450)
    }

    private func send() {
        Task {
            await onSend(replyBody)
            dismiss()
        }
    }
}
