#if os(macOS)
import AppKit

struct EditorThemeAdapter {
    let backgroundColor: NSColor
    let textColor: NSColor
    let cursorColor: NSColor
    let selectionColor: NSColor
    let currentLineHighlight: NSColor
    let gutterBackground: NSColor
    let gutterText: NSColor
    let gutterActiveText: NSColor
    let matchHighlight: NSColor
    let currentMatchHighlight: NSColor
    let font: NSFont

    init(theme: ThemeDefinition) {
        backgroundColor = NSColor(hex: theme.obsidian.hex)
        textColor = NSColor(hex: theme.ivory.hex)
        cursorColor = NSColor(hex: theme.jade.hex)
        selectionColor = NSColor(hex: theme.jade.hex).withAlphaComponent(0.25)
        currentLineHighlight = NSColor(hex: theme.dusk.hex).withAlphaComponent(0.4)
        gutterBackground = NSColor(hex: theme.midnight.hex)
        gutterText = NSColor(hex: theme.ghost.hex).withAlphaComponent(0.3)
        gutterActiveText = NSColor(hex: theme.ghost.hex).withAlphaComponent(0.8)
        matchHighlight = NSColor(hex: theme.jade.hex).withAlphaComponent(0.2)
        currentMatchHighlight = NSColor(hex: theme.jade.hex).withAlphaComponent(0.5)
        font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    }
}

// MARK: - NSColor hex initializer

private extension NSColor {
    convenience init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else {
            self.init(white: 1.0, alpha: 1.0)
            return
        }
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8) & 0xFF) / 255.0
        let b = CGFloat(value & 0xFF) / 255.0
        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}
#endif
