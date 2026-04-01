import Foundation

struct ChatConversation: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var title: String
    var messages: [LLMMessage]
    var created: Date
    var modified: Date
    var model: String
    var provider: String
    var tags: [String]

    init(
        id: UUID = UUID(),
        title: String = "New Conversation",
        messages: [LLMMessage] = [],
        created: Date = Date(),
        modified: Date = Date(),
        model: String = LLMModel.defaultModel.id,
        provider: String = "anthropic",
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.created = created
        self.modified = modified
        self.model = model
        self.provider = provider
        self.tags = tags
    }

    var fileName: String {
        "\(id).json"
    }

    mutating func touch() {
        modified = Date()
    }

    mutating func addMessage(_ message: LLMMessage) {
        messages.append(message)
        touch()
    }

    mutating func updateLastAssistantMessage(appendingText text: String) {
        guard let lastIndex = messages.indices.last,
              messages[lastIndex].role == .assistant else { return }
        messages[lastIndex].content += text
        touch()
    }

    func toMetadata() -> ItemMetadata {
        ItemMetadata(
            id: id,
            created: created,
            modified: modified,
            tags: tags,
            moduleType: .chat,
            title: title,
            summary: messages.last?.content.prefix(200).description
        )
    }

    /// Auto-generates a title from the first user message
    mutating func autoTitle() {
        guard title == "New Conversation",
              let firstUserMsg = messages.first(where: { $0.role == .user }) else { return }
        let preview = String(firstUserMsg.content.prefix(50))
        title = preview.count < firstUserMsg.content.count ? preview + "..." : preview
    }
}
