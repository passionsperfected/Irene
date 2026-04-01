import Foundation
import UniformTypeIdentifiers

enum SupportedFileType: String, CaseIterable, Sendable {
    case txt
    case md
    case json

    var utType: UTType {
        switch self {
        case .txt: return .plainText
        case .md: return .init(filenameExtension: "md") ?? .plainText
        case .json: return .json
        }
    }

    var displayName: String {
        switch self {
        case .txt: return "Text File (.txt)"
        case .md: return "Markdown (.md)"
        case .json: return "JSON (.json)"
        }
    }

    var iconName: String {
        switch self {
        case .txt: return "doc.text"
        case .md: return "doc.richtext"
        case .json: return "curlybraces"
        }
    }

    static func from(extension ext: String) -> SupportedFileType? {
        SupportedFileType(rawValue: ext.lowercased())
    }

    static var supportedExtensions: Set<String> {
        Set(allCases.map(\.rawValue))
    }
}

final class FileTreeNode: Identifiable, ObservableObject, Hashable {
    let id: UUID
    let url: URL
    var name: String
    var isDirectory: Bool
    @Published var children: [FileTreeNode]
    @Published var isExpanded: Bool
    weak var parent: FileTreeNode?

    var fileType: SupportedFileType? {
        isDirectory ? nil : SupportedFileType.from(extension: url.pathExtension)
    }

    var iconName: String {
        if isDirectory {
            return isExpanded ? "folder.fill" : "folder"
        }
        return fileType?.iconName ?? "doc"
    }

    var isSupported: Bool {
        isDirectory || fileType != nil
    }

    init(url: URL, isDirectory: Bool, children: [FileTreeNode] = [], parent: FileTreeNode? = nil) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.isDirectory = isDirectory
        self.children = children
        self.isExpanded = false
        self.parent = parent
    }

    static func == (lhs: FileTreeNode, rhs: FileTreeNode) -> Bool {
        lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    func sortedChildren() -> [FileTreeNode] {
        children.sorted { a, b in
            // Folders first, then alphabetical
            if a.isDirectory != b.isDirectory {
                return a.isDirectory
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
}
