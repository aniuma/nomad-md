import Foundation
import AppKit

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
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Markdownファイルを含むフォルダを選択してください"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        // Duplicate check
        if appState.registeredFolderURLs.contains(where: { $0.path == url.path }) { return }

        appState.addFolder(url)
        if let node = FileSystemService.scanDirectory(at: url) {
            rootNodes.append(node)
            // Auto-select first markdown file if nothing is selected
            if appState.selectedFileURL == nil,
               let firstFile = FileSystemService.findFirstMarkdownFile(in: node) {
                appState.selectFile(firstFile)
            }
        }
        startWatching()
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
