import Testing
import Foundation
@testable import IRENE

@Suite("Vault Configuration Tests")
struct VaultConfigurationTests {
    @Test("Default configuration has expected values")
    func defaultConfiguration() {
        let config = VaultConfiguration()
        #expect(config.vaultVersion == 1)
        #expect(config.selectedProvider == "anthropic")
        #expect(config.selectedTheme == "deep-ocean")
        #expect(config.selectedPersonality == "professional")
        #expect(config.apiKeys.isEmpty)
    }

    @Test("Configuration encodes and decodes correctly")
    func configRoundTrip() throws {
        var config = VaultConfiguration()
        config.apiKeys["anthropic"] = "test-key-123"
        config.selectedTheme = "arctic-frost"

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)
        let decoded = try JSONDecoder().decode(VaultConfiguration.self, from: data)

        #expect(decoded.apiKeys["anthropic"] == "test-key-123")
        #expect(decoded.selectedTheme == "arctic-frost")
        #expect(decoded.vaultVersion == 1)
    }
}

@Suite("Item Metadata Tests")
struct ItemMetadataTests {
    @Test("Metadata initializes with correct defaults")
    func defaultInit() {
        let meta = ItemMetadata(moduleType: .note, title: "Test Note")
        #expect(meta.tags.isEmpty)
        #expect(meta.completed == nil)
        #expect(meta.summary == nil)
        #expect(meta.title == "Test Note")
        #expect(meta.moduleType == .note)
    }

    @Test("Touch updates modified date")
    func touchUpdates() {
        var meta = ItemMetadata(
            created: Date.distantPast,
            modified: Date.distantPast,
            moduleType: .toDo,
            title: "Test"
        )
        let before = meta.modified
        meta.touch()
        #expect(meta.modified > before)
    }

    @Test("Mark completed sets both dates")
    func markCompleted() {
        var meta = ItemMetadata(moduleType: .toDo, title: "Test")
        #expect(meta.completed == nil)
        meta.markCompleted()
        #expect(meta.completed != nil)
    }

    @Test("Metadata round-trips through JSON")
    func jsonRoundTrip() throws {
        let meta = ItemMetadata(
            tags: ["important", "work"],
            moduleType: .stickyNote,
            title: "Quick note",
            summary: "A brief summary"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(meta)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ItemMetadata.self, from: data)

        #expect(decoded.id == meta.id)
        #expect(decoded.title == "Quick note")
        #expect(decoded.tags == ["important", "work"])
        #expect(decoded.moduleType == .stickyNote)
        #expect(decoded.summary == "A brief summary")
    }
}
