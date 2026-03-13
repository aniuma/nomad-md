import Foundation

struct TabItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
}

@Observable
final class AppState {
    var registeredFolderURLs: [URL]
    var selectedFileURL: URL?
    var openTabs: [TabItem] = []
    var activeTabID: UUID?
    var recentFiles: [URL] = []
    var previewTabID: UUID?
    var pinnedTabIDs: Set<UUID> = []

    var activeTabURL: URL? {
        guard let id = activeTabID else { return nil }
        return openTabs.first { $0.id == id }?.url
    }

    init() {
        BookmarkManager.migrateIfNeeded()
        self.registeredFolderURLs = BookmarkManager.restoreBookmarks()
        self.selectedFileURL = BookmarkManager.restoreSelectedFile()
        self.recentFiles = BookmarkManager.restoreRecentFiles()

        if let selected = selectedFileURL {
            let tab = TabItem(url: selected)
            openTabs = [tab]
            activeTabID = tab.id
            pinnedTabIDs.insert(tab.id)
        }
    }

    func addFolder(_ url: URL) {
        try? BookmarkManager.saveBookmark(for: url)
        if !registeredFolderURLs.contains(where: { $0.path == url.path }) {
            registeredFolderURLs.append(url)
        }
    }

    func removeFolder(_ url: URL) {
        BookmarkManager.removeBookmark(for: url)
        registeredFolderURLs.removeAll { $0.path == url.path }
        let tabsToClose = openTabs.filter { $0.url.path.hasPrefix(url.path) }
        for tab in tabsToClose {
            closeTab(tab.id)
        }
        if let selected = selectedFileURL, selected.path.hasPrefix(url.path) {
            selectedFileURL = nil
            BookmarkManager.saveSelectedFile(nil)
        }
    }

    func selectFile(_ url: URL?) {
        guard let url = url else {
            selectedFileURL = nil
            activeTabID = nil
            BookmarkManager.saveSelectedFile(nil)
            return
        }

        // Already open — just activate the first matching tab
        if let existing = openTabs.first(where: { $0.url.path == url.path }) {
            activeTabID = existing.id
            selectedFileURL = url
            BookmarkManager.saveSelectedFile(url)
            addToRecentFiles(url)
            return
        }

        // Replace preview tab or add new preview tab
        if let previewID = previewTabID,
           let index = openTabs.firstIndex(where: { $0.id == previewID }) {
            let newTab = TabItem(url: url)
            openTabs[index] = newTab
            previewTabID = newTab.id
            activeTabID = newTab.id
        } else if let activeID = activeTabID,
                  let activeIndex = openTabs.firstIndex(where: { $0.id == activeID }) {
            let newTab = TabItem(url: url)
            openTabs.insert(newTab, at: activeIndex + 1)
            previewTabID = newTab.id
            activeTabID = newTab.id
        } else {
            let newTab = TabItem(url: url)
            openTabs.append(newTab)
            previewTabID = newTab.id
            activeTabID = newTab.id
        }
        selectedFileURL = url
        BookmarkManager.saveSelectedFile(url)
        addToRecentFiles(url)
    }

    /// 既存プレビューを昇格し、新ファイルをプレビュータブとして開く（同一ファイルでも新タブ追加）
    func openInNewTab(_ url: URL) {
        // 既存プレビュータブをピン留めに昇格
        if let previewID = previewTabID {
            pinnedTabIDs.insert(previewID)
            previewTabID = nil
        }

        // 新タブをプレビューとして末尾に追加
        let newTab = TabItem(url: url)
        previewTabID = newTab.id
        openTabs.append(newTab)
        activeTabID = newTab.id
        selectedFileURL = url
        BookmarkManager.saveSelectedFile(url)
        addToRecentFiles(url)
    }

    func pinTab(_ id: UUID) {
        pinnedTabIDs.insert(id)
        if previewTabID == id {
            previewTabID = nil
        }
    }

    /// URL指定でピン留め（サイドバーから呼ぶ用）
    func pinTab(url: URL) {
        if let tab = openTabs.first(where: { $0.url.path == url.path }) {
            pinTab(tab.id)
        }
    }

    func isPreviewTab(_ id: UUID) -> Bool {
        previewTabID == id
    }

    func closeTab(_ id: UUID) {
        let closedIndex = openTabs.firstIndex(where: { $0.id == id })

        openTabs.removeAll { $0.id == id }
        pinnedTabIDs.remove(id)
        if previewTabID == id {
            previewTabID = nil
        }

        if activeTabID == id {
            if let idx = closedIndex {
                if idx < openTabs.count {
                    let next = openTabs[idx]
                    activeTabID = next.id
                    selectedFileURL = next.url
                    BookmarkManager.saveSelectedFile(next.url)
                } else if idx > 0, !openTabs.isEmpty {
                    let prev = openTabs[idx - 1]
                    activeTabID = prev.id
                    selectedFileURL = prev.url
                    BookmarkManager.saveSelectedFile(prev.url)
                } else {
                    activeTabID = nil
                    selectedFileURL = nil
                    BookmarkManager.saveSelectedFile(nil)
                }
            } else {
                activeTabID = nil
                selectedFileURL = nil
                BookmarkManager.saveSelectedFile(nil)
            }
        }
    }

    func activateTab(_ id: UUID) {
        guard let tab = openTabs.first(where: { $0.id == id }) else { return }
        activeTabID = id
        selectedFileURL = tab.url
        BookmarkManager.saveSelectedFile(tab.url)
    }

    private func addToRecentFiles(_ url: URL) {
        recentFiles.removeAll { $0.path == url.path }
        recentFiles.insert(url, at: 0)
        if recentFiles.count > 20 {
            recentFiles = Array(recentFiles.prefix(20))
        }
        BookmarkManager.addRecentFile(url)
    }
}
