import Foundation
import Markdown

struct MarkdownRenderer {
    let baseURL: URL?

    init(baseURL: URL? = nil) {
        self.baseURL = baseURL
    }

    func renderWithReadingTime(_ markdownString: String) -> (html: String, readingTime: ReadingTime) {
        let readingTime = ReadingTimeCalculator.calculate(markdown: markdownString)
        let html = render(markdownString)
        return (html, readingTime)
    }

    func render(_ markdownString: String) -> String {
        let (strippedMarkdown, frontMatterHTML) = extractFrontMatter(markdownString)
        let (processedMarkdown, footnotes) = extractFootnotes(strippedMarkdown)
        let document = Document(parsing: processedMarkdown)
        var generator = HTMLGenerator(baseURL: baseURL)
        generator.visit(document)

        var html = generator.html

        // Replace footnote reference placeholders
        for (index, footnote) in footnotes.enumerated() {
            let num = index + 1
            let placeholder = "FNREF_\(footnote.id)_FNREF"
            let ref = "<sup><a href=\"#fn-\(footnote.id)\" id=\"fnref-\(footnote.id)\" class=\"footnote-ref\">[\(num)]</a></sup>"
            html = html.replacingOccurrences(of: placeholder, with: ref)
        }

        // Append footnote definitions
        if !footnotes.isEmpty {
            html += renderFootnoteSection(footnotes)
        }

        // Callout/Admonition conversion
        html = convertCallouts(html)

        // oEmbed conversion (standalone URL lines → embed iframes)
        html = OEmbedService.convert(html)

        // Heading level warnings
        let warnings = detectHeadingLevelWarnings(generator.headings)
        if !warnings.isEmpty {
            html = renderHeadingWarnings(warnings) + html
        }

        // Prepend front matter metadata
        if !frontMatterHTML.isEmpty {
            html = frontMatterHTML + html
        }

        if generator.headings.isEmpty {
            return html
        }

        return generateNestedTOC(generator.headings) + html
    }

    // MARK: - Front Matter

