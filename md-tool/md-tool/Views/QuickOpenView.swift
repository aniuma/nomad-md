import SwiftUI

struct QuickOpenItem: Identifiable {
    let id = UUID()
    let url: URL
    let heading: String?  // nil = file item, non-nil = heading item
    let headingLevel: Int?
}

struct QuickOpenView: View {
    let files: [URL]
    let onSelect: (URL) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var selectedIndex = 0
    @State private var searchHeadings = false
    @FocusState private var isSearchFocused: Bool

    private var filteredItems: [QuickOpenItem] {
        if query.isEmpty && !searchHeadings {
            return files.map { QuickOpenItem(url: $0, heading: nil, headingLevel: nil) }
        }
        let q = query.lowercased()

        if searchHeadings || query.hasPrefix("#") {
            let headingQuery = query.hasPrefix("#") ? String(query.dropFirst()).trimmingCharacters(in: .whitespaces).lowercased() : q
            return collectHeadings().filter { item in
                headingQuery.isEmpty || (item.heading?.lowercased().contains(headingQuery) ?? false)
            }
        }

        return files
            .filter { $0.lastPathComponent.lowercased().contains(q) }
            .map { QuickOpenItem(url: $0, heading: nil, headingLevel: nil) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(searchHeadings ? "見出しを検索... (# prefix)" : "ファイル名を検索... (# で見出し検索)", text: $query)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit {
                        selectCurrent()
                    }
                Button {
                    searchHeadings.toggle()
                } label: {
                    Image(systemName: searchHeadings ? "number.circle.fill" : "number.circle")
                        .foregroundStyle(searchHeadings ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .help("見出し検索モード切替")
            }
            .padding(12)

            Divider()

            if filteredItems.isEmpty {
                Text("一致する項目がありません")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ScrollViewReader { proxy in
                    List(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                        QuickOpenRow(item: item, isSelected: index == selectedIndex)
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(item.url)
                                onDismiss()
                            }
                    }
                    .listStyle(.plain)
                    .onChange(of: selectedIndex) { _, newValue in
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .frame(width: 500)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .onAppear {
            isSearchFocused = true
            selectedIndex = 0
        }
        .onChange(of: query) { _, newValue in
            selectedIndex = 0
            if newValue.hasPrefix("#") {
                searchHeadings = true
            }
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 { selectedIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredItems.count - 1 { selectedIndex += 1 }
            return .handled
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }

    private func selectCurrent() {
        guard !filteredItems.isEmpty, selectedIndex < filteredItems.count else { return }
        onSelect(filteredItems[selectedIndex].url)
        onDismiss()
    }

    private func collectHeadings() -> [QuickOpenItem] {
        let headingPattern = try! NSRegularExpression(pattern: #"^(#{1,6})\s+(.+)$"#, options: .anchorsMatchLines)
        var items: [QuickOpenItem] = []
        for url in files {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let range = NSRange(content.startIndex..., in: content)
            for match in headingPattern.matches(in: content, range: range) {
                let level = Range(match.range(at: 1), in: content).map { content[$0].count } ?? 1
                let text = Range(match.range(at: 2), in: content).map { String(content[$0]) } ?? ""
                items.append(QuickOpenItem(url: url, heading: text, headingLevel: level))
            }
        }
        return items
    }
}

private struct QuickOpenRow: View {
    let item: QuickOpenItem
    let isSelected: Bool

    var body: some View {
        HStack {
            if let heading = item.heading {
                Image(systemName: "number")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(String(repeating: "#", count: item.headingLevel ?? 1))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        Text(heading)
                            .font(.system(size: 13))
                            .lineLimit(1)
                    }
                    Text(item.url.lastPathComponent)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            } else {
                Image(systemName: "text.page")
                    .foregroundStyle(NomadColors.sandGold.opacity(0.7))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.url.lastPathComponent)
                        .font(.system(size: 13))
                        .lineLimit(1)
                    Text(item.url.deletingLastPathComponent().path)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
    }
}
