import SwiftUI

// MARK: - Environment Key

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: ThemeDefinition = ThemeManager.fallbackTheme
}

extension EnvironmentValues {
    var ireneTheme: ThemeDefinition {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    func ireneTheme(_ theme: ThemeDefinition) -> some View {
        environment(\.ireneTheme, theme)
            .preferredColorScheme(theme.isDark ? .dark : .light)
    }
}

// MARK: - Themed View Modifiers

struct ThemedBackgroundModifier: ViewModifier {
    @Environment(\.ireneTheme) private var theme

    func body(content: Content) -> some View {
        content
            .background(theme.background)
    }
}

struct ThemedCardModifier: ViewModifier {
    @Environment(\.ireneTheme) private var theme
    var elevation: CardElevation

    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(elevation == .raised ? theme.cardBackground : theme.secondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(theme.border, lineWidth: 1)
                    )
            )
    }
}

enum CardElevation: Sendable {
    case flat
    case raised
}

extension View {
    func themedBackground() -> some View {
        modifier(ThemedBackgroundModifier())
    }

    func themedCard(elevation: CardElevation = .raised) -> some View {
        modifier(ThemedCardModifier(elevation: elevation))
    }
}
