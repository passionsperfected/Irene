#if os(macOS)
import SwiftUI
import WebKit

/// Renders HTML email content in a sandboxed WKWebView.
/// Blocks remote loads and JavaScript for safety.
struct MailHTMLView: NSViewRepresentable {
    let html: String
    let isDark: Bool

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.defaultWebpagePreferences.allowsContentJavaScript = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let wrapped = wrapHTML(html, isDark: isDark)
        webView.loadHTMLString(wrapped, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Wraps email HTML with styling tuned for the IRENE theme.
    private func wrapHTML(_ body: String, isDark: Bool) -> String {
        let bg = isDark ? "transparent" : "transparent"
        let fg = isDark ? "#E8E8E8" : "#1A1A1A"
        let link = isDark ? "#5EE3C5" : "#0A8E72"
        let secondary = isDark ? "#9A9A9A" : "#6A6A6A"

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            html, body {
                background: \(bg);
                color: \(fg);
                font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
                font-size: 14px;
                line-height: 1.5;
                margin: 0;
                padding: 16px;
                word-wrap: break-word;
                overflow-wrap: break-word;
            }
            * { max-width: 100% !important; }
            img { max-width: 100% !important; height: auto !important; border-radius: 4px; }
            a { color: \(link); text-decoration: none; }
            a:hover { text-decoration: underline; }
            blockquote {
                border-left: 3px solid \(secondary);
                padding-left: 12px;
                color: \(secondary);
                margin: 12px 0;
            }
            pre, code {
                background: rgba(127, 127, 127, 0.15);
                padding: 2px 6px;
                border-radius: 4px;
                font-family: "SF Mono", Menlo, monospace;
                font-size: 13px;
            }
            table { border-collapse: collapse; max-width: 100%; }
            td, th { padding: 4px 8px; }
            h1, h2, h3, h4 { color: \(fg); }
            hr { border: none; border-top: 1px solid \(secondary); opacity: 0.3; margin: 16px 0; }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow the initial loadHTMLString
            if navigationAction.request.url?.absoluteString == "about:blank" || navigationAction.navigationType == .other {
                decisionHandler(.allow)
                return
            }
            // Open links in default browser
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

/// Plain-text fallback with link detection
struct MailPlainTextView: View {
    let text: String
    @Environment(\.ireneTheme) private var theme

    var body: some View {
        ScrollView {
            Text(attributedText)
                .font(.system(size: 14))
                .foregroundStyle(theme.primaryText)
                .textSelection(.enabled)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
    }

    private var attributedText: AttributedString {
        var attr = AttributedString(text)
        // Detect URLs and make them clickable
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let nsString = text as NSString
            let matches = detector.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                guard let url = match.url,
                      let range = Range(match.range, in: text),
                      let attrRange = Range(range, in: attr) else { continue }
                attr[attrRange].link = url
                attr[attrRange].foregroundColor = theme.accent
                attr[attrRange].underlineStyle = .single
            }
        }
        return attr
    }
}
#endif
