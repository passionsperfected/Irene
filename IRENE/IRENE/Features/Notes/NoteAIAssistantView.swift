import SwiftUI

struct NoteAIAssistantView: View {
    let noteContent: String
    let noteTitle: String
    let llmService: LLMService

    @Environment(\.ireneTheme) private var theme
    @State private var messages: [LLMMessage] = []
    @State private var inputText: String = ""
    @State private var isGenerating = false
    @State private var streamTask: Task<Void, Never>?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(theme.border.opacity(0.3))
            messageList
            Divider().overlay(theme.border.opacity(0.3))
            inputArea
        }
        .frame(minWidth: 280)
        .background(theme.background)
    }

    private var header: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 12))
                .foregroundStyle(theme.accent)
            Text("Ask IRENE")
                .font(Typography.bodySemiBold(size: 12))
                .foregroundStyle(theme.primaryText)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty {
                    VStack(spacing: 8) {
                        Text("Ask about this note")
                            .font(Typography.body(size: 12))
                            .foregroundStyle(theme.secondaryText.opacity(0.6))

                        ForEach(quickActions, id: \.self) { action in
                            Button {
                                inputText = action
                                sendMessage()
                            } label: {
                                Text(action)
                                    .font(Typography.body(size: 11))
                                    .foregroundStyle(theme.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(theme.accent.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(messages) { message in
                            assistantBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding(10)
                }
            }
            .onChange(of: messages.count) { _, _ in
                if let lastId = messages.last?.id {
                    withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                }
            }
        }
    }

    private func assistantBubble(_ message: LLMMessage) -> some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
            Text(message.role == .user ? "You" : "IRENE")
                .font(Typography.caption(size: 8))
                .foregroundStyle(theme.secondaryText.opacity(0.5))

            Text(message.content)
                .font(Typography.body(size: 12))
                .foregroundStyle(theme.primaryText)
                .textSelection(.enabled)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(message.role == .user
                            ? theme.amethystDeep.color
                            : theme.emeraldAbyss.color
                        )
                )
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        }
    }

    private var inputArea: some View {
        HStack(spacing: 8) {
            TextField("Ask about this note...", text: $inputText)
                .font(Typography.body(size: 12))
                .textFieldStyle(.plain)
                .foregroundStyle(theme.primaryText)
                .focused($isInputFocused)
                .onSubmit { sendMessage() }
                .padding(8)
                .background(theme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if isGenerating {
                Button {
                    streamTask?.cancel()
                    isGenerating = false
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(inputText.isEmpty ? theme.secondaryText.opacity(0.3) : theme.accent)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty)
            }
        }
        .padding(10)
    }

    private var quickActions: [String] {
        [
            "Summarize this note",
            "Find action items",
            "What are the key points?",
            "Suggest improvements"
        ]
    }

    private func sendMessage() {
        let content = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        inputText = ""
        messages.append(.user(content))
        messages.append(.assistant(""))

        isGenerating = true
        streamTask = Task {
            let systemPrompt = """
            You are IRENE, analyzing a note titled "\(noteTitle)". \
            Here is the note content:\n\n\(noteContent)\n\n\
            Answer the user's question based on this note content. Be concise and helpful.
            """

            let userMessages = messages.filter { $0.role == .user }
            let stream = llmService.send(
                messages: userMessages,
                systemPrompt: systemPrompt,
                maxTokens: 2048
            )

            do {
                for try await chunk in stream {
                    if Task.isCancelled { break }
                    if let lastIndex = messages.indices.last,
                       messages[lastIndex].role == .assistant {
                        messages[lastIndex].content += chunk.text
                    }
                    if chunk.isComplete { break }
                }
            } catch {
                if let lastIndex = messages.indices.last,
                   messages[lastIndex].role == .assistant,
                   messages[lastIndex].content.isEmpty {
                    messages[lastIndex].content = "Error: \(error.localizedDescription)"
                }
            }

            isGenerating = false
        }
    }
}
