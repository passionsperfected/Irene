import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)?
    var actionLabel: String?

    @Environment(\.ireneTheme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(theme.secondaryText.opacity(0.5))

            Text(title)
                .font(Typography.subheading(size: 20))
                .foregroundStyle(theme.primaryText)

            Text(message)
                .font(Typography.body(size: 14))
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            if let action, let actionLabel {
                Button(action: action) {
                    Text(actionLabel)
                        .font(Typography.button())
                        .textCase(.uppercase)
                        .tracking(1)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(theme.accent.opacity(0.2))
                        .foregroundStyle(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(theme.accent.opacity(0.4), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
