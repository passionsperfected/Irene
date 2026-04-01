import Foundation

struct MarkdownDocument: Sendable {
    var frontmatter: [String: String]
    var body: String

    init(frontmatter: [String: String] = [:], body: String = "") {
        self.frontmatter = frontmatter
        self.body = body
    }
}

struct MarkdownStorage: Sendable {
    private let fileCoordinator = FileCoordinator()

    func load(from url: URL) async throws -> MarkdownDocument {
        let data = try await fileCoordinator.read(from: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw IRENEError.serializationFailed("Failed to decode markdown as UTF-8")
        }
        return parse(text)
    }

    func save(_ document: MarkdownDocument, to url: URL) async throws {
        let text = serialize(document)
        guard let data = text.data(using: .utf8) else {
            throw IRENEError.serializationFailed("Failed to encode markdown as UTF-8")
        }
        try await fileCoordinator.write(data, to: url)
    }

    func delete(at url: URL) async throws {
        try await fileCoordinator.delete(at: url)
    }

    private func parse(_ text: String) -> MarkdownDocument {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.hasPrefix("---") else {
            return MarkdownDocument(body: text)
        }

        let parts = trimmed.components(separatedBy: "\n")
        var frontmatter: [String: String] = [:]
        var bodyStartIndex = 0
        var foundClosing = false

        for (index, line) in parts.enumerated() {
            if index == 0 { continue } // skip opening ---
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                bodyStartIndex = index + 1
                foundClosing = true
                break
            }
            let keyValue = line.split(separator: ":", maxSplits: 1)
            if keyValue.count == 2 {
                let key = keyValue[0].trimmingCharacters(in: .whitespaces)
                let value = keyValue[1].trimmingCharacters(in: .whitespaces)
                frontmatter[key] = value
            }
        }

        if !foundClosing {
            return MarkdownDocument(body: text)
        }

        let body = parts[bodyStartIndex...].joined(separator: "\n")
        return MarkdownDocument(frontmatter: frontmatter, body: body)
    }

    private func serialize(_ document: MarkdownDocument) -> String {
        if document.frontmatter.isEmpty {
            return document.body
        }

        var lines = ["---"]
        for (key, value) in document.frontmatter.sorted(by: { $0.key < $1.key }) {
            lines.append("\(key): \(value)")
        }
        lines.append("---")
        lines.append("")
        lines.append(document.body)
        return lines.joined(separator: "\n")
    }
}
