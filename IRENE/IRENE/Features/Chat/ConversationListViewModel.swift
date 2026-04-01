import Foundation

@MainActor @Observable
final class ConversationListViewModel {
    private(set) var conversations: [ChatConversation] = []
    private(set) var isLoading = false
    var searchText: String = ""
    var errorMessage: String?

    private let vaultManager: VaultManager
    private let storage = JSONStorage<ChatConversation>()

    init(vaultManager: VaultManager) {
        self.vaultManager = vaultManager
    }

    var filteredConversations: [ChatConversation] {
        var result = conversations
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.messages.contains(where: { $0.content.lowercased().contains(query) })
            }
        }
        return result.sorted { $0.modified > $1.modified }
    }

    func loadConversations() async {
        guard let dir = try? vaultManager.directoryURL(for: .chat) else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            conversations = try await storage.loadAll(in: dir)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createConversation() -> ChatConversation {
        let conversation = ChatConversation()
        conversations.insert(conversation, at: 0)
        return conversation
    }

    func saveConversation(_ conversation: ChatConversation) async {
        do {
            let dir = try vaultManager.directoryURL(for: .chat)
            let fileURL = dir.appendingPathComponent(conversation.fileName)
            try await storage.save(conversation, to: fileURL)

            if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
                conversations[index] = conversation
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteConversation(_ conversation: ChatConversation) async {
        do {
            let dir = try vaultManager.directoryURL(for: .chat)
            let fileURL = dir.appendingPathComponent(conversation.fileName)
            try await storage.delete(at: fileURL)
            conversations.removeAll { $0.id == conversation.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateConversation(_ conversation: ChatConversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
        }
    }
}