    private func extractFrontMatter(_ markdown: String) -> (String, String) {
        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else { return (markdown, "") }

        // Find closing ---
        let lines = markdown.components(separatedBy: "\n")
        guard let firstDashIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return (markdown, "")
        }
        let startIndex = firstDashIndex + 1
        guard let endIndex = lines[startIndex...].firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return (markdown, "")
        }

        let yamlLines = Array(lines[startIndex..<endIndex])
        let remainingLines = Array(lines[(endIndex + 1)...])
        let strippedMarkdown = remainingLines.joined(separator: "\n")

        let metadata = parseSimpleYAML(yamlLines)
        guard !metadata.isEmpty else { return (strippedMarkdown, "") }

        let html = renderFrontMatterHTML(metadata)
        return (strippedMarkdown, html)
    }

    private func parseSimpleYAML(_ lines: [String]) -> [(key: String, value: String)] {
        var result: [(key: String, value: String)] = []
        var currentKey: String?
        var listItems: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // List item under a key (e.g., "  - item")
            if trimmed.hasPrefix("- "), currentKey != nil {
                let item = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                listItems.append(item)
                continue
            }

            // Flush previous list
            if let key = currentKey, !listItems.isEmpty {
                result.append((key: key, value: listItems.joined(separator: ", ")))
                listItems = []
                currentKey = nil
            }

            // Key: value pair
            guard let colonIndex = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[trimmed.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let rawValue = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

            if rawValue.isEmpty {
                // Value may be a list on subsequent lines
                currentKey = key
            } else {
                // Strip surrounding quotes
                var value = rawValue
                if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
                   (value.hasPrefix("'") && value.hasSuffix("'")) {
                    value = String(value.dropFirst().dropLast())
                }
                // Inline list [a, b, c]
                if value.hasPrefix("[") && value.hasSuffix("]") {
                    let inner = String(value.dropFirst().dropLast())
                    let items = inner.components(separatedBy: ",").map {
                        $0.trimmingCharacters(in: .whitespaces)
                          .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    }
                    value = items.joined(separator: ", ")
                }
                result.append((key: key, value: value))
                currentKey = nil
            }
        }

        // Flush trailing list
        if let key = currentKey, !listItems.isEmpty {
            result.append((key: key, value: listItems.joined(separator: ", ")))
        }

        return result
    }

    private func renderFrontMatterHTML(_ metadata: [(key: String, value: String)]) -> String {
        var html = "<div class=\"front-matter\">\n"
        html += "<details open>\n"
        html += "<summary>メタデータ</summary>\n"
        html += "<table>\n"
        for item in metadata {
            let escapedKey = escapeHTMLString(item.key)
            let escapedValue = escapeHTMLString(item.value)
            // Render comma-separated values as tags
            if item.value.contains(",") {
                let tags = item.value.components(separatedBy: ",").map { tag in
                    "<span class=\"front-matter-tag\">\(escapeHTMLString(tag.trimmingCharacters(in: .whitespaces)))</span>"
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

    private func escapeHTMLString(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func extractFootnotes(_ markdown: String) -> (String, [FootnoteDefinition]) {
        var lines = markdown.components(separatedBy: "\n")
        var definitions: [FootnoteDefinition] = []
        var definitionIds: [String] = []

        // Extract footnote definitions: [^id]: text
        let defPattern = try! NSRegularExpression(pattern: #"^\[\^([^\]]+)\]:\s+(.+)$"#, options: .anchorsMatchLines)
        var indicesToRemove: [Int] = []

        for (i, line) in lines.enumerated() {
            let range = NSRange(line.startIndex..., in: line)
            if let match = defPattern.firstMatch(in: line, range: range) {
                let id = String(line[Range(match.range(at: 1), in: line)!])
                let text = String(line[Range(match.range(at: 2), in: line)!])
                if !definitionIds.contains(id) {
                    definitions.append(FootnoteDefinition(id: id, text: text))
                    definitionIds.append(id)
                }
                indicesToRemove.append(i)
            }
        }

        for i in indicesToRemove.reversed() {
            lines.remove(at: i)
        }

        // Replace footnote references [^id] with placeholders
        var processed = lines.joined(separator: "\n")
        let refPattern = try! NSRegularExpression(pattern: #"\[\^([^\]]+)\]"#)
        let mutableString = NSMutableString(string: processed)
        let fullRange = NSRange(location: 0, length: mutableString.length)
        refPattern.replaceMatches(in: mutableString, range: fullRange, withTemplate: "FNREF_$1_FNREF")
        processed = mutableString as String

        return (processed, definitions)
    }

    private func renderFootnoteSection(_ footnotes: [FootnoteDefinition]) -> String {
        var html = "<section class=\"footnotes\">\n<ol>\n"
        for footnote in footnotes {
            let text = footnote.text
            html += "<li id=\"fn-\(footnote.id)\">\(text)<a href=\"#fnref-\(footnote.id)\" class=\"footnote-backref\">↩</a></li>\n"
        }
        html += "</ol>\n</section>\n"
        return html
    }

    private func generateNestedTOC(_ headings: [HeadingInfo]) -> String {
        var html = "<nav class=\"toc-sidebar\">\n<div class=\"toc-title\">目次</div>\n"
        var currentLevel = 0

        for heading in headings {
            if heading.level > currentLevel {
                for _ in currentLevel..<heading.level {
                    html += "<ul>\n"
                }
            } else if heading.level < currentLevel {
                for _ in heading.level..<currentLevel {
                    html += "</li>\n</ul>\n"
                }
                html += "</li>\n"
            } else if currentLevel > 0 {
                html += "</li>\n"
            }
            html += "<li><a href=\"#\(heading.id)\">\(heading.text)</a>\n"
            currentLevel = heading.level
        }

        for _ in 0..<currentLevel {
            html += "</li>\n</ul>\n"
        }

        html += "</nav>\n"
        return html
    }
    private func detectHeadingLevelWarnings(_ headings: [HeadingInfo]) -> [String] {
        var warnings: [String] = []
        var prevLevel = 0
        for heading in headings {
            if prevLevel > 0 && heading.level > prevLevel + 1 {
                warnings.append("「\(heading.text)」(h\(heading.level)) が h\(prevLevel) の後にあります（h\(prevLevel + 1) がスキップされています）")
            }
            prevLevel = heading.level
        }
        return warnings
    }

    private func convertCallouts(_ html: String) -> String {
        // Match <blockquote> containing [!TYPE] or [!TYPE]- pattern
        // The HTML from MarkupWalker looks like:
        // <blockquote>\n<p>[!NOTE]\nBody text</p>\n</blockquote>
        // or with collapsible: <p>[!NOTE]-\nBody text</p>
        let pattern = #"<blockquote>\s*<p>\[!(NOTE|TIP|WARNING|IMPORTANT|CAUTION)\](-)?(?:<br>)?\s*\n?([\s\S]*?)</p>([\s\S]*?)</blockquote>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return html
        }

        let calloutIcons: [String: String] = [
            "NOTE": "\u{2139}\u{FE0F}",       // info
            "TIP": "\u{1F4A1}",                // lightbulb
            "WARNING": "\u{26A0}\u{FE0F}",     // warning
            "IMPORTANT": "\u{2757}",           // exclamation
            "CAUTION": "\u{1F525}"             // flame
        ]

        let calloutLabels: [String: String] = [
            "NOTE": "Note",
            "TIP": "Tip",
            "WARNING": "Warning",
            "IMPORTANT": "Important",
            "CAUTION": "Caution"
        ]

        let mutableHTML = NSMutableString(string: html)
        let fullRange = NSRange(location: 0, length: mutableHTML.length)
        let matches = regex.matches(in: html, range: fullRange)

        // Process matches in reverse to preserve ranges
        for match in matches.reversed() {
            let typeRange = match.range(at: 1)
            let collapseRange = match.range(at: 2)
            let firstParaRange = match.range(at: 3)
            let restRange = match.range(at: 4)

            let type = (html as NSString).substring(with: typeRange)
            let isCollapsible = collapseRange.location != NSNotFound
            let firstPara = (html as NSString).substring(with: firstParaRange).trimmingCharacters(in: .whitespacesAndNewlines)
            let rest = (html as NSString).substring(with: restRange).trimmingCharacters(in: .whitespacesAndNewlines)

            let typeLower = type.lowercased()
            let icon = calloutIcons[type] ?? ""
            let label = calloutLabels[type] ?? type

            var body = ""
            if !firstPara.isEmpty {
                body += "<p>\(firstPara)</p>\n"
            }
            if !rest.isEmpty {
                body += rest
            }

            var replacement: String
            if isCollapsible {
                replacement = """
                <div class="callout callout-\(typeLower) callout-collapsible">
                <details>
                <summary class="callout-title"><span class="callout-icon">\(icon)</span> \(label)</summary>
                <div class="callout-body">
                \(body)
                </div>
                </details>
                </div>
                """
            } else {
                replacement = """
                <div class="callout callout-\(typeLower)">
                <div class="callout-title"><span class="callout-icon">\(icon)</span> \(label)</div>
                <div class="callout-body">
                \(body)
                </div>
                </div>
                """
            }

            mutableHTML.replaceCharacters(in: match.range, with: replacement)
        }

        return mutableHTML as String
    }

    private func renderHeadingWarnings(_ warnings: [String]) -> String {
        var html = "<div class=\"heading-warnings\">"
        html += "<details><summary>見出しレベル警告 (\(warnings.count)件)</summary><ul>"
        for w in warnings {
            html += "<li>\(w)</li>"
        }
        html += "</ul></details></div>\n"
        return html
    }
}

struct ReadingTime {
    let minutes: Int
    let wordCount: Int
    let charCount: Int

    /// 表示文字列。日本語主体なら文字数、英語主体なら単語数を使う。
    var displayText: String {
        let min = max(1, minutes)
        if charCount > wordCount * 3 {
            // 日本語主体
            let formatted = charCount >= 1000
                ? "\(charCount / 1000),\(String(format: "%03d", charCount % 1000))"
                : "\(charCount)"
            return "約\(min)分 · \(formatted)文字"
        } else {
            // 英語主体
            let formatted = wordCount >= 1000
                ? "\(wordCount / 1000),\(String(format: "%03d", wordCount % 1000))"
                : "\(wordCount)"
            return "About \(min) min · \(formatted) words"
        }
    }
}

// MARK: - Reading Time Calculator

enum ReadingTimeCalculator {
    /// Markdown文字列から読了時間を計算する。Front MatterとCode blockを除外。
    nonisolated static func calculate(markdown: String) -> ReadingTime {
        let stripped = stripFrontMatter(markdown)
        let (noCode, codeChars) = stripCodeBlocks(stripped)

        // 通常本文の日本語文字数と英語単語数を計測
        let jaChars = countJapaneseChars(noCode)
        let enWords = countEnglishWords(noCode)

        // コードブロックは1/5の重み（読み飛ばしやすい）
        let codeWordEquivalent = codeChars / 5

        // 読了時間計算（日本語: 550文字/分, 英語: 220語/分）
        let jaMinutes = Double(jaChars) / 550.0
        let enMinutes = Double(enWords + codeWordEquivalent) / 220.0
        let totalMinutes = Int((jaMinutes + enMinutes).rounded(.up))

        return ReadingTime(
            minutes: max(1, totalMinutes),
            wordCount: enWords,
            charCount: jaChars
        )
    }

    nonisolated private static func stripFrontMatter(_ markdown: String) -> String {
        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else { return markdown }
        let lines = markdown.components(separatedBy: "\n")
        guard let first = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }),
              let end = lines[(first + 1)...].firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return markdown
        }
        return lines[(end + 1)...].joined(separator: "\n")
    }

    /// コードブロック（```...```）を除去し、本文とコードの文字数を返す
    nonisolated private static func stripCodeBlocks(_ markdown: String) -> (String, Int) {
        var result = ""
        var codeChars = 0
        var inCode = false
        for line in markdown.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                inCode.toggle()
                continue
            }
            if inCode {
                codeChars += line.count
            } else {
                result += line + "\n"
            }
        }
        return (result, codeChars)
    }

    nonisolated private static func countJapaneseChars(_ text: String) -> Int {
        text.unicodeScalars.filter { scalar in
            // CJK統合漢字、ひらがな、カタカナ、その他CJK
            (0x3040...0x309F).contains(scalar.value) ||   // ひらがな
            (0x30A0...0x30FF).contains(scalar.value) ||   // カタカナ
            (0x4E00...0x9FFF).contains(scalar.value) ||   // CJK統合漢字
            (0x3400...0x4DBF).contains(scalar.value) ||   // CJK拡張A
            (0xF900...0xFAFF).contains(scalar.value)      // CJK互換漢字
        }.count
    }

    nonisolated private static func countEnglishWords(_ text: String) -> Int {
        // 連続するアルファベット文字列を単語として数える
        let pattern = try? NSRegularExpression(pattern: "[a-zA-Z]+")
        let range = NSRange(text.startIndex..., in: text)
        return pattern?.numberOfMatches(in: text, range: range) ?? 0
    }
}

