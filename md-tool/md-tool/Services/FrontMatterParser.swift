import Foundation

/// AI生成Markdown用 Front Matterパーサ
/// 1段ネストYAML対応（ai: ブロック等）
nonisolated struct FrontMatterParser {

    struct FrontMatter {
        let raw: [(key: String, value: String)]
        let ai: AIMetadata?
        let tags: [String]
        let title: String?
    }

    struct AIMetadata {
        let model: String?
        let provider: String?      // anthropic, openai, google, local
        let tool: String?           // Claude Code, Cursor, Copilot等
        let generated: String?      // ISO8601
        let prompt: String?
        let confidence: String?     // high / medium / low / unverified
        let status: String?         // draft / review / approved / archived
        let version: Int?
        let contextFiles: [String]
    }

    // MARK: - Public API

    /// Markdown文字列からFront Matterを抽出し、パース結果と残りのMarkdownを返す
    nonisolated static func parse(_ markdown: String) -> (frontMatter: FrontMatter?, body: String) {
        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else { return (nil, markdown) }

        let lines = markdown.components(separatedBy: "\n")
        guard let firstDashIndex = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "---"
        }) else {
            return (nil, markdown)
        }
        let startIndex = firstDashIndex + 1
        guard let endIndex = lines[startIndex...].firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "---"
        }) else {
            return (nil, markdown)
        }

        let yamlLines = Array(lines[startIndex..<endIndex])
        let remainingLines = Array(lines[(endIndex + 1)...])
        let body = remainingLines.joined(separator: "\n")

        guard !yamlLines.isEmpty else { return (nil, body) }

        let frontMatter = parseYAML(yamlLines)
        return (frontMatter, body)
    }

    /// FrontMatterからHTMLを生成（AIバッジ含む）
    nonisolated static func renderHTML(_ fm: FrontMatter) -> String {
        var html = ""

        // AIメタデータバッジ
        if let ai = fm.ai {
            html += renderAIBadgeHTML(ai)
        }

        // 通常のFront Matterテーブル
        let displayItems = fm.raw.filter { $0.key != "ai" }
        if !displayItems.isEmpty {
            html += renderFrontMatterTableHTML(displayItems)
        }

        return html
    }

    // MARK: - YAML Parsing (1段ネスト対応)

    private nonisolated static func parseYAML(_ lines: [String]) -> FrontMatter {
        var flatItems: [(key: String, value: String)] = []
        var nestedBlocks: [String: [(key: String, value: String)]] = [:]
        var currentKey: String?
        var listItems: [String] = []
        var inNestedBlock: String?
        var nestedItems: [(key: String, value: String)] = []
        var nestedListKey: String?
        var nestedListItems: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            let indent = line.prefix(while: { $0 == " " }).count

            // ネストブロック内のリストアイテム
            if let nlk = nestedListKey, indent >= 4, trimmed.hasPrefix("- ") {
                let item = String(trimmed.dropFirst(2))
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                nestedListItems.append(item)
                continue
            }

            // ネストリスト終了
            if nestedListKey != nil, !(indent >= 4 && trimmed.hasPrefix("- ")) {
                if !nestedListItems.isEmpty {
                    nestedItems.append((key: nestedListKey!, value: nestedListItems.joined(separator: ", ")))
                }
                nestedListKey = nil
                nestedListItems = []
            }

            // ネストブロック内のkey: value
            if inNestedBlock != nil, indent >= 2 {
                // リストアイテム（- item）をフラットリストとして処理
                if trimmed.hasPrefix("- ") {
                    // ネストブロックではなくフラットリストだった
                    let item = String(trimmed.dropFirst(2))
                        .trimmingCharacters(in: .whitespaces)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    listItems.append(item)
                    continue
                }
                if let colonIdx = trimmed.firstIndex(of: ":") {
                    // ネストブロック内のkey: value → リストはネストブロック
                    // まずフラットリストをフラッシュ
                    if let key = currentKey, !listItems.isEmpty {
                        flatItems.append((key: key, value: listItems.joined(separator: ", ")))
                        listItems = []
                        currentKey = nil
                    }
                    let key = String(trimmed[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                    let rawValue = String(trimmed[trimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)

                    if rawValue.isEmpty {
                        // ネスト内リスト開始
                        nestedListKey = key
                        nestedListItems = []
                    } else {
                        let value = stripQuotes(rawValue)
                        nestedItems.append((key: key, value: value))
                    }
                }
                continue
            }

            // ネストブロック終了（インデントが戻った）
            if let blockKey = inNestedBlock, indent < 2 {
                if !nestedItems.isEmpty {
                    nestedBlocks[blockKey] = nestedItems
                }
                // フラットリストが溜まっていたらフラッシュ
                if let key = currentKey, !listItems.isEmpty {
                    flatItems.append((key: key, value: listItems.joined(separator: ", ")))
                    listItems = []
                    currentKey = nil
                }
                inNestedBlock = nil
                nestedItems = []
            }

            // トップレベルのリストアイテム
            if trimmed.hasPrefix("- "), currentKey != nil {
                let item = String(trimmed.dropFirst(2))
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                listItems.append(item)
                continue
            }

            // 前のリスト終了
            if let key = currentKey, !listItems.isEmpty {
                flatItems.append((key: key, value: listItems.joined(separator: ", ")))
                listItems = []
                currentKey = nil
            }

            // トップレベルkey: value
            guard let colonIdx = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[..<colonIdx]).trimmingCharacters(in: .whitespaces)
            let rawValue = String(trimmed[trimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)

            if rawValue.isEmpty {
                // 値なし → ネストブロックまたはリスト開始
                // 次の行のインデントで判定するため、両方の可能性を記録
                currentKey = key
                inNestedBlock = key
            } else {
                var value = stripQuotes(rawValue)
                // インラインリスト [a, b, c]
                if value.hasPrefix("[") && value.hasSuffix("]") {
                    let inner = String(value.dropFirst().dropLast())
                    let items = inner.components(separatedBy: ",").map {
                        $0.trimmingCharacters(in: .whitespaces)
                          .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    }
                    value = items.joined(separator: ", ")
                }
                flatItems.append((key: key, value: value))
                currentKey = nil
            }
        }

        // 末尾フラッシュ
        if let pendingKey = nestedListKey, !nestedListItems.isEmpty {
            nestedItems.append((key: pendingKey, value: nestedListItems.joined(separator: ", ")))
        }
        if let blockKey = inNestedBlock, !nestedItems.isEmpty {
            nestedBlocks[blockKey] = nestedItems
        } else if let key = currentKey, !listItems.isEmpty {
            flatItems.append((key: key, value: listItems.joined(separator: ", ")))
        }

        // AI メタデータ抽出
        let ai = extractAIMetadata(from: nestedBlocks["ai"])

        // タグ抽出
        let tags = extractTags(from: flatItems)

        // タイトル抽出
        let title = flatItems.first(where: { $0.key == "title" })?.value

        return FrontMatter(raw: flatItems, ai: ai, tags: tags, title: title)
    }

    private nonisolated static func extractAIMetadata(from items: [(key: String, value: String)]?) -> AIMetadata? {
        guard let items = items, !items.isEmpty else { return nil }

        let dict = Dictionary(items.map { ($0.key, $0.value) }, uniquingKeysWith: { _, last in last })

        return AIMetadata(
            model: dict["model"],
            provider: dict["provider"],
            tool: dict["tool"],
            generated: dict["generated"],
            prompt: dict["prompt"],
            confidence: dict["confidence"],
            status: dict["status"],
            version: dict["version"].flatMap { Int($0) },
            contextFiles: dict["context_files"]?.components(separatedBy: ", ") ?? []
        )
    }

    private nonisolated static func extractTags(from items: [(key: String, value: String)]) -> [String] {
        guard let tagsValue = items.first(where: { $0.key.lowercased() == "tags" })?.value else {
            return []
        }
        return tagsValue.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private nonisolated static func stripQuotes(_ s: String) -> String {
        var value = s
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
           (value.hasPrefix("'") && value.hasSuffix("'")) {
            value = String(value.dropFirst().dropLast())
        }
        return value
    }

    // MARK: - HTML Rendering

    private nonisolated static func renderAIBadgeHTML(_ ai: AIMetadata) -> String {
        let providerIcon = providerIconName(ai.provider)
        let confidenceColor = confidenceColorCode(ai.confidence)
        let statusLabel = statusDisplayLabel(ai.status)

        var html = "<div class=\"ai-metadata\">\n"
        html += "<div class=\"ai-badge\">\n"

        // プロバイダ + モデル
        html += "<span class=\"ai-provider\">"
        html += "<span class=\"ai-provider-icon\">\(providerIcon)</span>"
        if let tool = ai.tool {
            html += " \(escapeHTML(tool))"
        } else if let provider = ai.provider {
            html += " \(escapeHTML(provider))"
        }
        html += "</span>\n"

        // Confidence
        if let confidence = ai.confidence {
            html += "<span class=\"ai-confidence\" style=\"--confidence-color: \(confidenceColor)\">"
            html += "\(escapeHTML(confidence))"
            html += "</span>\n"
        }

        // Status
        if let status = ai.status {
            html += "<span class=\"ai-status ai-status-\(escapeHTML(status))\">"
            html += "\(statusLabel)"
            html += "</span>\n"
        }

        html += "</div>\n"

        // 詳細情報（折りたたみ）
        var details: [(String, String)] = []
        if let model = ai.model { details.append(("モデル", model)) }
        if let prompt = ai.prompt { details.append(("プロンプト", prompt)) }
        if let generated = ai.generated { details.append(("生成日時", formatDate(generated))) }
        if let version = ai.version { details.append(("バージョン", String(version))) }
        if !ai.contextFiles.isEmpty {
            details.append(("コンテキスト", ai.contextFiles.joined(separator: ", ")))
        }

        if !details.isEmpty {
            html += "<details class=\"ai-details\">\n"
            html += "<summary>AI生成情報</summary>\n"
            html += "<table>\n"
            for (key, value) in details {
                html += "<tr><th>\(escapeHTML(key))</th><td>\(escapeHTML(value))</td></tr>\n"
            }
            html += "</table>\n"
            html += "</details>\n"
        }

        html += "</div>\n"
        return html
    }

    private nonisolated static func renderFrontMatterTableHTML(_ items: [(key: String, value: String)]) -> String {
        var html = "<div class=\"front-matter\">\n"
        html += "<details open>\n"
        html += "<summary>メタデータ</summary>\n"
        html += "<table>\n"
        for item in items {
            let escapedKey = escapeHTML(item.key)
            let escapedValue = escapeHTML(item.value)
            if item.value.contains(",") {
                let tags = item.value.components(separatedBy: ",").map { tag in
                    "<span class=\"front-matter-tag\">\(escapeHTML(tag.trimmingCharacters(in: .whitespaces)))</span>"
                }
                html += "<tr><th>\(escapedKey)</th><td>\(tags.joined(separator: " "))</td></tr>\n"
            } else {
                html += "<tr><th>\(escapedKey)</th><td>\(escapedValue)</td></tr>\n"
            }
        }
        html += "</table>\n"
        html += "</details>\n"
        html += "</div>\n"
        return html
    }

    private nonisolated static func providerIconName(_ provider: String?) -> String {
        switch provider?.lowercased() {
        case "anthropic": return "🅰️"
        case "openai":    return "🤖"
        case "google":    return "🔷"
        case "local":     return "💻"
        default:          return "✨"
        }
    }

    private nonisolated static func confidenceColorCode(_ confidence: String?) -> String {
        switch confidence?.lowercased() {
        case "high":       return "#3fb950"
        case "medium":     return "#d29922"
        case "low":        return "#f85149"
        case "unverified": return "#8b949e"
        default:           return "#8b949e"
        }
    }

    private nonisolated static func statusDisplayLabel(_ status: String?) -> String {
        switch status?.lowercased() {
        case "draft":    return "📝 Draft"
        case "review":   return "👀 Review"
        case "approved": return "✅ Approved"
        case "archived": return "📦 Archived"
        default:         return status ?? ""
        }
    }

    private nonisolated static func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoString) {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .short
            df.locale = Locale(identifier: "ja_JP")
            return df.string(from: date)
        }
        return isoString
    }

    private nonisolated static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
