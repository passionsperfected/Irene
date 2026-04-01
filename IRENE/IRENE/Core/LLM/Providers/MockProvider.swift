import Foundation

/// A mock LLM provider for testing and development without API keys.
struct MockProvider: LLMProvider {
    let providerType: LLMProviderType = .anthropic

    var supportedModels: [LLMModel] {
        [LLMModel(id: "mock-model", displayName: "Mock Model", provider: "mock", contextWindow: 100_000)]
    }

    func sendMessage(
        _ messages: [LLMMessage],
        model: LLMModel,
        systemPrompt: String?,
        temperature: Double,
        maxTokens: Int
    ) -> AsyncThrowingStream<LLMResponseChunk, Error> {
        let lastMessage = messages.last?.content ?? ""
        let response = generateMockResponse(for: lastMessage)

        return AsyncThrowingStream { continuation in
            Task {
                // Simulate streaming word by word
                let words = response.split(separator: " ")
                for (index, word) in words.enumerated() {
                    try? await Task.sleep(for: .milliseconds(30))
                    if Task.isCancelled { break }
                    let text = (index == 0 ? "" : " ") + word
                    continuation.yield(LLMResponseChunk(text: String(text)))
                }
                continuation.yield(LLMResponseChunk(text: "", isComplete: true))
                continuation.finish()
            }
        }
    }

    func validateAPIKey(_ key: String) async throws -> Bool {
        return true
    }

    private func generateMockResponse(for input: String) -> String {
        let lowered = input.lowercased()
        if lowered.contains("summarize") || lowered.contains("summary") {
            return "Here's a summary of the key points: The content covers several important topics that are interconnected. The main themes include organization, planning, and execution. I'd recommend focusing on the highest-priority items first."
        } else if lowered.contains("action") || lowered.contains("todo") || lowered.contains("to do") {
            return "Based on what I see, here are the action items:\n\n1. Review and prioritize the main objectives\n2. Set up a timeline for deliverables\n3. Follow up on outstanding items\n4. Schedule a check-in to review progress"
        } else {
            return "I understand your question. Let me think about this carefully. Based on the context available, I'd suggest approaching this systematically. Would you like me to elaborate on any specific aspect?"
        }
    }
}
