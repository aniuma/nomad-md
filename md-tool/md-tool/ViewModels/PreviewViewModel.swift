import Foundation

@Observable
final class PreviewViewModel {
    var htmlContent: String = ""

    private let fileWatcher = FileWatcher()
    private var currentURL: URL?

    func loadFile(at url: URL?) {
        guard let url = url else {
            stopWatching()
            currentURL = nil
            htmlContent = ""
            return
        }
        currentURL = url
        renderFile(at: url)
        watchCurrentFile()
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
