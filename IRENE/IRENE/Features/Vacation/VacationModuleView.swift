import SwiftUI

struct VacationModuleView: View {
    @State private var service = VacationService()
    @State private var showSettingsSheet = false

    @Environment(\.ireneTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(theme.border.opacity(0.3))

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    summaryCards
                    calendarSection
                    periodTable
                    Spacer(minLength: 40)
                }
                .padding(16)
            }
        }
        .background(theme.background)
        .sheet(isPresented: $showSettingsSheet) {
            VacationConfigSheet(service: service)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("Vacation")
                .font(Typography.bodySemiBold(size: 14))
                .foregroundStyle(theme.primaryText)

            Text("Plan time off to stay under the cap")
                .font(Typography.caption(size: 11))
                .foregroundStyle(theme.secondaryText)

            Spacer()

            Button { showSettingsSheet = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                    Text("Configure")
                }
                .font(Typography.button(size: 11))
                .foregroundStyle(theme.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(theme.secondaryBackground)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Summary cards

    private var summaryCards: some View {
        HStack(spacing: 12) {
            summaryCard(
                title: "Current Balance",
                value: String(format: "%.1f hrs", service.config.currentBalance),
                icon: "clock.fill",
                color: theme.accent
            )
            summaryCard(
                title: "Days Planned",
                value: "\(service.totalDaysOff)",
                icon: "calendar.badge.minus",
                color: .orange
            )
            summaryCard(
                title: "Hours Planned",
                value: String(format: "%.0f hrs", service.totalHoursPlanned),
                icon: "hourglass",
                color: theme.secondaryText
            )
            summaryCard(
                title: "Year-End Projection",
                value: String(format: "%.1f hrs", service.projectedYearEndBalance),
                icon: "chart.line.uptrend.xyaxis",
                color: service.projectedYearEndBalance < service.config.maxBalance ? .green : .red
            )
            if service.uncoveredPeriods > 0 {
                summaryCard(
                    title: "Uncovered",
                    value: "\(service.uncoveredPeriods)",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                )
            }
        }
    }

    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                Text(title.uppercased())
                    .font(Typography.label())
                    .tracking(1.2)
                    .foregroundStyle(theme.secondaryText)
            }
            Text(value)
                .font(Typography.subheading(size: 20))
                .foregroundStyle(theme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(theme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CALENDAR")
                .font(Typography.label())
                .tracking(1.5)
                .foregroundStyle(theme.secondaryText)

            // Show current month + next 9 months (10 months total).
            let calendar = Calendar.current
            let firstOfThisMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: Date())
            ) ?? Date()
            let months: [Date] = (0..<10).compactMap {
                calendar.date(byAdding: .month, value: $0, to: firstOfThisMonth)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(months, id: \.self) { month in
                    MonthCalendarCard(month: month, service: service)
                }
            }
        }
    }

    // MARK: - Period table

    private var periodTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PAY PERIOD DETAILS")
                .font(Typography.label())
                .tracking(1.5)
                .foregroundStyle(theme.secondaryText)

            VStack(spacing: 0) {
                periodHeader
                Divider().overlay(theme.border.opacity(0.2))
                ForEach(service.visiblePeriods) { summary in
                    periodRow(summary)
                    Divider().overlay(theme.border.opacity(0.1))
                }
            }
            .background(theme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(theme.border.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private var periodHeader: some View {
        HStack {
            Text("Period").frame(width: 150, alignment: .leading)
            Text("Start").frame(width: 70, alignment: .trailing)
            Text("Off").frame(width: 50, alignment: .center)
            Text("Used").frame(width: 60, alignment: .trailing)
            Text("Accrued").frame(width: 70, alignment: .trailing)
            Text("End").frame(width: 70, alignment: .trailing)
            Text("Status").frame(width: 90, alignment: .center)
        }
        .font(Typography.label())
        .tracking(1)
        .foregroundStyle(theme.secondaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func periodRow(_ summary: PayPeriodSummary) -> some View {
        let needsAttention = summary.isAtRisk && !summary.isCovered
        return HStack {
            Text("\(formatDate(summary.period.startDate)) – \(formatDate(summary.period.endDate))")
                .frame(width: 150, alignment: .leading)
            Text(String(format: "%.1f", summary.startBalance))
                .frame(width: 70, alignment: .trailing)
            Text("\(summary.daysOffInPeriod.count)")
                .frame(width: 50, alignment: .center)
            Text(String(format: "%.0f", summary.hoursUsed))
                .frame(width: 60, alignment: .trailing)
            Text(String(format: "+%.2f", summary.accrued))
                .frame(width: 70, alignment: .trailing)
                .foregroundStyle(theme.secondaryText)
            Text(String(format: "%.1f", summary.endBalance))
                .frame(width: 70, alignment: .trailing)
                .foregroundStyle(summary.endBalance >= service.config.maxBalance ? .red : theme.primaryText)
            statusBadge(summary).frame(width: 90, alignment: .center)
        }
        .font(Typography.body(size: 12))
        .foregroundStyle(theme.primaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(needsAttention ? Color.orange.opacity(0.08) : Color.clear)
    }

    @ViewBuilder
    private func statusBadge(_ summary: PayPeriodSummary) -> some View {
        if !summary.isAtRisk {
            Text("OK")
                .font(Typography.caption(size: 10))
                .foregroundStyle(theme.secondaryText)
        } else if summary.isCovered {
            Text("Covered")
                .font(Typography.caption(size: 10))
                .foregroundStyle(.green)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.15))
                .clipShape(Capsule())
        } else {
            Text("At Risk")
                .font(Typography.caption(size: 10))
                .foregroundStyle(.red)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.15))
                .clipShape(Capsule())
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Month calendar card

struct MonthCalendarCard: View {
    let month: Date
    let service: VacationService

    @Environment(\.ireneTheme) private var theme
    private let calendar = Calendar.current
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 4) {
            Text(monthName)
                .font(Typography.bodySemiBold(size: 12))
                .foregroundStyle(theme.primaryText)

            HStack(spacing: 2) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(Typography.caption(size: 9))
                        .foregroundStyle(theme.secondaryText.opacity(0.6))
                        .frame(width: 22, height: 16)
                }
            }

            let days = daysInMonth()
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(22), spacing: 2), count: 7),
                spacing: 2
            ) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let date = day {
                        DayCell(date: date, service: service)
                    } else {
                        Color.clear.frame(width: 22, height: 22)
                    }
                }
            }
        }
        .padding(8)
        .background(theme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(theme.border.opacity(0.2), lineWidth: 1)
        )
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }

    private func daysInMonth() -> [Date?] {
        var days: [Date?] = []

        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return days }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        for _ in 1..<firstWeekday { days.append(nil) }

        for day in range {
            var components = calendar.dateComponents([.year, .month], from: month)
            components.day = day
            days.append(calendar.date(from: components))
        }
        return days
    }
}

