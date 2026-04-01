#if os(macOS)
import AppKit
import Carbon

enum HotkeyAction: Sendable {
    case stickyCapture    // ⌃⌥⌘0
    case todoCapture      // ⌃⌥⌘=
    case reminderCapture  // ⌃⌥⌘-
}

final class GlobalHotkeyManager: @unchecked Sendable {
    private var monitors: [Any] = []
    var onHotkey: ((HotkeyAction) -> Void)?

    func register() {
        // Use local + global monitoring for key events
        // ⌃⌥⌘ is the modifier combo for all three hotkeys
        let requiredFlags: NSEvent.ModifierFlags = [.control, .option, .command]

        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event, requiredFlags: requiredFlags)
        }

        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event, requiredFlags: requiredFlags)
            return event
        }

        if let globalMonitor { monitors.append(globalMonitor) }
        if let localMonitor { monitors.append(localMonitor) }
    }

    func unregister() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors.removeAll()
    }

    private func handleKeyEvent(_ event: NSEvent, requiredFlags: NSEvent.ModifierFlags) {
        guard event.modifierFlags.contains(requiredFlags) else { return }

        switch event.keyCode {
        case 29: // 0 key
            onHotkey?(.stickyCapture)
        case 24: // = key
            onHotkey?(.todoCapture)
        case 27: // - key
            onHotkey?(.reminderCapture)
        default:
            break
        }
    }

    deinit {
        unregister()
    }
}
#endif
