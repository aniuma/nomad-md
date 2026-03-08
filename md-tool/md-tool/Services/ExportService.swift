import AppKit
import PDFKit
import UniformTypeIdentifiers
import WebKit

enum ExportError: Error, LocalizedError {
    case invalidPDF
    case contextCreationFailed

    var errorDescription: String? {
        switch self {
        case .invalidPDF: "生成されたPDFデータが無効です"
        case .contextCreationFailed: "PDFコンテキストの作成に失敗しました"
        }
    }
}

enum ExportService {

    // Retain the delegate + webView + window until PDF generation completes
    private static var activePDFContext: (window: NSWindow, webView: WKWebView, delegate: PDFNavigationDelegate)?

    // MARK: - HTML Export

    static func exportHTML(htmlBody: String, theme: String, showTOC: Bool, sourceFileName: String = "export") {
        let baseName = (sourceFileName as NSString).deletingPathExtension
        let panel = NSSavePanel()
        panel.title = "HTMLとして保存"
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = "\(baseName).html"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let html = PreviewView.exportHTMLTemplate(htmlBody, theme: theme, showTOC: showTOC)
        do {
            try html.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            let alert = NSAlert()
            alert.messageText = "HTMLの保存に失敗しました"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    // MARK: - PDF Export

    static func exportPDF(htmlBody: String, sourceFileName: String = "export", settings: PDFExportSettings) {
        let baseName = (sourceFileName as NSString).deletingPathExtension
        let panel = NSSavePanel()
        panel.title = "PDFとして保存"
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(baseName).pdf"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let saveURL = panel.url else { return }

        let html = pdfHTMLTemplate(body: htmlBody, fileName: sourceFileName, settings: settings)

        // WebView width = content area (page width minus left/right margins)
        let contentWidth = settings.pageSize.width - settings.marginPreset.points * 2

        // Hidden window is required for WKWebView to fully lay out content
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: contentWidth, height: 800),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.orderOut(nil)

        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: contentWidth, height: 800))
        webView.setValue(false, forKey: "drawsBackground")
        window.contentView = webView

        let delegate = PDFNavigationDelegate(
            saveURL: saveURL,
            settings: settings,
            fileName: sourceFileName
        ) {
            // Release retained context after PDF generation
            ExportService.activePDFContext = nil
        }
        webView.navigationDelegate = delegate

        // Retain window, webView, and delegate until PDF generation completes
        activePDFContext = (window: window, webView: webView, delegate: delegate)

