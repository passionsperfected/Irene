import Foundation

struct FileCoordinator: Sendable {
    func read(from url: URL) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let coordinator = NSFileCoordinator()
            var error: NSError?
            coordinator.coordinate(readingItemAt: url, options: [], error: &error) { readURL in
                do {
                    let data = try Data(contentsOf: readURL)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            if let error {
                continuation.resume(throwing: error)
            }
        }
    }

    func write(_ data: Data, to url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let coordinator = NSFileCoordinator()
            var error: NSError?
            coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &error) { writeURL in
                do {
                    let directory = writeURL.deletingLastPathComponent()
                    if !FileManager.default.fileExists(atPath: directory.path) {
                        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    }
                    try data.write(to: writeURL, options: .atomic)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            if let error {
                continuation.resume(throwing: error)
            }
        }
    }

    func delete(at url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let coordinator = NSFileCoordinator()
            var error: NSError?
            coordinator.coordinate(writingItemAt: url, options: .forDeleting, error: &error) { deleteURL in
                do {
                    try FileManager.default.removeItem(at: deleteURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            if let error {
                continuation.resume(throwing: error)
            }
        }
    }
}
