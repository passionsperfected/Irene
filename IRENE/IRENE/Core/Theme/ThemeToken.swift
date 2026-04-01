import SwiftUI

enum ThemeToken: String, CaseIterable, Sendable {
    // Darks
    case void, obsidian, midnight, shadow, slate, dusk, ash
    // Primary Accent
    case emeraldAbyss, emeraldDeep, emerald, jade, sage, luminous, mintHaze
    // Secondary Accent
    case amethystAbyss, amethystDeep, amethyst, violet, lavender, mist, lilac
    // Neutrals
    case pewterDeep, pewter, steel, silverCool, silver, pearl, moonstone, shimmer
    // Warm Accents
    case espresso, umber, bronze, tan, honey, sand, blush, warmWhite
    // Interface
    case ghost, ivory

    var group: TokenGroup {
        switch self {
        case .void, .obsidian, .midnight, .shadow, .slate, .dusk, .ash:
            return .darks
        case .emeraldAbyss, .emeraldDeep, .emerald, .jade, .sage, .luminous, .mintHaze:
            return .primaryAccent
        case .amethystAbyss, .amethystDeep, .amethyst, .violet, .lavender, .mist, .lilac:
            return .secondaryAccent
        case .pewterDeep, .pewter, .steel, .silverCool, .silver, .pearl, .moonstone, .shimmer:
            return .neutrals
        case .espresso, .umber, .bronze, .tan, .honey, .sand, .blush, .warmWhite:
            return .warmAccents
        case .ghost, .ivory:
            return .interface
        }
    }

    func color(from theme: ThemeDefinition) -> Color {
        switch self {
        case .void: return theme.void.color
        case .obsidian: return theme.obsidian.color
        case .midnight: return theme.midnight.color
        case .shadow: return theme.shadow.color
        case .slate: return theme.slate.color
        case .dusk: return theme.dusk.color
        case .ash: return theme.ash.color
        case .emeraldAbyss: return theme.emeraldAbyss.color
        case .emeraldDeep: return theme.emeraldDeep.color
        case .emerald: return theme.emerald.color
        case .jade: return theme.jade.color
        case .sage: return theme.sage.color
        case .luminous: return theme.luminous.color
        case .mintHaze: return theme.mintHaze.color
        case .amethystAbyss: return theme.amethystAbyss.color
        case .amethystDeep: return theme.amethystDeep.color
        case .amethyst: return theme.amethyst.color
        case .violet: return theme.violet.color
        case .lavender: return theme.lavender.color
        case .mist: return theme.mist.color
        case .lilac: return theme.lilac.color
        case .pewterDeep: return theme.pewterDeep.color
        case .pewter: return theme.pewter.color
        case .steel: return theme.steel.color
        case .silverCool: return theme.silverCool.color
        case .silver: return theme.silver.color
        case .pearl: return theme.pearl.color
        case .moonstone: return theme.moonstone.color
        case .shimmer: return theme.shimmer.color
        case .espresso: return theme.espresso.color
        case .umber: return theme.umber.color
        case .bronze: return theme.bronze.color
        case .tan: return theme.tan.color
        case .honey: return theme.honey.color
        case .sand: return theme.sand.color
        case .blush: return theme.blush.color
        case .warmWhite: return theme.warmWhite.color
        case .ghost: return theme.ghost.color
        case .ivory: return theme.ivory.color
        }
    }
}

enum TokenGroup: String, CaseIterable, Sendable {
    case darks = "Darks"
    case primaryAccent = "Primary Accent"
    case secondaryAccent = "Secondary Accent"
    case neutrals = "Neutrals"
    case warmAccents = "Warm Accents"
    case interface = "Interface"
}
