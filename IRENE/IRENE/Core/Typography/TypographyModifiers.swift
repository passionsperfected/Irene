import SwiftUI

// MARK: - Typography View Modifiers

struct IreneHeadingModifier: ViewModifier {
    @Environment(\.ireneTheme) private var theme
    var size: CGFloat

    func body(content: Content) -> some View {
        content
            .font(Typography.heading(size: size))
            .foregroundStyle(theme.primaryText)
    }
}

struct IreneSubheadingModifier: ViewModifier {
    @Environment(\.ireneTheme) private var theme
    var size: CGFloat

    func body(content: Content) -> some View {
        content
            .font(Typography.subheading(size: size))
            .foregroundStyle(theme.secondaryText)
    }
}

struct IreneBodyModifier: ViewModifier {
    @Environment(\.ireneTheme) private var theme
    var size: CGFloat

    func body(content: Content) -> some View {
        content
            .font(Typography.body(size: size))
            .foregroundStyle(theme.primaryText)
    }
}

struct IreneLabelModifier: ViewModifier {
    @Environment(\.ireneTheme) private var theme

    func body(content: Content) -> some View {
        content
            .font(Typography.label())
            .textCase(.uppercase)
            .tracking(2)
            .foregroundStyle(theme.secondaryText)
    }
}

extension View {
    func ireneHeading(size: CGFloat = 28) -> some View {
        modifier(IreneHeadingModifier(size: size))
    }

    func ireneSubheading(size: CGFloat = 18) -> some View {
        modifier(IreneSubheadingModifier(size: size))
    }

    func ireneBody(size: CGFloat = 14) -> some View {
        modifier(IreneBodyModifier(size: size))
    }

    func ireneLabel() -> some View {
        modifier(IreneLabelModifier())
    }
}
