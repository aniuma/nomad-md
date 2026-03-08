import Foundation
import AppKit
import UniformTypeIdentifiers

@Observable
final class SidebarViewModel {
    var rootNodes: [FileNode] = []
    var allTags: [String: [URL]] = [:]
    var selectedTag: String?

    private let appState: AppState
    private let fileWatcher = FileWatcher()

    private var exclusionObserver: Any?

    /// 選択中タグでフィルタされたファイルURL一覧
    var filteredFileURLs: Set<URL>? {
        guard let tag = selectedTag, let urls = allTags[tag] else { return nil }
        return Set(urls)
    }

    /// ソート済みタグ名一覧
    var sortedTagNames: [String] {
        allTags.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    init(appState: AppState) {
        self.appState = appState
        loadAllFolders()
        refreshTags()
        startWatching()
        exclusionObserver = NotificationCenter.default.addObserver(
            forName: .exclusionSettingsChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.refreshAllFolders()
        }
    }

    func addFolder() {
        addFileOrFolder(onFileSelected: nil)
    }

    func addFileOrFolder(onFileSelected: ((URL) -> Void)?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.folder, .init(filenameExtension: "md")!, .init(filenameExtension: "markdown")!]
        panel.message = "Markdownファイルまたはフォルダを選択してください"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)

        if isDir.boolValue {
            if appState.registeredFolderURLs.contains(where: { $0.path == url.path }) { return }
            appState.addFolder(url)
            if let node = FileSystemService.scanDirectory(at: url) {
                rootNodes.append(node)
                if appState.selectedFileURL == nil,
                   let firstFile = FileSystemService.findFirstMarkdownFile(in: node) {
                    appState.selectFile(firstFile)
                }
            }
            startWatching()
        } else {
            onFileSelected?(url)
        }
    }

    func addFolderByURL(_ url: URL) {
        if appState.registeredFolderURLs.contains(where: { $0.path == url.path }) { return }

        appState.addFolder(url)
        if let node = FileSystemService.scanDirectory(at: url) {
            rootNodes.append(node)
            if appState.selectedFileURL == nil,
               let firstFile = FileSystemService.findFirstMarkdownFile(in: node) {
                appState.selectFile(firstFile)
            }
        }
        startWatching()
    }

    func removeFolder(at url: URL) {
        rootNodes.removeAll { $0.url.path == url.path }
        appState.removeFolder(url)
        startWatching()
    }

    func refreshAllFolders() {
        loadAllFolders()
        refreshTags()
    }

    func refreshTags() {
        let allFiles = rootNodes.flatMap { FileSystemService.collectAllMarkdownFiles(in: $0) }
        Task.detached {
            let tags = TagService.collectAllTags(from: allFiles)
            await MainActor.run { [weak self] in
                self?.allTags = tags
            }
        }
    }

    func toggleTag(_ tag: String) {
        if selectedTag == tag {
            selectedTag = nil
        } else {
            selectedTag = tag
        }
    }

    func clearTagFilter() {
        selectedTag = nil
    }

    /// 新規Markdownファイルを作成（NSSavePanel）
    func createNewFile(in directoryURL: URL?) -> URL? {
        let panel = NSSavePanel()
        panel.title = "新規Markdownファイル"
        panel.nameFieldStringValue = "新規ファイル.md"
        panel.allowedContentTypes = [.init(filenameExtension: "md")!]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        // 初期ディレクトリ: 選択中ファイルの同階層 → 登録フォルダの先頭
        if let dir = directoryURL {
            panel.directoryURL = dir
        } else if let first = appState.registeredFolderURLs.first {
            panel.directoryURL = first
        }

        guard panel.runModal() == .OK, let fileURL = panel.url else { return nil }

        // タイトルをファイル名から推定して # 見出し挿入
        let title = fileURL.deletingPathExtension().lastPathComponent
        let initialContent = (title == "新規ファイル" || title == "Untitled") ? "" : "# \(title)\n\n"
        do {
            try initialContent.write(to: fileURL, atomically: true, encoding: .utf8)
            // 保存先フォルダがサイドバーに未登録なら追加
            let parentDir = fileURL.deletingLastPathComponent()
            if !appState.registeredFolderURLs.contains(where: { parentDir.path.hasPrefix($0.path) }) {
                addFolderByURL(parentDir)
            }
            refreshAllFolders()
            return fileURL
        } catch {
            print("Failed to create file: \(error)")
            return nil
        }
    }

    func refreshFolder(at url: URL) {
        guard let index = rootNodes.firstIndex(where: { $0.url.path == url.path }) else { return }
        if let node = FileSystemService.scanDirectory(at: url) {
            rootNodes[index] = node
        } else {
            rootNodes.remove(at: index)
        }
    }

    func selectFile(_ url: URL) {
        appState.selectFile(url)
    }

    private func loadAllFolders() {
        rootNodes = appState.registeredFolderURLs.compactMap { url in
            FileSystemService.scanDirectory(at: url)
        }
    }

    private func startWatching() {
        let urls = appState.registeredFolderURLs
        fileWatcher.start(paths: urls) { [weak self] _ in
            self?.refreshAllFolders()
        }
    }
}
