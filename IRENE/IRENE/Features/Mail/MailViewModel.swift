import Foundation

@MainActor @Observable
final class MailViewModel {
    private(set) var messages: [MailMessage] = []
    private(set) var isLoading = false
    private(set) var canRead: Bool
    var selectedMessage: MailMessage?
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

    func loadInbox() async {
        guard canRead else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            messages = try await bridge.fetchInbox(limit: 20)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadFullMessage(_ message: MailMessage) async {
        guard canRead else { return }
        do {
            if let full = try await bridge.fetchMessage(id: message.id) {
                selectedMessage = full
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendMessage(to: [String], subject: String, body: String) async {
        do {
            try await bridge.sendMessage(to: to, subject: subject, body: body)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
