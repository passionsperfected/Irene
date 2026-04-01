import SwiftUI

struct ChatBubbleView: View {
    let message: LLMMessage
    let isStreaming: Bool
    var onRetry: (() -> Void)?
    var onCopy: (() -> Void)?
    var onDelete: (() -> Void)?

    @Environment(\.ireneTheme) private var theme

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                // Sender label
                HStack(spacing: 4) {
                    if !isUser {
                        Text("IRENE")
                            .font(Typography.label())
                            .tracking(1.5)
                            .foregroundStyle(theme.accent)
                    } else {
                        Text("YOU")
                            .font(Typography.label())
                            .tracking(1.5)
                            .foregroundStyle(theme.secondaryText.opacity(0.6))
                    }

                    Text(message.timestamp, style: .time)
                        .font(Typography.caption(size: 8))
                        .foregroundStyle(theme.secondaryText.opacity(0.4))
                }

                // Message content
                if message.content.isEmpty && isStreaming {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Thinking...")
                            .font(Typography.body(size: 12))
                            .foregroundStyle(theme.secondaryText.opacity(0.5))
                    }
                    .padding(12)
                    .background(bubbleBackground)
                } else {
                    Group {
                        if isUser {
                            Text(message.content)
                                .font(Typography.body(size: 14))
                                .foregroundStyle(theme.primaryText)
                        } else {
                            // Render assistant markdown
                            if let rendered = try? AttributedString(
                                markdown: message.content,
                                options: .init(interpretedSyntax: .full)
                            ) {
                                Text(rendered)
                                    .font(Typography.body(size: 14))
                                    .foregroundStyle(theme.primaryText)
                            } else {
                                Text(message.content)
                                    .font(Typography.body(size: 14))
                                    .foregroundStyle(theme.primaryText)
                            }
                        }
                    }
                    .textSelection(.enabled)
                    .padding(12)
                    .background(bubbleBackground)
                }
            }
            .contextMenu {
                if let onCopy {
                    Button("Copy", action: onCopy)
                }
                if !isUser, let onRetry {
                    Button("Retry", action: onRetry)
                }
                if let onDelete {
                    Divider()
                    Button("Delete", role: .destructive, action: onDelete)
                }
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }

    private var bubbleBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isUser ? theme.amethystDeep.color : theme.emeraldAbyss.color)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isUser ? theme.secondaryAccent.opacity(0.2) : theme.accent.opacity(0.2),
                        lineWidth: 0.5
                    )
            )
    }
}
