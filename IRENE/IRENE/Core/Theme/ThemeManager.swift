import Foundation
import SwiftUI

@Observable
final class ThemeManager: @unchecked Sendable {
    private(set) var themes: [ThemeDefinition] = []
    private(set) var current: ThemeDefinition = ThemeManager.fallbackTheme

    private var selectedThemeId: String = "deep-ocean"

    init() {
        loadBundledThemes()
    }

    func select(themeId: String) {
        selectedThemeId = themeId
        if let theme = themes.first(where: { $0.id == themeId }) {
            current = theme
        }
    }

    func select(theme: ThemeDefinition) {
        selectedThemeId = theme.id
        current = theme
    }

    private func loadBundledThemes() {
        guard let themeURLs = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) else {
            themes = [Self.fallbackTheme]
            current = Self.fallbackTheme
            return
        }

        let decoder = JSONDecoder()
        var loaded: [ThemeDefinition] = []

        for url in themeURLs {
            guard let data = try? Data(contentsOf: url),
                  let theme = try? decoder.decode(ThemeDefinition.self, from: data) else {
                continue
            }
            loaded.append(theme)
        }

        if loaded.isEmpty {
            loaded = [Self.fallbackTheme]
        }

        themes = loaded.sorted { $0.name < $1.name }

        if let selected = themes.first(where: { $0.id == selectedThemeId }) {
            current = selected
        } else {
            current = themes[0]
        }
    }

    static let fallbackTheme = ThemeDefinition(
        name: "Deep Ocean",
        id: "deep-ocean",
        isDark: true,
        void: HexColor("#000508"),
        obsidian: HexColor("#010d14"),
        midnight: HexColor("#021520"),
        shadow: HexColor("#04202e"),
        slate: HexColor("#082a3c"),
        dusk: HexColor("#0c3448"),
        ash: HexColor("#144460"),
        emeraldAbyss: HexColor("#001820"),
        emeraldDeep: HexColor("#002838"),
        emerald: HexColor("#006878"),
        jade: HexColor("#00a098"),
        sage: HexColor("#00c8b8"),
        luminous: HexColor("#00e8c8"),
        mintHaze: HexColor("#88fff4"),
        amethystAbyss: HexColor("#1a0820"),
        amethystDeep: HexColor("#2c0c38"),
        amethyst: HexColor("#6018a0"),
        violet: HexColor("#8828d8"),
        lavender: HexColor("#b060f8"),
        mist: HexColor("#d0a0ff"),
        lilac: HexColor("#ecdcff"),
        pewterDeep: HexColor("#04101c"),
        pewter: HexColor("#0c2030"),
        steel: HexColor("#184050"),
        silverCool: HexColor("#386888"),
        silver: HexColor("#6898b8"),
        pearl: HexColor("#a8c8e0"),
        moonstone: HexColor("#d4e8f4"),
        shimmer: HexColor("#eef8ff"),
        espresso: HexColor("#100818"),
        umber: HexColor("#200c30"),
        bronze: HexColor("#481860"),
        tan: HexColor("#803098"),
        honey: HexColor("#c050d8"),
        sand: HexColor("#e888f8"),
        blush: HexColor("#f8c8ff"),
        warmWhite: HexColor("#fdf0ff"),
        ghost: HexColor("#a8c8e0"),
        ivory: HexColor("#eef8ff")
    )
}
