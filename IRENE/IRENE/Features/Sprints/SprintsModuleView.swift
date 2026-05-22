import SwiftUI

struct SprintsModuleView: View {
    let vaultManager: VaultManager

    @State private var viewModel: SprintsViewModel
    @State private var expandedSprints: Set<UUID> = []
    @State private var editingGoal: GoalEdit?
    @State private var editingSprint: Sprint?
    @State private var showNewSprint = false
    @State private var newSprintName = ""

    @Environment(\.ireneTheme) private var theme

    init(vaultManager: VaultManager) {
        self.vaultManager = vaultManager
        self._viewModel = State(initialValue: SprintsViewModel(vaultManager: vaultManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(theme.border.opacity(0.3))

            if viewModel.sprints.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    icon: "flag.checkered",
                    title: "No Sprints Yet",
                    message: "Create a sprint to start tracking high-level goals.",
                    action: { showNewSprint = true },
                    actionLabel: "New Sprint"
                )
            } else {
                sprintList
            }
        }
        .background(theme.background)
        .task { await viewModel.loadSprints() }
        .sheet(isPresented: $showNewSprint, onDismiss: { newSprintName = "" }) {
            newSprintSheet
        }
        .sheet(item: $editingGoal) { edit in
            GoalEditorSheet(
                goal: edit.goal,
                isNew: edit.isNew,
                onSave: { updated in
                    Task {
                        if edit.isNew {
                            await viewModel.addGoal(updated, to: edit.sprintID)
                        } else {
                            await viewModel.updateGoal(updated, in: edit.sprintID)
                        }
                    }
                },
                onDelete: edit.isNew ? nil : { Task { await viewModel.deleteGoal(edit.goal.id, from: edit.sprintID) } }
            )
        }
        .sheet(item: $editingSprint) { sprint in
            SprintEditorSheet(
                sprint: sprint,
                onSave: { updated in Task { await viewModel.updateSprint(updated) } },
                onDelete: { Task { await viewModel.deleteSprint(sprint) } }
            )
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("Sprint Goals")
                .font(Typography.bodySemiBold(size: 14))
                .foregroundStyle(theme.primaryText)

            if !viewModel.sprints.isEmpty {
                Text("\(viewModel.sprints.count)")
                    .font(Typography.caption(size: 10))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.accent.opacity(0.15))
                    .clipShape(Capsule())
            }

            Spacer()

            Button { showNewSprint = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("New Sprint")
                }
                .font(Typography.button(size: 11))
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(theme.accent.opacity(0.12))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Sprint list

