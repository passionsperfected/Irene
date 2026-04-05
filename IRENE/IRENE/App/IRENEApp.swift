import SwiftUI

@main
struct IRENEApp: App {
    @State private var vaultManager = VaultManager()
    @State private var themeManager = ThemeManager()
    @State private var appState = AppState()
    @State private var llmService: LLMService?

    #if os(macOS)
    @NSApplicationDelegateAdaptor(IRENEAppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        mainWindow
        #if os(macOS)
        Settings {
            SettingsView(vaultManager: vaultManager, themeManager: themeManager, llmService: llmService)
                .ireneTheme(themeManager.current)
        }
        #endif
    }

    private var mainWindow: some Scene {
        WindowGroup {
            ContentView(
                vaultManager: vaultManager,
                themeManager: themeManager,
                llmService: llmService ?? LLMService(vaultManager: vaultManager),
                appState: appState
            )
            .ireneTheme(themeManager.current)
            .onAppear {
                applyStoredTheme()
                if llmService == nil {
                    llmService = LLMService(vaultManager: vaultManager)
                }
                #if os(macOS)
                appDelegate.vaultManager = vaultManager
                appDelegate.themeManager = themeManager
                NotificationDelegate.shared.vaultManager = vaultManager
                #endif
            }
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    appState.showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        #endif
    }

    private func applyStoredTheme() {
        let storedId = vaultManager.configuration.selectedTheme
        themeManager.select(themeId: storedId)
    }
}
