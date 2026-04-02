import SwiftUI

struct StickyNoteCard: View {
    let sticky: StickyNote
    let isJiggling: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @Environment(\.ireneTheme) private var theme
    @State private var jiggleTick = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main card
            cardContent
                .rotationEffect(.degrees(isJiggling ? (jiggleTick ? 1.3 : -1.3) : 0))
                .scaleEffect(isJiggling ? 0.97 : 1.0)

            // Delete badge
            if isJiggling {
                Button(action: onDelete) {
                    ZStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 22, height: 22)
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
            }
        }
        // Single animation value drives the wiggle smoothly
        .animation(.easeInOut(duration: 0.12), value: jiggleTick)
        .animation(.easeInOut(duration: 0.2), value: isJiggling)
        .onChange(of: isJiggling) { _, jiggling in
            if jiggling {
                startJiggle()
            }
        }
        .contextMenu {
            Button("Delete", role: .destructive, action: onDelete)
        }
    }

    private var cardContent: some View {
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
                    .strokeBorder(
                        sticky.color.borderColor(from: theme).opacity(isJiggling ? 0.8 : 0.4),
                        lineWidth: isJiggling ? 1.5 : 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func startJiggle() {
        Task { @MainActor in
            while isJiggling {
                try? await Task.sleep(for: .milliseconds(130))
                guard isJiggling else { break }
                jiggleTick.toggle()
            }
            jiggleTick = false
        }
    }
}
