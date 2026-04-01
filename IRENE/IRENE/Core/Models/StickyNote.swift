import Foundation
import SwiftUI

enum StickyColor: String, Codable, CaseIterable, Sendable {
    case accent
    case secondary
    case warm
    case neutral
    case muted

    func backgroundColor(from theme: ThemeDefinition) -> Color {
        switch self {
        case .accent: return theme.emeraldDeep.color
        case .secondary: return theme.amethystDeep.color
        case .warm: return theme.umber.color
        case .neutral: return theme.slate.color
        case .muted: return theme.pewter.color
        }
    }

    func borderColor(from theme: ThemeDefinition) -> Color {
        switch self {
        case .accent: return theme.jade.color
        case .secondary: return theme.violet.color
        case .warm: return theme.bronze.color
        case .neutral: return theme.ash.color
        case .muted: return theme.steel.color
        }
    }

    var displayName: String {
        switch self {
        case .accent: return "Accent"
        case .secondary: return "Secondary"
        case .warm: return "Warm"
        case .neutral: return "Neutral"
        case .muted: return "Muted"
        }
    }
}

struct StickyNote: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var content: String
    var color: StickyColor
    var created: Date
    var modified: Date
    var tags: [String]
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        content: String = "",
        color: StickyColor = .accent,
        created: Date = Date(),
        modified: Date = Date(),
        tags: [String] = [],
        sortOrder: Int = 0
    ) {
        self.id = id
        self.content = content
        self.color = color
        self.created = created
        self.modified = modified
        self.tags = tags
        self.sortOrder = sortOrder
    }

    var fileName: String {
        "\(id).json"
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
            moduleType: .stickyNote,
            title: String(content.prefix(50)),
            summary: String(content.prefix(200))
        )
    }
}
