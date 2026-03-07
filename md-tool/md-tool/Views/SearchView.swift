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

    var body: some View {
        VStack(spacing: 0) {
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
            }
            .padding(12)

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
                        SearchResultRow(result: result, query: query, isSelected: index == selectedIndex)
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
        .onChange(of: query) { _, newValue in
            selectedIndex = 0
            searchTask?.cancel()
            let q = newValue
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
    }

    private func selectCurrent() {
        guard !results.isEmpty, selectedIndex < results.count else { return }
        onSelect(results[selectedIndex].url)
        onDismiss()
    }

    private func performSearch(query: String) async {
        isSearching = true
        let q = query.lowercased()
        var found: [SearchResult] = []
        let maxResults = 100

        for fileURL in files {
            if Task.isCancelled { break }
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            let lines = content.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                if line.lowercased().contains(q) {
                    found.append(SearchResult(url: fileURL, lineNumber: index + 1, lineContent: line))
                    if found.count >= maxResults { break }
                }
            }
            if found.count >= maxResults { break }
        }

        if !Task.isCancelled {
            results = found
            isSearching = false
        }
    }
}

private struct SearchResultRow: View {
    let result: SearchResult
    let query: String
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)
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
        let lowered = content.lowercased()
        let q = query.lowercased()
        var searchStart = lowered.startIndex
        while let range = lowered.range(of: q, range: searchStart..<lowered.endIndex) {
            let attrStart = attributed.index(attributed.startIndex, offsetByCharacters: lowered.distance(from: lowered.startIndex, to: range.lowerBound))
            let attrEnd = attributed.index(attrStart, offsetByCharacters: q.count)
            attributed[attrStart..<attrEnd].foregroundColor = .accentColor
            attributed[attrStart..<attrEnd].font = .system(size: 12, weight: .bold, design: .monospaced)
            searchStart = range.upperBound
        }
        return attributed
    }
}
