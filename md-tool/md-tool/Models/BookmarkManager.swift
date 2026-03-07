import Foundation

struct BookmarkManager {
    private static let bookmarkKey = "registeredFolderBookmark"
    private static let selectedFileKey = "selectedFileURL"

    static func saveBookmark(for url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
    }

    static func restoreBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        if isStale {
            try? saveBookmark(for: url)
        }
        return url
    }

    static func clearBookmark() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        UserDefaults.standard.removeObject(forKey: selectedFileKey)
    }

    static func saveSelectedFile(_ url: URL?) {
        UserDefaults.standard.set(url?.path, forKey: selectedFileKey)
    }

    static func restoreSelectedFile() -> URL? {
        guard let path = UserDefaults.standard.string(forKey: selectedFileKey) else { return nil }
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: path) ? url : nil
    }
}
