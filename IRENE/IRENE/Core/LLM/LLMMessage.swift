import Foundation

enum LLMRole: String, Codable, Sendable {
    case system
    case user
    case assistant
}

struct LLMMessage: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let role: LLMRole
    var content: String
    let timestamp: Date

    init(
        id: UUID = UUID(),
        role: LLMRole,
        content: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }

    static func user(_ content: String) -> LLMMessage {
        LLMMessage(role: .user, content: content)
    }

    static func assistant(_ content: String) -> LLMMessage {
        LLMMessage(role: .assistant, content: content)
    }

    static func system(_ content: String) -> LLMMessage {
        LLMMessage(role: .system, content: content)
    }
}
