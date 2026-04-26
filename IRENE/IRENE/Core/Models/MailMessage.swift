import Foundation

struct MailMessage: Identifiable, Sendable, Equatable {
    let id: String
    var subject: String
    var from: String
    var to: [String]
    var date: Date
    var bodyPreview: String
    var body: String?
    var htmlBody: String?
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
        htmlBody: String? = nil,
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
        self.htmlBody = htmlBody
        self.isRead = isRead
        self.mailbox = mailbox
    }

    var displayFrom: String {
        // Extract name from "Name <email>" format
        if let angleBracket = from.firstIndex(of: "<") {
            let name = from[from.startIndex..<angleBracket].trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? from : name
        }
        return from
    }

    var senderEmail: String {
        if let start = from.firstIndex(of: "<"), let end = from.firstIndex(of: ">") {
            return String(from[from.index(after: start)..<end])
        }
        return from
    }
}
