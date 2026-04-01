import Foundation

struct Note: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var title: String
    var content: String
    var created: Date
    var modified: Date
    var tags: [String]
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        title: String = "Untitled",
        content: String = "",
        created: Date = Date(),
        modified: Date = Date(),
        tags: [String] = [],
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.created = created
        self.modified = modified
        self.tags = tags
        self.isPinned = isPinned
    }

    var fileName: String {
        "\(id).md"
    }

    var metadataFileName: String {
        "\(id).meta.json"
    }

    mutating func touch() {
        modified = Date()
    }

    func toMetadata() -> ItemMetadata {
        ItemMetadata(
            id: id,
            created: created,
            modified: modified,
            tags: tags,
            moduleType: .note,
            title: title,
            summary: String(content.prefix(200))
        )
    }

    func toMarkdownDocument() -> MarkdownDocument {
        var frontmatter: [String: String] = [
            "id": id.uuidString,
            "title": title,
            "pinned": isPinned ? "true" : "false"
        ]
        if !tags.isEmpty {
            frontmatter["tags"] = tags.joined(separator: ", ")
        }
        return MarkdownDocument(frontmatter: frontmatter, body: content)
    }

    static func fromMarkdownDocument(_ doc: MarkdownDocument, fileURL: URL) -> Note {
        let idString = doc.frontmatter["id"] ?? UUID().uuidString
        let id = UUID(uuidString: idString) ?? UUID()
        let title = doc.frontmatter["title"] ?? fileURL.deletingPathExtension().lastPathComponent
        let isPinned = doc.frontmatter["pinned"] == "true"
        let tags = doc.frontmatter["tags"]?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? []

        return Note(
            id: id,
            title: title,
            content: doc.body,
            tags: tags,
            isPinned: isPinned
        )
    }
}
