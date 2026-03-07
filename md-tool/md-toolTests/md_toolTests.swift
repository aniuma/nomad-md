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
        #expect(html.contains("<h1>Hello</h1>"))
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
}
