import Foundation

struct TagService {
    /// ファイルからFront Matterのtagsフィールドを抽出する
    static func extractTags(from url: URL) -> [String] {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else { return [] }

        let lines = content.components(separatedBy: "\n")
        guard let firstDashIndex = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "---"
        }) else {
            return []
        }
        let startIndex = firstDashIndex + 1
        guard let endIndex = lines[startIndex...].firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "---"
        }) else {
            return []
        }

        let yamlLines = Array(lines[startIndex..<endIndex])
        return parseTagsFromYAML(yamlLines)
    }

    /// YAML行からtagsフィールドのみを抽出する
    private static func parseTagsFromYAML(_ lines: [String]) -> [String] {
        var inTags = false
        var tags: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // リストアイテム（tagsキーの下にある場合）
            if trimmed.hasPrefix("- "), inTags {
                let item = String(trimmed.dropFirst(2))
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if !item.isEmpty {
                    tags.append(item)
                }
                continue
            }

            // 別のキーが来たらtagsセクション終了
            if inTags && !trimmed.hasPrefix("- ") {
                inTags = false
            }

            // tags: で始まる行を探す
            guard let colonIndex = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[trimmed.startIndex..<colonIndex])
                .trimmingCharacters(in: .whitespaces)
                .lowercased()

            guard key == "tags" else { continue }

            let rawValue = String(trimmed[trimmed.index(after: colonIndex)...])
                .trimmingCharacters(in: .whitespaces)

            if rawValue.isEmpty {
                // tags:\n  - item1\n  - item2 形式
                inTags = true
            } else if rawValue.hasPrefix("[") && rawValue.hasSuffix("]") {
                // tags: [Swift, macOS] 形式
                let inner = String(rawValue.dropFirst().dropLast())
                tags = inner.components(separatedBy: ",").compactMap { item in
                    let cleaned = item
                        .trimmingCharacters(in: .whitespaces)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    return cleaned.isEmpty ? nil : cleaned
                }
            } else {
                // tags: single-tag 形式
                let cleaned = rawValue
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if !cleaned.isEmpty {
                    tags = [cleaned]
                }
            }
        }

        return tags
    }

    /// 全ファイルからタグを収集し、タグ→ファイルURL辞書を返す
    static func collectAllTags(from urls: [URL]) -> [String: [URL]] {
        var result: [String: [URL]] = [:]
        for url in urls {
            let tags = extractTags(from: url)
            for tag in tags {
                result[tag, default: []].append(url)
            }
        }
        return result
    }
}
