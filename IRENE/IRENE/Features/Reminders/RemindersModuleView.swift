import SwiftUI

struct RemindersModuleView: View {
    let vaultManager: VaultManager

    @State private var viewModel: RemindersViewModel
    @State private var editingReminder: Reminder?
    @State private var showQuickCapture = false

    @Environment(\.ireneTheme) private var theme

    init(vaultManager: VaultManager) {
        self.vaultManager = vaultManager
        self._viewModel = State(initialValue: RemindersViewModel(vaultManager: vaultManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(theme.border.opacity(0.3))

            if viewModel.reminders.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    icon: "bell",
                    title: "No Reminders",
                    message: "Set a reminder to stay on track",
                    action: { showQuickCapture = true },
                    actionLabel: "New Reminder"
                )
            } else {
                reminderList
            }
        }
        .background(theme.background)
        .task { await viewModel.loadReminders() }
        .sheet(item: $editingReminder) { reminder in
            ReminderDetailView(
                reminder: reminder,
                onSave: { updated in Task { await viewModel.updateReminder(updated) } },
                onDelete: { Task { await viewModel.deleteReminder(reminder) } }
            )
        }
        .sheet(isPresented: $showQuickCapture) {
            ReminderQuickCaptureView { title, date in
                Task { _ = await viewModel.createReminder(title: title, date: date) }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("Reminders")
                .font(Typography.bodySemiBold(size: 14))
                .foregroundStyle(theme.primaryText)

            if viewModel.upcomingCount > 0 {
                Text("\(viewModel.upcomingCount)")
                    .font(Typography.caption(size: 10))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.accent.opacity(0.15))
                    .clipShape(Capsule())
            }

            Spacer()

            SearchBar(
                text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.searchText = $0 }
                ),
                placeholder: "Search reminders..."
            )
            .frame(maxWidth: 220)

            Button { showQuickCapture = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var reminderList: some View {
        List {
            if !viewModel.overdueReminders.isEmpty {
                reminderSection("Overdue", icon: "exclamationmark.circle", reminders: viewModel.overdueReminders, tint: .red)
            }
            if !viewModel.todayReminders.isEmpty {
                reminderSection("Today", icon: "sun.max", reminders: viewModel.todayReminders, tint: nil)
            }
            if !viewModel.upcomingReminders.isEmpty {
                reminderSection("Upcoming", icon: "calendar", reminders: viewModel.upcomingReminders, tint: nil)
            }
            if viewModel.showCompleted && !viewModel.completedReminders.isEmpty {
                reminderSection("Completed", icon: "checkmark.circle", reminders: viewModel.completedReminders, tint: nil)
            }

            if !viewModel.completedReminders.isEmpty {
                Button {
                    withAnimation { viewModel.showCompleted.toggle() }
                } label: {
                    HStack {
                        Image(systemName: viewModel.showCompleted ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                        Text("\(viewModel.completedReminders.count) completed")
                            .font(Typography.caption(size: 10))
                    }
                    .foregroundStyle(theme.secondaryText.opacity(0.5))
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func reminderSection(_ title: String, icon: String, reminders: [Reminder], tint: Color?) -> some View {
        Section {
            ForEach(reminders) { reminder in
                reminderRow(reminder, tint: tint)
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(tint ?? theme.secondaryText)
                Text(title)
                    .font(Typography.label())
                    .tracking(1.5)
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }

    private func reminderRow(_ reminder: Reminder, tint: Color?) -> some View {
        Button { editingReminder = reminder } label: {
            HStack(spacing: 10) {
                Button {
                    Task { await viewModel.toggleCompletion(reminder) }
                } label: {
                    Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(reminder.isCompleted ? theme.accent : theme.secondaryText.opacity(0.4))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(reminder.title)
                        .font(Typography.bodySemiBold(size: 13))
                        .foregroundStyle(reminder.isCompleted ? theme.secondaryText.opacity(0.5) : theme.primaryText)
                        .strikethrough(reminder.isCompleted)

                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(reminder.reminderDate, style: .relative)
                            .font(Typography.caption(size: 10))

                        if reminder.isRecurring {
                            Image(systemName: "repeat")
                                .font(.system(size: 8))
                            Text(reminder.recurrenceRule?.displayString ?? "Recurring")
                                .font(Typography.caption(size: 9))
                        }
                    }
                    .foregroundStyle(tint ?? theme.secondaryText.opacity(0.6))
                }

                Spacer()
            }
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteReminder(reminder) }
            }
        }
    }
}
