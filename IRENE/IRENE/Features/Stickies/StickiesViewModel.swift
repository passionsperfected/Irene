import Foundation
import SwiftUI

@MainActor @Observable
final class StickiesViewModel {
    private(set) var stickies: [StickyNote] = []
    private(set) var isLoading = false
    var searchText: String = ""
    var errorMessage: String?

    private let vaultManager: VaultManager
    private let storage = JSONStorage<StickyNote>()
    private let metadataStore: MetadataStore?

    init(vaultManager: VaultManager) {
        self.vaultManager = vaultManager
        if let url = vaultManager.vaultURL {
            self.metadataStore = MetadataStore(vaultURL: url)
        } else {
            self.metadataStore = nil
        }
    }

    var filteredStickies: [StickyNote] {
        var result = stickies
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.content.lowercased().contains(query) ||
                $0.tags.contains(where: { $0.lowercased().contains(query) })
            }
        }
        return result.sorted { $0.sortOrder < $1.sortOrder }
    }

    func loadStickies() async {
        guard let dir = try? vaultManager.directoryURL(for: .stickyNote) else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            stickies = try await storage.loadAll(in: dir)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createSticky(content: String = "", color: StickyColor = .accent) async -> StickyNote? {
        let sticky = StickyNote(
            content: content,
            color: color,
            sortOrder: stickies.count
        )

        do {
            try await saveSticky(sticky)
            stickies.append(sticky)
            return sticky
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func saveSticky(_ sticky: StickyNote) async throws {
        let dir = try vaultManager.directoryURL(for: .stickyNote)
        let fileURL = dir.appendingPathComponent(sticky.fileName)
        try await storage.save(sticky, to: fileURL)

        if let metadataStore {
            try await metadataStore.save(sticky.toMetadata(), for: fileURL)
        }
    }

    func updateSticky(_ sticky: StickyNote) async {
        guard let index = stickies.firstIndex(where: { $0.id == sticky.id }) else { return }
        var updated = sticky
        updated.touch()
        stickies[index] = updated
        try? await saveSticky(updated)
    }

    func moveSticky(from source: IndexSet, to destination: Int) async {
        var ordered = filteredStickies
        ordered.move(fromOffsets: source, toOffset: destination)

        // Update sortOrder for all items
        for (index, var sticky) in ordered.enumerated() {
            sticky.sortOrder = index
            if let i = stickies.firstIndex(where: { $0.id == sticky.id }) {
                stickies[i].sortOrder = index
                try? await saveSticky(stickies[i])
            }
        }
    }

    func deleteSticky(_ sticky: StickyNote) async {
        do {
            let dir = try vaultManager.directoryURL(for: .stickyNote)
            let fileURL = dir.appendingPathComponent(sticky.fileName)
            try await storage.delete(at: fileURL)

            if let metadataStore {
                try? await metadataStore.delete(for: fileURL)
            }

            stickies.removeAll { $0.id == sticky.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
