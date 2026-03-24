import Foundation

/// セクション承認/却下をHTMLコメントで管理するサービス
/// No Database方式: `<!-- nomad-review: approved by=user at=2026-03-09T15:00:00+09:00 -->`
nonisolated struct ReviewService {

    enum ReviewStatus: String {
        case approved
        case rejected

        var displayLabel: String {
            switch self {
            case .approved: return "✅ 承認済み"
            case .rejected: return "❌ 却下"
            }
        }

        var cssClass: String {
            switch self {
            case .approved: return "review-approved"
            case .rejected: return "review-rejected"
            }
        }
    }

    struct ReviewComment {
        let status: ReviewStatus
        let by: String?
        let at: String?
        let reason: String?
        /// コメントが存在する行番号（0-based）
        let lineIndex: Int
    }

    // MARK: - パース

    /// Markdown文字列からレビューコメントを抽出する
    nonisolated static func parseReviews(from markdown: String) -> [ReviewComment] {
        let lines = markdown.components(separatedBy: "\n")
        var reviews: [ReviewComment] = []
        let pattern = #"<!--\s*nomad-review:\s*(approved|rejected)\s*(.*?)-->"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }

        for (index, line) in lines.enumerated() {
            let range = NSRange(line.startIndex..., in: line)
            guard let match = regex.firstMatch(in: line, range: range) else { continue }

            let statusStr = String(line[Range(match.range(at: 1), in: line)!])
            let attrsStr = String(line[Range(match.range(at: 2), in: line)!])

            guard let status = ReviewStatus(rawValue: statusStr) else { continue }

            let by = extractAttribute("by", from: attrsStr)
            let at = extractAttribute("at", from: attrsStr)
            let reason = extractAttribute("reason", from: attrsStr)

            reviews.append(ReviewComment(
                status: status,
                by: by,
                at: at,
                reason: reason,
                lineIndex: index
            ))
        }

        return reviews
    }

    /// 見出しIDとレビューコメントの対応を返す
    /// 各見出しの直後にあるレビューコメントをその見出しに紐付ける
    nonisolated static func reviewsBySection(markdown: String) -> [String: ReviewComment] {
        let lines = markdown.components(separatedBy: "\n")
        let reviews = parseReviews(from: markdown)
        var result: [String: ReviewComment] = [:]

        for review in reviews {
            // レビューコメントの直前の行が見出しか確認
            let prevIndex = review.lineIndex - 1
            guard prevIndex >= 0 else { continue }
            let prevLine = lines[prevIndex].trimmingCharacters(in: .whitespaces)
            if prevLine.hasPrefix("#") {
                let headingText = prevLine.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                let id = generateHeadingId(headingText)
                result[id] = review
            }
        }

        return result
    }

    // MARK: - 書き込み

    /// 見出しの直後にレビューコメントを挿入/更新する
    nonisolated static func setReview(
        in markdown: String,
        afterHeadingContaining headingText: String,
        status: ReviewStatus,
        by: String,
        reason: String? = nil
    ) -> String {
        var lines = markdown.components(separatedBy: "\n")
        let now = ISO8601DateFormatter().string(from: Date())

        // 対象の見出し行を探す
        var targetIndex: Int?
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                let text = trimmed.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                if text == headingText {
                    targetIndex = index
                    break
                }
            }
        }

        guard let headingIndex = targetIndex else { return markdown }

        // コメント生成
        var comment = "<!-- nomad-review: \(status.rawValue) by=\(by) at=\(now)"
        if let reason = reason, !reason.isEmpty {
            comment += " reason=\"\(reason)\""
        }
        comment += " -->"

        // 既存コメントがあれば更新、なければ挿入
        let nextIndex = headingIndex + 1
        if nextIndex < lines.count {
            let nextLine = lines[nextIndex].trimmingCharacters(in: .whitespaces)
            if nextLine.contains("nomad-review:") {
                lines[nextIndex] = comment
                return lines.joined(separator: "\n")
            }
        }

        lines.insert(comment, at: nextIndex)
        return lines.joined(separator: "\n")
    }

    /// レビューコメントを削除する
    nonisolated static func removeReview(
        in markdown: String,
        afterHeadingContaining headingText: String
    ) -> String {
        var lines = markdown.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                let text = trimmed.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                if text == headingText {
                    let nextIndex = index + 1
                    if nextIndex < lines.count,
                       lines[nextIndex].contains("nomad-review:") {
                        lines.remove(at: nextIndex)
                        return lines.joined(separator: "\n")
                    }
                }
            }
        }

        return markdown
    }

    // MARK: - HTML生成

    /// レビューステータスのバッジHTMLを生成
    nonisolated static func renderReviewBadgeHTML(for review: ReviewComment) -> String {
        var html = "<div class=\"review-badge \(review.status.cssClass)\">"
        html += "<span class=\"review-status\">\(review.status.displayLabel)</span>"
        if let by = review.by {
            html += "<span class=\"review-by\">\(escapeHTML(by))</span>"
        }
        if let reason = review.reason {
            html += "<span class=\"review-reason\">\(escapeHTML(reason))</span>"
        }
        html += "</div>"
        return html
    }

    // MARK: - Helpers

    private nonisolated static func extractAttribute(_ name: String, from attrs: String) -> String? {
        // reason="value with spaces"
        let quotedPattern = "\(name)=\"([^\"]*)\""
        if let regex = try? NSRegularExpression(pattern: quotedPattern),
           let match = regex.firstMatch(in: attrs, range: NSRange(attrs.startIndex..., in: attrs)),
           let range = Range(match.range(at: 1), in: attrs) {
            return String(attrs[range])
        }
        // name=value (no spaces)
        let simplePattern = "\(name)=(\\S+)"
        if let regex = try? NSRegularExpression(pattern: simplePattern),
           let match = regex.firstMatch(in: attrs, range: NSRange(attrs.startIndex..., in: attrs)),
           let range = Range(match.range(at: 1), in: attrs) {
            return String(attrs[range])
        }
        return nil
    }

    private nonisolated static func generateHeadingId(_ text: String) -> String {
        let lowered = text.lowercased()
        let allowed = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "\u{3040}"..."\u{309F}"))  // ひらがな
            .union(CharacterSet(charactersIn: "\u{30A0}"..."\u{30FF}"))  // カタカナ
            .union(CharacterSet(charactersIn: "\u{4E00}"..."\u{9FFF}"))  // CJK漢字
            .union(CharacterSet(charactersIn: " -"))
        let cleaned = lowered.unicodeScalars.filter { allowed.contains($0) }
        return String(cleaned)
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "-")
    }

    private nonisolated static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
