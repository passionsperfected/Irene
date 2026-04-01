import Foundation

struct AnthropicProvider: LLMProvider {
    let providerType: LLMProviderType = .anthropic
    let apiKey: String

    private static let baseURL = "https://api.anthropic.com/v1/messages"
    private static let apiVersion = "2023-06-01"

    var supportedModels: [LLMModel] {
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
                    let request = try buildRequest(
                        messages: messages,
                        model: model,
                        systemPrompt: systemPrompt,
                        temperature: temperature,
                        maxTokens: maxTokens,
                        stream: true
                    )

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw LLMError.networkError("Invalid response type")
                    }

                    // For non-200 responses, read the error body
                    if !(200...299).contains(httpResponse.statusCode) {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                        }
                        // Try to extract error message from JSON
                        if let data = errorBody.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let error = json["error"] as? [String: Any],
                           let message = error["message"] as? String {
                            throw LLMError.serverError(httpResponse.statusCode, message)
                        }
                        throw LLMError.serverError(httpResponse.statusCode, errorBody.isEmpty ? "Unknown error" : String(errorBody.prefix(500)))
                    }

                    // Parse SSE stream
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        guard line.hasPrefix("data: ") else { continue }
                        let data = String(line.dropFirst(6))

                        if data == "[DONE]" {
                            continuation.yield(LLMResponseChunk(text: "", isComplete: true))
                            break
                        }

                        guard let jsonData = data.data(using: .utf8),
                              let event = try? JSONDecoder().decode(StreamEvent.self, from: jsonData) else {
                            continue
                        }

                        switch event.type {
                        case "content_block_delta":
                            if let delta = event.delta, let text = delta.text {
                                continuation.yield(LLMResponseChunk(text: text))
                            }
                        case "message_stop":
                            continuation.yield(LLMResponseChunk(text: "", isComplete: true))
                        case "error":
                            if let error = event.error {
                                throw LLMError.serverError(0, error.message)
                            }
                        default:
                            break
                        }
                    }

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
        var request = URLRequest(url: URL(string: Self.baseURL)!)
        request.httpMethod = "POST"
        request.addValue(key, forHTTPHeaderField: "x-api-key")
        request.addValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": LLMModel.claudeSonnet4.id,
            "max_tokens": 1,
            "messages": [["role": "user", "content": "hi"]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { return false }

        // 200 = valid key, 401 = invalid key, anything else = maybe valid but error
        return httpResponse.statusCode == 200
    }

    // MARK: - Request Building

    private func buildRequest(
        messages: [LLMMessage],
        model: LLMModel,
        systemPrompt: String?,
        temperature: Double,
        maxTokens: Int,
        stream: Bool
    ) throws -> URLRequest {
        var request = URLRequest(url: URL(string: Self.baseURL)!)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "content-type")

        var body: [String: Any] = [
            "model": model.id,
            "max_tokens": maxTokens,
            "temperature": temperature,
            "stream": stream
        ]

        if let systemPrompt, !systemPrompt.isEmpty {
            body["system"] = systemPrompt
        }

        // Convert messages (exclude system — handled above)
        let apiMessages = messages
            .filter { $0.role != .system }
            .map { msg -> [String: String] in
                ["role": msg.role.rawValue, "content": msg.content]
            }
        body["messages"] = apiMessages

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func validateResponse(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 401:
            throw LLMError.invalidAPIKey
        case 429:
            let retryAfter = response.value(forHTTPHeaderField: "retry-after")
                .flatMap(Int.init)
            throw LLMError.rateLimited(retryAfter: retryAfter)
        default:
            // For streaming responses, the error body will come through the stream
            // For non-streaming, this gives a basic code-based message
            throw LLMError.serverError(response.statusCode, "Anthropic API error (HTTP \(response.statusCode))")
        }
    }
}

// MARK: - SSE Response Types

private struct StreamEvent: Decodable {
    let type: String
    let delta: Delta?
    let error: StreamError?

    struct Delta: Decodable {
        let type: String?
        let text: String?
    }

    struct StreamError: Decodable {
        let type: String
        let message: String
    }
}
