import SwiftUI

/// Generates a consistent color for a tag based on its name.
/// Same tag name always produces the same color.
enum TagColor {
    private static let palette: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal,
        .cyan, .blue, .indigo, .purple, .pink, .brown
    ]

    static func color(for tag: String) -> Color {
        let hash = abs(tag.hashValue)
        return palette[hash % palette.count]
    }
}
