import Foundation

struct VaultConfiguration: Codable, Sendable {
    var vaultVersion: Int = 1
    var selectedProvider: String = "anthropic"
    var selectedTheme: String = "deep-ocean"
    var selectedPersonality: String = "professional"
    var apiKeys: [String: String] = [:]

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
        "settings/system_prompts",
        "settings/metadata"
    ]
}
