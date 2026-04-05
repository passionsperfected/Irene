import SwiftUI

struct ToDoItemRow: View {
    let item: ToDoItem
    let onToggle: () -> Void
    let onTap: () -> Void

    @Environment(\.ireneTheme) private var theme

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Checkbox
                Button(action: onToggle) {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(item.isCompleted ? theme.accent : theme.secondaryText.opacity(0.4))
                }
                .buttonStyle(.plain)

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(Typography.bodySemiBold(size: 13))
                        .foregroundStyle(item.isCompleted ? theme.secondaryText.opacity(0.5) : theme.primaryText)
                        .strikethrough(item.isCompleted)
                        .lineLimit(1)

                    if !item.description.isEmpty {
                        Text(item.description)
                            .font(Typography.body(size: 11))
                            .foregroundStyle(theme.secondaryText.opacity(0.6))
                            .lineLimit(1)
                    }

                    // Tags + dates row
                    HStack(spacing: 6) {
                        // Tags
                        if !item.tags.isEmpty {
                            ForEach(item.tags.prefix(4), id: \.self) { tag in
                                Text(tag)
                                    .font(Typography.caption(size: 8))
                                    .foregroundStyle(TagColor.color(for: tag))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(TagColor.color(for: tag).opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }

                        Spacer()

                        HStack(spacing: 3) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 8))
                            Text(Self.dateFormatter.string(from: item.created))
                        }
                        .font(Typography.caption(size: 8))
                        .foregroundStyle(theme.secondaryText.opacity(0.35))

                        if let dueDate = item.dueDate {
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.system(size: 8))
                                Text(Self.dateFormatter.string(from: dueDate))
                            }
                            .font(Typography.caption(size: 8))
                            .foregroundStyle(item.isOverdue ? .red.opacity(0.8) : theme.secondaryText.opacity(0.5))
                        }
                    }
                }

                Spacer()

                // Priority badge
                priorityBadge

                // Due date badge (compact)
                if let dueDate = item.dueDate {
                    dueDateBadge(dueDate)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var priorityBadge: some View {
        Image(systemName: item.priority.iconName)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(priorityColor)
            .frame(width: 18, height: 18)
            .background(priorityColor.opacity(0.15))
            .clipShape(Circle())
    }

    private var priorityColor: Color {
        switch item.priority {
        case .low: return theme.secondaryText.opacity(0.5)
        case .medium: return theme.accent
        case .high: return theme.honey.color
        case .urgent: return theme.amethyst.color
        }
    }

    private func dueDateBadge(_ date: Date) -> some View {
        Text(date, style: .date)
            .font(Typography.caption(size: 9))
            .foregroundStyle(item.isOverdue ? .red : theme.secondaryText.opacity(0.6))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(item.isOverdue ? Color.red.opacity(0.1) : theme.secondaryBackground)
            .clipShape(Capsule())
    }
}
