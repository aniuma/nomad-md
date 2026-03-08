import SwiftUI
import WebKit

struct PreviewView: NSViewRepresentable {
    let htmlContent: String
    var baseURL: URL?
    var showTOC: Bool = true
    var theme: String = UserDefaults.standard.string(forKey: "previewTheme") ?? "default"
    var onInternalLink: ((URL) -> Void)?
    var onWebViewReady: ((WKWebView) -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(context.coordinator, name: "copySection")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView
        let readyCallback = onWebViewReady
        DispatchQueue.main.async { readyCallback?(webView) }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.baseURL = baseURL
        context.coordinator.onInternalLink = onInternalLink
        let fullHTML = wrapInHTMLTemplate(htmlContent)

        let server = LocalHTTPServer.shared
        server.start()
        server.updateContent(html: fullHTML, baseDirectory: baseURL)

        if let serverURL = server.previewURL {
            // Reload from server to get proper Referer headers (fixes YouTube embed)
            let currentURL = webView.url
            if currentURL == serverURL {
                // Same URL — force reload to pick up new content
                webView.reload()
            } else {
                webView.load(URLRequest(url: serverURL))
            }
        } else {
            // Fallback: direct HTML loading
            webView.loadHTMLString(fullHTML, baseURL: baseURL ?? URL(string: "https://localhost/"))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func rewriteLocalFileURLs(_ html: String) -> String {
        let serverPort = LocalHTTPServer.shared.port
        guard serverPort > 0 else { return html }
        // Rewrite file:// URLs to localhost server
        let pattern = #"(src\s*=\s*")(file://[^"]+)(")"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        let mutable = NSMutableString(string: html)
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: mutable.length))
        for match in matches.reversed() {
            let fileURLRange = match.range(at: 2)
            let fileURLString = (html as NSString).substring(with: fileURLRange)
            if let fileURL = URL(string: fileURLString) {
                let serverPath = "http://localhost:\(serverPort)/file\(fileURL.path)"
                mutable.replaceCharacters(in: fileURLRange, with: serverPath)
            }
        }
        return mutable as String
    }

    private func wrapInHTMLTemplate(_ body: String) -> String {
        let processedBody = rewriteLocalFileURLs(body)
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        \(HTMLTemplateProvider.themeCSS(theme))
        \(HTMLTemplateProvider.layoutCSS)
        \(HTMLTemplateProvider.customCSS)
        </style>
        </head>
        <body class="\(showTOC ? "" : "toc-hidden")">
        <article class="markdown-body">
        \(processedBody)
        </article>
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">
        <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>
        <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js" onload="renderMathInElement(document.body, {delimiters: [{left: '$$', right: '$$', display: true}, {left: '$', right: '$', display: false}], throwOnError: false});"></script>
        <script type="module">
        import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
        mermaid.initialize({ startOnLoad: true, theme: window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'default' });
        </script>
        <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
        <script>
        \(Self.highlightJSSetup)
        </script>
        </body>
        </html>
        """
    }

    // CSS is now provided by HTMLTemplateProvider

    private static let highlightJSSetup = """
    document.querySelectorAll('pre code[class^="language-"]').forEach(function(el) {
        // highlight.js will be loaded if available
    });

    // Section copy buttons
    (function() {
        var copySvg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>';
        var checkSvg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>';
        var headings = document.querySelectorAll('h1[id], h2[id], h3[id], h4[id], h5[id], h6[id]');
        headings.forEach(function(h) {
            var btn = document.createElement('button');
            btn.className = 'section-copy-btn';
            btn.innerHTML = copySvg;
            btn.title = 'セクションをコピー';
            btn.addEventListener('click', function(e) {
                e.preventDefault();
                e.stopPropagation();
                var content = [];
                var el = h.nextElementSibling;
                var hLevel = parseInt(h.tagName.charAt(1));
                while (el) {
                    if (/^H[1-6]$/.test(el.tagName) && parseInt(el.tagName.charAt(1)) <= hLevel) break;
                    content.push(el.textContent);
                    el = el.nextElementSibling;
                }
                var headingText = '';
                for (var i = 0; i < h.childNodes.length; i++) {
                    if (h.childNodes[i] !== btn) headingText += h.childNodes[i].textContent;
                }
                var text = headingText.trim() + '\\n\\n' + content.join('\\n');
                window.webkit.messageHandlers.copySection.postMessage(text.trim());
                btn.innerHTML = checkSvg;
                btn.classList.add('copied');
                setTimeout(function() {
                    btn.innerHTML = copySvg;
                    btn.classList.remove('copied');
                }, 1500);
            });
            h.appendChild(btn);
        });
    })();

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

    // MARK: - Export HTML Template (delegated to HTMLTemplateProvider)

    static func exportHTMLTemplate(_ body: String, theme: String, showTOC: Bool) -> String {
        HTMLTemplateProvider.exportHTMLTemplate(body, theme: theme, showTOC: showTOC)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var baseURL: URL?
        var onInternalLink: ((URL) -> Void)?
        weak var webView: WKWebView?

        nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            MainActor.assumeIsolated {
                if message.name == "copySection", let text = message.body as? String {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // Allow localhost server navigation (for LocalHTTPServer)
            if url.host == "localhost" || url.host == "127.0.0.1" {
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
