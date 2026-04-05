import SwiftUI

struct ToDoModuleView: View {
    let vaultManager: VaultManager

    @State private var viewModel: ToDoViewModel
    @State private var editingItem: ToDoItem?
    @State private var showQuickCapture = false
    @State private var draggingItem: ToDoItem?

    @Environment(\.ireneTheme) private var theme

    init(vaultManager: VaultManager) {
        self.vaultManager = vaultManager
        self._viewModel = State(initialValue: ToDoViewModel(vaultManager: vaultManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(theme.border.opacity(0.3))

            // Tag filter strip
            if !viewModel.allTags.isEmpty {
                tagFilterStrip
                Divider().overlay(theme.border.opacity(0.15))
            }

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
        .overlay {
            Button { showQuickCapture = true } label: { Color.clear }
                .keyboardShortcut("n", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)
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

    // MARK: - Tag Filter Strip

    private var tagFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // "All" button to clear filter
                Button {
                    viewModel.selectedTag = nil
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "tag")
                            .font(.system(size: 9))
                        Text("All")
                            .font(Typography.caption(size: 10))
                    }
                    .foregroundStyle(viewModel.selectedTag == nil ? theme.accent : theme.secondaryText.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(viewModel.selectedTag == nil ? theme.accent.opacity(0.15) : Color.clear)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().strokeBorder(
                            viewModel.selectedTag == nil ? theme.accent.opacity(0.3) : theme.border.opacity(0.2),
                            lineWidth: 1
                        )
                    )
                }
                .buttonStyle(.plain)

                ForEach(viewModel.allTags, id: \.tag) { tagInfo in
                    Button {
                        if viewModel.selectedTag == tagInfo.tag {
                            viewModel.selectedTag = nil
                        } else {
                            viewModel.selectedTag = tagInfo.tag
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(TagColor.color(for: tagInfo.tag))
                                .frame(width: 6, height: 6)
                            Text(tagInfo.tag)
                                .font(Typography.caption(size: 10))
                            Text("\(tagInfo.count)")
                                .font(Typography.caption(size: 8))
                                .foregroundStyle(theme.secondaryText.opacity(0.4))
                        }
                        .foregroundStyle(
                            viewModel.selectedTag == tagInfo.tag
                                ? TagColor.color(for: tagInfo.tag)
                                : theme.secondaryText.opacity(0.7)
                        )
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            viewModel.selectedTag == tagInfo.tag
                                ? TagColor.color(for: tagInfo.tag).opacity(0.12)
                                : Color.clear
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(
                                viewModel.selectedTag == tagInfo.tag
                                    ? TagColor.color(for: tagInfo.tag).opacity(0.3)
                                    : theme.border.opacity(0.2),
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Task List

    private var taskList: some View {
        ScrollView {
            VStack(spacing: 0) {
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
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func taskSection(_ title: String, icon: String, items: [ToDoItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(Typography.label())
                    .tracking(1.5)
                Text("(\(items.count))")
                    .font(Typography.caption(size: 9))
            }
            .foregroundStyle(theme.secondaryText)
            .padding(.vertical, 8)

            // Items
            ForEach(items) { item in
                ToDoItemRow(
                    item: item,
                    onToggle: { Task { await viewModel.toggleCompletion(item) } },
                    onTap: { editingItem = item }
                )
                .opacity(draggingItem?.id == item.id ? 0.4 : 1.0)
                .onDrag {
                    draggingItem = item
                    return NSItemProvider(object: item.id.uuidString as NSString)
                }
                .onDrop(of: [.text], delegate: ToDoDropDelegate(
                    targetItem: item,
                    draggingItem: $draggingItem,
                    viewModel: viewModel,
                    sectionItems: items
                ))
                .contextMenu {
                    if item.inbox {
                        Button("Move from Inbox") {
                            Task { await viewModel.moveFromInbox(item) }
                        }
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        Task { await viewModel.deleteItem(item) }
                    }
                }

                Divider().overlay(theme.border.opacity(0.1))
            }
        }
    }
}

// MARK: - Drop Delegate for reordering

struct ToDoDropDelegate: DropDelegate {
    let targetItem: ToDoItem
    @Binding var draggingItem: ToDoItem?
    let viewModel: ToDoViewModel
    let sectionItems: [ToDoItem]

    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingItem,
              dragging.id != targetItem.id else { return }

        guard let fromIndex = sectionItems.firstIndex(where: { $0.id == dragging.id }),
              let toIndex = sectionItems.firstIndex(where: { $0.id == targetItem.id }) else { return }

        Task {
            await viewModel.moveItem(
                from: IndexSet(integer: fromIndex),
                to: toIndex > fromIndex ? toIndex + 1 : toIndex,
                in: sectionItems
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggingItem != nil
    }
}
