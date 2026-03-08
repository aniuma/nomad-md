import Cocoa
import QuickLookUI
import WebKit

class PreviewViewController: NSViewController, QLPreviewingController {

    private var webView: WKWebView!

    override func loadView() {
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        view = webView
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        let renderer = MarkdownRenderer(baseURL: url.deletingLastPathComponent())
        let html = renderer.render(content)
        let fullHTML = HTMLTemplateProvider.quickLookTemplate(html)
        webView.loadHTMLString(fullHTML, baseURL: url.deletingLastPathComponent())
    }
}
