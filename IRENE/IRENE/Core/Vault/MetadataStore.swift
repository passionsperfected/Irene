import Foundation

struct MetadataStore: Sendable {
    private let storage = JSONStorage<ItemMetadata>()
    private let vaultURL: URL

    init(vaultURL: URL) {
        self.vaultURL = vaultURL
    }

    private func metadataURL(for itemURL: URL) -> URL {
        let relativePath = itemURL.path.replacingOccurrences(of: vaultURL.path + "/", with: "")
        let baseName = (relativePath as NSString).deletingPathExtension
        return vaultURL
            .appendingPathComponent("settings/metadata")
            .appendingPathComponent(baseName + ".meta.json")
    }

    func load(for itemURL: URL) async throws -> ItemMetadata {
        let url = metadataURL(for: itemURL)
        return try await storage.load(from: url)
    }

    func save(_ metadata: ItemMetadata, for itemURL: URL) async throws {
        let url = metadataURL(for: itemURL)
        try await storage.save(metadata, to: url)
    }

    func delete(for itemURL: URL) async throws {
        let url = metadataURL(for: itemURL)
        try await storage.delete(at: url)
    }

    func loadAll(for moduleType: ModuleType) async throws -> [ItemMetadata] {
        let metadataDir: URL
        switch moduleType {
        case .note:
            metadataDir = vaultURL.appendingPathComponent("settings/metadata/notes")
        case .stickyNote:
            metadataDir = vaultURL.appendingPathComponent("settings/metadata/sticky_notes")
        case .toDo:
            metadataDir = vaultURL.appendingPathComponent("settings/metadata/to_do")
        case .reminder:
            metadataDir = vaultURL.appendingPathComponent("settings/metadata/reminders")
        case .chat:
            metadataDir = vaultURL.appendingPathComponent("settings/metadata/chats")
        case .recording:
            metadataDir = vaultURL.appendingPathComponent("settings/metadata/recording")
        }
        return try await storage.loadAll(in: metadataDir)
    }
}
