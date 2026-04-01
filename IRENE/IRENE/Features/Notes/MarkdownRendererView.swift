import SwiftUI
import Markdown

struct MarkdownRendererView: View {
    let markdown: String
    @Environment(\.ireneTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                let document = Document(parsing: markdown)
                ForEach(Array(document.children.enumerated()), id: \.offset) { _, block in
                    MarkdownBlockView(block: block, theme: theme)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
    }
}

// Separate struct to avoid recursive type inference in the main view
private struct MarkdownBlockView: View {
    let block: any Markup
    let theme: ThemeDefinition

    var body: some View {
        // Use AnyView to break recursive type inference
        renderBlock(block)
    }

    private func renderBlock(_ markup: any Markup) -> AnyView {
        if let heading = markup as? Heading {
            AnyView(headingView(heading))
        } else if let paragraph = markup as? Paragraph {
            AnyView(
                inlineText(paragraph)
                    .font(Typography.body(size: 14))
                    .foregroundStyle(theme.primaryText)
            )
        } else if let list = markup as? UnorderedList {
            AnyView(unorderedListView(list))
        } else if let list = markup as? OrderedList {
            AnyView(orderedListView(list))
        } else if let codeBlock = markup as? CodeBlock {
            AnyView(codeBlockView(codeBlock))
        } else if let blockQuote = markup as? BlockQuote {
            AnyView(blockQuoteView(blockQuote))
        } else if markup is ThematicBreak {
            AnyView(Divider().overlay(theme.border.opacity(0.3)))
        } else {
            AnyView(
                SwiftUI.Text(markup.format())
                    .font(Typography.body(size: 14))
                    .foregroundStyle(theme.primaryText)
            )
        }
    }

    // MARK: - Headings

    private func headingView(_ heading: Heading) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            switch heading.level {
            case 1:
                inlineText(heading)
                    .font(Typography.heading(size: 28))
                    .foregroundStyle(theme.primaryText)
                Divider().overlay(theme.border.opacity(0.2))
            case 2:
                inlineText(heading)
                    .font(Typography.heading(size: 22))
                    .foregroundStyle(theme.primaryText)
                Divider().overlay(theme.border.opacity(0.2))
            case 3:
                inlineText(heading)
                    .font(Typography.subheading(size: 18))
                    .foregroundStyle(theme.primaryText)
            case 4:
                inlineText(heading)
                    .font(Typography.bodySemiBold(size: 16))
                    .foregroundStyle(theme.primaryText)
            default:
                inlineText(heading)
                    .font(Typography.bodySemiBold(size: 14))
                    .foregroundStyle(theme.primaryText)
            }
        }
        .padding(.top, heading.level <= 2 ? 8 : 4)
    }

    // MARK: - Lists

    private func unorderedListView(_ list: UnorderedList) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(list.listItems.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    SwiftUI.Text("\u{2022}")
                        .font(Typography.body(size: 14))
                        .foregroundStyle(theme.accent)
                        .frame(width: 12, alignment: .center)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(item.children.enumerated()), id: \.offset) { _, child in
                            if let paragraph = child as? Paragraph {
                                inlineText(paragraph)
                                    .font(Typography.body(size: 14))
                                    .foregroundStyle(theme.primaryText)
                            } else {
                                MarkdownBlockView(block: child, theme: theme)
                            }
                        }
                    }
                }
                .padding(.leading, 4)
            }
        }
    }

    private func orderedListView(_ list: OrderedList) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(list.listItems.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    SwiftUI.Text("\(index + 1).")
                        .font(Typography.bodySemiBold(size: 13))
                        .foregroundStyle(theme.accent)
                        .frame(width: 20, alignment: .trailing)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(item.children.enumerated()), id: \.offset) { _, child in
                            if let paragraph = child as? Paragraph {
                                inlineText(paragraph)
                                    .font(Typography.body(size: 14))
                                    .foregroundStyle(theme.primaryText)
                            } else {
                                MarkdownBlockView(block: child, theme: theme)
                            }
                        }
                    }
                }
                .padding(.leading, 4)
            }
        }
    }

    // MARK: - Code Block

    private func codeBlockView(_ codeBlock: CodeBlock) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            SwiftUI.Text(codeBlock.code.trimmingCharacters(in: .newlines))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(theme.mintHaze.color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.void.color)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(theme.border.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Block Quote

    private func blockQuoteView(_ blockQuote: BlockQuote) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(theme.accent.opacity(0.4))
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(blockQuote.children.enumerated()), id: \.offset) { _, child in
                    MarkdownBlockView(block: child, theme: theme)
                }
            }
            .padding(.leading, 12)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Inline text

    private func inlineText(_ markup: any Markup) -> SwiftUI.Text {
        var result = SwiftUI.Text("")
        for child in markup.children {
            result = result + renderInline(child)
        }
        return result
    }

    private func renderInline(_ markup: any Markup) -> SwiftUI.Text {
        if let text = markup as? Markdown.Text {
            return SwiftUI.Text(text.string)
        } else if let strong = markup as? Strong {
            return inlineText(strong).bold()
        } else if let emphasis = markup as? Emphasis {
            return inlineText(emphasis).italic()
        } else if let code = markup as? InlineCode {
            return SwiftUI.Text(code.code)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.init(theme.mintHaze.color))
        } else if let link = markup as? Markdown.Link {
            return inlineText(link)
                .foregroundColor(.init(theme.accent))
        } else if markup is SoftBreak {
            return SwiftUI.Text("\n")
        } else if markup is LineBreak {
            return SwiftUI.Text("\n")
        } else if let image = markup as? Markdown.Image {
            return SwiftUI.Text("[\(image.title ?? "image")]")
                .foregroundColor(.init(theme.secondaryText))
        } else if let strikethrough = markup as? Strikethrough {
            return inlineText(strikethrough).strikethrough()
        } else {
            return SwiftUI.Text(markup.format())
        }
    }
}
