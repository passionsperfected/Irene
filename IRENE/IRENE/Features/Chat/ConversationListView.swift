import SwiftUI

struct ConversationListView: View {
    @Bindable var viewModel: ConversationListViewModel
    @Binding var selectedConversation: ChatConversation?
    let onNewConversation: () -> Void

    @Environment(\.ireneTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 10) {
                HStack {
                    Text("Conversations")
                        .font(Typography.bodySemiBold(size: 14))
                        .foregroundStyle(theme.primaryText)

                    Spacer()

                    Button(action: onNewConversation) {
                        Image(systemName: "plus.bubble")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                }

                SearchBar(text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.searchText = $0 }
                ))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider().overlay(theme.border.opacity(0.3))

            // Conversation list
            if viewModel.filteredConversations.isEmpty {
                EmptyStateView(
                    icon: "bubble.left.and.bubble.right",
                    title: "No Conversations",
                    message: "Start a new conversation with IRENE",
                    action: onNewConversation,
                    actionLabel: "New Chat"
                )
            } else {
                List(selection: $selectedConversation) {
                    ForEach(viewModel.filteredConversations) { conversation in
                        conversationRow(conversation)
                            .tag(conversation)
                    }
                    .onDelete { offsets in
                        let conversations = viewModel.filteredConversations
                        for offset in offsets {
                            Task { await viewModel.deleteConversation(conversations[offset]) }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(theme.background)
        .task {
            await viewModel.loadConversations()
        }
    }

    private func conversationRow(_ conversation: ChatConversation) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(conversation.title)
                .font(Typography.bodySemiBold(size: 13))
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)

            if let lastMessage = conversation.messages.last(where: { $0.role == .assistant }) {
                Text(lastMessage.content.prefix(60))
                    .font(Typography.body(size: 11))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Text(conversation.modified, style: .relative)
                    .font(Typography.caption(size: 9))
                    .foregroundStyle(theme.secondaryText.opacity(0.5))

                Text("\(conversation.messages.count) messages")
                    .font(Typography.caption(size: 9))
                    .foregroundStyle(theme.secondaryText.opacity(0.5))
            }
        }
        .padding(.vertical, 3)
        .contextMenu {
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteConversation(conversation) }
            }
        }
    }
}
