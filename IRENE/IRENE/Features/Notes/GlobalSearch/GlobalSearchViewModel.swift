import Foundation

struct GlobalSearchResult: Identifiable, Sendable {
    let id = UUID()
    let fileURL: URL
    let fileName: String
    let lineNumber: Int
    let lineContent: String
    let matchRange: NSRange
}

struct GroupedSearchResults: Identifiable {
    let id: URL
    let fileURL: URL
    let fileName: String
    let results: [GlobalSearchResult]
}

@MainActor @Observable
final class GlobalSearchViewModel {
    var searchText: String = "" {
        didSet { scheduleSearch() }
    }
    var caseSensitive: Bool = false {
        didSet { scheduleSearch() }
    }
    var useRegex: Bool = false {
        didSet { scheduleSearch() }
    }

    private(set) var results: [GlobalSearchResult] = []
    private(set) var isSearching = false

    private let rootURL: URL
    private var searchTask: Task<Void, Never>?

    init(rootURL: URL) {
        self.rootURL = rootURL
    }

    var groupedResults: [GroupedSearchResults] {
        let grouped = Dictionary(grouping: results) { $0.fileURL }
        return grouped.map { url, results in
            GroupedSearchResults(
                id: url,
                fileURL: url,
                fileName: url.lastPathComponent,
                results: results.sorted { $0.lineNumber < $1.lineNumber }
            )
        }
        .sorted { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
    }

    var resultCount: Int { results.count }
    var fileCount: Int { Set(results.map(\.fileURL)).count }

    private func scheduleSearch() {
        searchTask?.cancel()
        guard !searchText.isEmpty else {
            results = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await performSearch()
        }
    }

    private func performSearch() async {
        isSearching = true
        defer { isSearching = false }

        let query = searchText
        let files = collectFiles()

        var found: [GlobalSearchResult] = []

        for file in files {
            guard !Task.isCancelled else { return }
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }

            let lines = content.components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                let matches = findMatches(in: line, query: query)
                for match in matches {
                    found.append(GlobalSearchResult(
                        fileURL: file,
                        fileName: file.lastPathComponent,
                        lineNumber: index + 1,
                        lineContent: line,
                        matchRange: match
                    ))
                }
            }
        }

        guard !Task.isCancelled else { return }
        results = found
    }

    private func findMatches(in line: String, query: String) -> [NSRange] {
        if useRegex {
            let options: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
            guard let regex = try? NSRegularExpression(pattern: query, options: options) else { return [] }
            let nsRange = NSRange(line.startIndex..., in: line)
            return regex.matches(in: line, range: nsRange).map(\.range)
        } else {
            let searchIn = caseSensitive ? line : line.lowercased()
            let searchFor = caseSensitive ? query : query.lowercased()
            var matches: [NSRange] = []
            var searchStart = searchIn.startIndex
            while let range = searchIn.range(of: searchFor, range: searchStart..<searchIn.endIndex) {
                matches.append(NSRange(range, in: searchIn))
                searchStart = range.upperBound
            }
            return matches
        }
    }

    private func collectFiles() -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [URL] = []
        let supported = SupportedFileType.supportedExtensions
        for case let url as URL in enumerator {
            if supported.contains(url.pathExtension.lowercased()) {
                files.append(url)
            }
        }
        return files
    }
}
