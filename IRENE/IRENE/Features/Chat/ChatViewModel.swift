import Foundation
import SwiftUI

@MainActor @Observable
final class ChatViewModel {
    var conversation: ChatConversation
    var inputText: String = ""
    var isGenerating: Bool = false
    var errorMessage: String?

    private let llmService: LLMService
    private let onConversationUpdated: (ChatConversation) -> Void
    private var streamTask: Task<Void, Never>?

    init(
        conversation: ChatConversation,
        llmService: LLMService,
        onConversationUpdated: @escaping (ChatConversation) -> Void
    ) {
        self.conversation = conversation
        self.llmService = llmService
        self.onConversationUpdated = onConversationUpdated
    }

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    func sendMessage() {
        let content = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        inputText = ""
        errorMessage = nil

        // Add user message
        let userMessage = LLMMessage.user(content)
        conversation.addMessage(userMessage)
        conversation.autoTitle()

        // Add placeholder assistant message
        let assistantMessage = LLMMessage.assistant("")
        conversation.addMessage(assistantMessage)

        // Start streaming
        isGenerating = true
        streamTask = Task {
            do {
                // Get all non-system messages with content, excluding the empty assistant placeholder
                let messagesToSend = conversation.messages.filter { $0.role != .system && !$0.content.isEmpty }
                let stream = llmService.send(messages: messagesToSend)

                for try await chunk in stream {
                    if Task.isCancelled { break }
                    conversation.updateLastAssistantMessage(appendingText: chunk.text)
                    if chunk.isComplete { break }
                }
            } catch {
                errorMessage = error.localizedDescription
                // Remove empty assistant message on error
                if let last = conversation.messages.last, last.role == .assistant, last.content.isEmpty {
                    conversation.messages.removeLast()
                }
            }

            isGenerating = false
            onConversationUpdated(conversation)
        }
    }

    func stopGenerating() {
        streamTask?.cancel()
        streamTask = nil
        isGenerating = false
        onConversationUpdated(conversation)
    }

    func retryLastMessage() {
        // Remove last assistant message and resend
        if let last = conversation.messages.last, last.role == .assistant {
            conversation.messages.removeLast()
        }
        if let lastUser = conversation.messages.last, lastUser.role == .user {
            inputText = lastUser.content
            conversation.messages.removeLast()
            sendMessage()
        }
    }

    func deleteMessage(_ message: LLMMessage) {
        conversation.messages.removeAll { $0.id == message.id }
        onConversationUpdated(conversation)
    }
}
