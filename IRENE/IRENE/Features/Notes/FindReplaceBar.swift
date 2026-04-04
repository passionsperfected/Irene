import SwiftUI

struct FindReplaceBar: View {
    @Binding var isVisible: Bool
    @Binding var content: String
    var findDelegate: (any EditorFindDelegate)?

    @State private var findText: String = ""
    @State private var replaceText: String = ""
    @State private var showReplace: Bool = false
    @State private var caseSensitive: Bool = false
    @State private var useRegex: Bool = false
    @State private var currentMatchIndex: Int = 0
    @State private var matches: [Range<String.Index>] = []

    @Environment(\.ireneTheme) private var theme
    @FocusState private var focusedField: Field?

    private enum Field {
        case find, replace
    }

    var body: some View {
        VStack(spacing: 4) {
            // Find row
            HStack(spacing: 5) {
                Button {
                    showReplace.toggle()
                } label: {
                    Image(systemName: showReplace ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(theme.secondaryText.opacity(0.5))
                }
                .buttonStyle(.plain)
                .frame(width: 14)

                TextField("Find", text: $findText)
                    .font(.system(size: 12, design: .monospaced))
                    .textFieldStyle(.plain)
                    .foregroundStyle(theme.primaryText)
                    .focused($focusedField, equals: .find)
                    .onSubmit { findNext() }
                    .onChange(of: findText) { _, _ in updateMatches() }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(theme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(
                                matches.isEmpty && !findText.isEmpty
                                    ? Color.red.opacity(0.5)
                                    : theme.border.opacity(0.3),
                                lineWidth: 1
                            )
                    )

                if !findText.isEmpty {
                    Text(matches.isEmpty ? "0" : "\(currentMatchIndex + 1)/\(matches.count)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(matches.isEmpty ? .red.opacity(0.7) : theme.secondaryText)
                        .frame(minWidth: 32)
                }

                Button { findPrevious() } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(matches.isEmpty ? theme.secondaryText.opacity(0.2) : theme.secondaryText)
                .disabled(matches.isEmpty)
                .keyboardShortcut("g", modifiers: [.command, .shift])

                Button { findNext() } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(matches.isEmpty ? theme.secondaryText.opacity(0.2) : theme.secondaryText)
                .disabled(matches.isEmpty)
                .keyboardShortcut("g", modifiers: .command)

                Button { selectAllMatches() } label: {
                    Text("All")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(matches.isEmpty ? theme.secondaryText.opacity(0.2) : theme.accent)
                .disabled(matches.isEmpty)
                .help("Select All Matches (multi-cursor)")

                Rectangle()
                    .fill(theme.border.opacity(0.3))
                    .frame(width: 1, height: 14)

                Button {
                    caseSensitive.toggle()
                    updateMatches()
                } label: {
                    Text("Aa")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(caseSensitive ? theme.accent.opacity(0.2) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .buttonStyle(.plain)
                .foregroundStyle(caseSensitive ? theme.accent : theme.secondaryText.opacity(0.5))

                Button {
                    useRegex.toggle()
                    updateMatches()
                } label: {
                    Text(".*")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(useRegex ? theme.accent.opacity(0.2) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .buttonStyle(.plain)
                .foregroundStyle(useRegex ? theme.accent : theme.secondaryText.opacity(0.5))

                Button { close() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.secondaryText.opacity(0.5))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }

            if showReplace {
                HStack(spacing: 5) {
                    Color.clear.frame(width: 14)

                    TextField("Replace", text: $replaceText)
                        .font(.system(size: 12, design: .monospaced))
                        .textFieldStyle(.plain)
                        .foregroundStyle(theme.primaryText)
                        .focused($focusedField, equals: .replace)
                        .onSubmit { replaceCurrent() }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(theme.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(theme.border.opacity(0.3), lineWidth: 1)
                        )

                    Button { replaceCurrent() } label: {
                        Image(systemName: "arrow.right.arrow.left")
                            .font(.system(size: 9))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(matches.isEmpty ? theme.secondaryText.opacity(0.2) : theme.secondaryText)
                    .disabled(matches.isEmpty)
                    .help("Replace")

                    Button { replaceAll() } label: {
                        Text("Replace All")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(matches.isEmpty ? theme.secondaryText.opacity(0.2) : theme.accent)
                    .disabled(matches.isEmpty)

                    Spacer()
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.cardBackground)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            focusedField = .find
            updateMatches()
        }
    }

    // MARK: - Find Logic

    private func updateMatches() {
        guard !findText.isEmpty else {
            matches = []
            currentMatchIndex = 0
            notifyHighlight()
            return
        }

        if useRegex {
            updateRegexMatches()
        } else {
            updateStringMatches()
        }

        if !matches.isEmpty {
            currentMatchIndex = min(currentMatchIndex, matches.count - 1)
        } else {
            currentMatchIndex = 0
        }
        notifyHighlight()
    }

    private func updateStringMatches() {
        var found: [Range<String.Index>] = []
        let searchIn = caseSensitive ? content : content.lowercased()
        let searchFor = caseSensitive ? findText : findText.lowercased()

        var searchStart = searchIn.startIndex
        while let range = searchIn.range(of: searchFor, range: searchStart..<searchIn.endIndex) {
            found.append(range.lowerBound..<range.upperBound)
            searchStart = range.upperBound
        }
        matches = found
    }

    private func updateRegexMatches() {
        do {
            let options: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
            let regex = try NSRegularExpression(pattern: findText, options: options)
            let nsRange = NSRange(content.startIndex..., in: content)
            let results = regex.matches(in: content, range: nsRange)
            matches = results.compactMap { Range($0.range, in: content) }
        } catch {
            matches = []
        }
    }

    private func findNext() {
        guard !matches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + 1) % matches.count
        notifyHighlight()
    }

    private func findPrevious() {
        guard !matches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex - 1 + matches.count) % matches.count
        notifyHighlight()
    }

    private func selectAllMatches() {
        let nsRanges = matches.compactMap { range -> NSRange? in
            NSRange(range, in: content)
        }
        findDelegate?.selectAllMatches(nsRanges)
    }

    private func notifyHighlight() {
        let nsRanges = matches.compactMap { range -> NSRange? in
            NSRange(range, in: content)
        }
        findDelegate?.highlightMatches(nsRanges, currentIndex: currentMatchIndex)
    }

    // MARK: - Replace

    private func replaceCurrent() {
        guard !matches.isEmpty, currentMatchIndex < matches.count else { return }
        let range = matches[currentMatchIndex]
        content.replaceSubrange(range, with: replaceText)
        updateMatches()
        if currentMatchIndex >= matches.count && !matches.isEmpty {
            currentMatchIndex = 0
        }
    }

    private func replaceAll() {
        guard !matches.isEmpty else { return }
        for range in matches.reversed() {
            content.replaceSubrange(range, with: replaceText)
        }
        updateMatches()
    }

    private func close() {
        findDelegate?.clearHighlights()
        withAnimation(.easeOut(duration: 0.15)) {
            isVisible = false
        }
    }
}
