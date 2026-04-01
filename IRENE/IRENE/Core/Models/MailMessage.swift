import Foundation

struct MailMessage: Identifiable, Sendable {
    let id: String
    var subject: String
    var from: String
    var to: [String]
    var date: Date
    var bodyPreview: String
    var body: String?
    var isRead: Bool
    var mailbox: String

    init(
        id: String = UUID().uuidString,
        subject: String,
        from: String,
        to: [String] = [],
        date: Date = Date(),
        bodyPreview: String = "",
        body: String? = nil,
        isRead: Bool = false,
        mailbox: String = "INBOX"
    ) {
        self.id = id
        self.subject = subject
        self.from = from
        self.to = to
        self.date = date
        self.bodyPreview = bodyPreview
        self.body = body
        self.isRead = isRead
        self.mailbox = mailbox
    }
}