struct DayCell: View {
    let date: Date
    let service: VacationService

    @State private var isHovered = false
    @Environment(\.ireneTheme) private var theme
    private let calendar = Calendar.current

    var body: some View {
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7
        let isDayOff = service.isDayOff(date)
        let period = service.payPeriod(for: date)
        let summary = period.flatMap { service.summary(for: $0) }
        let showRisk = (summary?.isAtRisk ?? false) && !(summary?.isCovered ?? true) && !isWeekend

        Button {
            if !isWeekend { service.toggleDayOff(date) }
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(Typography.caption(size: 10))
                .foregroundStyle(textColor(isWeekend: isWeekend, isDayOff: isDayOff))
                .frame(width: 22, height: 22)
                .background(
                    Group {
                        if isDayOff {
                            Circle().fill(Color.orange)
                        } else if showRisk {
                            RoundedRectangle(cornerRadius: 4).fill(Color.orange.opacity(0.2))
                        } else if isHovered && !isWeekend {
                            Circle().fill(theme.primaryText.opacity(0.1))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .disabled(isWeekend)
        .onHover { isHovered = $0 }
    }

    private func textColor(isWeekend: Bool, isDayOff: Bool) -> Color {
        if isDayOff { return .white }
        if isWeekend { return theme.secondaryText.opacity(0.4) }
        return theme.primaryText
    }
}

// MARK: - Config sheet

private struct VacationConfigSheet: View {
    @Bindable var service: VacationService

    @State private var currentBalance: Double = 0
    @State private var accrualPerPeriod: Double = 0
    @State private var maxBalance: Double = 0
    @State private var hoursPerDay: Double = 8

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ireneTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Vacation Configuration")
                .font(Typography.subheading(size: 18))
                .foregroundStyle(theme.primaryText)

            stepperRow("Current balance", value: $currentBalance, range: 0...500, step: 0.01, format: "%.2f hr")
            stepperRow("Accrual per period", value: $accrualPerPeriod, range: 0...20, step: 0.01, format: "%.2f hr")
            stepperRow("Max balance", value: $maxBalance, range: 0...1000, step: 1, format: "%.0f hr")
            stepperRow("Hours per day", value: $hoursPerDay, range: 1...12, step: 0.5, format: "%.1f hr")

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.secondaryText)

                Button("Save") {
                    service.updateConfig { c in
                        c.currentBalance = currentBalance
                        c.accrualPerPeriod = accrualPerPeriod
                        c.maxBalance = maxBalance
                        c.hoursPerDay = hoursPerDay
                    }
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(theme.accent.opacity(0.15))
                .clipShape(Capsule())
            }
        }
        .padding(20)
        .frame(width: 380)
        .background(theme.background)
        .onAppear {
            currentBalance = service.config.currentBalance
            accrualPerPeriod = service.config.accrualPerPeriod
            maxBalance = service.config.maxBalance
            hoursPerDay = service.config.hoursPerDay
        }
    }

    private func stepperRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, format: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Stepper(value: value, in: range, step: step) {
                Text(String(format: format, value.wrappedValue))
                    .font(Typography.bodyMedium(size: 13))
            }
        }
    }
}
