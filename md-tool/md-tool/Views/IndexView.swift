import SwiftUI

struct IndexEntry: Identifiable {
    let id = UUID()
    let url: URL
    let heading: String
    let level: Int
}

struct IndexView: View {
    let files: [URL]
    let onSelect: (URL) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var entries: [IndexEntry] = []
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    private var filteredEntries: [IndexEntry] {
        if query.isEmpty { return entries }
        let q = query.lowercased()
        return entries.filter {
            $0.heading.lowercased().contains(q) ||
            $0.url.lastPathComponent.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "list.bullet.indent")
                    .foregroundStyle(.secondary)
                TextField("索引を検索...", text: $query)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit { selectCurrent() }
                Text("\(filteredEntries.count)件")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)

            Divider()

            if filteredEntries.isEmpty {
                Text("見出しが見つかりません")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ScrollViewReader { proxy in
                    List(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
                        IndexRow(entry: entry, isSelected: index == selectedIndex)
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(entry.url)
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
        .frame(width: 550)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .onAppear {
            isSearchFocused = true
            buildIndex()
        }
        .onChange(of: query) { _, _ in
            selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 { selectedIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredEntries.count - 1 { selectedIndex += 1 }
            return .handled
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }

    private func selectCurrent() {
        guard !filteredEntries.isEmpty, selectedIndex < filteredEntries.count else { return }
        onSelect(filteredEntries[selectedIndex].url)
        onDismiss()
    }

    private func buildIndex() {
        let headingPattern = try! NSRegularExpression(pattern: #"^(#{1,6})\s+(.+)$"#, options: .anchorsMatchLines)
        var result: [IndexEntry] = []
        for url in files.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let range = NSRange(content.startIndex..., in: content)
            for match in headingPattern.matches(in: content, range: range) {
                let level = Range(match.range(at: 1), in: content).map { content[$0].count } ?? 1
                let text = Range(match.range(at: 2), in: content).map { String(content[$0]) } ?? ""
                result.append(IndexEntry(url: url, heading: text, level: level))
            }
        }
        entries = result
    }
}

private struct IndexRow: View {
    let entry: IndexEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text("H\(entry.level)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(NomadColors.sandGold)
                .frame(width: 24)
            Text(entry.heading)
                .font(.system(size: 13))
                .lineLimit(1)
            Spacer()
            Text(entry.url.lastPathComponent)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .padding(.leading, CGFloat((entry.level - 1) * 12))
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
    }
}
