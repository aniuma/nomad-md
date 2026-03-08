import AppKit
import UniformTypeIdentifiers
import WebKit

enum ExportService {

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

    static func exportPDF(from webView: WKWebView, sourceFileName: String = "export") {
        let baseName = (sourceFileName as NSString).deletingPathExtension
        let panel = NSSavePanel()
        panel.title = "PDFとして保存"
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(baseName).pdf"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let saveURL = panel.url else { return }

        let config = WKPDFConfiguration()
        // A4: 595.28 x 841.89 points (72dpi)
        config.rect = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        webView.createPDF(configuration: config) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    do {
                        try data.write(to: saveURL)
                    } catch {
                        let alert = NSAlert()
                        alert.messageText = "PDFの保存に失敗しました"
                        alert.informativeText = error.localizedDescription
                        alert.runModal()
                    }
                case .failure(let error):
                    let alert = NSAlert()
                    alert.messageText = "PDFの生成に失敗しました"
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                }
            }
        }
    }
}
