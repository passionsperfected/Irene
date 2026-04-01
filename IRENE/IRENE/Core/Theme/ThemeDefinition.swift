import SwiftUI

struct HexColor: Codable, Hashable, Sendable {
    let hex: String

    init(_ hex: String) {
        self.hex = hex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        hex = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }

    var color: Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6,
              let value = UInt64(cleaned, radix: 16) else {
            return .clear
        }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}

struct ThemeDefinition: Codable, Hashable, Sendable, Identifiable {
    let name: String
    let id: String
    let isDark: Bool

    // Darks
    let void: HexColor
    let obsidian: HexColor
    let midnight: HexColor
    let shadow: HexColor
    let slate: HexColor
    let dusk: HexColor
    let ash: HexColor

    // Primary Accent
    let emeraldAbyss: HexColor
    let emeraldDeep: HexColor
    let emerald: HexColor
    let jade: HexColor
    let sage: HexColor
    let luminous: HexColor
    let mintHaze: HexColor

    // Secondary Accent
    let amethystAbyss: HexColor
    let amethystDeep: HexColor
    let amethyst: HexColor
    let violet: HexColor
    let lavender: HexColor
    let mist: HexColor
    let lilac: HexColor

    // Neutrals
    let pewterDeep: HexColor
    let pewter: HexColor
    let steel: HexColor
    let silverCool: HexColor
    let silver: HexColor
    let pearl: HexColor
    let moonstone: HexColor
    let shimmer: HexColor

    // Warm Accents
    let espresso: HexColor
    let umber: HexColor
    let bronze: HexColor
    let tan: HexColor
    let honey: HexColor
    let sand: HexColor
    let blush: HexColor
    let warmWhite: HexColor

    // Interface
    let ghost: HexColor
    let ivory: HexColor
}

// MARK: - Color Convenience Accessors

extension ThemeDefinition {
    /// Primary background
    var background: Color { obsidian.color }
    /// Secondary background
    var secondaryBackground: Color { midnight.color }
    /// Card/container background
    var cardBackground: Color { slate.color }
    /// Primary accent
    var accent: Color { jade.color }
    /// Secondary accent
    var secondaryAccent: Color { violet.color }
    /// Primary text
    var primaryText: Color { ivory.color }
    /// Secondary text
    var secondaryText: Color { ghost.color }
    /// Border color
    var border: Color { ash.color }
    /// Subtle background
    var subtleBackground: Color { dusk.color }
}
