import SwiftUI

struct ToDoModuleView: View {
    let vaultManager: VaultManager

    @State private var viewModel: ToDoViewModel
    @State private var editingItem: ToDoItem?
    @State private var showQuickCapture = false

    @Environment(\.ireneTheme) private var theme

    init(vaultManager: VaultManager) {
        self.vaultManager = vaultManager
        self._viewModel = State(initialValue: ToDoViewModel(vaultManager: vaultManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(theme.border.opacity(0.3))

            if viewModel.items.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    icon: "checklist",
                    title: "No Tasks",
                    message: "Add a task to get started",
                    action: { showQuickCapture = true },
                    actionLabel: "New Task"
                )
            } else {
                taskList
            }
        }
        .background(theme.background)
        .task { await viewModel.loadItems() }
        .sheet(item: $editingItem) { item in
            ToDoDetailView(
                item: item,
                onSave: { updated in Task { await viewModel.updateItem(updated) } },
                onDelete: { Task { await viewModel.deleteItem(item) } }
            )
        }
        .sheet(isPresented: $showQuickCapture) {
            ToDoQuickCaptureView { title in
                Task { _ = await viewModel.createItem(title: title) }
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("To Do")
                .font(Typography.bodySemiBold(size: 14))
                .foregroundStyle(theme.primaryText)

            if viewModel.openCount > 0 {
                Text("\(viewModel.openCount)")
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
                placeholder: "Search tasks..."
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

    // MARK: - Task List

    private var taskList: some View {
        List {
            if !viewModel.inboxItems.isEmpty {
                taskSection("Inbox", icon: "tray", items: viewModel.inboxItems)
            }
            if !viewModel.overdueItems.isEmpty {
                taskSection("Overdue", icon: "exclamationmark.circle", items: viewModel.overdueItems)
            }
            if !viewModel.todayItems.isEmpty {
                taskSection("Today", icon: "sun.max", items: viewModel.todayItems)
            }
            if !viewModel.upcomingItems.isEmpty {
                taskSection("Upcoming", icon: "calendar", items: viewModel.upcomingItems)
            }
            if viewModel.showCompleted && !viewModel.completedItems.isEmpty {
                taskSection("Completed", icon: "checkmark.circle", items: viewModel.completedItems)
            }

            // Toggle completed visibility
            if !viewModel.completedItems.isEmpty {
                Button {
                    withAnimation { viewModel.showCompleted.toggle() }
                } label: {
                    HStack {
                        Image(systemName: viewModel.showCompleted ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                        Text("\(viewModel.completedItems.count) completed")
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

    private func taskSection(_ title: String, icon: String, items: [ToDoItem]) -> some View {
        Section {
            ForEach(items) { item in
                ToDoItemRow(
                    item: item,
                    onToggle: { Task { await viewModel.toggleCompletion(item) } },
                    onTap: { editingItem = item }
                )
                .contextMenu {
                    if item.inbox {
                        Button("Move from Inbox") {
                            Task { await viewModel.moveFromInbox(item) }
                        }
                    }
                    Button("Delete", role: .destructive) {
                        Task { await viewModel.deleteItem(item) }
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteItem(item) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(Typography.label())
                    .tracking(1.5)
            }
            .foregroundStyle(theme.secondaryText)
        }
    }
}
