import SwiftUI

struct StickyNoteCard: View {
    let sticky: StickyNote
    let isJiggling: Bool  // kept for API compat, no longer used
    let onTap: () -> Void
    let onDelete: () -> Void

    @Environment(\.ireneTheme) private var theme

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                Text(sticky.content.isEmpty ? "Empty note" : sticky.content)
                    .font(Typography.body(size: 14))
                    .foregroundStyle(sticky.content.isEmpty
                        ? theme.secondaryText.opacity(0.4)
                        : theme.primaryText
                    )
                    .lineLimit(12)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                if !sticky.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(sticky.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(Typography.caption(size: 8))
                                .foregroundStyle(theme.secondaryText.opacity(0.6))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(theme.secondaryText.opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Created")
                            .foregroundStyle(theme.secondaryText.opacity(0.3))
                        Text(Self.dateFormatter.string(from: sticky.created))
                            .foregroundStyle(theme.secondaryText.opacity(0.5))
                    }
                    .font(Typography.caption(size: 8))

                    if sticky.modified != sticky.created {
                        HStack(spacing: 4) {
                            Text("Modified")
                                .foregroundStyle(theme.secondaryText.opacity(0.3))
                            Text(Self.dateFormatter.string(from: sticky.modified))
                                .foregroundStyle(theme.secondaryText.opacity(0.5))
                        }
                        .font(Typography.caption(size: 8))
                    }
                }
            }
            .padding(18)
            .frame(minHeight: 180)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(sticky.color.backgroundColor(from: theme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(sticky.color.borderColor(from: theme).opacity(0.4), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}
