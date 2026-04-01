import SwiftUI

struct NotesModuleView: View {
    let vaultManager: VaultManager
    let llmService: LLMService?

    @State private var treeViewModel: FileTreeViewModel?
    @State private var editorViewModel: FileEditorViewModel?
    @State private var lastSelectedFile: URL?

    @Environment(\.ireneTheme) private var theme

    init(vaultManager: VaultManager, llmService: LLMService? = nil) {
        self.vaultManager = vaultManager
        self.llmService = llmService
    }

    var body: some View {
        Group {
            if let treeViewModel {
                editorLayout(treeViewModel)
            } else {
                EmptyStateView(
                    icon: "folder",
                    title: "No Vault",
                    message: "Configure a vault in Settings to use Notes"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.background)
            }
        }
        .onAppear { setupTreeViewModel() }
    }

    #if os(macOS)
    private func editorLayout(_ treeVM: FileTreeViewModel) -> some View {
        HStack(spacing: 0) {
            FileTreeView(viewModel: treeVM)
                .frame(width: 240)

            Divider().overlay(theme.border.opacity(0.3))

            if let editorVM = editorViewModel {
                FileEditorView(viewModel: editorVM, llmService: llmService) { newName in
                    renameCurrentFile(newName, treeVM: treeVM, editorVM: editorVM)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(editorVM.fileURL)
            } else {
                EmptyStateView(
                    icon: "doc.text",
                    title: "Select a File",
                    message: "Choose a file from the tree or create a new one"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.background)
            }
        }
        .onChange(of: treeVM.selectionGeneration) { _, _ in
            handleFileSelection(treeVM.selectedFile)
        }
    }
    #else
    private func editorLayout(_ treeVM: FileTreeViewModel) -> some View {
        NavigationStack {
            FileTreeView(viewModel: treeVM)
                .navigationDestination(item: Binding(
                    get: { treeVM.selectedFile },
                    set: { treeVM.selectedFile = $0 }
                )) { url in
                    FileEditorView(
                        viewModel: FileEditorViewModel(fileURL: url),
                        llmService: llmService
                    ) { newName in
                        renameFile(at: url, to: newName, treeVM: treeVM)
                    }
                }
        }
    }
    #endif

    // MARK: - Rename (direct file operation, then rescan tree)

    private func renameCurrentFile(_ newName: String, treeVM: FileTreeViewModel, editorVM: FileEditorViewModel) {
        // Invalidate current editor so it won't save back to the old URL
        editorVM.isInvalidated = true
        editorVM.saveTask?.cancel()
        renameFile(at: editorVM.fileURL, to: newName, treeVM: treeVM)
    }

    private func renameFile(at url: URL, to newName: String, treeVM: FileTreeViewModel) {
        let parentURL = url.deletingLastPathComponent()
        let newURL: URL

        if newName.contains(".") {
            newURL = parentURL.appendingPathComponent(newName)
        } else {
            newURL = parentURL.appendingPathComponent("\(newName).txt")
        }

        guard !FileManager.default.fileExists(atPath: newURL.path) else { return }
        guard url != newURL else { return }

        do {
            try FileManager.default.moveItem(at: url, to: newURL)
            // Set new editor BEFORE scan to prevent onChange from creating a stale one
            editorViewModel = FileEditorViewModel(fileURL: newURL)
            treeVM.selectedFile = newURL
            treeVM.scan()
        } catch {
            treeVM.errorMessage = error.localizedDescription
        }
    }

    private func handleFileSelection(_ newFile: URL?) {
        // Skip if the editor already points to this file (e.g. after inline rename)
        if let newFile, editorViewModel?.fileURL == newFile {
            return
        }

        // Save current editor before switching
        if let currentEditor = editorViewModel, !currentEditor.isInvalidated, currentEditor.fileURL != newFile {
            Task {
                await currentEditor.saveImmediately()
            }
        }

        if let newFile {
            editorViewModel = FileEditorViewModel(fileURL: newFile)
            lastSelectedFile = newFile
        } else {
            editorViewModel = nil
            lastSelectedFile = nil
        }
    }

    private func setupTreeViewModel() {
        guard treeViewModel == nil, let notesDir = try? vaultManager.directoryURL(for: .note) else { return }
        if !FileManager.default.fileExists(atPath: notesDir.path) {
            try? FileManager.default.createDirectory(at: notesDir, withIntermediateDirectories: true)
        }
        treeViewModel = FileTreeViewModel(rootURL: notesDir)
    }
}
