import Foundation

// MARK: - Models

struct PayPeriod: Identifiable, Codable, Hashable, Sendable {
    var id: String { "\(start)-\(end)" }
    let payDate: String
    let start: String
    let end: String

    var startDate: Date {
        Self.dateFormatter.date(from: start) ?? Date()
    }

    var endDate: Date {
        Self.dateFormatter.date(from: end) ?? Date()
    }

    var payDateParsed: Date {
        Self.dateFormatter.date(from: payDate) ?? Date()
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Weekdays in this pay period (Mon-Fri).
    var weekdays: [Date] {
        var dates: [Date] = []
        var current = startDate
        let calendar = Calendar.current

        while current <= endDate {
            let weekday = calendar.component(.weekday, from: current)
            if weekday >= 2 && weekday <= 6 {
                dates.append(current)
            }
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return dates
    }
}

struct VacationConfig: Codable, Sendable {
    var currentBalance: Double
    var accrualPerPeriod: Double
    var maxBalance: Double
    var hoursPerDay: Double
    var daysOff: [String]  // ISO date strings (yyyy-MM-dd)

    static let `default` = VacationConfig(
        currentBalance: 237.52,
        accrualPerPeriod: 4.92,
        maxBalance: 240.0,
        hoursPerDay: 8.0,
        daysOff: []
    )
}

struct PayPeriodSummary: Identifiable, Sendable {
    let id: String
    let period: PayPeriod
    let startBalance: Double
    let daysOffInPeriod: [Date]
    let hoursUsed: Double
    let accrued: Double
    let endBalance: Double
    let isAtRisk: Bool   // Would exceed max without days off
    let isCovered: Bool  // Has enough days off to stay under max
}

// MARK: - Service

@Observable @MainActor
final class VacationService {
    var config: VacationConfig = .default
    var payPeriods: [PayPeriod] = []
    var periodSummaries: [PayPeriodSummary] = []

    private let configPath: String

    init() {
        let configsDir = NSString(string: "~/__ai/irene_configs").expandingTildeInPath
        configPath = (configsDir as NSString).appendingPathComponent("vacation_config.json")
        loadConfig()
        loadPayPeriods()
        recalculate()
    }

    // MARK: - Pay Periods

    private func loadPayPeriods() {
        // 2026 pay periods (biweekly)
        payPeriods = [
            PayPeriod(payDate: "2026-01-02", start: "2025-12-13", end: "2025-12-26"),
            PayPeriod(payDate: "2026-01-16", start: "2025-12-27", end: "2026-01-09"),
            PayPeriod(payDate: "2026-01-30", start: "2026-01-10", end: "2026-01-23"),
            PayPeriod(payDate: "2026-02-13", start: "2026-01-24", end: "2026-02-06"),
            PayPeriod(payDate: "2026-02-27", start: "2026-02-07", end: "2026-02-20"),
            PayPeriod(payDate: "2026-03-13", start: "2026-02-21", end: "2026-03-06"),
            PayPeriod(payDate: "2026-03-27", start: "2026-03-07", end: "2026-03-20"),
            PayPeriod(payDate: "2026-04-10", start: "2026-03-21", end: "2026-04-03"),
            PayPeriod(payDate: "2026-04-24", start: "2026-04-04", end: "2026-04-17"),
            PayPeriod(payDate: "2026-05-08", start: "2026-04-18", end: "2026-05-01"),
            PayPeriod(payDate: "2026-05-22", start: "2026-05-02", end: "2026-05-15"),
            PayPeriod(payDate: "2026-06-05", start: "2026-05-16", end: "2026-05-29"),
            PayPeriod(payDate: "2026-06-18", start: "2026-05-30", end: "2026-06-12"),
            PayPeriod(payDate: "2026-07-03", start: "2026-06-13", end: "2026-06-26"),
            PayPeriod(payDate: "2026-07-17", start: "2026-06-27", end: "2026-07-10"),
            PayPeriod(payDate: "2026-07-31", start: "2026-07-11", end: "2026-07-24"),
            PayPeriod(payDate: "2026-08-14", start: "2026-07-25", end: "2026-08-07"),
            PayPeriod(payDate: "2026-08-28", start: "2026-08-08", end: "2026-08-21"),
            PayPeriod(payDate: "2026-09-11", start: "2026-08-22", end: "2026-09-04"),
            PayPeriod(payDate: "2026-09-25", start: "2026-09-05", end: "2026-09-18"),
            PayPeriod(payDate: "2026-10-09", start: "2026-09-19", end: "2026-10-02"),
            PayPeriod(payDate: "2026-10-23", start: "2026-10-03", end: "2026-10-16"),
            PayPeriod(payDate: "2026-11-06", start: "2026-10-17", end: "2026-10-30"),
            PayPeriod(payDate: "2026-11-20", start: "2026-10-31", end: "2026-11-13"),
            PayPeriod(payDate: "2026-12-04", start: "2026-11-14", end: "2026-11-27"),
            PayPeriod(payDate: "2026-12-18", start: "2026-11-28", end: "2026-12-11"),
            PayPeriod(payDate: "2026-12-31", start: "2026-12-12", end: "2026-12-25")
        ]
    }

    // MARK: - Persistence

    private func loadConfig() {
        guard FileManager.default.fileExists(atPath: configPath) else {
            Log.info("No vacation config found, using defaults")
            return
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
            config = try JSONDecoder().decode(VacationConfig.self, from: data)
            Log.info("Loaded vacation config with \(config.daysOff.count) days off")
        } catch {
            Log.error("Failed to load vacation config: \(error)")
        }
    }

    private func saveConfig() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)

            let directory = (configPath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(
                atPath: directory,
                withIntermediateDirectories: true
            )
            try data.write(to: URL(fileURLWithPath: configPath))
            Log.info("Saved vacation config")
        } catch {
            Log.error("Failed to save vacation config: \(error)")
        }
    }

