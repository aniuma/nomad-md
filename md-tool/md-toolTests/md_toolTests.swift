//
//  md_toolTests.swift
//  md-toolTests
//
//  Created by Susumu on 2026/03/07.
//

import Testing
import Foundation
@testable import md_tool

// MARK: - FileSystemService Tests

struct FileSystemServiceTests {
    @Test func scanDirectoryFindsMarkdownFiles() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        try "# Hello".write(to: tmpDir.appendingPathComponent("test.md"), atomically: true, encoding: .utf8)
        try "plain text".write(to: tmpDir.appendingPathComponent("readme.txt"), atomically: true, encoding: .utf8)

        let node = FileSystemService.scanDirectory(at: tmpDir)
        #expect(node != nil)
        #expect(node?.children?.count == 1)
        #expect(node?.children?.first?.name == "test.md")
    }

    @Test func scanDirectoryExcludesNodeModules() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let nodeModules = tmpDir.appendingPathComponent("node_modules")
        try FileManager.default.createDirectory(at: nodeModules, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        try "# Hidden".write(to: nodeModules.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try "# Visible".write(to: tmpDir.appendingPathComponent("doc.md"), atomically: true, encoding: .utf8)

        let node = FileSystemService.scanDirectory(at: tmpDir)
        #expect(node != nil)
        #expect(node?.children?.count == 1)
        #expect(node?.children?.first?.name == "doc.md")
    }

    @Test func scanDirectorySortsFoldersFirst() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let subDir = tmpDir.appendingPathComponent("aaa-folder")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        try "# Sub".write(to: subDir.appendingPathComponent("sub.md"), atomically: true, encoding: .utf8)
        try "# Root".write(to: tmpDir.appendingPathComponent("zzz.md"), atomically: true, encoding: .utf8)

        let node = FileSystemService.scanDirectory(at: tmpDir)
        #expect(node?.children?.first?.isDirectory == true)
    }

    @Test func emptyDirectoryReturnsNil() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let node = FileSystemService.scanDirectory(at: tmpDir)
        #expect(node == nil)
    }

    @Test func findFirstMarkdownFile() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        try "# A".write(to: tmpDir.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)

        let node = FileSystemService.scanDirectory(at: tmpDir)!
        let first = FileSystemService.findFirstMarkdownFile(in: node)
        #expect(first?.lastPathComponent == "a.md")
    }
}

// MARK: - MarkdownRenderer Tests

struct MarkdownRendererTests {
    let renderer = MarkdownRenderer()

    @Test func heading() {
        let html = renderer.render("# Hello")
        #expect(html.contains("<h1 id=\"hello\">Hello</h1>"))
    }

    @Test func headingTOC() {
        let html = renderer.render("# Title\n## Section A\n## Section B")
        #expect(html.contains("<nav class=\"toc-sidebar\">"))
        #expect(html.contains("href=\"#title\""))
        #expect(html.contains("href=\"#section-a\""))
        #expect(html.contains("href=\"#section-b\""))
    }

    @Test func headingTOCNested() {
        let html = renderer.render("# Top\n## Sub\n### Deep")
        // Nested ul structure
        #expect(html.contains("<ul>\n<li><a href=\"#top\">"))
        #expect(html.contains("<ul>\n<li><a href=\"#sub\">"))
        #expect(html.contains("<ul>\n<li><a href=\"#deep\">"))
    }

    @Test func headingDuplicateIds() {
        let html = renderer.render("## Foo\n## Foo\n## Foo")
        #expect(html.contains("id=\"foo\""))
        #expect(html.contains("id=\"foo-1\""))
        #expect(html.contains("id=\"foo-2\""))
    }

    @Test func paragraph() {
        let html = renderer.render("Some text")
        #expect(html.contains("<p>Some text</p>"))
    }

    @Test func bold() {
        let html = renderer.render("**bold**")
        #expect(html.contains("<strong>bold</strong>"))
    }

