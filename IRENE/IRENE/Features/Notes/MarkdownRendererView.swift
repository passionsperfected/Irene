import SwiftUI

struct MarkdownRendererView: View {
    let markdown: String

    var body: some View {
        ScrollView {
            MarkdownContentView(markdown: markdown)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}
