import SwiftUI

struct DashboardSummaryCard: View {
    let icon: String
    let title: String
    let count: Int
    let subtitle: String
    var accentColor: Color? = nil
    var onTap: (() -> Void)? = nil

    @Environment(\.ireneTheme) private var theme

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(accentColor ?? theme.accent)

                    Spacer()

                    Text("\(count)")
                        .font(Typography.heading(size: 22))
                        .foregroundStyle(theme.primaryText)
                }

                Text(title)
                    .font(Typography.bodySemiBold(size: 12))
                    .foregroundStyle(theme.primaryText)

                Text(subtitle)
                    .font(Typography.caption(size: 10))
                    .foregroundStyle(theme.secondaryText.opacity(0.6))
                    .lineLimit(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(theme.border.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
