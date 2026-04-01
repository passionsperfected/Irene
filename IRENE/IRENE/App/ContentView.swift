import SwiftUI

struct ContentView: View {
    let vaultManager: VaultManager
    let themeManager: ThemeManager
    let llmService: LLMService
    @Bindable var appState: AppState

    @Environment(\.ireneTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if !vaultManager.isConfigured {
                VaultPickerView(vaultManager: vaultManager) {
                    appState.showVaultPicker = false
                }
            } else {
                mainContent
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        #if os(macOS)
        macOSLayout
        #else
        if horizontalSizeClass == .compact {
            iPhoneLayout
        } else {
            iPadLayout
        }
        #endif
    }

    // MARK: - macOS Layout

    #if os(macOS)
    private var macOSLayout: some View {
        NavigationSplitView {
            IRENESidebar(selectedModule: $appState.selectedModule)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            moduleView(for: appState.selectedModule)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.background)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    appState.showSettings = true
                } label: {
                    Image(systemName: "gear")
                        .foregroundStyle(theme.secondaryText)
                }
            }
        }
        .sheet(isPresented: $appState.showSettings) {
            SettingsView(vaultManager: vaultManager, themeManager: themeManager, llmService: llmService)
        }
    }
    #endif

    // MARK: - iPad Layout

    private var iPadLayout: some View {
        NavigationSplitView {
            IRENESidebar(selectedModule: $appState.selectedModule)
        } detail: {
            moduleView(for: appState.selectedModule)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.background)
        }
        .sheet(isPresented: $appState.showSettings) {
            SettingsView(vaultManager: vaultManager, themeManager: themeManager, llmService: llmService)
        }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        TabView(selection: $appState.selectedModule) {
            ForEach(AppModule.allCases) { module in
                moduleView(for: module)
                    .tabItem {
                        Label(module.displayName, systemImage: module.iconName)
                    }
                    .tag(module as AppModule?)
            }
        }
        .sheet(isPresented: $appState.showSettings) {
            SettingsView(vaultManager: vaultManager, themeManager: themeManager, llmService: llmService)
        }
    }

    // MARK: - Module Router

    @ViewBuilder
    private func moduleView(for module: AppModule?) -> some View {
        switch module {
        case .dashboard:
            DashboardView(vaultManager: vaultManager, llmService: llmService) { module in
                appState.selectedModule = module
            }
        case .chat:
            ChatModuleView(vaultManager: vaultManager, llmService: llmService)
        case .notes:
            NotesModuleView(vaultManager: vaultManager, llmService: llmService)
        case .stickies:
            StickiesModuleView(vaultManager: vaultManager)
        case .toDo:
            ToDoModuleView(vaultManager: vaultManager)
        case .reminders:
            RemindersModuleView(vaultManager: vaultManager)
        case .mail:
            MailModuleView()
        case .calendar:
            CalendarModuleView()
        case .recording:
            RecordingModuleView(vaultManager: vaultManager, llmService: llmService)
        case nil:
            DashboardView(vaultManager: vaultManager, llmService: llmService) { module in
                appState.selectedModule = module
            }
        }
    }

    private func modulePlaceholder(_ title: String, icon: String, description: String) -> some View {
        EmptyStateView(
            icon: icon,
            title: title,
            message: description
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
        .navigationTitle(title)
    }
}
