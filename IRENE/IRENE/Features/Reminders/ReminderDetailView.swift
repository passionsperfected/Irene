import SwiftUI

struct ReminderDetailView: View {
    @State var reminder: Reminder
    let onSave: (Reminder) -> Void
    let onDelete: () -> Void

    @Environment(\.ireneTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                titleSection
                notesSection
                dateSection
                recurrenceSection
                tagsSection
                Spacer()
                deleteButton
            }
            .padding(20)
        }
        .background(theme.background)
        .frame(minWidth: 400, minHeight: 480)
    }

    private var header: some View {
        HStack {
            Text("Edit Reminder")
                .font(Typography.bodySemiBold(size: 16))
                .foregroundStyle(theme.primaryText)
            Spacer()
            Button("Save") {
                onSave(reminder)
                dismiss()
            }
            .font(Typography.bodySemiBold(size: 13))
            .foregroundStyle(theme.accent)
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("TITLE")
            TextField("Reminder title", text: $reminder.title)
                .font(Typography.body(size: 14))
                .textFieldStyle(.plain)
                .foregroundStyle(theme.primaryText)
                .padding(10)
                .background(theme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("NOTES")
            TextEditor(text: $reminder.notes)
                .font(Typography.body(size: 13))
                .foregroundStyle(theme.primaryText)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 60)
                .padding(8)
                .background(theme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("DATE & TIME")
            DatePicker(
                "Remind at",
                selection: $reminder.reminderDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(Typography.body(size: 13))
            .foregroundStyle(theme.primaryText)
        }
    }

    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("RECURRENCE")

            Toggle("Recurring", isOn: $reminder.isRecurring)
                .font(Typography.body(size: 13))
                .foregroundStyle(theme.primaryText)
                .toggleStyle(.switch)
                .tint(theme.accent)
                .onChange(of: reminder.isRecurring) { _, isOn in
                    if isOn && reminder.recurrenceRule == nil {
                        reminder.recurrenceRule = RecurrenceRule()
                    }
                }

            if reminder.isRecurring {
                let rule = Binding(
                    get: { reminder.recurrenceRule ?? RecurrenceRule() },
                    set: { reminder.recurrenceRule = $0 }
                )
                HStack(spacing: 12) {
                    Picker("Frequency", selection: rule.frequency) {
                        ForEach(RecurrenceFrequency.allCases, id: \.self) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                    .font(Typography.body(size: 13))

                    Stepper("Every \(rule.wrappedValue.interval)", value: rule.interval, in: 1...365)
                        .font(Typography.body(size: 13))
                        .foregroundStyle(theme.primaryText)
                }
            }
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("TAGS")
            TagEditor(tags: $reminder.tags)
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            onDelete()
            dismiss()
        } label: {
            Text("Delete Reminder")
                .font(Typography.bodySemiBold(size: 13))
                .foregroundStyle(.red.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Typography.label())
            .textCase(.uppercase)
            .tracking(2)
            .foregroundStyle(theme.secondaryText)
    }
}
