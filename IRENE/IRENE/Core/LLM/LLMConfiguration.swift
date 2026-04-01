import Foundation

struct LLMConfiguration: Codable, Sendable {
    var apiKey: String
    var model: LLMModel
    var temperature: Double
    var maxTokens: Int

    init(
        apiKey: String,
        model: LLMModel = .defaultModel,
        temperature: Double = 0.7,
        maxTokens: Int = 4096
    ) {
        self.apiKey = apiKey
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}
