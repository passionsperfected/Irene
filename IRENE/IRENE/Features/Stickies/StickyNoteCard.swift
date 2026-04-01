import SwiftUI

struct StickyNoteCard: View {
    let sticky: StickyNote
    let onTap: () -> Void
    let onDelete: () -> Void

    @Environment(\.ireneTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Content
                Text(sticky.content.isEmpty ? "Empty note" : sticky.content)
                    .font(Typography.body(size: 13))
                    .foregroundStyle(sticky.content.isEmpty
                        ? theme.secondaryText.opacity(0.4)
                        : theme.primaryText
                    )
                    .lineLimit(8)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                // Footer
                HStack {
                    // Tags
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

                    Spacer()

                    Text(sticky.modified, style: .relative)
                        .font(Typography.caption(size: 8))
                        .foregroundStyle(theme.secondaryText.opacity(0.4))
                }
            }
            .padding(14)
            .frame(minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(sticky.color.backgroundColor(from: theme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(sticky.color.borderColor(from: theme).opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}
