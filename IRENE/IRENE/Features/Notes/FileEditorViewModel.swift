import Foundation
import SwiftUI

@MainActor @Observable
final class FileEditorViewModel {
    let fileURL: URL
    var content: String = ""
    var isSaving: Bool = false
    var isRendering: Bool = false
    var isInvalidated: Bool = false  // Set true after rename — prevents further saves to old URL
    var errorMessage: String?

    var saveTask: Task<Void, Never>?
    private let debounceInterval: Duration = .milliseconds(1500)

    var fileName: String { fileURL.lastPathComponent }
    var fileExtension: String { fileURL.pathExtension.lowercased() }

    var fileType: SupportedFileType? {
        SupportedFileType.from(extension: fileExtension)
    }

    var isMarkdown: Bool { fileExtension == "md" }
    var isJSON: Bool { fileExtension == "json" }

    var contentBinding: Binding<String> {
        Binding(
            get: { self.content },
            set: { newValue in
                self.content = newValue
                self.scheduleSave()
            }
        )
    }

    var wordCount: Int {
        content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    var lineCount: Int {
        content.components(separatedBy: .newlines).count
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() {
        do {
            let raw = try String(contentsOf: fileURL, encoding: .utf8)
            content = stripFrontmatter(raw)
        } catch {
            errorMessage = error.localizedDescription
            content = ""
        }
    }

    /// Strips YAML frontmatter (--- ... ---) from legacy files
    private func stripFrontmatter(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else { return text }

        let lines = text.components(separatedBy: "\n")
        guard lines.count > 1 else { return text }

        // Find the closing ---
        for i in 1..<lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
                // Return everything after the closing ---
                let bodyLines = lines[(i + 1)...]
                let body = bodyLines.joined(separator: "\n")
                    .trimmingCharacters(in: .newlines)
                return body
            }
        }

        // No closing --- found, return as-is
        return text
    }

    func toggleRenderMode() {
        isRendering.toggle()
    }

    func formatJSON() {
        guard isJSON else { return }

        // Fix smart quotes/dashes that macOS may have inserted
        var cleaned = content
        cleaned = cleaned.replacingOccurrences(of: "\u{201C}", with: "\"") // left double quote
        cleaned = cleaned.replacingOccurrences(of: "\u{201D}", with: "\"") // right double quote
        cleaned = cleaned.replacingOccurrences(of: "\u{2018}", with: "'")  // left single quote
        cleaned = cleaned.replacingOccurrences(of: "\u{2019}", with: "'")  // right single quote
        cleaned = cleaned.replacingOccurrences(of: "\u{2013}", with: "-")  // en dash
        cleaned = cleaned.replacingOccurrences(of: "\u{2014}", with: "-")  // em dash

        guard let data = cleaned.data(using: .utf8) else {
            errorMessage = "Cannot encode content as UTF-8"
            return
        }

        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            let formatted = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])
            guard let formattedString = String(data: formatted, encoding: .utf8) else {
                errorMessage = "Cannot decode formatted JSON"
                return
            }
            content = formattedString
            errorMessage = nil
            scheduleSave()
        } catch {
            errorMessage = "Invalid JSON: \(error.localizedDescription)"
        }
    }

    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: debounceInterval)
            guard !Task.isCancelled else { return }
            await save()
        }
    }

    func save() async {
        guard !isInvalidated else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveImmediately() async {
        guard !isInvalidated else { return }
        saveTask?.cancel()
        await save()
    }

    nonisolated deinit {
    }
}
