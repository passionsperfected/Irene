import SwiftUI

struct MailModuleView: View {
    @State private var viewModel = MailViewModel()
    @State private var showCompose = false

    @Environment(\.ireneTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(theme.border.opacity(0.3))

            if !viewModel.canRead {
                platformLimitationView
            } else if viewModel.messages.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    icon: "envelope",
                    title: "No Messages",
                    message: "Your inbox is empty or Mail.app is not running",
                    action: { Task { await viewModel.loadInbox() } },
                    actionLabel: "Refresh"
                )
            } else {
                mailContent
            }
        }
        .background(theme.background)
        .task {
            if viewModel.canRead {
                await viewModel.loadInbox()
            }
        }
        .sheet(isPresented: $showCompose) {
            MailComposeView { recipients, subject, body in
                await viewModel.sendMessage(to: recipients, subject: subject, body: body)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("Mail")
                .font(Typography.bodySemiBold(size: 14))
                .foregroundStyle(theme.primaryText)

            Spacer()

            if viewModel.canRead {
                Button {
                    Task { await viewModel.loadInbox() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.secondaryText)
                }
                .buttonStyle(.plain)
            }

            Button { showCompose = true } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var mailContent: some View {
        HSplitView {
            // Message list
            List(viewModel.messages) { message in
                Button {
                    viewModel.selectedMessage = message
                    Task { await viewModel.loadFullMessage(message) }
                } label: {
                    messageRow(message)
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    viewModel.selectedMessage?.id == message.id
                        ? theme.accent.opacity(0.1)
                        : Color.clear
                )
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(minWidth: 280, maxWidth: 350)

            // Message detail
            if let selected = viewModel.selectedMessage {
                messageDetail(selected)
            } else {
                EmptyStateView(
                    icon: "envelope.open",
                    title: "Select a Message",
                    message: "Choose a message to read"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.background)
            }
        }
    }

    private func messageRow(_ message: MailMessage) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Circle()
                    .fill(message.isRead ? Color.clear : theme.accent)
                    .frame(width: 6, height: 6)

                Text(message.from)
                    .font(Typography.bodySemiBold(size: 12))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)

                Spacer()

                Text(message.date, style: .relative)
                    .font(Typography.caption(size: 9))
                    .foregroundStyle(theme.secondaryText.opacity(0.5))
            }

            Text(message.subject)
                .font(Typography.body(size: 12))
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)

            if !message.bodyPreview.isEmpty {
                Text(message.bodyPreview)
                    .font(Typography.body(size: 11))
                    .foregroundStyle(theme.secondaryText.opacity(0.6))
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private func messageDetail(_ message: MailMessage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(message.subject)
                    .font(Typography.subheading(size: 18))
                    .foregroundStyle(theme.primaryText)

                HStack {
                    Text("From: \(message.from)")
                        .font(Typography.body(size: 12))
                        .foregroundStyle(theme.secondaryText)
                    Spacer()
                    Text(message.date.formatted())
                        .font(Typography.caption(size: 10))
                        .foregroundStyle(theme.secondaryText.opacity(0.6))
                }

                Divider().overlay(theme.border.opacity(0.3))

                Text(message.body ?? message.bodyPreview)
                    .font(Typography.body(size: 13))
                    .foregroundStyle(theme.primaryText)
                    .textSelection(.enabled)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }

    private var platformLimitationView: some View {
        VStack(spacing: 16) {
            EmptyStateView(
                icon: "envelope",
                title: "Mail",
                message: "Reading mail requires macOS with Mail.app. You can still compose and send emails.",
                action: { showCompose = true },
                actionLabel: "Compose Email"
            )
        }
    }
}