struct FootnoteDefinition {
    let id: String
    let text: String
}

struct HeadingInfo {
    let level: Int
    let text: String
    let id: String
}

struct HTMLGenerator: MarkupWalker {
    let baseURL: URL?
    private(set) var html = ""
    private(set) var headings: [HeadingInfo] = []
    private var listItemPrefix = ""
    private var headingIdCounts: [String: Int] = [:]

    init(baseURL: URL? = nil) {
        self.baseURL = baseURL
    }

    // MARK: - Block elements

    mutating func visitDocument(_ document: Document) -> () {
        descendInto(document)
    }

    mutating func visitHeading(_ heading: Heading) -> () {
        let tag = "h\(heading.level)"
        let plainText = heading.plainText
        var id = generateHeadingId(plainText)

        // Handle duplicate IDs
        if let count = headingIdCounts[id] {
            headingIdCounts[id] = count + 1
            id = "\(id)-\(count)"
        } else {
            headingIdCounts[id] = 1
        }

        headings.append(HeadingInfo(level: heading.level, text: escapeHTML(plainText), id: id))
        html += "<\(tag) id=\"\(id)\">"
        descendInto(heading)
        html += "</\(tag)>\n"
    }

    private func generateHeadingId(_ text: String) -> String {
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

    mutating func visitParagraph(_ paragraph: Paragraph) -> () {
        html += "<p>"
        descendInto(paragraph)
        html += "</p>\n"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> () {
        html += "<blockquote>\n"
        descendInto(blockQuote)
        html += "</blockquote>\n"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> () {
        let lang = codeBlock.language ?? ""
        if lang == "mermaid" {
            html += "<pre class=\"mermaid\">\(codeBlock.code)</pre>\n"
        } else {
            let code = escapeHTML(codeBlock.code)
            if lang.isEmpty {
                html += "<pre><code>\(code)</code></pre>\n"
            } else {
                html += "<pre><code class=\"language-\(lang)\">\(code)</code></pre>\n"
            }
        }
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> () {
        html += "<hr>\n"
    }

    // MARK: - Lists

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> () {
        let hasTaskItems = unorderedList.listItems.contains { $0.checkbox != nil }
        html += hasTaskItems ? "<ul class=\"task-list\">\n" : "<ul>\n"
        descendInto(unorderedList)
        html += "</ul>\n"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> () {
        let hasTaskItems = orderedList.listItems.contains { $0.checkbox != nil }
        html += hasTaskItems ? "<ol class=\"task-list\">\n" : "<ol>\n"
        descendInto(orderedList)
        html += "</ol>\n"
    }

    mutating func visitListItem(_ listItem: ListItem) -> () {
        if let checkbox = listItem.checkbox {
            let checked = checkbox == .checked ? " checked" : ""
            let checkedClass = checkbox == .checked ? " checked" : ""
            let line = listItem.range?.lowerBound.line ?? 0
            html += "<li class=\"task-list-item\(checkedClass)\"><input type=\"checkbox\"\(checked) data-line=\"\(line)\"><span class=\"task-text\">"
            descendInto(listItem)
            html += "</span></li>\n"
        } else {
            html += "<li>"
            descendInto(listItem)
            html += "</li>\n"
        }
    }

    // MARK: - Inline elements

    mutating func visitText(_ text: Text) -> () {
        html += escapeHTML(text.string)
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> () {
        html += "<em>"
        descendInto(emphasis)
        html += "</em>"
    }

    mutating func visitStrong(_ strong: Strong) -> () {
        html += "<strong>"
        descendInto(strong)
        html += "</strong>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> () {
        html += "<code>\(escapeHTML(inlineCode.code))</code>"
    }

    mutating func visitLink(_ link: Markdown.Link) -> () {
        let dest = link.destination ?? ""
        var cssClass = ""

        // Check for broken relative .md links
        if let baseURL = baseURL,
           !dest.isEmpty,
           !dest.hasPrefix("http://"),
           !dest.hasPrefix("https://"),
           !dest.hasPrefix("#"),
           !dest.hasPrefix("mailto:") {
            let cleanDest = dest.components(separatedBy: "#").first ?? dest
            let ext = (cleanDest as NSString).pathExtension.lowercased()
            if ext == "md" || ext == "markdown" {
                let resolved = baseURL.appendingPathComponent(cleanDest).standardized
                if !FileManager.default.fileExists(atPath: resolved.path) {
                    cssClass = " class=\"broken-link\""
                }
            }
        }

        html += "<a href=\"\(dest)\"\(cssClass)>"
        descendInto(link)
        html += "</a>"
    }

    mutating func visitImage(_ image: Markdown.Image) -> () {
        var src = image.source ?? ""
        if let baseURL = baseURL,
           !src.hasPrefix("http://"),
           !src.hasPrefix("https://"),
           !src.hasPrefix("data:") {
            src = baseURL.appendingPathComponent(src).absoluteString
        }
        let alt = image.plainText
        html += "<img src=\"\(src)\" alt=\"\(escapeHTML(alt))\">"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> () {
        html += "<br>\n"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> () {
        html += "\n"
    }

    // MARK: - Table

    mutating func visitTable(_ table: Table) -> () {
        html += "<table>\n"
        descendInto(table)
        html += "</table>\n"
    }

    mutating func visitTableHead(_ tableHead: Table.Head) -> () {
        html += "<thead>\n<tr>\n"
        for cell in tableHead.cells {
            html += "<th>"
            var cellGenerator = HTMLGenerator(baseURL: baseURL)
            cellGenerator.descendInto(cell)
            html += cellGenerator.html
            html += "</th>\n"
        }
        html += "</tr>\n</thead>\n"
    }

    mutating func visitTableBody(_ tableBody: Table.Body) -> () {
        html += "<tbody>\n"
        descendInto(tableBody)
        html += "</tbody>\n"
    }

    mutating func visitTableRow(_ tableRow: Table.Row) -> () {
        html += "<tr>\n"
        for cell in tableRow.cells {
            html += "<td>"
            var cellGenerator = HTMLGenerator(baseURL: baseURL)
            cellGenerator.descendInto(cell)
            html += cellGenerator.html
            html += "</td>\n"
        }
        html += "</tr>\n"
    }

    // MARK: - Helpers

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