    // MARK: - Day Off Management

    func toggleDayOff(_ date: Date) {
        let dateString = Self.dateString(from: date)

        if config.daysOff.contains(dateString) {
            config.daysOff.removeAll { $0 == dateString }
        } else {
            config.daysOff.append(dateString)
        }

        saveConfig()
        recalculate()
    }

    func isDayOff(_ date: Date) -> Bool {
        let dateString = Self.dateString(from: date)
        return config.daysOff.contains(dateString)
    }

    // MARK: - Calculations

    func recalculate() {
        var summaries: [PayPeriodSummary] = []
        var runningBalance = config.currentBalance

        for period in payPeriods {
            let startBalance = runningBalance

            let daysOffInPeriod = period.weekdays.filter { isDayOff($0) }
            let hoursUsed = Double(daysOffInPeriod.count) * config.hoursPerDay

            let wouldBeWithoutDaysOff = min(startBalance + config.accrualPerPeriod, config.maxBalance)
            let isAtRisk = wouldBeWithoutDaysOff >= config.maxBalance

            let afterUsage = startBalance - hoursUsed
            let afterAccrual = afterUsage + config.accrualPerPeriod
            let endBalance = min(afterAccrual, config.maxBalance)

            let isCovered = endBalance < config.maxBalance || !isAtRisk

            summaries.append(PayPeriodSummary(
                id: period.id,
                period: period,
                startBalance: startBalance,
                daysOffInPeriod: daysOffInPeriod,
                hoursUsed: hoursUsed,
                accrued: config.accrualPerPeriod,
                endBalance: endBalance,
                isAtRisk: isAtRisk,
                isCovered: isCovered
            ))

            runningBalance = endBalance
        }

        periodSummaries = summaries
    }

    func updateBalance(_ newBalance: Double) {
        config.currentBalance = newBalance
        saveConfig()
        recalculate()
    }

    func updateConfig(_ update: (inout VacationConfig) -> Void) {
        update(&config)
        saveConfig()
        recalculate()
    }

    // MARK: - Computed

    var totalDaysOff: Int { config.daysOff.count }

    var totalHoursPlanned: Double { Double(config.daysOff.count) * config.hoursPerDay }

    var projectedYearEndBalance: Double {
        periodSummaries.last?.endBalance ?? config.currentBalance
    }

    var uncoveredPeriods: Int {
        periodSummaries.filter { $0.isAtRisk && !$0.isCovered }.count
    }

    /// Periods from the current month onward (don't pad the UI with already-past periods).
    var visiblePeriods: [PayPeriodSummary] {
        let calendar = Calendar.current
        let now = Date()
        return periodSummaries.filter { summary in
            // Show period if it ends in or after the current month.
            calendar.compare(summary.period.endDate, to: now, toGranularity: .month) != .orderedAscending
        }
    }

    // MARK: - Helpers

    static func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    func payPeriod(for date: Date) -> PayPeriod? {
        payPeriods.first { period in
            date >= period.startDate && date <= period.endDate
        }
    }

    func summary(for period: PayPeriod) -> PayPeriodSummary? {
        periodSummaries.first { $0.period.id == period.id }
    }
}
