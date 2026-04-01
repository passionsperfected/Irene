#if os(macOS)
import AppKit
import SwiftUI

@MainActor
final class IRENEAppDelegate: NSObject, NSApplicationDelegate {
    private let hotkeyManager = GlobalHotkeyManager()
    private var panel: HotkeyPanel?

    var vaultManager: VaultManager?
    var themeManager: ThemeManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupHotkeys()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregister()
    }

    private func setupHotkeys() {
        hotkeyManager.onHotkey = { [weak self] action in
            Task { @MainActor in
                self?.handleHotkey(action)
            }
        }
        hotkeyManager.register()
    }

    private func handleHotkey(_ action: HotkeyAction) {
        guard let vaultManager, let themeManager else { return }

        // Dismiss any existing panel
        panel?.dismiss()
        panel = HotkeyPanel()

        switch action {
        case .stickyCapture:
            let view = StickyQuickCaptureView { [weak self] content in
                Task { @MainActor in
                    let vm = StickiesViewModel(vaultManager: vaultManager)
                    _ = await vm.createSticky(content: content)
                    self?.panel?.dismiss()
                }
            }
            panel?.show(content: view, themeManager: themeManager)

        case .todoCapture:
            let view = ToDoQuickCaptureView { [weak self] title in
                Task { @MainActor in
                    let vm = ToDoViewModel(vaultManager: vaultManager)
                    _ = await vm.createItem(title: title)
                    self?.panel?.dismiss()
                }
            }
            panel?.show(content: view, themeManager: themeManager)

        case .reminderCapture:
            let view = ReminderQuickCaptureView { [weak self] title, date in
                Task { @MainActor in
                    let vm = RemindersViewModel(vaultManager: vaultManager)
                    _ = await vm.createReminder(title: title, date: date)
                    self?.panel?.dismiss()
                }
            }
            panel?.show(content: view, themeManager: themeManager)
        }
    }
}
#endif
