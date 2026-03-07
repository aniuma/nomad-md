import SwiftUI
import WebKit

struct PreviewView: NSViewRepresentable {
    let htmlContent: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let fullHTML = wrapInHTMLTemplate(htmlContent)
        webView.loadHTMLString(fullHTML, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func wrapInHTMLTemplate(_ body: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        \(Self.cssContent)
        </style>
        </head>
        <body>
        <article class="markdown-body">
        \(body)
        </article>
        <script>
        \(Self.highlightJSSetup)
        </script>
        </body>
        </html>
        """
    }

    private static let cssContent = """
    :root {
        --bg: #FFFBF7;
        --text: #2C2C2C;
        --code-bg: #F5F2F0;
        --border: #E0DCD8;
        --link: #0969DA;
        --blockquote-border: #D0D7DE;
        --blockquote-text: #656D76;
    }

    @media (prefers-color-scheme: dark) {
        :root {
            --bg: #2D2D2D;
            --text: #E0E0E0;
            --code-bg: #383838;
            --border: #484848;
            --link: #58A6FF;
            --blockquote-border: #505050;
            --blockquote-text: #A0A0A0;
        }
    }

    * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
    }

    body {
        font-family: "Hiragino Kaku Gothic ProN", "Hiragino Sans",
                     -apple-system, "SF Pro Text", system-ui, sans-serif;
        font-size: 16px;
        line-height: 1.8;
        letter-spacing: 0.03em;
        color: var(--text);
        background-color: var(--bg);
        -webkit-font-smoothing: antialiased;
    }

    .markdown-body {
        max-width: none;
        margin: 0;
        padding: 48px 56px;
    }

    h1, h2, h3, h4, h5, h6 {
        font-family: "Hiragino Kaku Gothic ProN", "Hiragino Sans",
                     -apple-system, "SF Pro Display", system-ui, sans-serif;
        margin-top: 1.5em;
        margin-bottom: 0.5em;
        letter-spacing: -0.01em;
        line-height: 1.3;
    }

    h1 { font-size: 1.75em; font-weight: 700; border-bottom: none; padding-bottom: 0; margin-bottom: 0.8em; }
    h2 { font-size: 1.35em; font-weight: 700; border-bottom: 1px solid var(--border); padding-bottom: 0.2em; }
    h3 { font-size: 1.15em; font-weight: 600; }
    h4 { font-size: 1em; font-weight: 600; }

    h1:first-child, h2:first-child, h3:first-child { margin-top: 0; }

    p { margin-bottom: 1.2em; }

    a { color: var(--link); text-decoration: none; }
    a:hover { text-decoration: underline; }

    code {
        font-family: "SF Mono", Menlo, monospace;
        font-size: 0.85em;
        background-color: var(--code-bg);
        padding: 0.2em 0.4em;
        border-radius: 4px;
    }

    pre {
        margin-bottom: 1em;
        padding: 16px;
        background-color: var(--code-bg);
        border-radius: 8px;
        overflow-x: auto;
    }

    pre code {
        padding: 0;
        background: none;
        font-size: 13px;
        line-height: 1.6;
    }

    blockquote {
        margin-bottom: 1em;
        padding: 0.25em 1.2em;
        border-left: 3px solid var(--blockquote-border);
        color: var(--blockquote-text);
        font-size: 0.95em;
    }

    blockquote p:last-child { margin-bottom: 0; }

    ul, ol {
        margin-bottom: 1em;
        padding-left: 2em;
    }

    li { margin-bottom: 0.35em; line-height: 1.7; }
    li > ul, li > ol { margin-bottom: 0; }

    hr {
        margin: 2em 0;
        border: none;
        border-top: 1px solid var(--border);
    }

    img {
        max-width: 100%;
        height: auto;
        border-radius: 4px;
    }

    table {
        width: 100%;
        margin-bottom: 1em;
        border-collapse: collapse;
    }

    th, td {
        padding: 8px 12px;
        border: 1px solid var(--border);
        text-align: left;
    }

    th {
        font-weight: 600;
        background-color: var(--code-bg);
    }

    input[type="checkbox"] {
        margin-right: 0.5em;
    }
    """

    private static let highlightJSSetup = """
    document.querySelectorAll('pre code[class^="language-"]').forEach(function(el) {
        // highlight.js will be loaded if available
    });
    """

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url,
               (url.scheme == "http" || url.scheme == "https") {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
