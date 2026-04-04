import SwiftUI

struct MiniCalendarView: View {
    @Environment(\.ireneTheme) private var theme
    @State private var displayedMonth = Date()

    private let calendar = Calendar.current
    private let dayOfWeekLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 6) {
            // Month/year header with navigation
            HStack {
                Button { previousMonth() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(theme.secondaryText.opacity(0.5))
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthYearString)
                    .font(Typography.bodySemiBold(size: 10))
                    .foregroundStyle(theme.secondaryText)

                Spacer()

                Button { nextMonth() } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(theme.secondaryText.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            // Day of week headers
            HStack(spacing: 0) {
                ForEach(Array(dayOfWeekLabels.enumerated()), id: \.offset) { _, label in
                    Text(label)
                        .font(Typography.caption(size: 8))
                        .foregroundStyle(theme.secondaryText.opacity(0.4))
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            let days = daysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Text("")
                            .frame(maxWidth: .infinity, minHeight: 18)
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.secondaryBackground.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(theme.border.opacity(0.2), lineWidth: 1)
        )
    }

    private func dayCell(_ day: Int) -> some View {
        let isToday = isCurrentDay(day)
        return Text("\(day)")
            .font(Typography.caption(size: 9))
            .fontWeight(isToday ? .bold : .regular)
            .foregroundStyle(isToday ? (theme.isDark ? Color.black : Color.white) : theme.secondaryText.opacity(0.7))
            .frame(maxWidth: .infinity, minHeight: 18)
            .background(
                Circle()
                    .fill(isToday ? theme.accent : Color.clear)
                    .frame(width: 18, height: 18)
            )
    }

    // MARK: - Helpers

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private func isCurrentDay(_ day: Int) -> Bool {
        let today = Date()
        return calendar.component(.day, from: today) == day
            && calendar.component(.month, from: today) == calendar.component(.month, from: displayedMonth)
            && calendar.component(.year, from: today) == calendar.component(.year, from: displayedMonth)
    }

    private func daysInMonth() -> [Int?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else {
            return []
        }

        let weekdayOfFirst = calendar.component(.weekday, from: firstDay) - 1 // 0 = Sunday
        var days: [Int?] = Array(repeating: nil, count: weekdayOfFirst)
        for day in range {
            days.append(day)
        }
        return days
    }

    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = newDate
        }
    }

    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = newDate
        }
    }
}
