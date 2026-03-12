import Foundation

struct BookmarkManager {
    private static let bookmarksKey = "registeredFolderBookmarks"
    private static let legacyBookmarkKey = "registeredFolderBookmark"
    private static let selectedFileKey = "selectedFileURL"

    // MARK: - Migration

    static func migrateIfNeeded() {
        let defaults = UserDefaults.standard
        guard let legacyData = defaults.data(forKey: legacyBookmarkKey) else { return }
        var existing = defaults.array(forKey: bookmarksKey) as? [Data] ?? []
        existing.append(legacyData)
        defaults.set(existing, forKey: bookmarksKey)
        defaults.removeObject(forKey: legacyBookmarkKey)
    }

    // MARK: - Multiple Bookmarks

    static func saveBookmark(for url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        var existing = UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] ?? []
        // Avoid duplicates by resolving existing bookmarks
        let existingURLs = existing.compactMap { resolveBookmarkData($0) }
        if existingURLs.contains(where: { $0.path == url.path }) { return }
        existing.append(bookmarkData)
        UserDefaults.standard.set(existing, forKey: bookmarksKey)
    }

    static func restoreBookmarks() -> [URL] {
        guard let dataArray = UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] else {
            return []
        }
        var urls: [URL] = []
        var updatedData: [Data] = []
        for data in dataArray {
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else { continue }
            if isStale {
                if let refreshed = try? url.bookmarkData(
                    options: [],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                ) {
                    updatedData.append(refreshed)
                } else {
                    updatedData.append(data)
                }
            } else {
                updatedData.append(data)
            }
            urls.append(url)
        }
        if updatedData.count != dataArray.count || updatedData != dataArray {
            UserDefaults.standard.set(updatedData, forKey: bookmarksKey)
        }
        return urls
    }

    static func removeBookmark(for url: URL) {
        guard let dataArray = UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] else {
            return
        }
        let filtered = dataArray.filter { data in
            guard let resolved = resolveBookmarkData(data) else { return false }
            return resolved.path != url.path
        }
        UserDefaults.standard.set(filtered, forKey: bookmarksKey)
    }

    static func clearAllBookmarks() {
        UserDefaults.standard.removeObject(forKey: bookmarksKey)
        UserDefaults.standard.removeObject(forKey: selectedFileKey)
    }

    // MARK: - Selected File

    static func saveSelectedFile(_ url: URL?) {
        UserDefaults.standard.set(url?.path, forKey: selectedFileKey)
    }

    static func restoreSelectedFile() -> URL? {
        guard let path = UserDefaults.standard.string(forKey: selectedFileKey) else { return nil }
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: path) ? url : nil
    }

    // MARK: - Recent Files

    private static let recentFilesKey = "recentFiles"
    private static let maxRecentFiles = 20

    static func saveRecentFiles(_ urls: [URL]) {
        let paths = urls.map { $0.path }
        UserDefaults.standard.set(paths, forKey: recentFilesKey)
    }

    static func restoreRecentFiles() -> [URL] {
        guard let paths = UserDefaults.standard.stringArray(forKey: recentFilesKey) else { return [] }
        return paths.compactMap { path in
            let url = URL(fileURLWithPath: path)
            return FileManager.default.fileExists(atPath: path) ? url : nil
        }
    }

    static func addRecentFile(_ url: URL) {
        var recent = restoreRecentFiles()
        recent.removeAll { $0.path == url.path }
        recent.insert(url, at: 0)
        if recent.count > maxRecentFiles {
            recent = Array(recent.prefix(maxRecentFiles))
        }
        saveRecentFiles(recent)
    }

    static func clearRecentFiles() {
        UserDefaults.standard.removeObject(forKey: recentFilesKey)
    }

    // MARK: - File Bookmarks

    private static let fileBookmarksKey = "fileBookmarks"

    static func saveFileBookmarks(_ urls: [URL]) {
        let paths = urls.map { $0.path }
        UserDefaults.standard.set(paths, forKey: fileBookmarksKey)
    }

    static func restoreFileBookmarks() -> [URL] {
        guard let paths = UserDefaults.standard.stringArray(forKey: fileBookmarksKey) else { return [] }
        return paths.compactMap { path in
            let url = URL(fileURLWithPath: path)
            return FileManager.default.fileExists(atPath: path) ? url : nil
        }
    }

    static func addFileBookmark(_ url: URL) {
        var bookmarks = restoreFileBookmarks()
        guard !bookmarks.contains(where: { $0.path == url.path }) else { return }
        bookmarks.insert(url, at: 0)
        saveFileBookmarks(bookmarks)
    }

    static func removeFileBookmark(_ url: URL) {
        var bookmarks = restoreFileBookmarks()
        bookmarks.removeAll { $0.path == url.path }
        saveFileBookmarks(bookmarks)
    }

    // MARK: - Private

    private static func resolveBookmarkData(_ data: Data) -> URL? {
        var isStale = false
        return try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }
}
