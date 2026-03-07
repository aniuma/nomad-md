import Foundation

@Observable
final class PreviewViewModel {
    var htmlContent: String = ""

    func loadFile(at url: URL?) {
        guard let url = url else {
            htmlContent = ""
            return
        }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            htmlContent = "<p>ファイルを読み込めませんでした。</p>"
            return
        }
        let renderer = MarkdownRenderer(baseURL: url.deletingLastPathComponent())
        htmlContent = renderer.render(content)
    }
}
