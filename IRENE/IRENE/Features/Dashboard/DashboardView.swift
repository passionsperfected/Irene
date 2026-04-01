import SwiftUI

struct DashboardView: View {
    let vaultManager: VaultManager
    let llmService: LLMService
    var onNavigate: ((AppModule) -> Void)?

    @State private var viewModel: DashboardViewModel
    @Environment(\.ireneTheme) private var theme

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 12)
    ]

    init(vaultManager: VaultManager, llmService: LLMService, onNavigate: ((AppModule) -> Void)? = nil) {
        self.vaultManager = vaultManager
        self.llmService = llmService
        self.onNavigate = onNavigate
        self._viewModel = State(initialValue: DashboardViewModel(vaultManager: vaultManager))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                greeting
                summaryCards
                recentActivity
                dashboardChat
            }
            .padding(20)
        }
        .background(theme.background)
        .task { await viewModel.loadSummary() }
    }

    // MARK: - Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(Typography.heading(size: 22))
                .foregroundStyle(theme.primaryText)

            Text(Date().formatted(date: .complete, time: .omitted))
                .font(Typography.subheading(size: 14))
                .foregroundStyle(theme.secondaryText)
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            DashboardSummaryCard(
                icon: "tray",
                title: "Inbox",
                count: viewModel.inboxCount,
                subtitle: "\(viewModel.openTodos.count) total open tasks",
                onTap: { onNavigate?(.toDo) }
            )

            DashboardSummaryCard(
                icon: "bell",
                title: "Reminders",
                count: viewModel.upcomingReminders.count,
                subtitle: viewModel.overdueReminderCount > 0
                    ? "\(viewModel.overdueReminderCount) overdue"
                    : "All on track",
                accentColor: viewModel.overdueReminderCount > 0 ? .red : nil,
                onTap: { onNavigate?(.reminders) }
            )

            DashboardSummaryCard(
                icon: "doc.text",
                title: "Notes",
                count: viewModel.recentNotes.count,
                subtitle: viewModel.recentNotes.first.map { "Latest: \($0.title)" } ?? "No recent notes",
                onTap: { onNavigate?(.notes) }
            )

            DashboardSummaryCard(
                icon: "note.text",
                title: "Stickies",
                count: viewModel.recentStickies.count,
                subtitle: "Quick capture notes",
                onTap: { onNavigate?(.stickies) }
            )
        }
    }

    // MARK: - Recent Activity

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT ACTIVITY")
                .font(Typography.label())
                .tracking(2)
                .foregroundStyle(theme.secondaryText)

            if viewModel.openTodos.isEmpty && viewModel.recentNotes.isEmpty {
                Text("No recent activity")
                    .font(Typography.body(size: 12))
                    .foregroundStyle(theme.secondaryText.opacity(0.5))
                    .padding(12)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.openTodos.filter(\.isDueToday).prefix(3)) { todo in
                        activityRow(
                            icon: "checklist",
                            text: todo.title,
                            detail: "Due today",
                            tint: theme.accent
                        )
                    }

                    ForEach(viewModel.openTodos.filter(\.isOverdue).prefix(2)) { todo in
                        activityRow(
                            icon: "exclamationmark.circle",
                            text: todo.title,
                            detail: "Overdue",
                            tint: .red
                        )
                    }

                    ForEach(viewModel.upcomingReminders.prefix(3)) { reminder in
                        activityRow(
                            icon: "bell",
                            text: reminder.title,
                            detail: reminder.reminderDate.formatted(date: .abbreviated, time: .shortened),
                            tint: reminder.isOverdue ? .red : theme.secondaryAccent
                        )
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(theme.border.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    private func activityRow(icon: String, text: String, detail: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(tint)
                .frame(width: 24)

            Text(text)
                .font(Typography.body(size: 12))
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)

            Spacer()

            Text(detail)
                .font(Typography.caption(size: 9))
                .foregroundStyle(theme.secondaryText.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Dashboard Chat

    private var dashboardChat: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ASK IRENE")
                .font(Typography.label())
                .tracking(2)
                .foregroundStyle(theme.secondaryText)

            DashboardChatView(
                llmService: llmService,
                contextSummary: viewModel.buildContextSummary()
            )
            .frame(minHeight: 250)
        }
    }
}
