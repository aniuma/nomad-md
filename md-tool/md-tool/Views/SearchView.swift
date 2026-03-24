import SwiftUI

struct SearchResult: Identifiable {
    let id = UUID()
    let url: URL
    let lineNumber: Int
    let lineContent: String
}

struct SearchView: View {
    let files: [URL]
    let onSelect: (URL) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var selectedIndex = 0
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool

    // 検索オプション
    @State private var useRegex = false
    @State private var caseSensitive = false
    @State private var regexError: String?

    // 置換
    @State private var showReplace = false
    @State private var replacementText = ""
    @State private var showReplaceAllConfirm = false
    @State private var replaceMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // 検索バー
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("全文検索...", text: $query)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit { selectCurrent() }
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                }

                // 正規表現トグル
                Button {
                    useRegex.toggle()
                    triggerSearch()
                } label: {
                    Text(".*")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(useRegex ? Color.accentColor : Color.secondary)
                        .frame(width: 24, height: 20)
                        .background(useRegex ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("正規表現")

                // 大文字小文字区別トグル
                Button {
                    caseSensitive.toggle()
                    triggerSearch()
                } label: {
                    Text("Aa")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(caseSensitive ? Color.accentColor : Color.secondary)
                        .frame(width: 24, height: 20)
                        .background(caseSensitive ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("大文字/小文字を区別")

                // 置換トグル
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showReplace.toggle()
                    }
                } label: {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.system(size: 12))
                        .foregroundStyle(showReplace ? Color.accentColor : Color.secondary)
                        .frame(width: 24, height: 20)
                        .background(showReplace ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("置換")
            }
            .padding(12)

            // 正規表現エラー表示
            if let regexError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(NomadColors.error)
                    Text(regexError)
                        .font(.system(size: 11))
                        .foregroundStyle(NomadColors.error)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }

            // 置換バー
            if showReplace {
                HStack {
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11))
                    TextField("置換テキスト...", text: $replacementText)
                        .textFieldStyle(.plain)
                    Button {
                        replaceOne()
                    } label: {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 12))
                            .help("選択中の1件を置換")
                    }
                    .buttonStyle(.plain)
                    .disabled(results.isEmpty || query.isEmpty)

                    Button {
                        showReplaceAllConfirm = true
                    } label: {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 12))
                            .overlay(alignment: .bottomTrailing) {
                                Text("all")
                                    .font(.system(size: 6, weight: .bold))
                                    .offset(x: 2, y: 2)
                            }
                            .help("すべて置換")
                    }
                    .buttonStyle(.plain)
                    .disabled(results.isEmpty || query.isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            // 置換メッセージ
            if let replaceMessage {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(NomadColors.success)
                    Text(replaceMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }

            Divider()

            if query.isEmpty {
                Text("検索キーワードを入力してください")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if results.isEmpty && !isSearching {
                Text("一致する結果がありません")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ScrollViewReader { proxy in
                    List(Array(results.enumerated()), id: \.element.id) { index, result in
                        SearchResultRow(result: result, query: query, useRegex: useRegex, caseSensitive: caseSensitive, isSelected: index == selectedIndex)
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(result.url)
                                onDismiss()
                            }
                    }
                    .listStyle(.plain)
                    .onChange(of: selectedIndex) { _, newValue in
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
                .frame(maxHeight: 400)
            }
        }
        .frame(width: 600)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .onAppear {
            isSearchFocused = true
        }
        .onChange(of: query) { _, _ in
            triggerSearch()
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 { selectedIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < results.count - 1 { selectedIndex += 1 }
            return .handled
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
        .alert("すべて置換", isPresented: $showReplaceAllConfirm) {
            Button("すべて置換", role: .destructive) { replaceAll() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(results.count)件の一致箇所をすべて置換しますか？この操作は取り消せません。")
        }
    }

    // MARK: - 検索

    private func triggerSearch() {
        selectedIndex = 0
        regexError = nil
        replaceMessage = nil
        searchTask?.cancel()
        let q = query
        guard !q.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await performSearch(query: q)
        }
    }

    private func selectCurrent() {
        guard !results.isEmpty, selectedIndex < results.count else { return }
        onSelect(results[selectedIndex].url)
        onDismiss()
    }

    private func performSearch(query: String) async {
        isSearching = true
        regexError = nil
        var found: [SearchResult] = []
        let maxResults = 100

        if useRegex {
            // 正規表現検索
            var options: NSRegularExpression.Options = []
            if !caseSensitive {
                options.insert(.caseInsensitive)
            }
            let regex: NSRegularExpression
            do {
                regex = try NSRegularExpression(pattern: query, options: options)
            } catch {
                if !Task.isCancelled {
                    regexError = "無効な正規表現: \(error.localizedDescription)"
                    results = []
                    isSearching = false
                }
                return
            }

            for fileURL in files {
                if Task.isCancelled { break }
                guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
                let lines = content.components(separatedBy: .newlines)
                for (index, line) in lines.enumerated() {
                    let range = NSRange(line.startIndex..<line.endIndex, in: line)
                    if regex.firstMatch(in: line, range: range) != nil {
                        found.append(SearchResult(url: fileURL, lineNumber: index + 1, lineContent: line))
                        if found.count >= maxResults { break }
                    }
                }
                if found.count >= maxResults { break }
            }
        } else {
            // 通常検索
            for fileURL in files {
                if Task.isCancelled { break }
                guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
                let lines = content.components(separatedBy: .newlines)
                for (index, line) in lines.enumerated() {
                    let matches: Bool
                    if caseSensitive {
                        matches = line.contains(query)
                    } else {
                        matches = line.lowercased().contains(query.lowercased())
                    }
                    if matches {
                        found.append(SearchResult(url: fileURL, lineNumber: index + 1, lineContent: line))
                        if found.count >= maxResults { break }
                    }
                }
                if found.count >= maxResults { break }
            }
        }

        if !Task.isCancelled {
            results = found
            isSearching = false
        }
    }

    // MARK: - 置換

    private func replaceOne() {
        guard !results.isEmpty, selectedIndex < results.count else { return }
        let result = results[selectedIndex]
        guard let content = try? String(contentsOf: result.url, encoding: .utf8) else { return }

        var lines = content.components(separatedBy: .newlines)
        let lineIndex = result.lineNumber - 1
        guard lineIndex >= 0, lineIndex < lines.count else { return }

        let originalLine = lines[lineIndex]
        let replacedLine = replaceLine(originalLine, query: query, replacement: replacementText)

        if replacedLine != originalLine {
            lines[lineIndex] = replacedLine
            let newContent = lines.joined(separator: "\n")
            do {
                try newContent.write(to: result.url, atomically: true, encoding: .utf8)
                replaceMessage = "1件置換しました"
                NotificationCenter.default.post(name: .init("FileContentChanged"), object: result.url)
                triggerSearch()
            } catch {
                replaceMessage = "置換エラー: \(error.localizedDescription)"
            }
        }
    }

    private func replaceAll() {
        let totalCount = results.count
        // ファイルごとにグループ化して一括処理
        var fileResults: [URL: [SearchResult]] = [:]
        for result in results {
            fileResults[result.url, default: []].append(result)
        }

        var replacedCount = 0
        for (fileURL, _) in fileResults {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }

            let newContent: String
            if useRegex {
                var options: NSRegularExpression.Options = []
                if !caseSensitive { options.insert(.caseInsensitive) }
                guard let regex = try? NSRegularExpression(pattern: query, options: options) else { continue }

                let mutableContent = NSMutableString(string: content)

                // 正規表現置換（$1等のキャプチャグループ対応）
                let template = replacementText
                let count = regex.replaceMatches(in: mutableContent, range: NSRange(location: 0, length: mutableContent.length), withTemplate: template)
                replacedCount += count
                newContent = mutableContent as String
            } else {
                // 通常置換
                if caseSensitive {
                    newContent = content.replacingOccurrences(of: query, with: replacementText)
                } else {
                    // 大小文字無視で置換
                    newContent = content.replacingOccurrences(of: query, with: replacementText, options: .caseInsensitive)
                }
                // 変更があった場合のみカウント
                if newContent != content {
                    replacedCount += 1
                }
            }

            if newContent != content {
                do {
                    try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
                    NotificationCenter.default.post(name: .init("FileContentChanged"), object: fileURL)
                } catch {
                    replaceMessage = "置換エラー: \(error.localizedDescription)"
                    return
                }
            }
        }

        replaceMessage = "\(totalCount)件(\(fileResults.count)ファイル)を置換しました"
        triggerSearch()
    }

    private func replaceLine(_ line: String, query: String, replacement: String) -> String {
        if useRegex {
            var options: NSRegularExpression.Options = []
            if !caseSensitive { options.insert(.caseInsensitive) }
            guard let regex = try? NSRegularExpression(pattern: query, options: options) else { return line }
            let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
            // 最初の1マッチのみ置換
            guard let match = regex.firstMatch(in: line, range: nsRange) else { return line }
            let matchRange = match.range
            let replacementResult = regex.replacementString(for: match, in: line, offset: 0, template: replacement)
            guard let swiftRange = Range(matchRange, in: line) else { return line }
            return line.replacingCharacters(in: swiftRange, with: replacementResult)
        } else {
            if caseSensitive {
                // 最初の1箇所のみ置換
                if let range = line.range(of: query) {
                    return line.replacingCharacters(in: range, with: replacement)
                }
                return line
            } else {
                if let range = line.range(of: query, options: .caseInsensitive) {
                    return line.replacingCharacters(in: range, with: replacement)
                }
                return line
            }
        }
    }
}

private struct SearchResultRow: View {
    let result: SearchResult
    let query: String
    let useRegex: Bool
    let caseSensitive: Bool
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "text.page")
                .foregroundStyle(NomadColors.sandGold.opacity(0.7))
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(result.url.lastPathComponent)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(":\(result.lineNumber)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Text(highlightedText)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                Text(result.url.deletingLastPathComponent().path)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 2)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
    }

    private var highlightedText: AttributedString {
        let content = result.lineContent.trimmingCharacters(in: .whitespaces)
        var attributed = AttributedString(content)

        if useRegex {
            // 正規表現ハイライト
            var options: NSRegularExpression.Options = []
            if !caseSensitive { options.insert(.caseInsensitive) }
            guard let regex = try? NSRegularExpression(pattern: query, options: options) else {
                return attributed
            }
            let nsContent = content as NSString
            let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
            for match in matches.reversed() {
                guard let swiftRange = Range(match.range, in: content) else { continue }
                let startDist = content.distance(from: content.startIndex, to: swiftRange.lowerBound)
                let length = content.distance(from: swiftRange.lowerBound, to: swiftRange.upperBound)
                let attrStart = attributed.index(attributed.startIndex, offsetByCharacters: startDist)
                let attrEnd = attributed.index(attrStart, offsetByCharacters: length)
                attributed[attrStart..<attrEnd].foregroundColor = .accentColor
                attributed[attrStart..<attrEnd].font = .system(size: 12, weight: .bold, design: .monospaced)
            }
        } else {
            // 通常ハイライト
            let searchContent = caseSensitive ? content : content.lowercased()
            let q = caseSensitive ? query : query.lowercased()
            var searchStart = searchContent.startIndex
            while let range = searchContent.range(of: q, range: searchStart..<searchContent.endIndex) {
                let attrStart = attributed.index(attributed.startIndex, offsetByCharacters: searchContent.distance(from: searchContent.startIndex, to: range.lowerBound))
                let attrEnd = attributed.index(attrStart, offsetByCharacters: q.count)
                attributed[attrStart..<attrEnd].foregroundColor = .accentColor
                attributed[attrStart..<attrEnd].font = .system(size: 12, weight: .bold, design: .monospaced)
                searchStart = range.upperBound
            }
        }

        return attributed
    }
}
