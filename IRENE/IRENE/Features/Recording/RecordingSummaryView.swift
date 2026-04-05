import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

struct RecordingSummaryView: View {
    let summary: RecordingSummary
    var onCreateToDo: ((String) -> Void)?

    @Environment(\.ireneTheme) private var theme
    @State private var showExportMenu = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with export button
            HStack {
                Text("AI SUMMARY")
                    .font(Typography.label())
                    .tracking(2)
                    .foregroundStyle(theme.secondaryText)

                Spacer()

                Text(summary.model)
                    .font(Typography.caption(size: 8))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.accent.opacity(0.1))
                    .clipShape(Capsule())

                // Export menu
                Menu {
                    Button {
                        exportAs(format: .markdown)
                    } label: {
                        Label("Export as Markdown (.md)", systemImage: "doc.richtext")
                    }
                    Button {
                        exportAs(format: .plainText)
                    } label: {
                        Label("Export as Plain Text (.txt)", systemImage: "doc.text")
                    }
                    Button {
                        exportAs(format: .pdf)
                    } label: {
                        Label("Export as PDF (.pdf)", systemImage: "doc.fill")
                    }
                    Divider()
                    Button {
                        exportAs(format: .docx)
                    } label: {
                        Label("Export for Word / Pages (.docx)", systemImage: "doc.badge.gearshape")
                    }
                    Button {
                        exportAs(format: .rtf)
                    } label: {
                        Label("Export as Rich Text (.rtf)", systemImage: "doc.badge.ellipsis")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 10))
                        Text("Export")
                            .font(Typography.caption(size: 10))
                    }
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(16)

            Divider().overlay(theme.border.opacity(0.2))

            // Rendered markdown summary
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    MarkdownRendererView(markdown: summary.summary)

                    // Action items with "Add Task" buttons
                    if !summary.actionItems.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ACTION ITEMS")
                                .font(Typography.label())
                                .tracking(2)
                                .foregroundStyle(theme.secondaryText)

                            ForEach(summary.actionItems, id: \.self) { item in
                                HStack(spacing: 8) {
                                    Image(systemName: "checklist")
                                        .font(.system(size: 10))
                                        .foregroundStyle(theme.accent)

                                    Text(item)
                                        .font(Typography.body(size: 12))
                                        .foregroundStyle(theme.primaryText)

                                    Spacer()

                                    if let onCreateToDo {
                                        Button {
                                            onCreateToDo(item)
                                        } label: {
                                            Text("Add Task")
                                                .font(Typography.caption(size: 8))
                                                .foregroundStyle(theme.accent)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(theme.accent.opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Text("Generated \(summary.generatedAt.formatted())")
                        .font(Typography.caption(size: 9))
                        .foregroundStyle(theme.secondaryText.opacity(0.4))
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Export

    private enum ExportFormat {
        case markdown, plainText, pdf, docx, rtf
    }

    private func exportAs(format: ExportFormat) {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.canCreateDirectories = true

        switch format {
        case .markdown:
            panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
            panel.nameFieldStringValue = "summary.md"
        case .plainText:
            panel.allowedContentTypes = [.plainText]
            panel.nameFieldStringValue = "summary.txt"
        case .pdf:
            panel.allowedContentTypes = [.pdf]
            panel.nameFieldStringValue = "summary.pdf"
        case .docx:
            panel.allowedContentTypes = [UTType(filenameExtension: "docx") ?? .data]
            panel.nameFieldStringValue = "summary.docx"
        case .rtf:
            panel.allowedContentTypes = [.rtf]
            panel.nameFieldStringValue = "summary.rtf"
        }

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            switch format {
            case .markdown:
                try? summary.summary.write(to: url, atomically: true, encoding: .utf8)
            case .plainText:
                let plain = summary.summary
                    .replacingOccurrences(of: "**", with: "")
                    .replacingOccurrences(of: "##", with: "")
                    .replacingOccurrences(of: "# ", with: "")
                    .replacingOccurrences(of: "- ", with: "• ")
                try? plain.write(to: url, atomically: true, encoding: .utf8)
            case .pdf:
                exportPDF(to: url)
            case .docx:
                exportRichDocument(to: url, type: .officeOpenXML)
            case .rtf:
                exportRichDocument(to: url, type: .rtf)
            }
        }
        #endif
    }

    #if os(macOS)
    /// Build a properly formatted NSAttributedString from the markdown
    private func makeFormattedAttributedString() -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = summary.summary.components(separatedBy: "\n")

        let bodyFont = NSFont.systemFont(ofSize: 12)
        let bodyBoldFont = NSFont.boldSystemFont(ofSize: 12)
        let h1Font = NSFont.boldSystemFont(ofSize: 22)
        let h2Font = NSFont.boldSystemFont(ofSize: 18)
        let h3Font = NSFont.boldSystemFont(ofSize: 15)
        let textColor = NSColor.labelColor

        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.lineSpacing = 4
        bodyParagraph.paragraphSpacing = 6

        let headingParagraph = NSMutableParagraphStyle()
        headingParagraph.paragraphSpacingBefore = 12
        headingParagraph.paragraphSpacing = 6

        let bulletParagraph = NSMutableParagraphStyle()
        bulletParagraph.headIndent = 20
        bulletParagraph.firstLineHeadIndent = 8
        bulletParagraph.lineSpacing = 3
        bulletParagraph.paragraphSpacing = 3

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("## ") {
                let text = String(trimmed.dropFirst(3))
                result.append(NSAttributedString(string: text + "\n", attributes: [
                    .font: h2Font, .foregroundColor: textColor, .paragraphStyle: headingParagraph
                ]))
            } else if trimmed.hasPrefix("# ") {
                let text = String(trimmed.dropFirst(2))
                result.append(NSAttributedString(string: text + "\n", attributes: [
                    .font: h1Font, .foregroundColor: textColor, .paragraphStyle: headingParagraph
                ]))
            } else if trimmed.hasPrefix("### ") {
                let text = String(trimmed.dropFirst(4))
                result.append(NSAttributedString(string: text + "\n", attributes: [
                    .font: h3Font, .foregroundColor: textColor, .paragraphStyle: headingParagraph
                ]))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let text = String(trimmed.dropFirst(2))
                let formatted = applyInlineFormatting("•  " + text + "\n", bodyFont: bodyFont, boldFont: bodyBoldFont, color: textColor)
                formatted.addAttribute(.paragraphStyle, value: bulletParagraph, range: NSRange(location: 0, length: formatted.length))
                result.append(formatted)
            } else if trimmed.isEmpty {
                result.append(NSAttributedString(string: "\n", attributes: [.font: bodyFont]))
            } else {
                let formatted = applyInlineFormatting(trimmed + "\n", bodyFont: bodyFont, boldFont: bodyBoldFont, color: textColor)
                formatted.addAttribute(.paragraphStyle, value: bodyParagraph, range: NSRange(location: 0, length: formatted.length))
                result.append(formatted)
            }
        }

        return result
    }

    /// Apply **bold** and *italic* inline formatting
    private func applyInlineFormatting(_ text: String, bodyFont: NSFont, boldFont: NSFont, color: NSColor) -> NSMutableAttributedString {
        var clean = text
        let result = NSMutableAttributedString()

        // Process **bold** markers
        while let startRange = clean.range(of: "**") {
            // Text before the bold marker
            let before = String(clean[clean.startIndex..<startRange.lowerBound])
            result.append(NSAttributedString(string: before, attributes: [.font: bodyFont, .foregroundColor: color]))

            clean = String(clean[startRange.upperBound...])

            if let endRange = clean.range(of: "**") {
                let boldText = String(clean[clean.startIndex..<endRange.lowerBound])
                result.append(NSAttributedString(string: boldText, attributes: [.font: boldFont, .foregroundColor: color]))
                clean = String(clean[endRange.upperBound...])
            }
        }

        // Remaining text
        if !clean.isEmpty {
            result.append(NSAttributedString(string: clean, attributes: [.font: bodyFont, .foregroundColor: color]))
        }

        return result
    }

    private func exportPDF(to url: URL) {
        let attrString = makeFormattedAttributedString()
        let margin: CGFloat = 72
        let pageWidth: CGFloat = 612
        let contentWidth = pageWidth - margin * 2

        // Use NSTextView to properly lay out and paginate
        let textStorage = NSTextStorage(attributedString: attrString)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(containerSize: NSSize(width: contentWidth, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)

        let textHeight = layoutManager.usedRect(for: textContainer).height

        // Create a single-page PDF with the exact height needed (up to letter size)
        let pageHeight = min(max(textHeight + margin * 2, 200), 20000)
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let pdfContext = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { return }

        pdfContext.beginPDFPage(nil)

        // Draw using Core Text
        let frameSetter = CTFramesetterCreateWithAttributedString(attrString)
        let framePath = CGPath(rect: CGRect(x: margin, y: margin, width: contentWidth, height: pageHeight - margin * 2), transform: nil)
        let frame = CTFramesetterCreateFrame(frameSetter, CFRange(location: 0, length: 0), framePath, nil)
        CTFrameDraw(frame, pdfContext)

        pdfContext.endPDFPage()
        pdfContext.closePDF()
    }

    private func exportRichDocument(to url: URL, type: NSAttributedString.DocumentType) {
        let attrString = makeFormattedAttributedString()
        let range = NSRange(location: 0, length: attrString.length)

        do {
            let data = try attrString.data(
                from: range,
                documentAttributes: [
                    .documentType: type,
                    .title: "Meeting Summary"
                ]
            )
            try data.write(to: url)
        } catch {
            print("[IRENE] Export failed: \(error)")
        }
    }
    #endif
}
