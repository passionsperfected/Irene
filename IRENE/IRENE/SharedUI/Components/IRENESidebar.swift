import SwiftUI

struct IRENESidebar: View {
    @Binding var selectedModule: AppModule?
    @Environment(\.ireneTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("IRENE")
                .font(Typography.heading(size: 16))
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(AppModule.allCases) { module in
                        sidebarItem(module)
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer(minLength: 0)

            // Mini calendar
            MiniCalendarView()
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .background(theme.background)
    }

    private func sidebarItem(_ module: AppModule) -> some View {
        Button {
            selectedModule = module
        } label: {
            HStack(spacing: 8) {
                Image(systemName: module.iconName)
                    .font(.system(size: 13))
                    .foregroundStyle(selectedModule == module ? theme.accent : theme.secondaryText)
                    .frame(width: 20)

                Text(module.displayName)
                    .font(Typography.bodyMedium(size: 13))
                    .foregroundStyle(selectedModule == module ? theme.primaryText : theme.secondaryText)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedModule == module ? theme.accent.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
