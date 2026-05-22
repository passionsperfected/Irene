import Foundation

@MainActor @Observable
final class LLMService {
    private(set) var activeProviderType: LLMProviderType = .anthropic
    private(set) var selectedModel: LLMModel = .defaultModel
    private(set) var systemPrompts: [SystemPrompt] = SystemPrompt.builtInPresets
    var selectedPrompt: SystemPrompt = .professional
    var isGenerating: Bool = false

    private var apiKeys: [LLMProviderType: String] = [:]
    private let vaultManager: VaultManager
    let certificateManager = CertificateManager()
    private(set) var workLLMConfigured: Bool = false
    private(set) var workLLMConfigError: String?

    init(vaultManager: VaultManager) {
        self.vaultManager = vaultManager
        loadAPIKeys()
        if vaultManager.configuration.useWorkLLM {
            tryConfigureWorkLLM()
        }
    }

    /// Attempt to load the certificates from the paths in vault config.
    /// Sets `workLLMConfigured` and `workLLMConfigError` for the UI.
    func tryConfigureWorkLLM() {
        let chain = vaultManager.configuration.workLLMChainPath
        let key = vaultManager.configuration.workLLMPrivateKeyPath
        guard !chain.isEmpty, !key.isEmpty else {
            workLLMConfigured = false
            workLLMConfigError = "Set chain and private-key paths in Settings."
            return
        }
        do {
            try certificateManager.configure(chainPath: chain, privatePath: key)
            workLLMConfigured = true
            workLLMConfigError = nil
        } catch {
            workLLMConfigured = false
            workLLMConfigError = error.localizedDescription
            Log.error("Work LLM cert configure failed: \(error)")
        }
    }

    var useWorkLLM: Bool {
        vaultManager.configuration.useWorkLLM
    }

    // MARK: - Configuration

    func setAPIKey(_ key: String, for provider: LLMProviderType) {
        apiKeys[provider] = key
    }

    func switchProvider(to provider: LLMProviderType) {
        activeProviderType = provider
        if let firstModel = provider.defaultModels.first {
            selectedModel = firstModel
        }
    }

    func selectModel(_ model: LLMModel) {
        selectedModel = model
    }

    var availableModels: [LLMModel] {
        activeProviderType.defaultModels
    }

    var isConfigured: Bool {
        if useWorkLLM { return workLLMConfigured }
        guard let key = apiKeys[activeProviderType], !key.isEmpty else { return false }
        return true
    }

    // MARK: - Sending Messages

    func send(
        messages: [LLMMessage],
        systemPrompt: String? = nil,
        temperature: Double = 0.7,
        maxTokens: Int = 4096
    ) -> AsyncThrowingStream<LLMResponseChunk, Error> {
        let prompt = systemPrompt ?? selectedPrompt.content
        let provider = makeProvider()
        let model = selectedModel

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let provider else {
                        throw LLMError.providerNotConfigured(activeProviderType.displayName)
                    }

                    let stream = provider.sendMessage(
                        messages,
                        model: model,
                        systemPrompt: prompt,
                        temperature: temperature,
                        maxTokens: maxTokens
                    )

                    for try await chunk in stream {
                        if Task.isCancelled { break }
                        continuation.yield(chunk)
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

    // MARK: - Provider Factory

    private func makeProvider() -> (any LLMProvider)? {
        // Re-read keys from vault config in case they were loaded after init
        if apiKeys.isEmpty {
            loadAPIKeys()
        }

        // Work LLM toggle wins over the provider picker — both routes reach
        // Claude, but via different transports.
        if useWorkLLM {
            guard workLLMConfigured, let session = certificateManager.createURLSession() else {
                return nil
            }
            let endpoint = vaultManager.configuration.workLLMEndpoint
            return FloodgateProvider(
                session: session,
                modelOverride: nil,
                endpointOverride: endpoint.isEmpty ? nil : endpoint
            )
        }

        switch activeProviderType {
        case .anthropic:
            guard let key = apiKeys[.anthropic], !key.isEmpty else { return nil }
            return AnthropicProvider(apiKey: key)
        case .openai, .grok:
            // Stub: will be implemented in future phases
            return nil
        }
    }

    /// Reload keys from vault config. Call this after config changes.
    func reloadFromConfig() {
        loadAPIKeys()
    }

    /// Returns a mock provider for testing without API keys
    func makeMockProvider() -> any LLMProvider {
        MockProvider()
    }

    // MARK: - Persistence

    private func loadAPIKeys() {
        let config = vaultManager.configuration
        for (key, value) in config.apiKeys {
            if let providerType = LLMProviderType(rawValue: key) {
                apiKeys[providerType] = value
            }
        }

        if let providerType = LLMProviderType(rawValue: config.selectedProvider) {
            activeProviderType = providerType
        }

        if let promptName = SystemPrompt.builtInPresets.first(where: {
            $0.name.lowercased().contains(config.selectedPersonality)
        }) {
            selectedPrompt = promptName
        }
    }

    func loadCustomPrompts() async {
        guard let vaultURL = vaultManager.vaultURL else { return }
        let promptsDir = vaultURL.appendingPathComponent("settings/system_prompts")
        let storage = JSONStorage<SystemPrompt>()

        do {
            let custom = try await storage.loadAll(in: promptsDir)
            systemPrompts = SystemPrompt.builtInPresets + custom
        } catch {
            systemPrompts = SystemPrompt.builtInPresets
        }
    }

    func saveCustomPrompt(_ prompt: SystemPrompt) async throws {
        guard let vaultURL = vaultManager.vaultURL else { throw IRENEError.vaultNotConfigured }
        let promptsDir = vaultURL.appendingPathComponent("settings/system_prompts")
        let fileURL = promptsDir.appendingPathComponent("\(prompt.id).json")
        let storage = JSONStorage<SystemPrompt>()
        try await storage.save(prompt, to: fileURL)
        await loadCustomPrompts()
    }
}
