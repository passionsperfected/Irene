import Foundation

/// Routes Claude requests through Apple's internal Floodgate gateway via mTLS
/// client certificates instead of an Anthropic API key. The gateway proxies
/// to Anthropic's Messages API.
///
/// Currently non-streaming: the response is yielded as a single chunk so the
/// existing AsyncThrowingStream interface still works. Real SSE streaming
/// can be added later if the gateway supports it.
struct FloodgateProvider: LLMProvider, @unchecked Sendable {
    let providerType: LLMProviderType = .anthropic
    let session: URLSession
    let modelOverride: String?
    let endpointOverride: String?

    private static let defaultBaseURL = "https://floodgate.g.apple.com/api"
    private static let defaultModel = "anthropic.claude-opus-4-6-v1"

    var supportedModels: [LLMModel] {
        // Floodgate exposes Claude under an internal model id; we still want the
        // chat UI to show familiar names. Reuse the Anthropic catalog.
        [.claudeSonnet4, .claudeOpus41, .claudeOpus45, .claudeOpus46]
    }

    func sendMessage(
        _ messages: [LLMMessage],
        model: LLMModel,
        systemPrompt: String?,
        temperature: Double,
        maxTokens: Int
    ) -> AsyncThrowingStream<LLMResponseChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let endpoint = endpointURL()
                    let body = buildRequestBody(
                        messages: messages,
                        modelID: modelOverride ?? Self.defaultModel,
                        systemPrompt: systemPrompt,
                        temperature: temperature,
                        maxTokens: maxTokens
                    )

                    var request = URLRequest(url: endpoint)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("application/json", forHTTPHeaderField: "Accept")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    Log.info("Floodgate: sending request to \(endpoint)")

                    let (data, response) = try await session.data(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw LLMError.networkError("Invalid response type")
                    }

                    guard (200...299).contains(http.statusCode) else {
                        let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                        throw LLMError.serverError(http.statusCode, String(errorBody.prefix(500)))
                    }

                    let text = try parseText(from: data)

                    if Task.isCancelled { return }
                    continuation.yield(LLMResponseChunk(text: text, isComplete: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func validateAPIKey(_ key: String) async throws -> Bool {
        // Floodgate is auth'd via mTLS, not API keys. This provider is
        // considered "valid" if the URLSession was created (i.e. certs are
        // configured). The LLMService gates that separately.
        true
    }

    // MARK: - Helpers

    private func endpointURL() -> URL {
        if let override = endpointOverride, !override.isEmpty,
           let url = URL(string: override) {
            return url
        }
        return URL(string: "\(Self.defaultBaseURL)/anthropic/v1/messages")!
    }

    private func buildRequestBody(
        messages: [LLMMessage],
        modelID: String,
        systemPrompt: String?,
        temperature: Double,
        maxTokens: Int
    ) -> [String: Any] {
        let payload: [[String: String]] = messages
            .filter { $0.role != .system }
            .map { ["role": $0.role.rawValue, "content": $0.content] }

        var body: [String: Any] = [
            "model": modelID,
            "max_tokens": maxTokens,
            "messages": payload
        ]
        if let systemPrompt, !systemPrompt.isEmpty {
            body["system"] = systemPrompt
        }
        return body
    }

    private func parseText(from data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.streamingError("Floodgate response is not JSON")
        }
        guard let content = json["content"] as? [[String: Any]] else {
            // Some error responses may shape differently; surface the raw body
            let raw = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.streamingError("Unexpected Floodgate response: \(String(raw.prefix(200)))")
        }
        let parts: [String] = content.compactMap { block in
            guard (block["type"] as? String) == "text" else { return nil }
            return block["text"] as? String
        }
        return parts.joined(separator: "\n")
    }
}
