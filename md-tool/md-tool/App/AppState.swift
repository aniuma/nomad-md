import Foundation

@Observable
final class AppState {
    var registeredFolderURLs: [URL]
    var selectedFileURL: URL?

    init() {
        BookmarkManager.migrateIfNeeded()
        self.registeredFolderURLs = BookmarkManager.restoreBookmarks()
        self.selectedFileURL = BookmarkManager.restoreSelectedFile()
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
        // Clear selected file if it was inside the removed folder
        if let selected = selectedFileURL, selected.path.hasPrefix(url.path) {
            selectedFileURL = nil
            BookmarkManager.saveSelectedFile(nil)
        }
    }

    func selectFile(_ url: URL?) {
        selectedFileURL = url
        BookmarkManager.saveSelectedFile(url)
    }
}
