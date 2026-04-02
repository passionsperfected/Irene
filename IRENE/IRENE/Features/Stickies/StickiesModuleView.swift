import SwiftUI

struct StickiesModuleView: View {
    let vaultManager: VaultManager

    @State private var viewModel: StickiesViewModel
    @State private var editingSticky: StickyNote?
    @State private var showQuickCapture = false
    @State private var isJiggleMode = false
    @State private var draggingSticky: StickyNote?
    @State private var longPressingSticky: UUID?

    @Environment(\.ireneTheme) private var theme

    init(vaultManager: VaultManager) {
        self.vaultManager = vaultManager
        self._viewModel = State(initialValue: StickiesViewModel(vaultManager: vaultManager))
    }

    private let columns = [
        GridItem(.adaptive(minimum: 270, maximum: 420), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(theme.border.opacity(0.3))

            if viewModel.filteredStickies.isEmpty {
                emptyState
            } else {
                gridContent
            }
        }
        .background(theme.background)
        .task {
            await viewModel.loadStickies()
        }
        .sheet(item: $editingSticky) { sticky in
            StickyNoteEditorView(
                sticky: sticky,
                onSave: { updated in
                    Task { await viewModel.updateSticky(updated) }
                },
                onDelete: {
                    Task { await viewModel.deleteSticky(sticky) }
                }
            )
        }
        .sheet(isPresented: $showQuickCapture) {
            StickyQuickCaptureView { content in
                Task {
                    _ = await viewModel.createSticky(content: content)
                }
            }
        }
        // Tap background to exit jiggle mode
        .onTapGesture {
            if isJiggleMode {
                withAnimation(.easeOut(duration: 0.2)) {
                    isJiggleMode = false
                }
            }
        }
        // Escape to exit jiggle mode
        #if os(macOS)
        .onExitCommand {
            if isJiggleMode {
                withAnimation(.easeOut(duration: 0.2)) {
                    isJiggleMode = false
                }
            }
        }
        #endif
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("Stickies")
                .font(Typography.bodySemiBold(size: 14))
                .foregroundStyle(theme.primaryText)

            if isJiggleMode {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isJiggleMode = false
                    }
                } label: {
                    Text("Done")
                        .font(Typography.bodySemiBold(size: 12))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if !isJiggleMode {
                SearchBar(
                    text: Binding(
                        get: { viewModel.searchText },
                        set: { viewModel.searchText = $0 }
                    ),
                    placeholder: "Search stickies..."
                )
                .frame(maxWidth: 220)
            }

            Button {
                showQuickCapture = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Grid

    private var gridContent: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.filteredStickies) { sticky in
                    StickyNoteCard(
                        sticky: sticky,
                        isJiggling: isJiggleMode,
                        onTap: {
                            if isJiggleMode {
                                // In jiggle mode, tap does nothing (drag to reorder)
                            } else {
                                editingSticky = sticky
                            }
                        },
                        onDelete: {
                            Task { await viewModel.deleteSticky(sticky) }
                        }
                    )
                    .onLongPressGesture(minimumDuration: 0.4, pressing: { pressing in
                        // Immediate scale feedback while pressing
                        withAnimation(.easeInOut(duration: 0.15)) {
                            longPressingSticky = pressing ? sticky.id : nil
                        }
                    }, perform: {
                        longPressingSticky = nil
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isJiggleMode = true
                        }
                    })
                    .scaleEffect(longPressingSticky == sticky.id ? 0.93 : 1.0)
                    .opacity(draggingSticky?.id == sticky.id ? 0.4 : 1.0)
                    .onDrag {
                        draggingSticky = sticky
                        return NSItemProvider(object: sticky.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: StickyDropDelegate(
                        targetSticky: sticky,
                        draggingSticky: $draggingSticky,
                        viewModel: viewModel
                    ))
                }
            }
            .padding(16)
            .animation(.easeInOut(duration: 0.2), value: viewModel.filteredStickies.map(\.id))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: "note.text",
            title: "No Stickies",
            message: viewModel.searchText.isEmpty
                ? "Create a quick sticky note to capture a thought"
                : "No stickies match your search",
            action: viewModel.searchText.isEmpty ? {
                showQuickCapture = true
            } : nil,
            actionLabel: viewModel.searchText.isEmpty ? "New Sticky" : nil
        )
    }
}

// MARK: - Drop Delegate for reordering

struct StickyDropDelegate: DropDelegate {
    let targetSticky: StickyNote
    @Binding var draggingSticky: StickyNote?
    let viewModel: StickiesViewModel

    func performDrop(info: DropInfo) -> Bool {
        draggingSticky = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingSticky,
              dragging.id != targetSticky.id else { return }

        let stickies = viewModel.filteredStickies
        guard let fromIndex = stickies.firstIndex(where: { $0.id == dragging.id }),
              let toIndex = stickies.firstIndex(where: { $0.id == targetSticky.id }) else { return }

        Task {
            await viewModel.moveSticky(
                from: IndexSet(integer: fromIndex),
                to: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggingSticky != nil
    }
}
