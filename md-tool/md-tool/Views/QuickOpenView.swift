import SwiftUI

struct QuickOpenView: View {
    let files: [URL]
    let onSelect: (URL) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    private var filteredFiles: [URL] {
        if query.isEmpty { return files }
        let q = query.lowercased()
        return files.filter { $0.lastPathComponent.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("ファイル名を検索...", text: $query)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit {
                        selectCurrent()
                    }
            }
            .padding(12)

            Divider()

            if filteredFiles.isEmpty {
                Text("一致するファイルがありません")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ScrollViewReader { proxy in
                    List(Array(filteredFiles.enumerated()), id: \.element) { index, url in
                        QuickOpenRow(url: url, isSelected: index == selectedIndex)
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(url)
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
        .onChange(of: query) { _, _ in
            selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 { selectedIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredFiles.count - 1 { selectedIndex += 1 }
            return .handled
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }

    private func selectCurrent() {
        guard !filteredFiles.isEmpty, selectedIndex < filteredFiles.count else { return }
        onSelect(filteredFiles[selectedIndex])
        onDismiss()
    }
}

private struct QuickOpenRow: View {
    let url: URL
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Text(url.deletingLastPathComponent().path)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 2)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
    }
}
