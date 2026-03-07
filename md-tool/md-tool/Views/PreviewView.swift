import SwiftUI
import WebKit

struct PreviewView: NSViewRepresentable {
    let htmlContent: String
    var baseURL: URL?
    var showTOC: Bool = true
    var onInternalLink: ((URL) -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.baseURL = baseURL
        context.coordinator.onInternalLink = onInternalLink
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
        <body class="\(showTOC ? "" : "toc-hidden")">
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

    .toc-sidebar {
        position: fixed;
        top: 16px;
        right: 12px;
        width: 220px;
        max-height: calc(100vh - 32px);
        overflow-y: auto;
        border-left: 2px solid var(--border);
        padding-left: 10px;
        scrollbar-width: none;
    }

    .toc-sidebar::-webkit-scrollbar {
        display: none;
    }

    .toc-sidebar .toc-title {
        font-weight: 600;
        font-size: 11px;
        margin-bottom: 6px;
        color: var(--text);
        opacity: 0.5;
        text-transform: uppercase;
        letter-spacing: 0.05em;
    }

    .toc-sidebar ul {
        list-style: none;
        padding-left: 0;
        margin: 0;
    }

    .toc-sidebar ul ul {
        padding-left: 0.7em;
    }

    .toc-sidebar li {
        margin-bottom: 0;
        line-height: 1.4;
    }

    .toc-sidebar a {
        color: var(--text);
        opacity: 0.4;
        text-decoration: none;
        display: block;
        padding: 1.5px 0;
        transition: opacity 0.15s, color 0.15s;
        font-size: 11px;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
    }

    .toc-sidebar a:hover {
        opacity: 0.8;
        text-decoration: none;
    }

    .toc-sidebar a.active {
        opacity: 1;
        color: var(--link);
        font-weight: 600;
    }

    .markdown-body {
        margin-right: 248px;
    }

    body.toc-hidden .toc-sidebar {
        display: none;
    }

    body.toc-hidden .markdown-body {
        margin-right: 0;
    }

    @media (max-width: 700px) {
        .toc-sidebar { display: none; }
        .markdown-body { margin-right: 0; }
    }

    h1, h2, h3, h4, h5, h6 {
        scroll-margin-top: 1em;
    }
    """

    private static let highlightJSSetup = """
    document.querySelectorAll('pre code[class^="language-"]').forEach(function(el) {
        // highlight.js will be loaded if available
    });

    // TOC scroll tracking
    (function() {
        var headings = Array.from(document.querySelectorAll('h1[id], h2[id], h3[id], h4[id], h5[id], h6[id]'));
        var tocLinks = document.querySelectorAll('.toc-sidebar a');
        if (headings.length === 0 || tocLinks.length === 0) return;

        var clickScrolling = false;

        // Click handler: immediate highlight + smooth scroll
        tocLinks.forEach(function(link) {
            link.addEventListener('click', function(e) {
                e.preventDefault();
                var targetId = this.getAttribute('href').substring(1);
                var target = document.getElementById(targetId);
                if (!target) return;

                clickScrolling = true;
                setActive(targetId);
                target.scrollIntoView({ behavior: 'smooth' });
                setTimeout(function() { clickScrolling = false; }, 800);
            });
        });

        // Scroll-based tracking
        function updateActiveHeading() {
            if (clickScrolling) return;
            var scrollTop = window.scrollY;
            var activeIndex = 0;

            for (var i = 0; i < headings.length; i++) {
                if (headings[i].offsetTop <= scrollTop + 60) {
                    activeIndex = i;
                }
            }

            setActive(headings[activeIndex].id);
        }

        function setActive(id) {
            tocLinks.forEach(function(a) { a.classList.remove('active'); });
            var link = document.querySelector('.toc-sidebar a[href=\"#' + id + '\"]');
            if (link) {
                link.classList.add('active');
                link.scrollIntoView({ block: 'nearest' });
            }
        }

        var scrollTimer;
        window.addEventListener('scroll', function() {
            clearTimeout(scrollTimer);
            scrollTimer = setTimeout(updateActiveHeading, 30);
        });

        updateActiveHeading();
    })();
    """

    class Coordinator: NSObject, WKNavigationDelegate {
        var baseURL: URL?
        var onInternalLink: ((URL) -> Void)?

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // External link
            if url.scheme == "http" || url.scheme == "https" {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            // Internal .md link
            if let baseURL = baseURL {
                let dest = url.lastPathComponent.isEmpty ? url.absoluteString : url.lastPathComponent
                let path = url.path.isEmpty ? dest : url.path
                let ext = (path as NSString).pathExtension.lowercased()
                if ext == "md" || ext == "markdown" {
                    let resolvedURL = baseURL.appendingPathComponent(path).standardized
                    if FileManager.default.fileExists(atPath: resolvedURL.path) {
                        onInternalLink?(resolvedURL)
                        decisionHandler(.cancel)
                        return
                    }
                }
            }

            decisionHandler(.allow)
        }
    }
}
