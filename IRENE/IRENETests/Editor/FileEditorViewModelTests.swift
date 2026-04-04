import Testing
import Foundation
@testable import IRENE

@Suite("FileEditorViewModel Tests")
struct FileEditorViewModelTests {

    private func tempFile(content: String = "", ext: String = "txt") -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - File Type Detection

    @MainActor @Test("fileType detects txt")
    func detectsTxt() {
        let vm = FileEditorViewModel(fileURL: URL(fileURLWithPath: "/tmp/test.txt"))
        #expect(vm.fileType == .txt)
        #expect(vm.isMarkdown == false)
        #expect(vm.isJSON == false)
    }

    @MainActor @Test("fileType detects md")
    func detectsMd() {
        let vm = FileEditorViewModel(fileURL: URL(fileURLWithPath: "/tmp/test.md"))
        #expect(vm.fileType == .md)
        #expect(vm.isMarkdown == true)
    }

    @MainActor @Test("fileType detects json")
    func detectsJson() {
        let vm = FileEditorViewModel(fileURL: URL(fileURLWithPath: "/tmp/test.json"))
        #expect(vm.fileType == .json)
        #expect(vm.isJSON == true)
    }

    // MARK: - Load

    @MainActor @Test("load reads file content")
    func loadReadsContent() {
        let url = tempFile(content: "hello world")
        defer { try? FileManager.default.removeItem(at: url) }

        let vm = FileEditorViewModel(fileURL: url)
        vm.load()

        #expect(vm.content == "hello world")
    }

    @MainActor @Test("load strips YAML frontmatter from legacy files")
    func loadStripsFrontmatter() {
        let content = "---\nid: abc123\ntitle: test\n---\nactual content here"
        let url = tempFile(content: content, ext: "md")
        defer { try? FileManager.default.removeItem(at: url) }

        let vm = FileEditorViewModel(fileURL: url)
        vm.load()

        #expect(vm.content == "actual content here")
        #expect(!vm.content.contains("---"))
        #expect(!vm.content.contains("id:"))
    }

    @MainActor @Test("load handles missing file gracefully")
    func loadMissingFile() {
        let url = URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString).txt")
        let vm = FileEditorViewModel(fileURL: url)
        vm.load()

        #expect(vm.content == "")
        #expect(vm.errorMessage != nil)
    }

    // MARK: - Save

    @MainActor @Test("save writes content to disk")
    func saveWritesToDisk() async {
        let url = tempFile(content: "")
        defer { try? FileManager.default.removeItem(at: url) }

        let vm = FileEditorViewModel(fileURL: url)
        vm.content = "new content"
        await vm.save()

        let onDisk = try? String(contentsOf: url, encoding: .utf8)
        #expect(onDisk == "new content")
    }

    @MainActor @Test("save respects isInvalidated flag")
    func saveRespectsInvalidated() async {
        let url = tempFile(content: "original")
        defer { try? FileManager.default.removeItem(at: url) }

        let vm = FileEditorViewModel(fileURL: url)
        vm.content = "modified"
        vm.isInvalidated = true
        await vm.save()

        let onDisk = try? String(contentsOf: url, encoding: .utf8)
        #expect(onDisk == "original") // Should NOT have saved
    }

    // MARK: - Word and Line Count

    @MainActor @Test("wordCount counts words correctly")
    func wordCount() {
        let vm = FileEditorViewModel(fileURL: URL(fileURLWithPath: "/tmp/test.txt"))
        vm.content = "hello world foo bar"
        #expect(vm.wordCount == 4)
    }

    @MainActor @Test("wordCount handles empty content")
    func wordCountEmpty() {
        let vm = FileEditorViewModel(fileURL: URL(fileURLWithPath: "/tmp/test.txt"))
        vm.content = ""
        #expect(vm.wordCount == 0)
    }

    @MainActor @Test("lineCount counts lines correctly")
    func lineCount() {
        let vm = FileEditorViewModel(fileURL: URL(fileURLWithPath: "/tmp/test.txt"))
        vm.content = "line1\nline2\nline3"
        #expect(vm.lineCount == 3)
    }

    @MainActor @Test("lineCount single line")
    func lineCountSingle() {
        let vm = FileEditorViewModel(fileURL: URL(fileURLWithPath: "/tmp/test.txt"))
        vm.content = "hello"
        #expect(vm.lineCount == 1)
    }

    // MARK: - JSON Format

    @MainActor @Test("formatJSON pretty-prints valid JSON")
    func formatValidJson() {
        let url = tempFile(ext: "json")
        defer { try? FileManager.default.removeItem(at: url) }

        let vm = FileEditorViewModel(fileURL: url)
        vm.content = "{\"b\":2,\"a\":1}"
        vm.formatJSON()

        #expect(vm.content.contains("\"a\" : 1"))
        #expect(vm.content.contains("\"b\" : 2"))
        #expect(vm.errorMessage == nil)
    }

    @MainActor @Test("formatJSON reports error for invalid JSON")
    func formatInvalidJson() {
        let url = tempFile(ext: "json")
        defer { try? FileManager.default.removeItem(at: url) }

        let vm = FileEditorViewModel(fileURL: url)
        vm.content = "{invalid json"
        vm.formatJSON()

        #expect(vm.errorMessage != nil)
        #expect(vm.errorMessage!.contains("Invalid JSON"))
    }

    @MainActor @Test("formatJSON fixes smart quotes")
    func formatFixesSmartQuotes() {
        let url = tempFile(ext: "json")
        defer { try? FileManager.default.removeItem(at: url) }

        let vm = FileEditorViewModel(fileURL: url)
        vm.content = "{\u{201C}key\u{201D}: \u{201C}value\u{201D}}"
        vm.formatJSON()

        #expect(vm.content.contains("\"key\""))
        #expect(!vm.content.contains("\u{201C}"))
    }

    @MainActor @Test("formatJSON does nothing for non-json files")
    func formatSkipsNonJson() {
        let url = tempFile(ext: "txt")
        defer { try? FileManager.default.removeItem(at: url) }

        let vm = FileEditorViewModel(fileURL: url)
        vm.content = "not json"
        vm.formatJSON()

        #expect(vm.content == "not json") // unchanged
    }

    // MARK: - Render Toggle

    @MainActor @Test("toggleRenderMode toggles isRendering")
    func toggleRender() {
        let vm = FileEditorViewModel(fileURL: URL(fileURLWithPath: "/tmp/test.md"))
        #expect(vm.isRendering == false)
        vm.toggleRenderMode()
        #expect(vm.isRendering == true)
        vm.toggleRenderMode()
        #expect(vm.isRendering == false)
    }
}
