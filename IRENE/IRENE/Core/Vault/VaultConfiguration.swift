import Foundation

struct VaultConfiguration: Codable, Sendable {
    var vaultVersion: Int = 1
    var selectedProvider: String = "anthropic"
    var selectedTheme: String = "deep-ocean"
    var selectedPersonality: String = "professional"
    var completionSound: String = "Hero"
    var apiKeys: [String: String] = [:]

    /// `owner/name` repo identifiers — kept for backward compatibility with
    /// the prior simple GitHub config. The new pane uses
    /// ~/__ai/irene_configs/dashboard/github_config.json (multi-host).
    var githubRepos: [String] = []

    // MARK: - Work LLM (Floodgate / mTLS)

    /// When true, chat routes through the Floodgate provider (Apple internal
    /// gateway) using mTLS client certificates. When false, the regular API
    /// provider (Anthropic with PAT) is used.
    var useWorkLLM: Bool = false
    /// Filesystem path to the chain certificate PEM.
    var workLLMChainPath: String = ""
    /// Filesystem path to the private key PEM.
    var workLLMPrivateKeyPath: String = ""
    /// Optional override endpoint (defaults to Floodgate).
    var workLLMEndpoint: String = ""

    init() {}

    /// Tolerant decoder so older config files without newer fields continue
    /// to load — every field falls back to its default if absent.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.vaultVersion = try c.decodeIfPresent(Int.self, forKey: .vaultVersion) ?? 1
        self.selectedProvider = try c.decodeIfPresent(String.self, forKey: .selectedProvider) ?? "anthropic"
        self.selectedTheme = try c.decodeIfPresent(String.self, forKey: .selectedTheme) ?? "deep-ocean"
        self.selectedPersonality = try c.decodeIfPresent(String.self, forKey: .selectedPersonality) ?? "professional"
        self.completionSound = try c.decodeIfPresent(String.self, forKey: .completionSound) ?? "Hero"
        self.apiKeys = try c.decodeIfPresent([String: String].self, forKey: .apiKeys) ?? [:]
        self.githubRepos = try c.decodeIfPresent([String].self, forKey: .githubRepos) ?? []
        self.useWorkLLM = try c.decodeIfPresent(Bool.self, forKey: .useWorkLLM) ?? false
        self.workLLMChainPath = try c.decodeIfPresent(String.self, forKey: .workLLMChainPath) ?? ""
        self.workLLMPrivateKeyPath = try c.decodeIfPresent(String.self, forKey: .workLLMPrivateKeyPath) ?? ""
        self.workLLMEndpoint = try c.decodeIfPresent(String.self, forKey: .workLLMEndpoint) ?? ""
    }

    static let fileName = "config.json"

    static let defaultDirectories = [
        "notes",
        "sticky_notes",
        "to_do",
        "reminders",
        "chats",
        "recording/audio",
        "recording/transcription",
        "recording/summary",
        "sprints",
        "settings/system_prompts",
        "settings/metadata"
    ]
}
