import Foundation

@Observable
final class AppState {
    var registeredFolderURL: URL?
    var selectedFileURL: URL?

    init() {
        self.registeredFolderURL = BookmarkManager.restoreBookmark()
        self.selectedFileURL = BookmarkManager.restoreSelectedFile()
    }

    func registerFolder(_ url: URL) {
        try? BookmarkManager.saveBookmark(for: url)
        registeredFolderURL = url
    }

    func unregisterFolder() {
        BookmarkManager.clearBookmark()
        registeredFolderURL = nil
        selectedFileURL = nil
    }

    func selectFile(_ url: URL?) {
        selectedFileURL = url
        BookmarkManager.saveSelectedFile(url)
    }
}