    private var sprintList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.orderedSprints) { sprint in
                    sprintCard(sprint)
                }
            }
            .padding(16)
        }
    }

    private func sprintCard(_ sprint: Sprint) -> some View {
        let expanded = expandedSprints.contains(sprint.id)
        return VStack(alignment: .leading, spacing: 0) {
            sprintHeader(sprint, expanded: expanded)

            if expanded {
                Divider().overlay(theme.border.opacity(0.2))
                VStack(spacing: 0) {
                    ForEach(sprint.goals) { goal in
                        goalRow(goal, sprintID: sprint.id)
                        Divider().overlay(theme.border.opacity(0.1))
                    }

                    addGoalRow(sprintID: sprint.id)
                }
            }
        }
        .background(theme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(theme.border.opacity(0.2), lineWidth: 1)
        )
    }

    private func sprintHeader(_ sprint: Sprint, expanded: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if expanded { expandedSprints.remove(sprint.id) }
                else { expandedSprints.insert(sprint.id) }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text(sprint.name.isEmpty ? "Untitled Sprint" : sprint.name)
                        .font(Typography.bodySemiBold(size: 14))
                        .foregroundStyle(theme.primaryText)

                    HStack(spacing: 8) {
                        if let start = sprint.startDate, let end = sprint.endDate {
                            Text("\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))")
                                .font(Typography.caption(size: 10))
                                .foregroundStyle(theme.secondaryText)
                        }
                        Text("\(sprint.completedGoalCount) / \(sprint.goals.count) goals")
                            .font(Typography.caption(size: 10))
                            .foregroundStyle(theme.secondaryText)
                    }
                }

                Spacer()

                if !sprint.goals.isEmpty {
                    progressBar(fraction: sprint.progressFraction)
                        .frame(width: 80, height: 4)
                }

                Button { editingSprint = sprint } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.secondaryText)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .help("Edit sprint")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func progressBar(fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.border.opacity(0.3))
                Capsule()
                    .fill(theme.accent)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
    }

    private func goalRow(_ goal: SprintGoal, sprintID: UUID) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                Task { await viewModel.cycleGoalStatus(goal, in: sprintID) }
            } label: {
                Image(systemName: goal.status.iconName)
                    .font(.system(size: 16))
                    .foregroundStyle(goal.status == .done ? theme.accent : theme.secondaryText.opacity(0.6))
                    .frame(width: 20)
            }
            .buttonStyle(.plain)
            .help(goal.status.displayName)

            VStack(alignment: .leading, spacing: 3) {
                Text(goal.title.isEmpty ? "Untitled goal" : goal.title)
                    .font(Typography.bodyMedium(size: 13))
                    .foregroundStyle(goal.status == .done || goal.status == .dropped
                        ? theme.secondaryText.opacity(0.6)
                        : theme.primaryText)
                    .strikethrough(goal.status == .done)

                if !goal.description.isEmpty {
                    Text(goal.description)
                        .font(Typography.body(size: 12))
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    if !goal.dri.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 9))
                            Text(goal.dri)
                                .font(Typography.caption(size: 10))
                        }
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.accent.opacity(0.12))
                        .clipShape(Capsule())
                    }

                    Text(goal.status.displayName)
                        .font(Typography.caption(size: 9))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(theme.secondaryText.opacity(0.7))
                }
            }

            Spacer()

            Button {
                editingGoal = GoalEdit(goal: goal, sprintID: sprintID)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.secondaryText)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contextMenu {
            Button("Delete Goal", role: .destructive) {
                Task { await viewModel.deleteGoal(goal.id, from: sprintID) }
            }
        }
    }

    private func addGoalRow(sprintID: UUID) -> some View {
        Button {
            editingGoal = GoalEdit(
                goal: SprintGoal(),
                sprintID: sprintID,
                isNew: true
            )
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 13))
                Text("Add Goal")
                    .font(Typography.bodyMedium(size: 12))
            }
            .foregroundStyle(theme.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - New sprint sheet

    private var newSprintSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Sprint")
                .font(Typography.subheading(size: 18))
                .foregroundStyle(theme.primaryText)

            TextField("Sprint name (e.g. Q2 Sprint 3)", text: $newSprintName)
                .textFieldStyle(.plain)
                .padding(10)
                .background(theme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onSubmit { commitNewSprint() }

            HStack {
                Spacer()
                Button("Cancel") { showNewSprint = false }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.secondaryText)

                Button("Create") { commitNewSprint() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(theme.accent.opacity(0.15))
                    .clipShape(Capsule())
                    .disabled(newSprintName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
        .background(theme.background)
    }

    private func commitNewSprint() {
        let name = newSprintName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        Task {
            if let sprint = await viewModel.createSprint(name: name) {
                expandedSprints.insert(sprint.id)
            }
        }
        newSprintName = ""
        showNewSprint = false
    }
}

// MARK: - Editor sheets

struct GoalEdit: Identifiable {
    var goal: SprintGoal
    var sprintID: UUID
    var isNew: Bool = false
    var id: UUID { goal.id }
}

private struct GoalEditorSheet: View {
    let goal: SprintGoal
    let isNew: Bool
    let onSave: (SprintGoal) -> Void
    let onDelete: (() -> Void)?

    @State private var title: String
    @State private var description: String
    @State private var dri: String
    @State private var status: SprintGoalStatus

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ireneTheme) private var theme

    init(
        goal: SprintGoal,
        isNew: Bool = false,
        onSave: @escaping (SprintGoal) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.goal = goal
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: goal.title)
        _description = State(initialValue: goal.description)
        _dri = State(initialValue: goal.dri)
        _status = State(initialValue: goal.status)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isNew ? "New Goal" : "Edit Goal")
                .font(Typography.subheading(size: 18))
                .foregroundStyle(theme.primaryText)

            field(label: "Title") {
                TextField("Goal title", text: $title)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(theme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            field(label: "Description") {
                TextEditor(text: $description)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 80)
                    .background(theme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            field(label: "DRI") {
                TextField("Directly responsible individual", text: $dri)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(theme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            field(label: "Status") {
                Picker("Status", selection: $status) {
                    ForEach(SprintGoalStatus.allCases, id: \.self) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack {
                if let onDelete {
                    Button("Delete", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }

                Spacer()

                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.secondaryText)

                Button(isNew ? "Create" : "Save") {
                    var updated = goal
                    updated.title = title
                    updated.description = description
                    updated.dri = dri
                    updated.status = status
                    onSave(updated)
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(theme.accent.opacity(0.15))
                .clipShape(Capsule())
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
        .background(theme.background)
    }

    @ViewBuilder
    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Typography.caption(size: 10))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(theme.secondaryText)
            content()
        }
    }
}

private struct SprintEditorSheet: View {
    let sprint: Sprint
    let onSave: (Sprint) -> Void
    let onDelete: () -> Void

    @State private var name: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var hasStartDate: Bool
    @State private var hasEndDate: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ireneTheme) private var theme

    init(sprint: Sprint, onSave: @escaping (Sprint) -> Void, onDelete: @escaping () -> Void) {
        self.sprint = sprint
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: sprint.name)
        _hasStartDate = State(initialValue: sprint.startDate != nil)
        _hasEndDate = State(initialValue: sprint.endDate != nil)
        _startDate = State(initialValue: sprint.startDate ?? Date())
        _endDate = State(initialValue: sprint.endDate ?? Date().addingTimeInterval(14 * 24 * 3600))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Sprint")
                .font(Typography.subheading(size: 18))
                .foregroundStyle(theme.primaryText)

            VStack(alignment: .leading, spacing: 4) {
                Text("NAME")
                    .font(Typography.caption(size: 10))
                    .tracking(1)
                    .foregroundStyle(theme.secondaryText)
                TextField("Sprint name", text: $name)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(theme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Toggle("Set start date", isOn: $hasStartDate)
            if hasStartDate {
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
            }

            Toggle("Set end date", isOn: $hasEndDate)
            if hasEndDate {
                DatePicker("End", selection: $endDate, displayedComponents: .date)
            }

            HStack {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)

                Spacer()

                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.secondaryText)

                Button("Save") {
                    var updated = sprint
                    updated.name = name
                    updated.startDate = hasStartDate ? startDate : nil
                    updated.endDate = hasEndDate ? endDate : nil
                    onSave(updated)
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
    }
}
