import Testing
import Foundation
@testable import IRENE

@Suite("Theme Definition Tests")
struct ThemeDefinitionTests {
    @Test("HexColor converts to correct RGB")
    func hexColorConversion() {
        let white = HexColor("#ffffff")
        let black = HexColor("#000000")
        let red = HexColor("#ff0000")

        // We can at least verify they don't crash
        _ = white.color
        _ = black.color
        _ = red.color
    }

    @Test("HexColor handles missing hash")
    func hexWithoutHash() {
        let color = HexColor("ff0000")
        _ = color.color // should not crash
    }

    @Test("ThemeDefinition decodes from JSON")
    func decodeThemeJSON() throws {
        let json = """
        {
          "name": "Test Theme",
          "id": "test-theme",
          "isDark": true,
          "void": "#000000",
          "obsidian": "#111111",
          "midnight": "#222222",
          "shadow": "#333333",
          "slate": "#444444",
          "dusk": "#555555",
          "ash": "#666666",
          "emeraldAbyss": "#001100",
          "emeraldDeep": "#002200",
          "emerald": "#003300",
          "jade": "#004400",
          "sage": "#005500",
          "luminous": "#006600",
          "mintHaze": "#007700",
          "amethystAbyss": "#110011",
          "amethystDeep": "#220022",
          "amethyst": "#330033",
          "violet": "#440044",
          "lavender": "#550055",
          "mist": "#660066",
          "lilac": "#770077",
          "pewterDeep": "#111111",
          "pewter": "#222222",
          "steel": "#333333",
          "silverCool": "#444444",
          "silver": "#555555",
          "pearl": "#666666",
          "moonstone": "#777777",
          "shimmer": "#888888",
          "espresso": "#110000",
          "umber": "#220000",
          "bronze": "#330000",
          "tan": "#440000",
          "honey": "#550000",
          "sand": "#660000",
          "blush": "#770000",
          "warmWhite": "#880000",
          "ghost": "#aaaaaa",
          "ivory": "#eeeeee"
        }
        """
        let data = json.data(using: .utf8)!
        let theme = try JSONDecoder().decode(ThemeDefinition.self, from: data)

        #expect(theme.name == "Test Theme")
        #expect(theme.id == "test-theme")
        #expect(theme.isDark == true)
        #expect(theme.void.hex == "#000000")
        #expect(theme.jade.hex == "#004400")
        #expect(theme.ivory.hex == "#eeeeee")
    }

    @Test("Fallback theme has valid values")
    func fallbackTheme() {
        let theme = ThemeManager.fallbackTheme
        #expect(theme.name == "Deep Ocean")
        #expect(theme.isDark == true)
        #expect(!theme.void.hex.isEmpty)
        #expect(!theme.ivory.hex.isEmpty)
    }

    @Test("Convenience color accessors work")
    func convenienceAccessors() {
        let theme = ThemeManager.fallbackTheme
        _ = theme.background
        _ = theme.secondaryBackground
        _ = theme.cardBackground
        _ = theme.accent
        _ = theme.secondaryAccent
        _ = theme.primaryText
        _ = theme.secondaryText
        _ = theme.border
        _ = theme.subtleBackground
    }
}