        webView.loadHTMLString(html, baseURL: nil)
    }

    // MARK: - Split single tall PDF into A4 pages at breakpoints

    /// Split a single tall PDF into multiple A4 pages, clipping at breakpoints.
    /// - Parameters:
    ///   - sourcePDFData: Single-page tall PDF from `createPDF()` without rect
    ///   - pageBreaks: Y positions (in CSS points) where pages should break
    ///   - settings: PDF export settings
    static func splitIntoPages(sourcePDFData: Data, pageBreaks: [CGFloat], settings: PDFExportSettings) throws -> PDFDocument {
        guard let sourceDoc = PDFDocument(data: sourcePDFData),
              sourceDoc.pageCount > 0,
              let sourcePage = sourceDoc.page(at: 0),
              let sourcePageRef = sourcePage.pageRef else {
            throw ExportError.invalidPDF
        }

        let sourceRect = sourcePage.bounds(for: .mediaBox)
        let scale = sourceRect.width / (settings.pageSize.width - settings.marginPreset.points * 2)

        let pageSize = settings.pageSize
        let margin = settings.marginPreset.points
        let headerSpace: CGFloat = settings.showHeader ? 28 : 0
        let footerSpace: CGFloat = settings.showFooter ? 28 : 0
        let contentAreaHeight = pageSize.height - margin * 2 - headerSpace - footerSpace

        let totalPages = pageBreaks.count - 1
        guard totalPages > 0 else { throw ExportError.invalidPDF }

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            throw ExportError.contextCreationFailed
        }

        var mediaBox = CGRect(x: 0, y: 0, width: pageSize.width, height: pageSize.height)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ExportError.contextCreationFailed
        }

        let sourceHeight = sourceRect.height
        let contentWidth = pageSize.width - margin * 2

        for pageIndex in 0..<totalPages {
            let startY = pageBreaks[pageIndex]     // CSS top-down coordinate
            let endY = pageBreaks[pageIndex + 1]
            let sliceCSS = endY - startY           // Slice height in CSS points
            let displayHeight = min(sliceCSS, contentAreaHeight) // Capped to content area

            context.beginPDFPage(nil)
            context.saveGState()

            // Clip: show only this page's slice, top-aligned in content area
            // Content area top = margin + footerSpace + contentAreaHeight
            // Clip bottom = content area top - displayHeight
            let clipRect = CGRect(
                x: margin,
                y: margin + footerSpace + contentAreaHeight - displayHeight,
                width: contentWidth,
                height: displayHeight
            )
            context.clip(to: clipRect)

            // Position source so that CSS startY aligns with content area top.
            // After scaleBy(1/scale), source dimensions become (contentWidth, sourceHeight/scale).
            // Source PDF y-coordinate for CSS startY = sourceHeight - startY * scale
            // After transform, that point maps to: offsetY + (sourceHeight - startY * scale) / scale
            // We want it at content area top: margin + footerSpace + contentAreaHeight
            // => offsetY = margin + footerSpace + contentAreaHeight - sourceHeight/scale + startY
            let offsetY = margin + footerSpace + contentAreaHeight - sourceHeight / scale + startY
            context.translateBy(x: margin, y: offsetY)
            context.scaleBy(x: 1 / scale, y: 1 / scale)
            context.drawPDFPage(sourcePageRef)

            context.restoreGState()
            context.endPDFPage()
        }

        context.closePDF()

        guard let resultDoc = PDFDocument(data: pdfData as Data) else {
            throw ExportError.invalidPDF
        }
        return resultDoc
    }

    // MARK: - Header / Footer

    static func addHeaderFooter(to pdfDoc: PDFDocument, settings: PDFExportSettings, fileName: String) {
        guard settings.showHeader || settings.showFooter else { return }

        let totalPages = pdfDoc.pageCount
        let margin = settings.marginPreset.points
        let font = NSFont.systemFont(ofSize: 9)
        let textColor = NSColor(calibratedRed: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)

        for i in 0..<totalPages {
            guard let page = pdfDoc.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)

            if settings.showHeader {
                let headerText = (fileName as NSString).deletingPathExtension
                let headerAnnotation = PDFAnnotation(bounds: CGRect(
                    x: margin,
                    y: bounds.height - margin - 12,
                    width: bounds.width - margin * 2,
                    height: 14
                ), forType: .freeText, withProperties: nil)
                headerAnnotation.font = font
                headerAnnotation.fontColor = textColor
                headerAnnotation.color = .clear
                headerAnnotation.contents = headerText
                headerAnnotation.alignment = .left
                page.addAnnotation(headerAnnotation)
            }

            if settings.showFooter {
                let footerText = "\(i + 1) / \(totalPages)"
                let footerAnnotation = PDFAnnotation(bounds: CGRect(
                    x: margin,
                    y: margin - 2,
                    width: bounds.width - margin * 2,
                    height: 14
                ), forType: .freeText, withProperties: nil)
                footerAnnotation.font = font
                footerAnnotation.fontColor = textColor
                footerAnnotation.color = .clear
                footerAnnotation.contents = footerText
                footerAnnotation.alignment = .center
                page.addAnnotation(footerAnnotation)
            }
        }
    }

    // MARK: - PDF HTML Template

    private static func pdfHTMLTemplate(body: String, fileName: String, settings: PDFExportSettings) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        \(pdfBaseCSS)

        body {
            padding: 0;
            position: relative;
        }
        </style>
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">
        </head>
        <body>
        <article class="markdown-body">
        \(body)
        </article>
        <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>
        <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js" onload="renderMathInElement(document.body, {delimiters: [{left: '$$', right: '$$', display: true}, {left: '$', right: '$', display: false}], throwOnError: false});"></script>
        <script type="module">
        import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
        mermaid.initialize({ startOnLoad: true, theme: 'default' });
        </script>
        </body>
        </html>
        """
    }

    // MARK: - PDF Base CSS

    private static let pdfBaseCSS = """
    * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
    }

    :root {
        --bg: #ffffff;
        --text: #2C2C2C;
        --code-bg: #f5f5f5;
        --border: #E0DCD8;
        --link: #2C2C2C;
        --blockquote-border: #D0D7DE;
        --blockquote-text: #656D76;
    }

    body {
        font-family: "Hiragino Kaku Gothic ProN", "Hiragino Sans", -apple-system, "SF Pro Text", system-ui, sans-serif;
        font-size: 10.5pt;
        line-height: 1.6;
        letter-spacing: 0.02em;
        color: var(--text);
        background-color: var(--bg);
        -webkit-font-smoothing: antialiased;
        -webkit-print-color-adjust: exact;
    }

    .markdown-body {
        max-width: none;
        margin: 0;
        padding: 0;
    }

    /* Typography - reuse from layoutCSS */
    h1, h2, h3, h4, h5, h6 {
        font-family: "Hiragino Kaku Gothic ProN", "Hiragino Sans", -apple-system, "SF Pro Display", system-ui, sans-serif;
        margin-top: 1.2em;
        margin-bottom: 0.5em;
        letter-spacing: -0.01em;
        line-height: 1.3;
    }

    h1 { font-size: 18pt; font-weight: 700; border-bottom: none; padding-bottom: 0; margin-top: 1.08em; }
    h2 { font-size: 14pt; font-weight: 700; border-bottom: 1px solid var(--border); padding-bottom: 0.15em; margin-top: 1.1em; }
    h3 { font-size: 12pt; font-weight: 600; margin-top: 1em; }
    h4 { font-size: 10.5pt; font-weight: 600; margin-top: 1em; }

    h1:first-child, h2:first-child, h3:first-child { margin-top: 0; }

    p { margin-bottom: 0.7em; }

    a { color: var(--link); text-decoration: none; }

    code {
        font-family: "SF Mono", Menlo, monospace;
        font-size: 9pt;
        background-color: var(--code-bg);
        padding: 0.15em 0.35em;
        border-radius: 3px;
    }

    pre {
        margin-bottom: 0.8em;
        padding: 10px 12px;
        background-color: var(--code-bg);
        border: 1px solid #e0e0e0;
        border-radius: 6px;
        overflow-x: auto;
    }

    pre code {
        padding: 0;
        background: none;
        font-size: 8.5pt;
        line-height: 1.5;
    }

    blockquote {
        margin-bottom: 0.6em;
        padding: 0.2em 1em;
        border-left: 3px solid var(--blockquote-border);
        color: var(--blockquote-text);
        font-size: 10pt;
    }

    blockquote p:last-child { margin-bottom: 0; }

    ul, ol {
        margin-bottom: 0.6em;
        padding-left: 1.7em;
    }

    li { margin-bottom: 0.05em; line-height: 1.5; }
    li > ul, li > ol { margin-bottom: 0; margin-top: 0.05em; }

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
        padding: 4px 8px;
        border: 1px solid var(--border);
        text-align: left;
        font-size: 9.5pt;
    }

    th {
        font-weight: 600;
        background-color: var(--code-bg);
    }

    input[type="checkbox"] {
        margin-right: 0.5em;
    }

    /* Hide non-print elements */
    .toc-sidebar,
    .section-copy-btn,
    .heading-warnings {
        display: none !important;
    }

    .front-matter {
        display: none !important;
    }

    /* Page break control */
    h1, h2, h3 {
        page-break-after: avoid;
    }

    pre, table, img {
        page-break-inside: avoid;
    }

    /* Mermaid / KaTeX */
    pre.mermaid {
        background: none;
        border: none;
        padding: 1em 0;
        text-align: center;
    }

    .katex-display {
        margin: 1em 0;
        overflow-x: auto;
    }

    /* Footnotes */
    .footnotes {
        margin-top: 1.5em;
        padding-top: 0.8em;
        border-top: 1px solid var(--border);
        font-size: 8.5pt;
    }

    .footnotes ol {
        padding-left: 1.5em;
    }

    .footnote-ref {
        font-size: 0.75em;
        vertical-align: super;
        line-height: 0;
        text-decoration: none;
    }

    .footnote-backref {
        text-decoration: none;
        margin-left: 0.3em;
    }

    /* Callout styles for print */
    .callout {
        margin-bottom: 1em;
        border-radius: 6px;
        border-left: 4px solid;
        overflow: hidden;
    }

    .callout .callout-title {
        font-weight: 600;
        font-size: 10pt;
        padding: 5px 10px;
        display: flex;
        align-items: center;
        gap: 5px;
    }

    .callout .callout-body {
        padding: 3px 10px 6px 10px;
        font-size: 10pt;
    }

    .callout .callout-body p:last-child { margin-bottom: 0; }

    .callout-note { border-left-color: #4393e5; background: rgba(67, 147, 229, 0.08); }
    .callout-note .callout-title { color: #4393e5; }
    .callout-tip { border-left-color: #3fb950; background: rgba(63, 185, 80, 0.08); }
    .callout-tip .callout-title { color: #3fb950; }
    .callout-warning { border-left-color: #d29922; background: rgba(210, 153, 34, 0.08); }
    .callout-warning .callout-title { color: #d29922; }
    .callout-important { border-left-color: #a371f7; background: rgba(163, 113, 247, 0.08); }
    .callout-important .callout-title { color: #a371f7; }
    .callout-caution { border-left-color: #f85149; background: rgba(248, 81, 73, 0.08); }
    .callout-caution .callout-title { color: #f85149; }
    """
}

// MARK: - PDF Navigation Delegate

fileprivate final class PDFNavigationDelegate: NSObject, WKNavigationDelegate {
    let saveURL: URL
    let settings: PDFExportSettings
    let fileName: String
    let onComplete: () -> Void

    init(saveURL: URL, settings: PDFExportSettings, fileName: String, onComplete: @escaping () -> Void) {
        self.saveURL = saveURL
        self.settings = settings
        self.fileName = fileName
        self.onComplete = onComplete
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MainActor.assumeIsolated {
            // Wait for Mermaid/KaTeX rendering
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                generatePDF(from: webView)
            }
        }
    }

    private func generatePDF(from webView: WKWebView) {
        let margin = settings.marginPreset.points
        let headerSpace: CGFloat = settings.showHeader ? 28 : 0
        let footerSpace: CGFloat = settings.showFooter ? 28 : 0
        let contentAreaHeight = settings.pageSize.height - margin * 2 - headerSpace - footerSpace

        // JS to collect page break points based on block element positions
        let breakpointJS = """
        (function() {
            var contentHeight = \(contentAreaHeight);
            var blocks = document.querySelectorAll('h1, h2, h3, h4, h5, h6, p, pre, table, blockquote, ul, ol, hr, .callout, .mermaid, .katex-display, img');
            var breakPoints = [0];
            var currentPageEnd = contentHeight;

            for (var i = 0; i < blocks.length; i++) {
                var el = blocks[i];
                var rect = el.getBoundingClientRect();
                var tagName = el.tagName.toLowerCase();
                var isHeading = /^h[1-6]$/.test(tagName);

                // For headings: break before the heading (so it starts on the next page)
                // For other blocks: break after the block completes
                var breakAt = isHeading ? rect.top : rect.bottom;

                if (breakAt > currentPageEnd) {
                    // This element exceeds current page — find best break point
                    var bestBreak = isHeading ? rect.top : currentPageEnd;

                    // For non-headings that overflow, try to break before this element
                    if (!isHeading && rect.top > breakPoints[breakPoints.length - 1]) {
                        bestBreak = rect.top;
                    }

                    breakPoints.push(bestBreak);
                    currentPageEnd = bestBreak + contentHeight;

                    // If the element still exceeds the new page, handle tall elements
                    while (rect.bottom > currentPageEnd) {
                        breakPoints.push(currentPageEnd);
                        currentPageEnd += contentHeight;
                    }
                }
            }

            // Final break at document bottom
            var docHeight = document.documentElement.scrollHeight;
            if (breakPoints[breakPoints.length - 1] < docHeight) {
                breakPoints.push(docHeight);
            }

            return breakPoints;
        })();
        """

        webView.evaluateJavaScript(breakpointJS) { [self] jsResult, jsError in
            guard let breakValues = jsResult as? [NSNumber], breakValues.count >= 2 else {
                // Fallback: if JS fails, use simple fixed-height splitting
                self.generatePDFWithoutBreakpoints(from: webView, contentAreaHeight: contentAreaHeight)
                return
            }

            let pageBreaks = breakValues.map { CGFloat($0.doubleValue) }

            // Get single tall PDF (no rect = full content height)
            let config = WKPDFConfiguration()
            webView.createPDF(configuration: config) { [self] result in
                switch result {
                case .success(let data):
                    do {
                        let pdfDoc = try ExportService.splitIntoPages(
                            sourcePDFData: data,
                            pageBreaks: pageBreaks,
                            settings: settings
                        )
                        ExportService.addHeaderFooter(to: pdfDoc, settings: settings, fileName: fileName)
                        pdfDoc.write(to: saveURL)
                    } catch {
                        let alert = NSAlert()
                        alert.messageText = "PDFの生成に失敗しました"
                        alert.informativeText = error.localizedDescription
                        alert.runModal()
                    }
                case .failure(let error):
                    let alert = NSAlert()
                    alert.messageText = "PDFの生成に失敗しました"
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                }
                onComplete()
            }
        }
    }

    /// Fallback: split by fixed content height when JS breakpoints are unavailable
    private func generatePDFWithoutBreakpoints(from webView: WKWebView, contentAreaHeight: CGFloat) {
        let config = WKPDFConfiguration()
        webView.createPDF(configuration: config) { [self] result in
            switch result {
            case .success(let data):
                do {
                    guard let sourceDoc = PDFDocument(data: data),
                          sourceDoc.pageCount > 0,
                          let sourcePage = sourceDoc.page(at: 0) else {
                        throw ExportError.invalidPDF
                    }
                    let sourceRect = sourcePage.bounds(for: .mediaBox)
                    let scale = sourceRect.width / (settings.pageSize.width - settings.marginPreset.points * 2)
                    let totalHeight = sourceRect.height / scale

                    // Generate fixed-height breakpoints
                    var pageBreaks: [CGFloat] = [0]
                    var y: CGFloat = contentAreaHeight
                    while y < totalHeight {
                        pageBreaks.append(y)
                        y += contentAreaHeight
                    }
                    pageBreaks.append(totalHeight)

                    let pdfDoc = try ExportService.splitIntoPages(
                        sourcePDFData: data,
                        pageBreaks: pageBreaks,
                        settings: settings
                    )
                    ExportService.addHeaderFooter(to: pdfDoc, settings: settings, fileName: fileName)
                    pdfDoc.write(to: saveURL)
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "PDFの生成に失敗しました"
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                }
            case .failure(let error):
                let alert = NSAlert()
                alert.messageText = "PDFの生成に失敗しました"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
            onComplete()
        }
    }
}
