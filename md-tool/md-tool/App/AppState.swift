import Foundation

@Observable
final class AppState {
    var registeredFolderURLs: [URL]
    var selectedFileURL: URL?
    var openTabs: [URL] = []
    var activeTabURL: URL?
    var recentFiles: [URL] = []
    var fileBookmarks: [URL] = []

    init() {
        BookmarkManager.migrateIfNeeded()
        self.registeredFolderURLs = BookmarkManager.restoreBookmarks()
        self.selectedFileURL = BookmarkManager.restoreSelectedFile()
        self.recentFiles = BookmarkManager.restoreRecentFiles()
        self.fileBookmarks = BookmarkManager.restoreFileBookmarks()

        // Restore tabs: if there was a previously selected file, open it as a tab
        if let selected = selectedFileURL {
            openTabs = [selected]
            activeTabURL = selected
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
        // Close tabs inside the removed folder
        let tabsToClose = openTabs.filter { $0.path.hasPrefix(url.path) }
        for tab in tabsToClose {
            closeTab(tab)
        }
        // Clear selected file if it was inside the removed folder
        if let selected = selectedFileURL, selected.path.hasPrefix(url.path) {
            selectedFileURL = nil
            BookmarkManager.saveSelectedFile(nil)
        }
    }

    func selectFile(_ url: URL?) {
        guard let url = url else {
            selectedFileURL = nil
            activeTabURL = nil
            BookmarkManager.saveSelectedFile(nil)
            return
        }

        // Add to tabs if not already open
        if !openTabs.contains(where: { $0.path == url.path }) {
            openTabs.append(url)
        }
        activeTabURL = url
        selectedFileURL = url
        BookmarkManager.saveSelectedFile(url)

        // Add to recent files
        addToRecentFiles(url)
    }

    func closeTab(_ url: URL) {
        openTabs.removeAll { $0.path == url.path }

        if activeTabURL?.path == url.path {
            // Activate the last tab, or nil if no tabs remain
            if let lastTab = openTabs.last {
                activeTabURL = lastTab
                selectedFileURL = lastTab
                BookmarkManager.saveSelectedFile(lastTab)
            } else {
                activeTabURL = nil
                selectedFileURL = nil
                BookmarkManager.saveSelectedFile(nil)
            }
        }
    }

    func activateTab(_ url: URL) {
        guard openTabs.contains(where: { $0.path == url.path }) else { return }
        activeTabURL = url
        selectedFileURL = url
        BookmarkManager.saveSelectedFile(url)
    }

    // MARK: - File Bookmarks

    func addFileBookmark(_ url: URL) {
        guard !fileBookmarks.contains(where: { $0.path == url.path }) else { return }
        fileBookmarks.insert(url, at: 0)
        BookmarkManager.addFileBookmark(url)
    }

    func removeFileBookmark(_ url: URL) {
        fileBookmarks.removeAll { $0.path == url.path }
        BookmarkManager.removeFileBookmark(url)
    }

    /// Finderからファイルを開く: 新規タブで開き、ブックマークに追加
    func openFileFromFinder(_ url: URL) {
        selectFile(url)
        addFileBookmark(url)
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
