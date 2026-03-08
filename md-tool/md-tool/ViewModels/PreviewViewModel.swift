import Foundation
import CryptoKit

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
    private var renderCache: [String: String] = [:]  // content hash -> html
    private let maxCacheEntries = 50
    private var skipNextFileWatch = false

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
        let key = cacheKey(text, baseURL: baseURL)
        if let cached = renderCache[key] {
            htmlContent = cached
            return
        }
        let renderer = MarkdownRenderer(baseURL: baseURL)
        let result = renderer.render(text)
        storeCache(key: key, value: result)
        htmlContent = result
    }

    private func renderFile(at url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            htmlContent = "<p>ファイルを読み込めませんでした。</p>"
            return
        }
        let baseURL = url.deletingLastPathComponent()
        let key = cacheKey(content, baseURL: baseURL)
        if let cached = renderCache[key] {
            htmlContent = cached
            return
        }
        let renderer = MarkdownRenderer(baseURL: baseURL)
        let result = renderer.render(content)
        storeCache(key: key, value: result)
        htmlContent = result
    }

    private func cacheKey(_ content: String, baseURL: URL) -> String {
        let data = Data((content + baseURL.path).utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func storeCache(key: String, value: String) {
        if renderCache.count >= maxCacheEntries {
            // Remove oldest (arbitrary) entry
            if let firstKey = renderCache.keys.first {
                renderCache.removeValue(forKey: firstKey)
            }
        }
        renderCache[key] = value
    }

    private func watchCurrentFile() {
        guard let url = currentURL else { return }
        let dir = url.deletingLastPathComponent()
        let fileName = url.lastPathComponent
        fileWatcher.start(paths: [dir]) { [weak self] changedPaths in
            guard let self, let currentURL = self.currentURL else { return }
            if self.skipNextFileWatch {
                self.skipNextFileWatch = false
                return
            }
            let shouldReload = changedPaths.isEmpty || changedPaths.contains { path in
                path.hasSuffix(fileName) || path == currentURL.path
            }
            if shouldReload {
                self.renderFile(at: currentURL)
            }
        }
    }

    func toggleCheckbox(at line: Int) {
        guard let url = currentURL,
              let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        var lines = content.components(separatedBy: "\n")
        // swift-markdown line numbers are 1-based
        let index = line - 1
        guard index >= 0, index < lines.count else { return }
        let currentLine = lines[index]
        if currentLine.contains("- [ ]") {
            lines[index] = currentLine.replacingOccurrences(of: "- [ ]", with: "- [x]")
        } else if currentLine.contains("- [x]") || currentLine.contains("- [X]") {
            lines[index] = currentLine
                .replacingOccurrences(of: "- [x]", with: "- [ ]")
                .replacingOccurrences(of: "- [X]", with: "- [ ]")
        } else {
            return
        }
        let newContent = lines.joined(separator: "\n")
        skipNextFileWatch = true
        try? newContent.write(to: url, atomically: true, encoding: .utf8)
    }

    private func stopWatching() {
        fileWatcher.stop()
    }
}
