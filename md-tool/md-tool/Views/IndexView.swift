import SwiftUI

// MARK: - IndexEntry (見出し単位の表示用)

struct IndexEntry: Identifiable {
    let id = UUID()
    let url: URL
    let heading: String
    let level: Int
}

// MARK: - Display Mode

private enum IndexDisplayMode: String, CaseIterable {
    case all = "全件"
    case byFolder = "フォルダ別"
}

// MARK: - IndexView

struct IndexView: View {
    let files: [URL]
    let rootFolders: [URL]
    let onSelect: (URL) -> Void
    let onDismiss: () -> Void

    @State private var cacheService = IndexCacheService()
    @State private var query = ""
    @State private var displayMode: IndexDisplayMode = .all
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    // 「全件」モード用: 見出しフラット一覧
    private var allEntries: [IndexEntry] {
        cacheService.entries.flatMap { fileEntry in
            let url = URL(fileURLWithPath: fileEntry.path)
            return fileEntry.headings.map { h in
                IndexEntry(url: url, heading: h.text, level: h.level)
            }
        }
    }

    private var filteredEntries: [IndexEntry] {
        if query.isEmpty { return allEntries }
        let q = query.lowercased()
        return allEntries.filter {
            $0.heading.lowercased().contains(q) ||
            $0.url.lastPathComponent.lowercased().contains(q)
        }
    }

    // 「フォルダ別」モード用: フォルダグループ
    private var folderGroups: [(folderName: String, folderPath: String, entries: [IndexFileEntry])] {
        let groups = cacheService.groupedByFolder(rootFolders: rootFolders)
        if query.isEmpty { return groups }
        let q = query.lowercased()
        return groups.compactMap { group in
            let filtered = group.entries.filter { entry in
                let fileName = URL(fileURLWithPath: entry.path).lastPathComponent.lowercased()
                let headingMatch = entry.headings.contains { $0.text.lowercased().contains(q) }
                let summaryMatch = entry.summary.lowercased().contains(q)
                return fileName.contains(q) || headingMatch || summaryMatch
            }
            return filtered.isEmpty ? nil : (group.folderName, group.folderPath, filtered)
        }
    }

    private var totalCount: Int {
        switch displayMode {
        case .all: filteredEntries.count
        case .byFolder: folderGroups.reduce(0) { $0 + $1.entries.count }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            segmentBar
            Divider()
            contentArea
        }
        .frame(width: 580)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .onAppear {
            isSearchFocused = true
            cacheService.loadFromDisk()
            cacheService.updateCache(for: files)
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

    // MARK: - Subviews

    private var headerBar: some View {
        HStack {
            Image(systemName: "list.bullet.indent")
                .foregroundStyle(.secondary)
            TextField("索引を検索...", text: $query)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onSubmit { selectCurrent() }
            if cacheService.isScanning {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            } else {
                Text("\(totalCount)件")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
    }

    private var segmentBar: some View {
        HStack {
            Picker("表示", selection: $displayMode) {
                ForEach(IndexDisplayMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)

            Spacer()

            Button {
                cacheService.updateCache(for: files)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("キャッシュを再スキャン")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var contentArea: some View {
        switch displayMode {
        case .all:
            allEntriesView
        case .byFolder:
            folderGroupsView
        }
    }

    // MARK: - All Entries View

    @ViewBuilder
    private var allEntriesView: some View {
        if filteredEntries.isEmpty {
            emptyView
        } else {
            ScrollViewReader { proxy in
                List(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
                    IndexHeadingRow(entry: entry, isSelected: index == selectedIndex)
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
            .frame(maxHeight: 420)
        }
    }

    // MARK: - Folder Groups View

    @ViewBuilder
    private var folderGroupsView: some View {
        if folderGroups.isEmpty {
            emptyView
        } else {
            List {
                ForEach(folderGroups, id: \.folderPath) { group in
                    Section {
                        ForEach(group.entries) { fileEntry in
                            IndexFileRow(
                                fileEntry: fileEntry,
                                onSelect: { url in
                                    onSelect(url)
                                    onDismiss()
                                }
                            )
                        }
                    } header: {
                        FolderSectionHeader(name: group.folderName)
                    }
                }
            }
            .listStyle(.plain)
            .frame(maxHeight: 460)
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 8) {
            if cacheService.isScanning {
                ProgressView()
                    .scaleEffect(0.8)
                Text("スキャン中...")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                Text("見出しが見つかりません")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80)
    }

    // MARK: - Actions

    private func selectCurrent() {
        guard !filteredEntries.isEmpty, selectedIndex < filteredEntries.count else { return }
        onSelect(filteredEntries[selectedIndex].url)
        onDismiss()
    }
}

// MARK: - IndexHeadingRow (全件モード)

private struct IndexHeadingRow: View {
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

// MARK: - FolderSectionHeader

private struct FolderSectionHeader: View {
    let name: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .font(.system(size: 11))
                .foregroundStyle(NomadColors.sandGold)
            Text(name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - IndexFileRow (フォルダ別モード: ファイル単位)

private struct IndexFileRow: View {
    let fileEntry: IndexFileEntry
    let onSelect: (URL) -> Void

    @State private var isExpanded = false

    private var fileURL: URL { URL(fileURLWithPath: fileEntry.path) }
    private var hasHeadings: Bool { !fileEntry.headings.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ファイル行
            Button {
                onSelect(fileURL)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(fileURL.lastPathComponent)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if !fileEntry.summary.isEmpty {
                            Text(fileEntry.summary)
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    if hasHeadings {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 5)

            // 見出し展開
            if isExpanded && hasHeadings {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(fileEntry.headings.prefix(20).enumerated()), id: \.offset) { _, heading in
                        Button {
                            onSelect(fileURL)
                        } label: {
                            HStack(spacing: 4) {
                                Text("H\(heading.level)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(NomadColors.sandGold.opacity(0.8))
                                    .frame(width: 20)
                                Text(heading.text)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 2)
                        .padding(.leading, CGFloat((heading.level - 1) * 10) + 24)
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .listRowBackground(Color.clear)
    }
}
