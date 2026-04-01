import SwiftUI

struct SettingsView: View {
    @Environment(\.ireneTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let vaultManager: VaultManager
    let themeManager: ThemeManager
    var llmService: LLMService?

    @State private var anthropicKey: String = ""
    @State private var openAIKey: String = ""
    @State private var grokKey: String = ""
    @State private var selectedProvider: LLMProviderType = .anthropic
    @State private var selectedPersonality: String = "professional"
    @State private var hasUnsavedChanges: Bool = false
    @State private var saveConfirmation: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                vaultSection
                themeSection
                providerSection
                apiKeysSection
                personalitySection
            }
            .padding(24)
        }
        .background(theme.background)
        .frame(minWidth: 500, minHeight: 600)
        .onAppear { loadCurrentSettings() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Settings")
                .font(Typography.heading(size: 24))
                .foregroundStyle(theme.primaryText)

            Spacer()

            if hasUnsavedChanges {
                Button {
                    saveAllSettings()
                } label: {
                    Text("Save")
                        .font(Typography.button(size: 12))
                        .textCase(.uppercase)
                        .tracking(1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(theme.accent)
                        .foregroundStyle(theme.isDark ? Color.black : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            if saveConfirmation {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                    Text("Saved")
                        .font(Typography.caption(size: 10))
                        .foregroundStyle(.green)
                }
                .transition(.opacity)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(theme.secondaryText.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help("Close Settings")
        }
    }

    // MARK: - Vault

    private var vaultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("VAULT")

            if let url = vaultManager.vaultURL {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(theme.accent)
                    Text(url.path)
                        .font(Typography.body(size: 13))
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .padding(12)
                .background(theme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("No vault configured")
                    .font(Typography.body())
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }

    // MARK: - Themes

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("THEME")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                ForEach(themeManager.themes) { themeDef in
                    themePreviewCard(themeDef)
                }
            }
        }
    }

    private func themePreviewCard(_ themeDef: ThemeDefinition) -> some View {
        let isSelected = themeManager.current.id == themeDef.id
        return Button {
            themeManager.select(theme: themeDef)
            markChanged()
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(themeDef.obsidian.color)
                    .frame(height: 48)
                    .overlay(
                        HStack(spacing: 4) {
                            Circle().fill(themeDef.jade.color).frame(width: 10, height: 10)
                            Circle().fill(themeDef.violet.color).frame(width: 10, height: 10)
                            Circle().fill(themeDef.ghost.color).frame(width: 10, height: 10)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isSelected ? themeDef.jade.color : Color.clear, lineWidth: 2)
                    )

                Text(themeDef.name)
                    .font(Typography.caption(size: 9))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - LLM Provider

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("LLM PROVIDER")

            HStack(spacing: 8) {
                ForEach(LLMProviderType.allCases) { provider in
                    Button {
                        selectedProvider = provider
                        llmService?.switchProvider(to: provider)
                        markChanged()
                    } label: {
                        Text(provider.displayName)
                            .font(Typography.button(size: 11))
                            .tracking(0.5)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(selectedProvider == provider
                                ? theme.accent.opacity(0.2)
                                : theme.secondaryBackground
                            )
                            .foregroundStyle(selectedProvider == provider
                                ? theme.accent
                                : theme.secondaryText
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        selectedProvider == provider ? theme.accent.opacity(0.4) : theme.border.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - API Keys

    private var apiKeysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("API KEYS")

            apiKeyField(label: "Anthropic (Claude)", value: $anthropicKey, key: "anthropic")
            apiKeyField(label: "OpenAI (ChatGPT)", value: $openAIKey, key: "openai")
            apiKeyField(label: "xAI (Grok)", value: $grokKey, key: "grok")
        }
    }

    private func apiKeyField(label: String, value: Binding<String>, key: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Typography.caption(size: 11))
                .foregroundStyle(theme.secondaryText)

            SecureField("Enter API key...", text: value)
                .font(Typography.body(size: 13))
                .textFieldStyle(.plain)
                .padding(10)
                .background(theme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(theme.border, lineWidth: 1)
                )
                .onChange(of: value.wrappedValue) { _, _ in
                    markChanged()
                }
        }
    }

    // MARK: - Personality

    private var personalitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("PERSONALITY")

            Text("Choose how IRENE communicates with you")
                .font(Typography.body(size: 12))
                .foregroundStyle(theme.secondaryText.opacity(0.6))

            VStack(spacing: 8) {
                ForEach(SystemPrompt.builtInPresets) { preset in
                    personalityCard(preset)
                }
            }
        }
    }

    private func personalityCard(_ preset: SystemPrompt) -> some View {
        let isSelected = selectedPersonality == preset.name.lowercased().components(separatedBy: " ").first ?? ""
        let presetKey = preset.name.lowercased().components(separatedBy: " ").first ?? ""

        return Button {
            selectedPersonality = presetKey
            llmService?.selectedPrompt = preset
            markChanged()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: personalityIcon(for: preset.name))
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? theme.accent : theme.secondaryText)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(Typography.bodySemiBold(size: 13))
                        .foregroundStyle(isSelected ? theme.primaryText : theme.secondaryText)

                    Text(personalityDescription(for: preset.name))
                        .font(Typography.body(size: 11))
                        .foregroundStyle(theme.secondaryText.opacity(0.6))
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? theme.accent.opacity(0.08) : theme.secondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? theme.accent.opacity(0.3) : theme.border.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func personalityIcon(for name: String) -> String {
        switch name {
        case "Professional Assistant": return "briefcase"
        case "Creative Companion": return "paintpalette"
        case "Research Analyst": return "magnifyingglass"
        case "Casual Friend": return "face.smiling"
        case "Socratic Tutor": return "lightbulb"
        case "Executive Secretary": return "sparkles"
        default: return "person"
        }
    }

    private func personalityDescription(for name: String) -> String {
        switch name {
        case "Professional Assistant": return "Formal, concise, and task-focused with structured responses"
        case "Creative Companion": return "Warm, curious, and idea-generating with unexpected connections"
        case "Research Analyst": return "Thorough, analytical, considers multiple perspectives"
        case "Casual Friend": return "Conversational, encouraging, relaxed tone"
        case "Socratic Tutor": return "Guides through questions, encourages deeper thinking"
        case "Executive Secretary": return "Sharp, polished, and playfully charming with flirtatious wit"
        default: return ""
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Typography.label())
            .textCase(.uppercase)
            .tracking(2)
            .foregroundStyle(theme.secondaryText)
    }

    private func loadCurrentSettings() {
        let config = vaultManager.configuration
        anthropicKey = config.apiKeys["anthropic"] ?? ""
        openAIKey = config.apiKeys["openai"] ?? ""
        grokKey = config.apiKeys["grok"] ?? ""
        selectedProvider = LLMProviderType(rawValue: config.selectedProvider) ?? .anthropic
        selectedPersonality = config.selectedPersonality
    }

    private func markChanged() {
        hasUnsavedChanges = true
        saveConfirmation = false
    }

    private func saveAllSettings() {
        Task {
            try? await vaultManager.updateConfiguration { config in
                config.apiKeys["anthropic"] = anthropicKey.isEmpty ? nil : anthropicKey
                config.apiKeys["openai"] = openAIKey.isEmpty ? nil : openAIKey
                config.apiKeys["grok"] = grokKey.isEmpty ? nil : grokKey
                config.selectedProvider = selectedProvider.rawValue
                config.selectedTheme = themeManager.current.id
                config.selectedPersonality = selectedPersonality
            }

            // Update LLM service with new keys
            if let llmService {
                if !anthropicKey.isEmpty {
                    llmService.setAPIKey(anthropicKey, for: .anthropic)
                }
                if !openAIKey.isEmpty {
                    llmService.setAPIKey(openAIKey, for: .openai)
                }
                if !grokKey.isEmpty {
                    llmService.setAPIKey(grokKey, for: .grok)
                }
            }

            hasUnsavedChanges = false
            withAnimation { saveConfirmation = true }

            // Hide confirmation after 2 seconds
            try? await Task.sleep(for: .seconds(2))
            withAnimation { saveConfirmation = false }
        }
    }
}
