import Foundation

@MainActor @Observable
final class MailViewModel {
    private(set) var mailboxes: [MailMailbox] = []
    private(set) var messages: [MailMessage] = []
    private(set) var isLoading = false
    private(set) var canRead: Bool
    var selectedMailboxId: String?
    var selectedMessage: MailMessage?
    var searchText: String = ""
    var errorMessage: String?

    private let bridge: any MailBridgeProtocol

    init() {
        #if os(macOS)
        let macBridge = AppleScriptMailBridge()
        self.bridge = macBridge
        self.canRead = macBridge.canReadMail
        #else
        let iosBridge = IOSMailBridge()
        self.bridge = iosBridge
        self.canRead = iosBridge.canReadMail
        #endif
    }

    var filteredMessages: [MailMessage] {
        guard !searchText.isEmpty else { return messages }
        let query = searchText.lowercased()
        return messages.filter {
            $0.subject.lowercased().contains(query) ||
            $0.from.lowercased().contains(query) ||
            $0.bodyPreview.lowercased().contains(query)
        }
    }

    var selectedMailbox: MailMailbox? {
        guard let selectedMailboxId else { return nil }
        return mailboxes.first { $0.id == selectedMailboxId }
    }

    // MARK: - Loading

    func loadMailboxes() async {
        guard canRead else { return }

        #if os(macOS)
        guard AppleScriptMailBridge.isMailRunning else {
            errorMessage = "Mail.app is not running. Please open Mail first."
            return
        }
        #endif

        do {
            mailboxes = try await bridge.fetchMailboxes()
            // Auto-select first INBOX if nothing selected
            if selectedMailboxId == nil {
                selectedMailboxId = mailboxes.first(where: { $0.name.uppercased() == "INBOX" })?.id
                    ?? mailboxes.first?.id
            }
            if let id = selectedMailboxId {
                await loadMessages(mailboxId: id)
            }
        } catch {
            print("[IRENE Mail] Mailbox load error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func selectMailbox(_ mailbox: MailMailbox) async {
        selectedMailboxId = mailbox.id
        selectedMessage = nil
        await loadMessages(mailboxId: mailbox.id)
    }

    func loadMessages(mailboxId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            messages = try await bridge.fetchMessages(mailboxId: mailboxId, limit: 25)
            print("[IRENE Mail] Loaded \(messages.count) messages from \(mailboxId)")
        } catch {
            print("[IRENE Mail] Load messages error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func reload() async {
        if let id = selectedMailboxId {
            await loadMessages(mailboxId: id)
        } else {
            await loadMailboxes()
        }
    }

    func loadFullMessage(_ message: MailMessage) async {
        guard canRead else { return }
        do {
            if let full = try await bridge.fetchMessage(id: message.id, mailboxId: message.mailbox) {
                selectedMessage = full
                // Update the list copy too so unread state stays in sync
                if let idx = messages.firstIndex(where: { $0.id == message.id }) {
                    messages[idx].isRead = full.isRead
                }
            }
        } catch {
            print("[IRENE Mail] Load message error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Operations

    func sendMessage(to: [String], subject: String, body: String) async {
        do {
            try await bridge.sendMessage(to: to, subject: subject, body: body)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func replyToSelected(body: String) async {
        guard let msg = selectedMessage else { return }
        let replySubject = msg.subject.hasPrefix("Re: ") ? msg.subject : "Re: \(msg.subject)"
        let replyBody = "\(body)\n\n---\nOn \(msg.date.formatted()), \(msg.from) wrote:\n\(msg.body ?? msg.bodyPreview)"
        await sendMessage(to: [msg.senderEmail], subject: replySubject, body: replyBody)
    }

    func toggleRead(_ message: MailMessage) async {
        let newReadState = !message.isRead
        do {
            try await bridge.setRead(messageId: message.id, mailboxId: message.mailbox, read: newReadState)
            if let idx = messages.firstIndex(where: { $0.id == message.id }) {
                messages[idx].isRead = newReadState
            }
            if selectedMessage?.id == message.id {
                selectedMessage?.isRead = newReadState
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteMessage(_ message: MailMessage) async {
        do {
            try await bridge.deleteMessage(messageId: message.id, mailboxId: message.mailbox)
            messages.removeAll { $0.id == message.id }
            if selectedMessage?.id == message.id {
                selectedMessage = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moveMessage(_ message: MailMessage, to mailbox: MailMailbox) async {
        do {
            try await bridge.moveMessage(messageId: message.id, fromMailboxId: message.mailbox, toMailboxId: mailbox.id)
            messages.removeAll { $0.id == message.id }
            if selectedMessage?.id == message.id {
                selectedMessage = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
