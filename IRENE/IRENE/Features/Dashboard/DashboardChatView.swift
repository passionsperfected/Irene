import SwiftUI

struct DashboardChatView: View {
    let llmService: LLMService
    let contextSummary: String

    @Environment(\.ireneTheme) private var theme
    @State private var messages: [LLMMessage] = []
    @State private var inputText: String = ""
    @State private var isGenerating = false
    @State private var streamTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.accent)
                Text("Ask IRENE about your day")
                    .font(Typography.bodySemiBold(size: 12))
                    .foregroundStyle(theme.primaryText)
                Spacer()
            }
            .padding(12)

            Divider().overlay(theme.border.opacity(0.3))

            // Messages
            ScrollView {
                if messages.isEmpty {
                    VStack(spacing: 8) {
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
                                    .frame(maxWidth: .infinity)
                                    .background(theme.accent.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { message in
                            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
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
                    }
                    .padding(10)
                }
            }

            Divider().overlay(theme.border.opacity(0.3))

            // Input
            HStack(spacing: 8) {
                TextField("Ask about your day...", text: $inputText)
                    .font(Typography.body(size: 12))
                    .textFieldStyle(.plain)
                    .foregroundStyle(theme.primaryText)
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
                            .font(.system(size: 16))
                            .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(inputText.isEmpty ? theme.secondaryText.opacity(0.3) : theme.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.isEmpty)
                }
            }
            .padding(10)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(theme.border.opacity(0.3), lineWidth: 1)
        )
    }

    private var quickActions: [String] {
        [
            "What's on my plate today?",
            "Summarize my recent activity",
            "What should I focus on?",
            "Any overdue items?"
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
            You are IRENE, the user's intelligent assistant. Here is a summary of their current data:

            \(contextSummary)

            Answer their question based on this context. Be concise, helpful, and actionable.
            """

            let userMessages = messages.filter { $0.role == .user }
            let stream = llmService.send(messages: userMessages, systemPrompt: systemPrompt, maxTokens: 1024)

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
