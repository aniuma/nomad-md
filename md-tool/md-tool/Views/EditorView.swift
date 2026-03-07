import SwiftUI
import AppKit

struct EditorView: NSViewRepresentable {
    @Binding var text: String
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

        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
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

        init(onTextChange: @escaping (String) -> Void) {
            self.onTextChange = onTextChange
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            applyHighlighting(textView)
            onTextChange(textView.string)
        }

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
