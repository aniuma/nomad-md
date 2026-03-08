import Foundation

// MARK: - Data Models

struct IndexHeading: Codable, Equatable, Sendable {
    let level: Int
    let text: String
}

struct IndexFileEntry: Codable, Identifiable, Sendable {
    var id: String { path }
    let path: String
    let modificationDate: Date
    let headings: [IndexHeading]
    let summary: String  // 先頭段落の最初の100文字程度
}

// MARK: - Cache Container

private nonisolated let _indexHeadingPattern: NSRegularExpression = {
    try! NSRegularExpression(pattern: #"^(#{1,6})\s+(.+)$"#, options: .anchorsMatchLines)
}()

private nonisolated struct IndexCache: Codable, Sendable {
    var entries: [String: IndexFileEntry]  // path -> entry
    var version: Int = 1
}

// MARK: - IndexCacheService

@Observable
final class IndexCacheService {
    private(set) var entries: [IndexFileEntry] = []
    private(set) var isScanning: Bool = false

    private nonisolated static var appSupportDir: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("com.susumu.nomad", isDirectory: true)
    }

    private nonisolated static var cacheFileURL: URL? {
        appSupportDir?.appendingPathComponent("index_cache.json")
    }

    // MARK: - Public API

    /// 差分スキャンを実行してキャッシュを更新する
    func updateCache(for files: [URL]) {
        isScanning = true
        let currentCache = Self.loadCacheFromDisk()
        Task.detached(priority: .userInitiated) { [files] in
            let updated = Self.scanFiles(files, existingCache: currentCache)
            await MainActor.run {
                Self.saveCacheToDisk(updated)
                self.entries = Array(updated.entries.values)
                    .sorted { $0.path < $1.path }
                self.isScanning = false
            }
        }
    }

    /// キャッシュをディスクから読み込んで entries を設定する（存在チェック付き）
    func loadFromDisk() {
        isScanning = true
        let cache = Self.loadCacheFromDisk()
        Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let valid = cache.entries.values.filter { fm.fileExists(atPath: $0.path) }
            let sorted = valid.sorted { $0.path < $1.path }
            await MainActor.run {
                self.entries = sorted
                self.isScanning = false
            }
        }
    }

    /// キャッシュを削除する
    func clearCache() {
        guard let url = Self.cacheFileURL else { return }
        try? FileManager.default.removeItem(at: url)
        entries = []
    }

    // MARK: - Scanning

    private nonisolated static func scanFiles(_ files: [URL], existingCache: IndexCache) -> IndexCache {
        var cache = existingCache
        let fm = FileManager.default
        var validPaths = Set<String>()

        for file in files {
            let path = file.path
            validPaths.insert(path)

            // 更新日時チェック
            let attrs = try? fm.attributesOfItem(atPath: path)
            let modDate = (attrs?[.modificationDate] as? Date) ?? Date.distantPast

            if let existing = cache.entries[path],
               abs(existing.modificationDate.timeIntervalSince(modDate)) < 1.0 {
                // 変更なし→スキップ
                continue
            }

            // 再パース
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let headings = parseHeadings(from: content)
            let summary = extractSummary(from: content)

            cache.entries[path] = IndexFileEntry(
                path: path,
                modificationDate: modDate,
                headings: headings,
                summary: summary
            )
        }

        // 削除されたファイルをキャッシュから除去
        let removedPaths = Set(cache.entries.keys).subtracting(validPaths)
        for path in removedPaths {
            cache.entries.removeValue(forKey: path)
        }

        return cache
    }

    // MARK: - Parsing Helpers

    private nonisolated static func parseHeadings(from content: String) -> [IndexHeading] {
        var result: [IndexHeading] = []
        let range = NSRange(content.startIndex..., in: content)
        for match in _indexHeadingPattern.matches(in: content, range: range) {
            let level = Range(match.range(at: 1), in: content).map { content[$0].count } ?? 1
            let text = Range(match.range(at: 2), in: content).map { String(content[$0]) } ?? ""
            if !text.isEmpty {
                result.append(IndexHeading(level: level, text: text))
            }
        }
        return result
    }

    private nonisolated static func extractSummary(from content: String) -> String {
        let lines = content.components(separatedBy: "\n")
        var inFrontMatter = false
        var frontMatterEnded = false
        var dashCount = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Front Matter スキップ
            if !frontMatterEnded {
                if trimmed == "---" {
                    dashCount += 1
                    if dashCount == 1 { inFrontMatter = true; continue }
                    if dashCount == 2 { inFrontMatter = false; frontMatterEnded = true; continue }
                }
                if inFrontMatter { continue }
            }

            // 見出し行スキップ
            if trimmed.hasPrefix("#") { continue }
            // 空行スキップ
            if trimmed.isEmpty { continue }
            // コードブロック開始スキップ
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { continue }

            // 最初の本文段落を取得（インラインMarkdownを除去）
            let cleaned = trimmed
                .replacingOccurrences(of: #"\*{1,2}([^*]+)\*{1,2}"#, with: "$1", options: .regularExpression)
                .replacingOccurrences(of: #"`([^`]+)`"#, with: "$1", options: .regularExpression)
                .replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)

            if cleaned.count > 5 {
                return String(cleaned.prefix(100))
            }
        }
        return ""
    }

    // MARK: - Disk I/O

    private nonisolated static func loadCacheFromDisk() -> IndexCache {
        guard let url = cacheFileURL,
              let data = try? Data(contentsOf: url),
              let cache = try? JSONDecoder().decode(IndexCache.self, from: data) else {
            return IndexCache(entries: [:])
        }
        return cache
    }

    private nonisolated static func saveCacheToDisk(_ cache: IndexCache) {
        guard let dir = appSupportDir, let url = cacheFileURL else { return }
        let fm = FileManager.default
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

// MARK: - Folder Grouping Helper

extension IndexCacheService {
    /// フォルダパスをキーにしてエントリをグループ化する
    func groupedByFolder(rootFolders: [URL]) -> [(folderName: String, folderPath: String, entries: [IndexFileEntry])] {
        var groups: [String: [IndexFileEntry]] = [:]
        var folderNames: [String: String] = [:]  // path -> displayName

        for entry in entries {
            let fileURL = URL(fileURLWithPath: entry.path)
            let folderURL = fileURL.deletingLastPathComponent()
            let folderPath = folderURL.path

            // ルートフォルダからの相対表示名を決定
            let displayName: String
            if let root = rootFolders.first(where: { folderURL.path.hasPrefix($0.path) }) {
                let relative = String(folderURL.path.dropFirst(root.path.count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                displayName = relative.isEmpty
                    ? root.lastPathComponent
                    : "\(root.lastPathComponent)/\(relative)"
            } else {
                displayName = folderURL.lastPathComponent
            }

            folderNames[folderPath] = displayName
            groups[folderPath, default: []].append(entry)
        }

        return groups
            .map { folderPath, groupEntries in
                (
                    folderName: folderNames[folderPath] ?? folderPath,
                    folderPath: folderPath,
                    entries: groupEntries.sorted { $0.path < $1.path }
                )
            }
            .sorted { $0.folderName.localizedStandardCompare($1.folderName) == .orderedAscending }
    }
}
