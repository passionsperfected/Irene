#if os(macOS)
import SwiftUI
import AppKit

/// View modifier that intercepts Enter (without Shift) in a TextEditor and calls an action.
/// Shift+Enter passes through normally to create a new line.
struct EnterToSubmitModifier: ViewModifier {
    let action: () -> Void
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear { installMonitor() }
            .onDisappear { removeMonitor() }
    }

    private func installMonitor() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Only intercept Enter (keyCode 36) without Shift
            if event.keyCode == 36 {
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                if flags.isEmpty || flags == .command {
                    // Plain Enter or Cmd+Enter — save
                    DispatchQueue.main.async { action() }
                    return nil // consume
                }
                // Shift+Enter — let through for new line
            }
            return event
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

extension View {
    func onEnterSubmit(action: @escaping () -> Void) -> some View {
        modifier(EnterToSubmitModifier(action: action))
    }
}
#endif
