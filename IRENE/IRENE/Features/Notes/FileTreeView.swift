import SwiftUI
import UniformTypeIdentifiers

struct FileTreeView: View {
    @Bindable var viewModel: FileTreeViewModel
    @Environment(\.ireneTheme) private var theme

    @State private var showNewFileSheet = false
    @State private var showNewFolderSheet = false
    @State private var newItemParent: FileTreeNode?
    @State private var renamingNode: FileTreeNode?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(theme.border.opacity(0.3))

            if let root = viewModel.rootNode {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(root.sortedChildren(), id: \.id) { child in
                            FileTreeNodeView(
                                node: child,
                                depth: 0,
                                selectedFile: viewModel.selectedFile,
                                onSelectFile: { viewModel.selectedFile = $0 },
                                onToggleExpand: { viewModel.toggleExpanded($0) },
                                onShowNewFile: { showNewFile(in: $0) },
                                onShowNewFolder: { showNewFolder(in: $0) },
                                onRename: { renamingNode = $0 },
                                onDelete: { viewModel.delete(node: $0) },
                                onDrop: { source, target in
                                    if let sourceNode = viewModel.findNode(for: source) {
                                        viewModel.move(node: sourceNode, to: target)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
                .id(viewModel.treeGeneration)
            } else {
                EmptyStateView(
                    icon: "folder",
                    title: "No Files",
                    message: "Create a file to get started",
                    action: { showNewFile(in: nil) },
                    actionLabel: "New File"
                )
            }
        }
        .background(theme.background)
        .onAppear { viewModel.scan() }
        .sheet(isPresented: $showNewFileSheet) {
            NewFileSheet(parent: newItemParent) { name, type in
                viewModel.createFile(name: name, type: type, in: newItemParent)
            }
        }
        .sheet(isPresented: $showNewFolderSheet) {
            NewFolderSheet { name in
                viewModel.createFolder(name: name, in: newItemParent)
            }
        }
        .sheet(item: $renamingNode) { node in
            RenameSheet(currentName: node.name) { newName in
                viewModel.rename(node: node, to: newName)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Text("Files")
                .font(Typography.bodySemiBold(size: 14))
                .foregroundStyle(theme.primaryText)

            Spacer()

            // Quick new file button
            Button {
                viewModel.quickCreateFile()
            } label: {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .help("New File (⌘N)")
            .keyboardShortcut("n", modifiers: .command)

            // More options menu
            Menu {
                Button {
                    showNewFile(in: nil)
                } label: {
                    Label("New File (choose type)...", systemImage: "doc.badge.plus")
                }
                Button {
                    showNewFolder(in: nil)
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                Divider()
                Button {
                    viewModel.scan()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.secondaryText)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func showNewFile(in parent: FileTreeNode?) {
        newItemParent = parent
        showNewFileSheet = true
    }

    private func showNewFolder(in parent: FileTreeNode?) {
        newItemParent = parent
        showNewFolderSheet = true
    }
}

// MARK: - Recursive Node View (separate struct to break type recursion)

struct FileTreeNodeView: View {
    @ObservedObject var node: FileTreeNode
    let depth: Int
    let selectedFile: URL?
    let onSelectFile: (URL) -> Void
    let onToggleExpand: (FileTreeNode) -> Void
    let onShowNewFile: (FileTreeNode?) -> Void
    let onShowNewFolder: (FileTreeNode?) -> Void
    let onRename: (FileTreeNode) -> Void
    let onDelete: (FileTreeNode) -> Void
    let onDrop: (URL, FileTreeNode) -> Void

    @Environment(\.ireneTheme) private var theme

    var body: some View {
        if node.isDirectory {
            folderContent
        } else {
            fileContent
        }
    }

    private var folderContent: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    onToggleExpand(node)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(theme.secondaryText.opacity(0.5))
                        .frame(width: 10)

                    Image(systemName: node.iconName)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.accent.opacity(0.7))

                    Text(node.name)
                        .font(Typography.bodySemiBold(size: 12))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.leading, CGFloat(depth) * 16 + 8)
                .padding(.vertical, 5)
                .padding(.trailing, 8)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button { onShowNewFile(node) } label: { Label("New File", systemImage: "doc.badge.plus") }
                Button { onShowNewFolder(node) } label: { Label("New Folder", systemImage: "folder.badge.plus") }
                Divider()
                Button { onRename(node) } label: { Label("Rename", systemImage: "pencil") }
                Divider()
                Button(role: .destructive) { onDelete(node) } label: { Label("Delete", systemImage: "trash") }
            }
            .onDrop(of: [.plainText], isTargeted: nil) { providers in
                handleDrop(providers: providers)
            }

            if node.isExpanded {
                ForEach(node.sortedChildren(), id: \.id) { child in
                    FileTreeNodeView(
                        node: child,
                        depth: depth + 1,
                        selectedFile: selectedFile,
                        onSelectFile: onSelectFile,
                        onToggleExpand: onToggleExpand,
                        onShowNewFile: onShowNewFile,
                        onShowNewFolder: onShowNewFolder,
                        onRename: onRename,
                        onDelete: onDelete,
                        onDrop: onDrop
                    )
                }
            }
        }
    }

    private var fileContent: some View {
        let isSelected = selectedFile == node.url
        return Button {
            onSelectFile(node.url)
        } label: {
            HStack(spacing: 6) {
                Color.clear.frame(width: 10)

                Image(systemName: node.iconName)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? theme.accent : theme.secondaryText.opacity(0.6))

                Text(node.name)
                    .font(Typography.body(size: 12))
                    .foregroundStyle(isSelected ? theme.primaryText : theme.secondaryText)
                    .lineLimit(1)

                Spacer()

                if let fileType = node.fileType {
                    Text(fileType.rawValue)
                        .font(Typography.caption(size: 8))
                        .foregroundStyle(theme.secondaryText.opacity(0.3))
                }
            }
            .padding(.leading, CGFloat(depth) * 16 + 8)
            .padding(.vertical, 5)
            .padding(.trailing, 8)
            .background(isSelected ? theme.accent.opacity(0.12) : Color.clear)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { onRename(node) } label: { Label("Rename", systemImage: "pencil") }
            Divider()
            Button(role: .destructive) { onDelete(node) } label: { Label("Delete", systemImage: "trash") }
        }
        .draggable(node.url.absoluteString) {
            Label(node.name, systemImage: node.iconName)
                .padding(6)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
            guard let data = data as? Data,
                  let urlString = String(data: data, encoding: .utf8),
                  let sourceURL = URL(string: urlString) else { return }
            Task { @MainActor in
                onDrop(sourceURL, node)
            }
        }
        return true
    }
}

// MARK: - Sheets

struct NewFileSheet: View {
    let parent: FileTreeNode?
    let onCreate: (String, SupportedFileType) -> Void

    @Environment(\.ireneTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var fileType: SupportedFileType = .txt
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("New File")
                    .font(Typography.bodySemiBold(size: 14))
                    .foregroundStyle(theme.primaryText)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.secondaryText.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            if let parent {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                    Text("In: \(parent.name)")
                        .font(Typography.caption(size: 10))
                }
                .foregroundStyle(theme.secondaryText.opacity(0.6))
            }

            TextField("File name", text: $name)
                .font(Typography.body(size: 14))
                .textFieldStyle(.plain)
                .foregroundStyle(theme.primaryText)
                .focused($isFocused)
                .padding(10)
                .background(theme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onSubmit { create() }

            Picker("Type", selection: $fileType) {
                ForEach(SupportedFileType.allCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.iconName).tag(type)
                }
            }
            .pickerStyle(.radioGroup)
            .font(Typography.body(size: 12))
            .foregroundStyle(theme.primaryText)

            HStack {
                Spacer()
                Button("Create") { create() }
                    .font(Typography.button(size: 12))
                    .foregroundStyle(theme.isDark ? Color.black : Color.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(name.isEmpty ? theme.secondaryText.opacity(0.3) : theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .disabled(name.isEmpty)
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(16)
        .background(theme.background)
        .frame(width: 320)
        .onAppear { isFocused = true }
    }

    private func create() {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        onCreate(cleaned, fileType)
        dismiss()
    }
}

struct NewFolderSheet: View {
    let onCreate: (String) -> Void

    @Environment(\.ireneTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("New Folder")
                    .font(Typography.bodySemiBold(size: 14))
                    .foregroundStyle(theme.primaryText)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.secondaryText.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            TextField("Folder name", text: $name)
                .font(Typography.body(size: 14))
                .textFieldStyle(.plain)
                .foregroundStyle(theme.primaryText)
                .focused($isFocused)
                .padding(10)
                .background(theme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onSubmit { create() }

            HStack {
                Spacer()
                Button("Create") { create() }
                    .font(Typography.button(size: 12))
                    .foregroundStyle(theme.isDark ? Color.black : Color.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(name.isEmpty ? theme.secondaryText.opacity(0.3) : theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .disabled(name.isEmpty)
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(16)
        .background(theme.background)
        .frame(width: 300)
        .onAppear { isFocused = true }
    }

    private func create() {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        onCreate(cleaned)
        dismiss()
    }
}

struct RenameSheet: View {
    let currentName: String
    let onRename: (String) -> Void

    @Environment(\.ireneTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Rename")
                    .font(Typography.bodySemiBold(size: 14))
                    .foregroundStyle(theme.primaryText)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.secondaryText.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            TextField("New name", text: $name)
                .font(Typography.body(size: 14))
                .textFieldStyle(.plain)
                .foregroundStyle(theme.primaryText)
                .focused($isFocused)
                .padding(10)
                .background(theme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onSubmit { rename() }

            HStack {
                Spacer()
                Button("Rename") { rename() }
                    .font(Typography.button(size: 12))
                    .foregroundStyle(theme.isDark ? Color.black : Color.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(name.isEmpty ? theme.secondaryText.opacity(0.3) : theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .disabled(name.isEmpty)
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(16)
        .background(theme.background)
        .frame(width: 300)
        .onAppear {
            name = currentName
            isFocused = true
        }
    }

    private func rename() {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        onRename(cleaned)
        dismiss()
    }
}
