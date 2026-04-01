import Foundation
import SwiftUI

@MainActor @Observable
final class FileTreeViewModel {
    private(set) var rootNode: FileTreeNode?
    private(set) var isLoading = false
    var selectedFile: URL? {
        didSet {
            // Notify observers that selection changed
            selectionGeneration += 1
        }
    }
    // Bumped each time selectedFile changes, used to drive view updates
    private(set) var selectionGeneration: Int = 0
    // Bumped each time the tree is rescanned, used to force view rebuild
    private(set) var treeGeneration: Int = 0
    var errorMessage: String?

    private var expandedFolders: Set<URL> = []
    let rootURL: URL
    private let fileManager = FileManager.default

    init(rootURL: URL) {
        self.rootURL = rootURL
        expandedFolders.insert(rootURL)
        ensureRootExists()
    }

    private func ensureRootExists() {
        if !fileManager.fileExists(atPath: rootURL.path) {
            try? fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        }
    }

    // MARK: - Scan

    func scan() {
        isLoading = true
        defer { isLoading = false }
        ensureRootExists()
        rootNode = buildTree(at: rootURL, parent: nil)
        treeGeneration += 1
    }

    private func buildTree(at url: URL, parent: FileTreeNode?) -> FileTreeNode {
        var isDir = false
        if let values = try? url.resourceValues(forKeys: [.isDirectoryKey]) {
            isDir = values.isDirectory ?? false
        }
        let node = FileTreeNode(url: url, isDirectory: isDir, parent: parent)
        node.isExpanded = expandedFolders.contains(url)

        if isDir {
            let contents = (try? fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? []

            node.children = contents
                .map { buildTree(at: $0, parent: node) }
                .filter(\.isSupported)
                .sorted { a, b in
                    if a.isDirectory != b.isDirectory { return a.isDirectory }
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }
        }

        return node
    }

    // MARK: - Expand/Collapse

    func toggleExpanded(_ node: FileTreeNode) {
        node.isExpanded.toggle()
        if node.isExpanded {
            expandedFolders.insert(node.url)
        } else {
            expandedFolders.remove(node.url)
        }
    }

    // MARK: - Create

    func quickCreateFile(in parent: FileTreeNode? = nil) {
        let parentURL = parent?.url ?? rootURL

        // Ensure parent directory exists
        if !fileManager.fileExists(atPath: parentURL.path) {
            try? fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)
        }

        var name = "untitled.txt"
        var counter = 1
        while fileManager.fileExists(atPath: parentURL.appendingPathComponent(name).path) {
            name = "untitled_\(counter).txt"
            counter += 1
        }

        let fileURL = parentURL.appendingPathComponent(name)
        do {
            try "".write(to: fileURL, atomically: true, encoding: .utf8)
            if let parent {
                expandedFolders.insert(parent.url)
            }
            scan()
            selectedFile = fileURL
        } catch {
            errorMessage = "Failed to create file: \(error.localizedDescription)"
        }
    }

    func createFile(name: String, type: SupportedFileType, in parent: FileTreeNode?) {
        let parentURL = parent?.url ?? rootURL

        if !fileManager.fileExists(atPath: parentURL.path) {
            try? fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)
        }

        let fileName = name.hasSuffix(".\(type.rawValue)") ? name : "\(name).\(type.rawValue)"
        let fileURL = parentURL.appendingPathComponent(fileName)

        guard !fileManager.fileExists(atPath: fileURL.path) else {
            errorMessage = "A file named \"\(fileName)\" already exists"
            return
        }

        let defaultContent: String
        switch type {
        case .txt: defaultContent = ""
        case .md: defaultContent = ""
        case .json: defaultContent = "{\n  \n}\n"
        }

        do {
            try defaultContent.write(to: fileURL, atomically: true, encoding: .utf8)
            if let parent {
                expandedFolders.insert(parent.url)
            }
            scan()
            selectedFile = fileURL
        } catch {
            errorMessage = "Failed to create file: \(error.localizedDescription)"
        }
    }

    func createFolder(name: String, in parent: FileTreeNode?) {
        let parentURL = parent?.url ?? rootURL
        let folderURL = parentURL.appendingPathComponent(name)

        guard !fileManager.fileExists(atPath: folderURL.path) else {
            errorMessage = "A folder named \"\(name)\" already exists"
            return
        }

        do {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            expandedFolders.insert(parentURL)
            expandedFolders.insert(folderURL)
            scan()
        } catch {
            errorMessage = "Failed to create folder: \(error.localizedDescription)"
        }
    }

    // MARK: - Rename

    func rename(node: FileTreeNode, to newName: String) {
        let parentURL = node.url.deletingLastPathComponent()
        let newURL: URL
        if node.isDirectory {
            newURL = parentURL.appendingPathComponent(newName)
        } else {
            if newName.contains(".") {
                newURL = parentURL.appendingPathComponent(newName)
            } else {
                let ext = node.url.pathExtension.isEmpty ? "txt" : node.url.pathExtension
                newURL = parentURL.appendingPathComponent("\(newName).\(ext)")
            }
        }

        guard !fileManager.fileExists(atPath: newURL.path) else {
            errorMessage = "An item named \"\(newName)\" already exists"
            return
        }

        do {
            if node.isDirectory && expandedFolders.contains(node.url) {
                expandedFolders.remove(node.url)
                expandedFolders.insert(newURL)
            }
            try fileManager.moveItem(at: node.url, to: newURL)
            if selectedFile == node.url {
                selectedFile = newURL
            }
            scan()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete

    func delete(node: FileTreeNode) {
        do {
            try fileManager.removeItem(at: node.url)
            expandedFolders.remove(node.url)
            if selectedFile == node.url {
                selectedFile = nil
            }
            scan()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Move

    func move(node: FileTreeNode, to destination: FileTreeNode) {
        let targetDir: URL
        if destination.isDirectory {
            targetDir = destination.url
        } else {
            targetDir = destination.url.deletingLastPathComponent()
        }

        let newURL = targetDir.appendingPathComponent(node.name)

        guard node.url != newURL else { return }
        guard !fileManager.fileExists(atPath: newURL.path) else {
            errorMessage = "\"\(node.name)\" already exists in the destination"
            return
        }

        if node.isDirectory && newURL.path.hasPrefix(node.url.path) {
            errorMessage = "Cannot move a folder into itself"
            return
        }

        do {
            try fileManager.moveItem(at: node.url, to: newURL)
            if selectedFile == node.url {
                selectedFile = newURL
            }
            expandedFolders.insert(targetDir)
            scan()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    func findNode(for url: URL) -> FileTreeNode? {
        guard let root = rootNode else { return nil }
        return findNode(url: url, in: root)
    }

    private func findNode(url: URL, in node: FileTreeNode) -> FileTreeNode? {
        if node.url == url { return node }
        for child in node.children {
            if let found = findNode(url: url, in: child) { return found }
        }
        return nil
    }
}
