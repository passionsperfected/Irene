import SwiftUI

struct MailModuleView: View {
    @State private var viewModel = MailViewModel()
    @State private var showCompose = false
    @State private var showReply = false
    @State private var showDeleteConfirm = false
    @State private var messageToDelete: MailMessage?
    @State private var draggedMessage: MailMessage?

    @Environment(\.ireneTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(theme.border.opacity(0.3))

            if !viewModel.canRead {
                platformLimitationView
            } else if let error = viewModel.errorMessage {
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "Mail Error",
                    message: error,
                    action: {
                        viewModel.errorMessage = nil
                        Task { await viewModel.loadMailboxes() }
                    },
                    actionLabel: "Retry"
                )
            } else {
                mailContent
            }
        }
        .background(theme.background)
        .task {
            if viewModel.canRead {
                await viewModel.loadMailboxes()
            }
        }
        .sheet(isPresented: $showCompose) {
            MailComposeView { recipients, subject, body in
                await viewModel.sendMessage(to: recipients, subject: subject, body: body)
            }
        }
        .sheet(isPresented: $showReply) {
            if let msg = viewModel.selectedMessage {
                MailReplyView(originalMessage: msg) { body in
                    await viewModel.replyToSelected(body: body)
                }
            }
        }
        .confirmationDialog(
            "Delete this message?",
            isPresented: $showDeleteConfirm,
            presenting: messageToDelete
        ) { msg in
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteMessage(msg) }
            }
            Button("Cancel", role: .cancel) {}
        }
        #if os(macOS)
        .alert(
            "Open \(viewModel.appLaunchPrompt?.displayName ?? "Mail")?",
            isPresented: Binding(
                get: { viewModel.appLaunchPrompt != nil },
                set: { if !$0 { viewModel.appLaunchPrompt = nil } }
            ),
            presenting: viewModel.appLaunchPrompt
        ) { app in
            Button("Open \(app.displayName)") {
                Task { await viewModel.confirmLaunchApp() }
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelLaunchApp()
            }
        } message: { app in
            Text("IRENE needs \(app.displayName) to be running to access your messages.")
        }
        #endif
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("Mail")
                .font(Typography.bodySemiBold(size: 14))
                .foregroundStyle(theme.primaryText)

            if !viewModel.messages.isEmpty {
                Text("\(viewModel.messages.count)")
                    .font(Typography.caption(size: 10))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.accent.opacity(0.15))
                    .clipShape(Capsule())
            }

            Spacer()

            if viewModel.canRead {
                SearchBar(
                    text: Binding(
                        get: { viewModel.searchText },
                        set: { viewModel.searchText = $0 }
                    ),
                    placeholder: "Search mail..."
                )
                .frame(maxWidth: 200)

                Button {
                    Task { await viewModel.reload() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.secondaryText)
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }

            Button { showCompose = true } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .help("Compose")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var mailContent: some View {
        HStack(spacing: 0) {
            mailboxSidebar
            Divider().overlay(theme.border.opacity(0.3))
            messageList
            Divider().overlay(theme.border.opacity(0.3))
            messageDetailPane
        }
    }

    // MARK: - Mailbox Sidebar

    private var mailboxSidebar: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                let grouped = Dictionary(grouping: viewModel.mailboxes, by: { $0.account })
                let accounts = grouped.keys.sorted()

                ForEach(accounts, id: \.self) { account in
                    Text(account.uppercased())
                        .font(Typography.label())
                        .tracking(1.5)
                        .foregroundStyle(theme.secondaryText.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 4)

                    ForEach(sortedMailboxes(grouped[account] ?? [])) { box in
                        mailboxRow(box)
                    }
                }
            }
        }
        .frame(minWidth: 180, maxWidth: 220)
        .background(theme.secondaryBackground.opacity(0.3))
    }

    private func sortedMailboxes(_ boxes: [MailMailbox]) -> [MailMailbox] {
        // Standard mailboxes first, then alphabetical
        let order = ["INBOX", "Drafts", "Sent", "Sent Messages", "Junk", "Trash", "Deleted Messages", "Archive"]
        return boxes.sorted { a, b in
            let ai = order.firstIndex(of: a.name) ?? Int.max
            let bi = order.firstIndex(of: b.name) ?? Int.max
            if ai != bi { return ai < bi }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    private func mailboxRow(_ box: MailMailbox) -> some View {
        let isSelected = viewModel.selectedMailboxId == box.id
        return Button {
            Task { await viewModel.selectMailbox(box) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: mailboxIcon(for: box.name))
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? theme.accent : theme.secondaryText)
                    .frame(width: 16)

                Text(box.name)
                    .font(Typography.body(size: 12))
                    .foregroundStyle(isSelected ? theme.primaryText : theme.secondaryText)
                    .lineLimit(1)

                Spacer()

                if box.unreadCount > 0 {
                    Text("\(box.unreadCount)")
                        .font(Typography.caption(size: 9))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(theme.accent.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? theme.accent.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onDrop(of: ["public.text"], delegate: MailboxDropDelegate(
            mailbox: box,
            draggedMessage: $draggedMessage,
            viewModel: viewModel
        ))
    }

    private func mailboxIcon(for name: String) -> String {
        switch name.uppercased() {
        case "INBOX": return "tray"
        case "DRAFTS": return "doc"
        case "SENT", "SENT MESSAGES": return "paperplane"
        case "JUNK": return "flame"
        case "TRASH", "DELETED MESSAGES": return "trash"
        case "ARCHIVE": return "archivebox"
        default: return "folder"
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding()
            }

            if viewModel.messages.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    icon: "envelope",
                    title: "No Messages",
                    message: viewModel.selectedMailbox?.name ?? "This mailbox is empty"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredMessages) { message in
                            messageRow(message)
                            Divider().overlay(theme.border.opacity(0.1))
                        }
                    }
                }
            }
        }
        .frame(minWidth: 280, maxWidth: 360)
    }

    private func messageRow(_ message: MailMessage) -> some View {
        Button {
            viewModel.selectedMessage = message
            Task { await viewModel.loadFullMessage(message) }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    if !message.isRead {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 6, height: 6)
                    }

                    Text(message.displayFrom)
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
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                viewModel.selectedMessage?.id == message.id
                    ? theme.accent.opacity(0.1)
                    : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(message.isRead ? "Mark as Unread" : "Mark as Read") {
                Task { await viewModel.toggleRead(message) }
            }
            Divider()
            Button("Delete", role: .destructive) {
                messageToDelete = message
                showDeleteConfirm = true
            }
        }
        .onDrag {
            draggedMessage = message
            return NSItemProvider(object: message.id as NSString)
        }
    }

    // MARK: - Message Detail Pane

    @ViewBuilder
    private var messageDetailPane: some View {
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

    private func messageDetail(_ message: MailMessage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text(message.subject)
                    .font(Typography.subheading(size: 18))
                    .foregroundStyle(theme.primaryText)
                    .textSelection(.enabled)

                HStack {
                    Text("From: \(message.from)")
                        .font(Typography.body(size: 12))
                        .foregroundStyle(theme.secondaryText)
                        .textSelection(.enabled)
                    Spacer()
                    Text(message.date.formatted())
                        .font(Typography.caption(size: 10))
                        .foregroundStyle(theme.secondaryText.opacity(0.6))
                }

                HStack(spacing: 8) {
                    actionButton(icon: "arrowshape.turn.up.left", label: "Reply") {
                        showReply = true
                    }
                    actionButton(
                        icon: message.isRead ? "envelope.badge" : "envelope.open",
                        label: message.isRead ? "Mark Unread" : "Mark Read"
                    ) {
                        Task { await viewModel.toggleRead(message) }
                    }
                    actionButton(icon: "trash", label: "Delete", destructive: true) {
                        messageToDelete = message
                        showDeleteConfirm = true
                    }
                }
            }
            .padding(16)

            Divider().overlay(theme.border.opacity(0.3))

            // Body — HTML if available, plain text otherwise
            #if os(macOS)
            if let html = message.htmlBody, !html.isEmpty {
                MailHTMLView(html: html, isDark: theme.isDark)
            } else if let body = message.body, !body.isEmpty {
                MailPlainTextView(text: body)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            #else
            ScrollView {
                Text(message.body ?? message.bodyPreview)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.primaryText)
                    .textSelection(.enabled)
                    .padding(16)
            }
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }

    private func actionButton(
        icon: String,
        label: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(Typography.caption(size: 10))
            }
            .foregroundStyle(destructive ? Color.red : theme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background((destructive ? Color.red : theme.accent).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var platformLimitationView: some View {
        EmptyStateView(
            icon: "envelope",
            title: "Mail",
            message: "Reading mail requires macOS with Mail.app. You can compose emails.",
            action: { showCompose = true },
            actionLabel: "Compose Email"
        )
    }
}

// MARK: - Drag-and-drop into mailbox

private struct MailboxDropDelegate: DropDelegate {
    let mailbox: MailMailbox
    @Binding var draggedMessage: MailMessage?
    let viewModel: MailViewModel

    func performDrop(info: DropInfo) -> Bool {
        guard let message = draggedMessage, message.mailbox != mailbox.id else { return false }
        Task { @MainActor in
            await viewModel.moveMessage(message, to: mailbox)
            draggedMessage = nil
        }
        return true
    }
}
