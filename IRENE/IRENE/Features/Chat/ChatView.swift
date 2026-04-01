import SwiftUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel

    @Environment(\.ireneTheme) private var theme
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider().overlay(theme.border.opacity(0.3))
            inputBar
        }
        .background(theme.background)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.conversation.messages.filter { $0.role != .system }) { message in
                        let isLast = message.id == viewModel.conversation.messages.last?.id
                        ChatBubbleView(
                            message: message,
                            isStreaming: isLast && viewModel.isGenerating,
                            onRetry: message.role == .assistant ? {
                                viewModel.retryLastMessage()
                            } : nil,
                            onCopy: {
                                #if os(macOS)
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(message.content, forType: .string)
                                #else
                                UIPasteboard.general.string = message.content
                                #endif
                            },
                            onDelete: {
                                viewModel.deleteMessage(message)
                            }
                        )
                        .id(message.id)
                    }
                }
                .padding(16)
            }
            .onChange(of: viewModel.conversation.messages.count) { _, _ in
                if let lastId = viewModel.conversation.messages.last?.id {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.conversation.messages.last?.content) { _, _ in
                if let lastId = viewModel.conversation.messages.last?.id {
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 8) {
            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(Typography.caption(size: 10))
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("Dismiss") {
                        viewModel.errorMessage = nil
                    }
                    .font(Typography.caption(size: 10))
                    .foregroundStyle(theme.secondaryText)
                }
                .padding(.horizontal, 16)
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Message IRENE...", text: $viewModel.inputText, axis: .vertical)
                    .font(Typography.body(size: 14))
                    .textFieldStyle(.plain)
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1...6)
                    .focused($isInputFocused)
                    .onSubmit {
                        if viewModel.canSend {
                            viewModel.sendMessage()
                        }
                    }
                    .padding(10)
                    .background(theme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(theme.border.opacity(0.5), lineWidth: 1)
                    )

                if viewModel.isGenerating {
                    Button {
                        viewModel.stopGenerating()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                    .help("Stop generating")
                } else {
                    Button {
                        viewModel.sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(viewModel.canSend ? theme.accent : theme.secondaryText.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canSend)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}
