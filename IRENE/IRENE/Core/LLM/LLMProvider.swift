import Foundation

enum LLMProviderType: String, Codable, CaseIterable, Sendable, Identifiable {
    case anthropic
    case openai
    case grok

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic (Claude)"
        case .openai: return "OpenAI (ChatGPT)"
        case .grok: return "xAI (Grok)"
        }
    }

    var defaultModels: [LLMModel] {
        switch self {
        case .anthropic:
            return [.claudeSonnet4, .claudeOpus41, .claudeOpus45, .claudeOpus46]
        case .openai:
            return [] // Phase 3+ extension
        case .grok:
            return [] // Phase 3+ extension
        }
    }
}

protocol LLMProvider: Sendable {
    var providerType: LLMProviderType { get }
    var supportedModels: [LLMModel] { get }

    func sendMessage(
        _ messages: [LLMMessage],
        model: LLMModel,
        systemPrompt: String?,
        temperature: Double,
        maxTokens: Int
    ) -> AsyncThrowingStream<LLMResponseChunk, Error>

    func validateAPIKey(_ key: String) async throws -> Bool
}

enum LLMError: LocalizedError, Sendable {
    case invalidAPIKey
    case rateLimited(retryAfter: Int?)
    case networkError(String)
    case serverError(Int, String)
    case streamingError(String)
    case providerNotConfigured(String)
    case modelNotSupported(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key. Please check your key in Settings."
        case .rateLimited(let retry):
            if let retry {
                return "Rate limited. Retry in \(retry) seconds."
            }
            return "Rate limited. Please wait a moment."
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .serverError(let code, let msg):
            return "Server error (\(code)): \(msg)"
        case .streamingError(let msg):
            return "Streaming error: \(msg)"
        case .providerNotConfigured(let name):
            return "\(name) is not configured. Add your API key in Settings."
        case .modelNotSupported(let model):
            return "Model \(model) is not supported."
        }
    }
}
