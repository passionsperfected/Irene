import SwiftUI

struct StickyNoteEditorView: View {
    @State var sticky: StickyNote
    let onSave: (StickyNote) -> Void
    let onDelete: () -> Void

    @Environment(\.ireneTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Sticky")
                    .font(Typography.bodySemiBold(size: 14))
                    .foregroundStyle(theme.primaryText)
                Spacer()
                Button("Done") {
                    onSave(sticky)
                    dismiss()
                }
                .font(Typography.bodySemiBold(size: 13))
                .foregroundStyle(theme.accent)
            }
            .padding(16)

            Divider().overlay(theme.border.opacity(0.3))

            // Content
            VStack(alignment: .leading, spacing: 16) {
                // Text editor
                TextEditor(text: $sticky.content)
                    .font(Typography.body(size: 14))
                    .foregroundStyle(theme.primaryText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 150)
                    .padding(8)
                    .background(theme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Color picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("COLOR")
                        .font(Typography.label())
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundStyle(theme.secondaryText)

                    HStack(spacing: 10) {
                        ForEach(StickyColor.allCases, id: \.self) { color in
                            colorOption(color)
                        }
                    }
                }

                // Tags
                VStack(alignment: .leading, spacing: 8) {
                    Text("TAGS")
                        .font(Typography.label())
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundStyle(theme.secondaryText)

                    TagEditor(tags: $sticky.tags)
                }

                Spacer()

                // Delete button
                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Text("Delete Sticky")
                        .font(Typography.bodySemiBold(size: 13))
                        .foregroundStyle(.red.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(theme.background)
        .frame(minWidth: 360, minHeight: 420)
    }

    private func colorOption(_ color: StickyColor) -> some View {
        Button {
            sticky.color = color
        } label: {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.backgroundColor(from: theme))
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                sticky.color == color
                                    ? color.borderColor(from: theme)
                                    : Color.clear,
                                lineWidth: 2
                            )
                    )
                Text(color.displayName)
                    .font(Typography.caption(size: 8))
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .buttonStyle(.plain)
    }
}
