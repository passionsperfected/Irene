import SwiftUI

struct ToDoDetailView: View {
    @State var item: ToDoItem
    let onSave: (ToDoItem) -> Void
    let onDelete: () -> Void

    @Environment(\.ireneTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                titleSection
                descriptionSection
                prioritySection
                dueDateSection
                tagsSection
                inboxSection
                Spacer()
                deleteButton
            }
            .padding(20)
        }
        .background(theme.background)
        .frame(minWidth: 400, minHeight: 500)
    }

    private var header: some View {
        HStack {
            Text("Edit Task")
                .font(Typography.bodySemiBold(size: 16))
                .foregroundStyle(theme.primaryText)
            Spacer()
            Button("Save") {
                onSave(item)
                dismiss()
            }
            .font(Typography.bodySemiBold(size: 13))
            .foregroundStyle(theme.accent)
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("TITLE")
            TextField("Task title", text: $item.title)
                .font(Typography.body(size: 14))
                .textFieldStyle(.plain)
                .foregroundStyle(theme.primaryText)
                .padding(10)
                .background(theme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("DESCRIPTION")
            TextEditor(text: $item.description)
                .font(Typography.body(size: 13))
                .foregroundStyle(theme.primaryText)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(8)
                .background(theme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("PRIORITY")
            HStack(spacing: 8) {
                ForEach(Priority.allCases, id: \.self) { priority in
                    Button {
                        item.priority = priority
                    } label: {
                        Text(priority.displayName)
                            .font(Typography.button(size: 11))
                            .tracking(0.5)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(item.priority == priority
                                ? theme.accent.opacity(0.2)
                                : theme.secondaryBackground
                            )
                            .foregroundStyle(item.priority == priority
                                ? theme.accent
                                : theme.secondaryText
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().strokeBorder(
                                    item.priority == priority ? theme.accent.opacity(0.4) : theme.border.opacity(0.3),
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dueDateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("DUE DATE")
            HStack {
                Toggle("Set due date", isOn: Binding(
                    get: { item.dueDate != nil },
                    set: { item.dueDate = $0 ? Date() : nil }
                ))
                .font(Typography.body(size: 13))
                .foregroundStyle(theme.primaryText)
                .toggleStyle(.switch)
                .tint(theme.accent)

                Spacer()

                if item.dueDate != nil {
                    let dueDate = Binding(
                        get: { item.dueDate ?? Date() },
                        set: { item.dueDate = $0 }
                    )
                    DatePicker("", selection: dueDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
            }
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("TAGS")
            TagEditor(tags: $item.tags)
        }
    }

    private var inboxSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("STATUS")
            Toggle("In Inbox", isOn: $item.inbox)
                .font(Typography.body(size: 13))
                .foregroundStyle(theme.primaryText)
                .toggleStyle(.switch)
                .tint(theme.accent)
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            onDelete()
            dismiss()
        } label: {
            Text("Delete Task")
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
