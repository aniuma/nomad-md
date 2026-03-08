import Cocoa
import UniformTypeIdentifiers
import WebKit

class ShareViewController: NSViewController {

    private var fileURL: URL?
    private var formatPopup: NSPopUpButton!
    private var convertButton: NSButton!
    private var statusLabel: NSTextField!
    private var webView: WKWebView?

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 160))

        let titleLabel = NSTextField(labelWithString: "Nomad: Markdownを変換")
        titleLabel.font = .boldSystemFont(ofSize: 14)
        titleLabel.frame = NSRect(x: 20, y: 120, width: 280, height: 20)
        container.addSubview(titleLabel)

        let formatLabel = NSTextField(labelWithString: "出力形式:")
        formatLabel.frame = NSRect(x: 20, y: 85, width: 70, height: 20)
        container.addSubview(formatLabel)

        formatPopup = NSPopUpButton(frame: NSRect(x: 95, y: 82, width: 120, height: 26))
        formatPopup.addItems(withTitles: ["HTML", "PDF"])
        container.addSubview(formatPopup)

        convertButton = NSButton(title: "変換", target: self, action: #selector(convert))
        convertButton.bezelStyle = .rounded
        convertButton.frame = NSRect(x: 130, y: 20, width: 80, height: 32)
        container.addSubview(convertButton)

        let cancelButton = NSButton(title: "キャンセル", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.frame = NSRect(x: 220, y: 20, width: 80, height: 32)
        container.addSubview(cancelButton)

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.frame = NSRect(x: 20, y: 55, width: 280, height: 20)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 11)
        container.addSubview(statusLabel)

        view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadInputFile()
    }

    private func loadInputFile() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachment = item.attachments?.first else { return }

        let typeID = UTType.fileURL.identifier
        if attachment.hasItemConformingToTypeIdentifier(typeID) {
            attachment.loadItem(forTypeIdentifier: typeID) { [weak self] data, _ in
                guard let self else { return }
                var url: URL?
                if let urlData = data as? Data {
                    url = URL(dataRepresentation: urlData, relativeTo: nil)
                } else if let fileURL = data as? URL {
                    url = fileURL
                }
                DispatchQueue.main.async {
                    self.fileURL = url
                    if let name = url?.lastPathComponent {
                        self.statusLabel.stringValue = name
                    }
                }
            }
        }
    }

    @objc private func convert() {
        guard let fileURL,
              let markdown = try? String(contentsOf: fileURL, encoding: .utf8) else {
            statusLabel.stringValue = "ファイルを読み込めませんでした"
            return
        }

        let renderer = MarkdownRenderer(baseURL: fileURL.deletingLastPathComponent())
        let html = renderer.render(markdown)

        if formatPopup.indexOfSelectedItem == 0 {
            // HTML export
            let fullHTML = HTMLTemplateProvider.exportHTMLTemplate(html, theme: "default", showTOC: false)
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent((fileURL.deletingPathExtension().lastPathComponent) + ".html")
            do {
                try fullHTML.write(to: outputURL, atomically: true, encoding: .utf8)
                let outputItem = NSExtensionItem()
                if let provider = NSItemProvider(contentsOf: outputURL) {
                    outputItem.attachments = [provider]
                }
                extensionContext?.completeRequest(returningItems: [outputItem])
            } catch {
                statusLabel.stringValue = "変換に失敗しました: \(error.localizedDescription)"
            }
        } else {
            // PDF export via offscreen WKWebView
            statusLabel.stringValue = "PDF生成中..."
            convertButton.isEnabled = false

            let fullHTML = HTMLTemplateProvider.exportHTMLTemplate(html, theme: "default", showTOC: false)
            let config = WKWebViewConfiguration()
            let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 595, height: 842), configuration: config)
            webView = wv

            let delegate = SharePDFDelegate { [weak self] pdfData in
                guard let self else { return }
                let outputURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent((fileURL.deletingPathExtension().lastPathComponent) + ".pdf")
                do {
                    try pdfData.write(to: outputURL)
                    let outputItem = NSExtensionItem()
                    if let provider = NSItemProvider(contentsOf: outputURL) {
                    outputItem.attachments = [provider]
                }
                    self.extensionContext?.completeRequest(returningItems: [outputItem])
                } catch {
                    self.statusLabel.stringValue = "PDF保存に失敗しました"
                    self.convertButton.isEnabled = true
                }
            }
            wv.navigationDelegate = delegate
            // Keep delegate alive
            objc_setAssociatedObject(wv, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            wv.loadHTMLString(fullHTML, baseURL: fileURL.deletingLastPathComponent())
        }
    }

    @objc private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }
}

// MARK: - PDF Navigation Delegate

private final class SharePDFDelegate: NSObject, WKNavigationDelegate {
    let onPDF: (Data) -> Void

    init(onPDF: @escaping (Data) -> Void) {
        self.onPDF = onPDF
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MainActor.assumeIsolated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
                let config = WKPDFConfiguration()
                config.rect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4
                webView.createPDF(configuration: config) { result in
                    switch result {
                    case .success(let data):
                        self.onPDF(data)
                    case .failure:
                        break
                    }
                }
            }
        }
    }
}
