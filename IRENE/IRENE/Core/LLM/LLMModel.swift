import Foundation

struct LLMModel: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let displayName: String
    let provider: String
    let contextWindow: Int

    static let claudeOpus46 = LLMModel(
        id: "claude-opus-4-6",
        displayName: "Claude Opus 4.6",
        provider: "anthropic",
        contextWindow: 200_000
    )

    static let claudeOpus45 = LLMModel(
        id: "claude-opus-4-5",
        displayName: "Claude Opus 4.5",
        provider: "anthropic",
        contextWindow: 200_000
    )

    static let claudeOpus41 = LLMModel(
        id: "claude-opus-4-1",
        displayName: "Claude Opus 4.1",
        provider: "anthropic",
        contextWindow: 200_000
    )

    static let claudeSonnet4 = LLMModel(
        id: "claude-sonnet-4-20250514",
        displayName: "Claude Sonnet 4",
        provider: "anthropic",
        contextWindow: 200_000
    )

    static let defaultModel = claudeSonnet4
}
