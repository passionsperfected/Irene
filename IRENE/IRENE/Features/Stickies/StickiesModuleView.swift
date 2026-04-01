import SwiftUI

struct StickiesModuleView: View {
    let vaultManager: VaultManager

    @State private var viewModel: StickiesViewModel
    @State private var editingSticky: StickyNote?
    @State private var showQuickCapture = false

    @Environment(\.ireneTheme) private var theme

    init(vaultManager: VaultManager) {
        self.vaultManager = vaultManager
        self._viewModel = State(initialValue: StickiesViewModel(vaultManager: vaultManager))
    }

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 280), spacing: 12)
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
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("Stickies")
                .font(Typography.bodySemiBold(size: 14))
                .foregroundStyle(theme.primaryText)

            Spacer()

            SearchBar(
                text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.searchText = $0 }
                ),
                placeholder: "Search stickies..."
            )
            .frame(maxWidth: 220)

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
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.filteredStickies) { sticky in
                    StickyNoteCard(
                        sticky: sticky,
                        onTap: {
                            editingSticky = sticky
                        },
                        onDelete: {
                            Task { await viewModel.deleteSticky(sticky) }
                        }
                    )
                }
            }
            .padding(16)
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
