import Foundation

@Observable
final class PreviewViewModel {
    var htmlContent: String = ""
    var fileSizeWarning: FileSizeWarning?

    enum FileSizeWarning {
        case large      // 1MB-10MB
        case veryLarge  // 10MB-50MB
        case tooLarge   // 50MB+
    }

    private let fileWatcher = FileWatcher()
    private var currentURL: URL?

    func loadFile(at url: URL?) {
        guard let url = url else {
            stopWatching()
            currentURL = nil
            htmlContent = ""
            fileSizeWarning = nil
            return
        }
        currentURL = url
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        if fileSize > 50_000_000 {
            fileSizeWarning = .tooLarge
            htmlContent = "<p style='color:red;padding:2em;'>ファイルサイズが50MBを超えています。プレビューできません。</p>"
            stopWatching()
            return
        } else if fileSize > 10_000_000 {
            fileSizeWarning = .veryLarge
        } else if fileSize > 1_000_000 {
            fileSizeWarning = .large
        } else {
            fileSizeWarning = nil
        }
        renderFile(at: url)
        watchCurrentFile()
    }

    func renderFromText(_ text: String, baseURL: URL) {
        let renderer = MarkdownRenderer(baseURL: baseURL)
        htmlContent = renderer.render(text)
    }

    private func renderFile(at url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            htmlContent = "<p>ファイルを読み込めませんでした。</p>"
            return
        }
        let renderer = MarkdownRenderer(baseURL: url.deletingLastPathComponent())
        htmlContent = renderer.render(content)
    }

    private func watchCurrentFile() {
        guard let url = currentURL else { return }
        let dir = url.deletingLastPathComponent()
        let fileName = url.lastPathComponent
        fileWatcher.start(paths: [dir]) { [weak self] changedPaths in
            guard let self, let currentURL = self.currentURL else { return }
            let shouldReload = changedPaths.isEmpty || changedPaths.contains { path in
                path.hasSuffix(fileName) || path == currentURL.path
            }
            if shouldReload {
                self.renderFile(at: currentURL)
            }
        }
    }

    private func stopWatching() {
        fileWatcher.stop()
    }
}
