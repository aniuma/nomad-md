import SwiftUI
import WebKit

struct PreviewView: NSViewRepresentable {
    let htmlContent: String
    var baseURL: URL?
    var showTOC: Bool = true
    var theme: String = UserDefaults.standard.string(forKey: "previewTheme") ?? "default"
    var onInternalLink: ((URL) -> Void)?
    var onWebViewReady: ((WKWebView) -> Void)?
    var onToggleCheckbox: ((Int) -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(context.coordinator, name: "copySection")
        config.userContentController.add(context.coordinator, name: "toggleCheckbox")
        config.userContentController.add(context.coordinator, name: "internalLink")
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
        context.coordinator.onToggleCheckbox = onToggleCheckbox

        let server = LocalHTTPServer.shared
        server.start()
        let fullHTML = wrapInHTMLTemplate(htmlContent)
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
                    var node = h.childNodes[i];
                    if (node === btn) continue;
                    if (node.nodeType === 1 && (node.classList.contains('section-copy-btn') || node.classList.contains('section-toggle-btn'))) continue;
                    headingText += node.textContent;
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

    // Task list checkbox toggle
    (function() {
        document.querySelectorAll('li.task-list-item input[type="checkbox"]').forEach(function(cb) {
            cb.addEventListener('change', function() {
                var line = parseInt(this.getAttribute('data-line'));
                if (!isNaN(line)) {
                    window.webkit.messageHandlers.toggleCheckbox.postMessage(line);
                }
                var li = this.closest('li.task-list-item');
                if (li) {
                    if (this.checked) {
                        li.classList.add('checked');
                    } else {
                        li.classList.remove('checked');
                    }
                }
            });
        });
    })();

    // Section collapse toggle
    (function() {
        var toggleSvg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><polygon points="5,7 1,3 9,3"/></svg>';
        var headings = Array.from(document.querySelectorAll('.markdown-body h2, .markdown-body h3, .markdown-body h4, .markdown-body h5, .markdown-body h6'));

        function toggleSection(h, btn) {
            var isCollapsed = btn.classList.contains('collapsed');
            var hLevel = parseInt(h.tagName.charAt(1));
            var el = h.nextElementSibling;
            while (el) {
                if (/^H[1-6]$/.test(el.tagName) && parseInt(el.tagName.charAt(1)) <= hLevel) break;
                if (isCollapsed) {
                    el.classList.remove('section-content-collapsed');
                } else {
                    el.classList.add('section-content-collapsed');
                }
                el = el.nextElementSibling;
            }
            if (isCollapsed) {
                btn.classList.remove('collapsed');
                btn.setAttribute('aria-expanded', 'true');
                btn.title = 'セクションを折りたたむ';
            } else {
                btn.classList.add('collapsed');
                btn.setAttribute('aria-expanded', 'false');
                btn.title = 'セクションを展開する';
            }
        }

        headings.forEach(function(h) {
            h.classList.add('section-heading');
            var btn = document.createElement('button');
            btn.className = 'section-toggle-btn';
            btn.innerHTML = toggleSvg;
            btn.title = 'セクションを折りたたむ';
            btn.setAttribute('aria-expanded', 'true');
            btn.addEventListener('click', function(e) {
                e.preventDefault();
                e.stopPropagation();
                toggleSection(h, btn);
            });
            h.insertBefore(btn, h.firstChild);
            // Heading text click also toggles
            h.addEventListener('click', function(e) {
                if (e.target === btn || btn.contains(e.target)) return;
                if (e.target.tagName === 'A') return;
                e.preventDefault();
                toggleSection(h, btn);
            });
        });

        // Expose expand function for TOC links
        window.expandHeading = function(targetId) {
            var target = document.getElementById(targetId);
            if (!target) return;
            // Walk up: if any ancestor section is collapsed, expand it
            // Walk forward from headings that contain this element
            var allHeadings = Array.from(document.querySelectorAll('.markdown-body h1, .markdown-body h2, .markdown-body h3, .markdown-body h4, .markdown-body h5, .markdown-body h6'));
            allHeadings.forEach(function(h) {
                var btn = h.querySelector('.section-toggle-btn');
                if (!btn || !btn.classList.contains('collapsed')) return;
                var hLevel = parseInt(h.tagName.charAt(1));
                var el = h.nextElementSibling;
                var found = false;
                while (el) {
                    if (/^H[1-6]$/.test(el.tagName) && parseInt(el.tagName.charAt(1)) <= hLevel) break;
                    if (el === target || el.contains(target)) { found = true; break; }
                    el = el.nextElementSibling;
                }
                if (found) {
                    btn.click();
                }
            });
        };
    })();

    // Internal markdown link interception
    (function() {
        document.addEventListener('click', function(e) {
            var link = e.target.closest('a');
            if (!link) return;
            var href = link.getAttribute('href');
            if (!href) return;
            if (href.startsWith('http://') || href.startsWith('https://') ||
                href.startsWith('#') || href.startsWith('mailto:')) return;
            var cleanHref = href.split('#')[0];
            var ext = cleanHref.split('.').pop().toLowerCase();
            if (ext === 'md' || ext === 'markdown') {
                e.preventDefault();
                e.stopPropagation();
                window.webkit.messageHandlers.internalLink.postMessage(href);
            }
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

                // Auto-expand if section is collapsed
                if (typeof window.expandHeading === 'function') {
                    window.expandHeading(targetId);
                }

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
        var onToggleCheckbox: ((Int) -> Void)?
        weak var webView: WKWebView?

        nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            MainActor.assumeIsolated {
                if message.name == "copySection", let text = message.body as? String {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } else if message.name == "toggleCheckbox", let line = message.body as? Int {
                    onToggleCheckbox?(line)
                } else if message.name == "internalLink", let href = message.body as? String {
                    handleInternalLink(href: href)
                }
            }
        }

        private func handleInternalLink(href: String) {
            guard let baseURL = baseURL else { return }
            let cleanHref = href.components(separatedBy: "#").first ?? href
            let ext = (cleanHref as NSString).pathExtension.lowercased()
            guard ext == "md" || ext == "markdown" else { return }

            let resolvedURL: URL
            if cleanHref.hasPrefix("/") {
                resolvedURL = URL(fileURLWithPath: cleanHref).standardized
            } else {
                resolvedURL = baseURL.appendingPathComponent(cleanHref).standardized
            }

            if FileManager.default.fileExists(atPath: resolvedURL.path) {
                onInternalLink?(resolvedURL)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // Localhost navigation: check for .md links before allowing
            if url.host == "localhost" || url.host == "127.0.0.1" {
                let pathExt = url.pathExtension.lowercased()
                if (pathExt == "md" || pathExt == "markdown"), let baseURL = baseURL {
                    let relativePath = String(url.path.dropFirst())
                    let resolvedURL = baseURL.appendingPathComponent(relativePath).standardized
                    if FileManager.default.fileExists(atPath: resolvedURL.path) {
                        onInternalLink?(resolvedURL)
                        decisionHandler(.cancel)
                        return
                    }
                }
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
