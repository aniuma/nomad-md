import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct EditorView: NSViewRepresentable {
    @Binding var text: String
    var fileURL: URL?
    var onTextChange: (String) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.usesFindPanel = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .textColor

        textView.textContainerInset = NSSize(width: 40, height: 32)
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        // 画像ドロップ対応
        textView.registerForDraggedTypes([.fileURL])

        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        context.coordinator.fileURL = fileURL
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            context.coordinator.applyHighlighting(textView)
            textView.selectedRanges = selectedRanges
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTextChange: onTextChange)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var onTextChange: (String) -> Void
        weak var textView: NSTextView?
        var fileURL: URL?

        private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "tiff", "tif", "ico"]

        init(onTextChange: @escaping (String) -> Void) {
            self.onTextChange = onTextChange
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            applyHighlighting(textView)
            onTextChange(textView.string)
        }

        // MARK: - List Continuation

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard let replacement = replacementString, replacement == "\n" else { return true }
            let text = textView.string as NSString
            let lineRange = text.lineRange(for: NSRange(location: affectedCharRange.location, length: 0))
            let currentLine = text.substring(with: lineRange).trimmingCharacters(in: .newlines)

            // マッチするリストパターン
            let patterns: [(regex: String, builder: (NSTextCheckingResult, String) -> String?)] = [
                // チェックリスト: - [ ] or - [x]
                (#"^(\s*)- \[[ x]\] (.+)$"#, { match, line in
                    let indent = Range(match.range(at: 1), in: line).map { String(line[$0]) } ?? ""
                    return "\(indent)- [ ] "
                }),
                // 順序なしリスト: - or * or +
                (#"^(\s*)([-*+]) (.+)$"#, { match, line in
                    let indent = Range(match.range(at: 1), in: line).map { String(line[$0]) } ?? ""
                    let marker = Range(match.range(at: 2), in: line).map { String(line[$0]) } ?? "-"
                    return "\(indent)\(marker) "
                }),
                // 順序付きリスト: 1. 2. etc
                (#"^(\s*)(\d+)\. (.+)$"#, { match, line in
                    let indent = Range(match.range(at: 1), in: line).map { String(line[$0]) } ?? ""
                    let num = Range(match.range(at: 2), in: line).flatMap { Int(line[$0]) } ?? 0
                    return "\(indent)\(num + 1). "
                }),
            ]

            // 空のリスト項目（マーカーだけ）→ リストを終了
            let emptyPatterns = [
                #"^\s*[-*+] \[[ x]\]\s*$"#,
                #"^\s*[-*+]\s*$"#,
                #"^\s*\d+\.\s*$"#,
            ]
            for pattern in emptyPatterns {
                if currentLine.range(of: pattern, options: .regularExpression) != nil {
                    // 現在行を空行に置き換え
                    textView.insertText("\n", replacementRange: NSRange(location: lineRange.location, length: lineRange.length))
                    return false
                }
            }

            for (pattern, builder) in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let match = regex.firstMatch(in: currentLine, range: NSRange(currentLine.startIndex..., in: currentLine)),
                      let prefix = builder(match, currentLine) else { continue }
                textView.insertText("\n\(prefix)", replacementRange: affectedCharRange)
                return false
            }

            return true
        }

        // MARK: - Drag & Drop

        func textView(_ view: NSTextView, draggingEntered info: any NSDraggingInfo) -> NSDragOperation {
            guard hasImageFiles(in: info) else { return [] }
            return .copy
        }

        func textView(_ view: NSTextView, performDragOperation info: any NSDraggingInfo) -> Bool {
            guard let fileURL = fileURL else { return false }
            let baseDir = fileURL.deletingLastPathComponent()

            guard let items = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
                .urlReadingFileURLsOnly: true
            ]) as? [URL] else { return false }

            let imageURLs = items.filter { Self.imageExtensions.contains($0.pathExtension.lowercased()) }
            guard !imageURLs.isEmpty else { return false }

            var markdownSnippets: [String] = []

            for imageURL in imageURLs {
                let fileName = imageURL.lastPathComponent
                let destURL = uniqueURL(for: fileName, in: baseDir)

                do {
                    try FileManager.default.copyItem(at: imageURL, to: destURL)
                    let relativePath = destURL.lastPathComponent
                    markdownSnippets.append("![\(destURL.deletingPathExtension().lastPathComponent)](\(relativePath))")
                } catch {
                    print("Image copy failed: \(error)")
                }
            }

            guard !markdownSnippets.isEmpty else { return false }

            let insertion = markdownSnippets.joined(separator: "\n") + "\n"
            view.insertText(insertion, replacementRange: view.selectedRange())

            return true
        }

        private func hasImageFiles(in info: NSDraggingInfo) -> Bool {
            guard let items = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
                .urlReadingFileURLsOnly: true
            ]) as? [URL] else { return false }
            return items.contains { Self.imageExtensions.contains($0.pathExtension.lowercased()) }
        }

        private func uniqueURL(for fileName: String, in directory: URL) -> URL {
            var destURL = directory.appendingPathComponent(fileName)
            guard FileManager.default.fileExists(atPath: destURL.path) else { return destURL }

            let name = destURL.deletingPathExtension().lastPathComponent
            let ext = destURL.pathExtension
            var counter = 1
            repeat {
                destURL = directory.appendingPathComponent("\(name)-\(counter).\(ext)")
                counter += 1
            } while FileManager.default.fileExists(atPath: destURL.path)
            return destURL
        }

        // MARK: - Syntax Highlighting

        func applyHighlighting(_ textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: textStorage.length)
            let text = textStorage.string

            let baseFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            let boldFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

            textStorage.beginEditing()

            // Reset to base style
            textStorage.setAttributes([
                .font: baseFont,
                .foregroundColor: NSColor.textColor,
            ], range: fullRange)

            let rules: [(pattern: String, color: NSColor, font: NSFont?, options: NSRegularExpression.Options)] = [
                // Headings (full line)
                ("^#{1,6}\\s+.*$", isDark ? NSColor(red: 0.55, green: 0.75, blue: 1.0, alpha: 1.0) : NSColor(red: 0.0, green: 0.35, blue: 0.75, alpha: 1.0), boldFont, .anchorsMatchLines),
                // Bold
                ("\\*\\*[^*]+\\*\\*|__[^_]+__", NSColor.textColor, boldFont, []),
                // Inline code
                ("`[^`\n]+`", isDark ? NSColor(red: 0.85, green: 0.6, blue: 0.4, alpha: 1.0) : NSColor(red: 0.6, green: 0.3, blue: 0.1, alpha: 1.0), nil, []),
                // Code fence markers
                ("^```.*$", isDark ? NSColor(red: 0.85, green: 0.6, blue: 0.4, alpha: 1.0) : NSColor(red: 0.6, green: 0.3, blue: 0.1, alpha: 1.0), nil, .anchorsMatchLines),
                // Links
                ("\\[([^\\]]+)\\]\\(([^)]+)\\)", isDark ? NSColor(red: 0.35, green: 0.65, blue: 1.0, alpha: 1.0) : NSColor(red: 0.05, green: 0.4, blue: 0.85, alpha: 1.0), nil, []),
                // Blockquotes
                ("^>\\s+.*$", isDark ? NSColor(red: 0.65, green: 0.65, blue: 0.7, alpha: 1.0) : NSColor(red: 0.4, green: 0.43, blue: 0.46, alpha: 1.0), nil, .anchorsMatchLines),
                // List markers
                ("^\\s*[-*+]\\s|^\\s*\\d+\\.\\s", isDark ? NSColor(red: 0.7, green: 0.75, blue: 0.55, alpha: 1.0) : NSColor(red: 0.35, green: 0.5, blue: 0.2, alpha: 1.0), nil, .anchorsMatchLines),
                // Horizontal rules
                ("^(---|\\*\\*\\*|___)\\s*$", NSColor.tertiaryLabelColor, nil, .anchorsMatchLines),
            ]

            for rule in rules {
                guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: rule.options) else { continue }
                regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                    guard let matchRange = match?.range else { return }
                    textStorage.addAttribute(.foregroundColor, value: rule.color, range: matchRange)
                    if let font = rule.font {
                        textStorage.addAttribute(.font, value: font, range: matchRange)
                    }
                }
            }

            textStorage.endEditing()
        }
    }
}
