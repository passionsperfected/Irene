import SwiftUI

struct FileEditorView: View {
    @Bindable var viewModel: FileEditorViewModel
    var llmService: LLMService?
    var onRename: ((String) -> Void)?
    var scrollToLine: Int?

    @Environment(\.ireneTheme) private var theme
    @FocusState private var focusedField: FocusField?
    @State private var showAIAssistant = false
    @State private var showFindReplace = false
    @State private var isEditingName = false
    @State private var editingName = ""
    @State private var cursorLine: Int = 1
    @State private var cursorColumn: Int = 1
    @AppStorage("irene.editor.fontSize") private var fontSize: Double = 14
    #if os(macOS)
    @State private var bridge = NSTextViewBridge()
    #endif

    private var findDelegate: (any EditorFindDelegate)? {
        #if os(macOS)
        return bridge
        #else
        return nil
        #endif
    }

    private enum FocusField {
        case editor
        case fileName
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                toolbar
                Divider().overlay(theme.border.opacity(0.3))

                // Find/Replace bar
                if showFindReplace {
                    FindReplaceBar(
                        isVisible: $showFindReplace,
                        content: viewModel.contentBinding,
                        findDelegate: findDelegate
                    )
                }

                // Editor / Preview content
                if viewModel.isRendering && viewModel.isMarkdown {
                    MarkdownRendererView(markdown: viewModel.content)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(spacing: 0) {
                        LineNumbersView(content: viewModel.content, fontSize: fontSize)

                        TextEditor(text: viewModel.contentBinding)
                            .font(.system(size: fontSize, design: .monospaced))
                            .foregroundStyle(theme.primaryText)
                            .scrollContentBackground(.hidden)
                            .focused($focusedField, equals: .editor)
                            .disableAutocorrection(true)
                            .textContentType(.none)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                        .onAppear {
                            #if os(macOS)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                bridge.reattach(window: NSApplication.shared.keyWindow, theme: theme)
                                bridge.onContentChanged = { newContent in
                                    viewModel.content = newContent
                                }
                            }
                            // Scroll to line with extra delay to let text layout complete
                            if let line = scrollToLine {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    bridge.scrollToLine(line)
                                }
                            }
                            #endif
                        }
                }

                bottomBar
            }

            if showAIAssistant, let llmService {
                Divider().overlay(theme.border.opacity(0.3))
                NoteAIAssistantView(
                    noteContent: viewModel.content,
                    noteTitle: viewModel.fileName,
                    llmService: llmService
                )
                .frame(width: 300)
            }
        }
        .background(theme.background)
        .onAppear {
            viewModel.load()
        }
        .onDisappear {
            Task {
                await viewModel.saveImmediately()
            }
        }
        .overlay { keyboardShortcuts }
    }

    // MARK: - Keyboard Shortcuts (invisible)

    @ViewBuilder
    private var keyboardShortcuts: some View {
        VStack {
            Button { withAnimation(.easeInOut(duration: 0.15)) { showFindReplace = true } } label: { Color.clear }
                .keyboardShortcut("f", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)

            Button { withAnimation(.easeInOut(duration: 0.15)) { showFindReplace = true } } label: { Color.clear }
                .keyboardShortcut("h", modifiers: [.command, .option])
                .frame(width: 0, height: 0)
                .opacity(0)

            Button { fontSize = min(fontSize + 1, 32) } label: { Color.clear }
                .keyboardShortcut("+", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)

            Button { fontSize = min(fontSize + 1, 32) } label: { Color.clear }
                .keyboardShortcut("=", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)

            Button { fontSize = max(fontSize - 1, 9) } label: { Color.clear }
                .keyboardShortcut("-", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: viewModel.fileType?.iconName ?? "doc")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.accent)

                if isEditingName {
                    TextField("File name", text: $editingName)
                        .font(Typography.bodySemiBold(size: 14))
                        .textFieldStyle(.plain)
                        .foregroundStyle(theme.primaryText)
                        .focused($focusedField, equals: .fileName)
                        .onSubmit { commitRename() }
                        .onExitCommand { cancelRename() }
                        .frame(maxWidth: 300)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(theme.accent.opacity(0.4), lineWidth: 1)
                        )
                } else {
                    Button {
                        startRename()
                    } label: {
                        Text(viewModel.fileName)
                            .font(Typography.bodySemiBold(size: 14))
                            .foregroundStyle(theme.primaryText)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .help("Click to rename")
                }
            }

            Spacer()

            contextualButtons

            if llmService != nil {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAIAssistant.toggle()
                    }
                } label: {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 13))
                        .foregroundStyle(showAIAssistant ? theme.accent : theme.secondaryText)
                        .frame(width: 28, height: 28)
                        .background(showAIAssistant ? theme.accent.opacity(0.15) : theme.accent.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Ask IRENE about this file")
            }

            if viewModel.isSaving {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Rename

    private func startRename() {
        editingName = viewModel.fileName
        isEditingName = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            focusedField = .fileName
        }
    }

    private func commitRename() {
        let newName = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        isEditingName = false

        guard !newName.isEmpty, newName != viewModel.fileName else {
            return
        }

        Task {
            await viewModel.saveImmediately()
            onRename?(newName)
        }
    }

    private func cancelRename() {
        isEditingName = false
    }

    // MARK: - Contextual Buttons

    @ViewBuilder
    private var contextualButtons: some View {
        switch viewModel.fileType {
        case .md:
            Button {
                viewModel.isRendering.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isRendering ? "pencil" : "eye")
                        .font(.system(size: 11))
                    Text(viewModel.isRendering ? "Edit" : "Preview")
                        .font(Typography.caption(size: 10))
                }
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(theme.accent.opacity(viewModel.isRendering ? 0.2 : 0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

        case .json:
            Button {
                viewModel.formatJSON()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 11))
                    Text("Format")
                        .font(Typography.caption(size: 10))
                }
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(theme.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

        case .txt, nil:
            EmptyView()
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            if let error = viewModel.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(Typography.caption(size: 10))
                        .foregroundStyle(.orange)
                    Spacer()
                    Button {
                        viewModel.errorMessage = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8))
                            .foregroundStyle(theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.08))
            }

            Divider().overlay(theme.border.opacity(0.3))

            HStack(spacing: 16) {
                Text(viewModel.fileExtension.uppercased())
                    .font(Typography.caption(size: 9))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.accent.opacity(0.1))
                    .clipShape(Capsule())

                Spacer()

                Text("\(Int(fontSize))px")
                    .font(Typography.caption(size: 10))
                    .foregroundStyle(theme.secondaryText.opacity(0.5))

                Text("Ln \(cursorLine), Col \(cursorColumn)")
                    .font(Typography.caption(size: 10))
                    .foregroundStyle(theme.secondaryText.opacity(0.5))

                Text("\(viewModel.wordCount) words")
                    .font(Typography.caption(size: 10))
                    .foregroundStyle(theme.secondaryText.opacity(0.5))

                Text("UTF-8")
                    .font(Typography.caption(size: 10))
                    .foregroundStyle(theme.secondaryText.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

}