    @Test func italic() {
        let html = renderer.render("*italic*")
        #expect(html.contains("<em>italic</em>"))
    }

    @Test func inlineCode() {
        let html = renderer.render("`code`")
        #expect(html.contains("<code>code</code>"))
    }

    @Test func codeBlock() {
        let html = renderer.render("```swift\nlet x = 1\n```")
        #expect(html.contains("<pre><code class=\"language-swift\">"))
        #expect(html.contains("let x = 1"))
    }

    @Test func link() {
        let html = renderer.render("[Link](https://example.com)")
        #expect(html.contains("<a href=\"https://example.com\">Link</a>"))
    }

    @Test func image() {
        let html = renderer.render("![alt](image.png)")
        #expect(html.contains("<img src=\"image.png\" alt=\"alt\">"))
    }

    @Test func imageWithBaseURL() {
        let r = MarkdownRenderer(baseURL: URL(fileURLWithPath: "/Users/test/docs"))
        let html = r.render("![alt](image.png)")
        #expect(html.contains("file:///Users/test/docs/image.png"))
    }

    @Test func unorderedList() {
        let html = renderer.render("- item1\n- item2")
        #expect(html.contains("<ul>"))
        #expect(html.contains("<li>"))
    }

    @Test func orderedList() {
        let html = renderer.render("1. first\n2. second")
        #expect(html.contains("<ol>"))
    }

    @Test func blockquote() {
        let html = renderer.render("> quote")
        #expect(html.contains("<blockquote>"))
    }

    @Test func horizontalRule() {
        let html = renderer.render("---")
        #expect(html.contains("<hr>"))
    }

    @Test func table() {
        let md = "| A | B |\n|---|---|\n| 1 | 2 |"
        let html = renderer.render(md)
        #expect(html.contains("<table>"))
        #expect(html.contains("<th>"))
        #expect(html.contains("<td>"))
    }

    @Test func checkbox() {
        let html = renderer.render("- [x] done\n- [ ] todo")
        #expect(html.contains("checked"))
        #expect(html.contains("checkbox"))
    }

    @Test func htmlEscaping() {
        let html = renderer.render("Use `<div>` tag")
        #expect(html.contains("&lt;div&gt;"))
    }

    // MARK: - Callout / Admonition

    @Test func calloutNote() {
        let html = renderer.render("> [!NOTE]\n> This is a note.")
        #expect(html.contains("callout callout-note"))
        #expect(html.contains("callout-title"))
        #expect(html.contains("Note"))
        #expect(html.contains("This is a note."))
        #expect(!html.contains("<blockquote>"))
    }

    @Test func calloutTip() {
        let html = renderer.render("> [!TIP]\n> Helpful tip here.")
        #expect(html.contains("callout-tip"))
        #expect(html.contains("Tip"))
    }

    @Test func calloutWarning() {
        let html = renderer.render("> [!WARNING]\n> Be careful.")
        #expect(html.contains("callout-warning"))
        #expect(html.contains("Warning"))
    }

    @Test func calloutImportant() {
        let html = renderer.render("> [!IMPORTANT]\n> Critical info.")
        #expect(html.contains("callout-important"))
        #expect(html.contains("Important"))
    }

    @Test func calloutCaution() {
        let html = renderer.render("> [!CAUTION]\n> Danger zone.")
        #expect(html.contains("callout-caution"))
        #expect(html.contains("Caution"))
    }

    @Test func calloutCollapsible() {
        let html = renderer.render("> [!NOTE]-\n> Collapsed content.")
        #expect(html.contains("callout-collapsible"))
        #expect(html.contains("<details>"))
        #expect(html.contains("<summary"))
        #expect(html.contains("Collapsed content."))
    }

    @Test func regularBlockquoteUnchanged() {
        let html = renderer.render("> Regular quote text")
        #expect(html.contains("<blockquote>"), "HTML should contain blockquote: \(html)")
        #expect(!html.contains("<div class=\"callout"), "HTML should not contain callout div: \(html)")
    }
}
