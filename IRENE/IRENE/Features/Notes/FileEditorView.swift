import SwiftUI

struct FileEditorView: View {
    @Bindable var viewModel: FileEditorViewModel
    var llmService: LLMService?
    var onRename: ((String) -> Void)?

    @Environment(\.ireneTheme) private var theme
    @FocusState private var focusedField: FocusField?
    @State private var showAIAssistant = false
    @State private var isEditingName = false
    @State private var editingName = ""

    private enum FocusField {
        case editor
        case fileName
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                toolbar
                Divider().overlay(theme.border.opacity(0.3))

                // Editor / Preview content
                if viewModel.isRendering && viewModel.isMarkdown {
                    MarkdownRendererView(markdown: viewModel.content)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TextEditor(text: viewModel.contentBinding)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(theme.primaryText)
                        .scrollContentBackground(.hidden)
                        .focused($focusedField, equals: .editor)
                        .disableAutocorrection(true)
                        .textContentType(.none)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                focusedField = .editor
                #if os(macOS)
                disableSmartEditing()
                #endif
            }
        }
        .onDisappear {
            Task {
                await viewModel.saveImmediately()
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            // File icon + editable name
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

            // Contextual buttons based on file type
            contextualButtons

            // AI assistant toggle
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

            // Save indicator
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
        // Pre-fill with the full filename including extension
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
            focusedField = .editor
            return
        }

        // Save current content, then rename
        Task {
            await viewModel.saveImmediately()
            onRename?(newName)
            focusedField = .editor
        }
    }

    private func cancelRename() {
        isEditingName = false
        focusedField = .editor
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
            // Error message bar
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
                // File type badge
                Text(viewModel.fileExtension.uppercased())
                    .font(Typography.caption(size: 9))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.accent.opacity(0.1))
                    .clipShape(Capsule())

                Spacer()

                Text("Ln \(viewModel.lineCount)")
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

    // MARK: - Disable macOS Smart Editing

    #if os(macOS)
    private func disableSmartEditing() {
        guard let window = NSApplication.shared.keyWindow else { return }
        disableSmartEditingInView(window.contentView)
    }

    private func disableSmartEditingInView(_ view: NSView?) {
        guard let view else { return }
        if let textView = view as? NSTextView {
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticDashSubstitutionEnabled = false
            textView.isAutomaticTextReplacementEnabled = false
            textView.isAutomaticSpellingCorrectionEnabled = false
            textView.isAutomaticLinkDetectionEnabled = false
            textView.smartInsertDeleteEnabled = false
        }
        for subview in view.subviews {
            disableSmartEditingInView(subview)
        }
    }
    #endif
}
