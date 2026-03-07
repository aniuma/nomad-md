import Foundation
import Markdown

struct MarkdownRenderer {
    let baseURL: URL?

    init(baseURL: URL? = nil) {
        self.baseURL = baseURL
    }

    func render(_ markdownString: String) -> String {
        let document = Document(parsing: markdownString)
        var generator = HTMLGenerator(baseURL: baseURL)
        generator.visit(document)

        if generator.headings.isEmpty {
            return generator.html
        }

        return generateNestedTOC(generator.headings) + generator.html
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
        let cleaned = lowered.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == " " || $0 == "-" }
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
        let code = escapeHTML(codeBlock.code)
        if lang.isEmpty {
            html += "<pre><code>\(code)</code></pre>\n"
        } else {
            html += "<pre><code class=\"language-\(lang)\">\(code)</code></pre>\n"
        }
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> () {
        html += "<hr>\n"
    }

    // MARK: - Lists

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> () {
        html += "<ul>\n"
        descendInto(unorderedList)
        html += "</ul>\n"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> () {
        html += "<ol>\n"
        descendInto(orderedList)
        html += "</ol>\n"
    }

    mutating func visitListItem(_ listItem: ListItem) -> () {
        if let checkbox = listItem.checkbox {
            let checked = checkbox == .checked ? " checked disabled" : " disabled"
            html += "<li><input type=\"checkbox\"\(checked)> "
            descendInto(listItem)
            html += "</li>\n"
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
        html += "<a href=\"\(dest)\">"
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
