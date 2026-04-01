#if os(macOS)
import AppKit
import SwiftUI

final class HotkeyPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
            styleMask: [.titled, .closable, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: true
        )

        isFloatingPanel = true
        level = .floating
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        backgroundColor = .clear
        isOpaque = false

        // Center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - frame.width / 2
            let y = screenFrame.midY - frame.height / 2
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    func show<V: View>(content: V, themeManager: ThemeManager) {
        let themed = content.ireneTheme(themeManager.current)
        contentView = NSHostingView(rootView: themed)
        makeKeyAndOrderFront(nil)

        // Size to content
        if let hostingView = contentView {
            let size = hostingView.fittingSize
            setContentSize(size)
        }
    }

    func dismiss() {
        orderOut(nil)
        contentView = nil
    }

    // Close on Escape
    override func cancelOperation(_ sender: Any?) {
        dismiss()
    }
}
#endif
