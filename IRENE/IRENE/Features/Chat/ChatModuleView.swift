import SwiftUI

struct ChatModuleView: View {
    let vaultManager: VaultManager
    let llmService: LLMService

    @State private var listViewModel: ConversationListViewModel
    @State private var selectedConversation: ChatConversation?
    @State private var chatViewModel: ChatViewModel?

    @Environment(\.ireneTheme) private var theme

    init(vaultManager: VaultManager, llmService: LLMService) {
        self.vaultManager = vaultManager
        self.llmService = llmService
        self._listViewModel = State(initialValue: ConversationListViewModel(vaultManager: vaultManager))
    }

    var body: some View {
        #if os(macOS)
        macOSLayout
        #else
        iOSLayout
        #endif
    }

    // MARK: - macOS

    #if os(macOS)
    private var macOSLayout: some View {
        HSplitView {
            ConversationListView(
                viewModel: listViewModel,
                selectedConversation: $selectedConversation,
                onNewConversation: createNewConversation
            )
            .frame(minWidth: 220, idealWidth: 260, maxWidth: 350)

            if let chatViewModel {
                chatContent(chatViewModel)
                    .id(chatViewModel.conversation.id)
            } else {
                EmptyStateView(
                    icon: "bubble.left.and.bubble.right",
                    title: "Chat with IRENE",
                    message: "Select a conversation or start a new one",
                    action: createNewConversation,
                    actionLabel: "New Chat"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.background)
            }
        }
        .onChange(of: selectedConversation) { _, newConversation in
            if let newConversation {
                chatViewModel = ChatViewModel(
                    conversation: newConversation,
                    llmService: llmService,
                    onConversationUpdated: { updated in
                        Task { await listViewModel.saveConversation(updated) }
                        listViewModel.updateConversation(updated)
                    }
                )
            } else {
                chatViewModel = nil
            }
        }
    }
    #endif

    // MARK: - iOS

    private var iOSLayout: some View {
        NavigationStack {
            ConversationListView(
                viewModel: listViewModel,
                selectedConversation: $selectedConversation,
                onNewConversation: createNewConversation
            )
            .navigationDestination(item: $selectedConversation) { conversation in
                let vm = ChatViewModel(
                    conversation: conversation,
                    llmService: llmService,
                    onConversationUpdated: { updated in
                        Task { await listViewModel.saveConversation(updated) }
                        listViewModel.updateConversation(updated)
                    }
                )
                chatContent(vm)
            }
        }
    }

    // MARK: - Shared

    private func chatContent(_ vm: ChatViewModel) -> some View {
        VStack(spacing: 0) {
            // Chat header with model info
            chatHeader(vm)
            Divider().overlay(theme.border.opacity(0.3))
            ChatView(viewModel: vm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }

    private func chatHeader(_ vm: ChatViewModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.conversation.title)
                    .font(Typography.bodySemiBold(size: 14))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(llmService.selectedModel.displayName)
                        .font(Typography.caption(size: 9))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.accent.opacity(0.1))
                        .clipShape(Capsule())

                    Text(llmService.selectedPrompt.name)
                        .font(Typography.caption(size: 9))
                        .foregroundStyle(theme.secondaryText.opacity(0.6))
                }
            }

            Spacer()

            // Model picker
            Menu {
                ForEach(llmService.availableModels) { model in
                    Button {
                        llmService.selectModel(model)
                    } label: {
                        HStack {
                            Text(model.displayName)
                            if llmService.selectedModel.id == model.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Divider()

                Menu("Personality") {
                    ForEach(llmService.systemPrompts) { prompt in
                        Button {
                            llmService.selectedPrompt = prompt
                        } label: {
                            HStack {
                                Text(prompt.name)
                                if llmService.selectedPrompt.id == prompt.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.secondaryText)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func createNewConversation() {
        let conversation = listViewModel.createConversation()
        selectedConversation = conversation
    }
}
