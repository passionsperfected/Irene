import Foundation
import SwiftUI

@Observable
final class VaultManager: @unchecked Sendable {
    private(set) var vaultURL: URL?
    private(set) var configuration: VaultConfiguration = VaultConfiguration()
    private(set) var isConfigured: Bool = false

    private let fileManager = FileManager.default
    private let configStorage = JSONStorage<VaultConfiguration>()

    private static let bookmarkKey = "irene.vault.bookmark"

    init() {
        restoreVaultFromBookmark()
    }

    // MARK: - Vault Setup

    func setVault(url: URL) async throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        try ensureDirectoryStructure(at: url)
        try saveBookmark(for: url)

        vaultURL = url
        isConfigured = true

        // Load or create configuration
        let configURL = url.appendingPathComponent("settings/\(VaultConfiguration.fileName)")
        if fileManager.fileExists(atPath: configURL.path) {
            configuration = try await configStorage.load(from: configURL)
        } else {
            try await configStorage.save(configuration, to: configURL)
        }
    }

    func saveConfiguration() async throws {
        guard let vaultURL else { throw IRENEError.vaultNotConfigured }
        let configURL = vaultURL.appendingPathComponent("settings/\(VaultConfiguration.fileName)")
        try await configStorage.save(configuration, to: configURL)
    }

    func updateConfiguration(_ update: @Sendable (inout VaultConfiguration) -> Void) async throws {
        update(&configuration)
        try await saveConfiguration()
    }

    // MARK: - Path Helpers

    func url(for subpath: String) throws -> URL {
        guard let vaultURL else { throw IRENEError.vaultNotConfigured }
        return vaultURL.appendingPathComponent(subpath)
    }

    func directoryURL(for moduleType: ModuleType) throws -> URL {
        guard let vaultURL else { throw IRENEError.vaultNotConfigured }
        switch moduleType {
        case .note: return vaultURL.appendingPathComponent("notes")
        case .stickyNote: return vaultURL.appendingPathComponent("sticky_notes")
        case .toDo: return vaultURL.appendingPathComponent("to_do")
        case .reminder: return vaultURL.appendingPathComponent("reminders")
        case .chat: return vaultURL.appendingPathComponent("chats")
        case .recording: return vaultURL.appendingPathComponent("recording")
        }
    }

    // MARK: - Bookmark Persistence

    private func saveBookmark(for url: URL) throws {
        let bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
    }

    private func restoreVaultFromBookmark() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return }

        if isStale {
            // Re-save the bookmark
            try? saveBookmark(for: url)
        }

        let accessing = url.startAccessingSecurityScopedResource()
        if fileManager.fileExists(atPath: url.path) {
            vaultURL = url
            isConfigured = true

            // Load configuration synchronously so it's available immediately
            let configURL = url.appendingPathComponent("settings/\(VaultConfiguration.fileName)")
            if let data = try? Data(contentsOf: configURL) {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                if let config = try? decoder.decode(VaultConfiguration.self, from: data) {
                    self.configuration = config
                }
            }
        } else if accessing {
            url.stopAccessingSecurityScopedResource()
        }
    }

    // MARK: - Directory Management

    private func ensureDirectoryStructure(at base: URL) throws {
        for dir in VaultConfiguration.defaultDirectories {
            let dirURL = base.appendingPathComponent(dir)
            if !fileManager.fileExists(atPath: dirURL.path) {
                try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)
            }
        }
    }

    func moveVault(to newURL: URL) async throws {
        guard let currentURL = vaultURL else { throw IRENEError.vaultNotConfigured }

        let accessing = newURL.startAccessingSecurityScopedResource()
        defer { if accessing { newURL.stopAccessingSecurityScopedResource() } }

        try fileManager.copyItem(at: currentURL, to: newURL)
        try saveBookmark(for: newURL)

        vaultURL = newURL
    }
}
