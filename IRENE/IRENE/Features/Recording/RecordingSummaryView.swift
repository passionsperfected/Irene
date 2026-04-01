import SwiftUI

struct RecordingSummaryView: View {
    let summary: RecordingSummary
    var onCreateToDo: ((String) -> Void)?

    @Environment(\.ireneTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("AI SUMMARY")
                        .font(Typography.label())
                        .tracking(2)
                        .foregroundStyle(theme.secondaryText)

                    Spacer()

                    Text(summary.model)
                        .font(Typography.caption(size: 8))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.accent.opacity(0.1))
                        .clipShape(Capsule())
                }

                // Summary text
                Text(summary.summary)
                    .font(Typography.body(size: 13))
                    .foregroundStyle(theme.primaryText)
                    .textSelection(.enabled)

                // Key topics
                if !summary.keyTopics.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("KEY TOPICS")
                            .font(Typography.label())
                            .tracking(2)
                            .foregroundStyle(theme.secondaryText)

                        ForEach(summary.keyTopics, id: \.self) { topic in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(theme.accent)
                                    .frame(width: 5, height: 5)
                                Text(topic)
                                    .font(Typography.body(size: 12))
                                    .foregroundStyle(theme.primaryText)
                            }
                        }
                    }
                }

                // Action items
                if !summary.actionItems.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ACTION ITEMS")
                            .font(Typography.label())
                            .tracking(2)
                            .foregroundStyle(theme.secondaryText)

                        ForEach(summary.actionItems, id: \.self) { item in
                            HStack(spacing: 8) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 10))
                                    .foregroundStyle(theme.accent)

                                Text(item)
                                    .font(Typography.body(size: 12))
                                    .foregroundStyle(theme.primaryText)

                                Spacer()

                                if let onCreateToDo {
                                    Button {
                                        onCreateToDo(item)
                                    } label: {
                                        Text("Add Task")
                                            .font(Typography.caption(size: 8))
                                            .foregroundStyle(theme.accent)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(theme.accent.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                Text("Generated \(summary.generatedAt.formatted())")
                    .font(Typography.caption(size: 9))
                    .foregroundStyle(theme.secondaryText.opacity(0.4))
            }
            .padding(16)
        }
    }
}
