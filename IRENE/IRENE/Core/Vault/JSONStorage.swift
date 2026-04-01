import Foundation

struct JSONStorage<T: Codable & Sendable>: Sendable {
    private let fileCoordinator = FileCoordinator()

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func load(from url: URL) async throws -> T {
        let data = try await fileCoordinator.read(from: url)
        return try Self.decoder.decode(T.self, from: data)
    }

    func save(_ item: T, to url: URL) async throws {
        let data = try Self.encoder.encode(item)
        try await fileCoordinator.write(data, to: url)
    }

    func loadAll(in directory: URL, matching extension: String = "json") async throws -> [T] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else { return [] }

        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        let matchingFiles = contents.filter { $0.pathExtension == `extension` }

        var items: [T] = []
        for file in matchingFiles {
            do {
                let item = try await load(from: file)
                items.append(item)
            } catch {
                // Skip files that can't be decoded — log in the future
                continue
            }
        }
        return items
    }

    func delete(at url: URL) async throws {
        try await fileCoordinator.delete(at: url)
    }
}
