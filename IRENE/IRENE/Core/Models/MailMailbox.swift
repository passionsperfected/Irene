import Foundation

struct MailMailbox: Identifiable, Sendable, Hashable {
    let id: String        // account|mailbox path
    let name: String      // display name
    let account: String   // account name
    let unreadCount: Int

    init(id: String, name: String, account: String, unreadCount: Int = 0) {
        self.id = id
        self.name = name
        self.account = account
        self.unreadCount = unreadCount
    }
}
