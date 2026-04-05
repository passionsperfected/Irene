import SwiftUI

struct GlobalSearchView: View {
    @Bindable var viewModel: GlobalSearchViewModel
    let onSelectResult: (URL, Int) -> Void
    let onClose: () -> Void

    @Environment(\.ireneTheme) private var theme
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(theme.border.opacity(0.3))
            searchField
            Divider().overlay(theme.border.opacity(0.3))

            if viewModel.isSearching {
                ProgressView()
                    .controlSize(.small)
                    .padding()
                Spacer()
            } else if viewModel.results.isEmpty && !viewModel.searchText.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "No Results",
                    message: "No matches found across files"
                )
            } else if viewModel.searchText.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "Global Search",
                    message: "Search across all files in your vault"
                )
            } else {
                resultsList
            }
        }
        .background(theme.background)
        .onAppear { isSearchFocused = true }
        #if os(macOS)
        .onExitCommand { onClose() }
        #endif
    }

    private var header: some View {
        HStack {
            Text("Search in Files")
                .font(Typography.bodySemiBold(size: 13))
                .foregroundStyle(theme.primaryText)

            if viewModel.resultCount > 0 {
                Text("\(viewModel.resultCount) in \(viewModel.fileCount) files")
                    .font(Typography.caption(size: 9))
                    .foregroundStyle(theme.secondaryText.opacity(0.6))
            }

            Spacer()

            Button { onClose() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.secondaryText.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var searchField: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.secondaryText.opacity(0.5))

                TextField("Search all files...", text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.searchText = $0 }
                ))
                .font(.system(size: 12, design: .monospaced))
                .textFieldStyle(.plain)
                .foregroundStyle(theme.primaryText)
                .focused($isSearchFocused)

                // Options
                Button {
                    viewModel.caseSensitive.toggle()
                } label: {
                    Text("Aa")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(viewModel.caseSensitive ? theme.accent.opacity(0.2) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .buttonStyle(.plain)
                .foregroundStyle(viewModel.caseSensitive ? theme.accent : theme.secondaryText.opacity(0.5))

                Button {
                    viewModel.useRegex.toggle()
                } label: {
                    Text(".*")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(viewModel.useRegex ? theme.accent.opacity(0.2) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .buttonStyle(.plain)
                .foregroundStyle(viewModel.useRegex ? theme.accent : theme.secondaryText.opacity(0.5))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(theme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.groupedResults) { group in
                    // File header — click opens file without scrolling to a line
                    Button {
                        onSelectResult(group.fileURL, 0)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.accent)
                            Text(group.fileName)
                                .font(Typography.bodySemiBold(size: 11))
                                .foregroundStyle(theme.primaryText)
                            Text("(\(group.results.count))")
                                .font(Typography.caption(size: 9))
                                .foregroundStyle(theme.secondaryText.opacity(0.5))
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                        .background(theme.secondaryBackground.opacity(0.5))
                    }
                    .buttonStyle(.plain)

                    // Results — click opens file and scrolls to that line
                    ForEach(group.results) { result in
                        Button {
                            onSelectResult(result.fileURL, result.lineNumber)
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(result.lineNumber)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(theme.secondaryText.opacity(0.4))
                                    .frame(width: 30, alignment: .trailing)

                                Text(result.lineContent)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(theme.primaryText)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
