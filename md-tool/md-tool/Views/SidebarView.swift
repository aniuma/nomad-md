import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Bindable var viewModel: SidebarViewModel
    let selectedFileURL: URL?
    let onSelect: (URL) -> Void
    var onPin: (URL) -> Void = { _ in }
    var onOpenInNewTab: (URL) -> Void = { _ in }

    @State private var folderToRemove: URL?
    @State private var isDropTargeted = false
    @State private var isTagSectionExpanded = true
    @State private var expandedFolders: Set<URL> = []
    @State private var initializedFolders = false

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.rootNodes.isEmpty {
                Spacer()
                Text("Markdownファイルが見つかりません")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Spacer()
            } else {
                List(selection: Binding(
                    get: { selectedFileURL },
                    set: { url in
                        guard let url else { return }
                        var isDir: ObjCBool = false
                        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                            if let file = Self.findFileInDirectory(url) {
                                onSelect(file)
                            }
                            return
                        }
                        onSelect(url)
                    }
                )) {
                    ForEach(viewModel.rootNodes, id: \.url) { root in
                        Section(isExpanded: folderExpandedBinding(for: root.url)) {
                            if let children = root.children {
                                OutlineGroup(children, id: \.url, children: \.children) { node in
                                    let isFiltered = viewModel.filteredFileURLs != nil
                                        && !node.isDirectory
                                        && !(viewModel.filteredFileURLs?.contains(node.url) ?? false)
                                    Label {
                                        Text(node.name)
                                            .font(node.isDirectory
                                                ? .system(size: 14, weight: .semibold)
                                                : .system(size: 13))
                                            .lineLimit(1)
                                            .opacity(isFiltered ? 0.3 : 1.0)
                                    } icon: {
                                        Image(systemName: node.isDirectory ? "folder.fill" : "doc.text")
                                            .foregroundStyle(node.isDirectory ? NomadColors.sandGold : .secondary)
                                            .opacity(isFiltered ? 0.3 : 1.0)
                                    }
                                    .tag(node.url)
                                    .contextMenu {
                                        if !node.isDirectory {
                                            Button("新規タブで開く") {
                                                onOpenInNewTab(node.url)
                                            }
                                            Button("タブをピン留め") {
                                                onSelect(node.url)
                                                onPin(node.url)
                                            }
                                            Divider()
                                            Button("Finderで表示") {
                                                NSWorkspace.shared.activateFileViewerSelecting([node.url])
                                            }
                                        } else {
                                            Button("Finderで表示") {
                                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: node.url.path)
                                            }
                                        }
                                    }
                                }
                            }
                        } header: {
                            Text(root.name)
                                .font(.system(size: 14, weight: .semibold))
                                .contextMenu {
                                    Button("Finderで表示") {
                                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: root.url.path)
                                    }
                                    Divider()
                                    Button("サイドバーから削除", role: .destructive) {
                                        folderToRemove = root.url
                                    }
                                }
                        }
                    }

                    // タグセクション
                    if !viewModel.allTags.isEmpty {
                        Section {
                            DisclosureGroup(isExpanded: $isTagSectionExpanded) {
                                ForEach(viewModel.sortedTagNames, id: \.self) { tag in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            viewModel.toggleTag(tag)
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "tag")
                                                .font(.system(size: 10))
                                                .foregroundStyle(viewModel.selectedTag == tag ? Color.accentColor : .secondary)
                                            Text(tag)
                                                .font(.system(size: 12))
                                                .foregroundStyle(viewModel.selectedTag == tag ? .primary : .primary)
                                                .lineLimit(1)
                                            Spacer()
                                            Text("\(viewModel.allTags[tag]?.count ?? 0)")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(.ultraThinMaterial, in: Capsule())
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .modifier(TagGlassModifier(isSelected: viewModel.selectedTag == tag))
                                    }
                                    .buttonStyle(.plain)
                                }
                            } label: {
                                HStack {
                                    Text("タグ")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    if viewModel.selectedTag != nil {
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                viewModel.clearTagFilter()
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }

            Divider()

            HStack {
                Button {
                    viewModel.addFileOrFolder { url in onSelect(url) }
                } label: {
                    Label("追加...", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.borderless)

                Spacer()

                Button {
                    let dir = selectedFileURL?.hasDirectoryPath == true
                        ? selectedFileURL
                        : selectedFileURL?.deletingLastPathComponent()
                    if let url = viewModel.createNewFile(in: dir) {
                        onSelect(url)
                    }
                } label: {
                    Label("新規ファイル", systemImage: "doc.badge.plus")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(8)
        }
        .onAppear {
            if !initializedFolders {
                expandedFolders = Set(viewModel.rootNodes.map(\.url))
                initializedFolders = true
            }
        }
        .onChange(of: viewModel.rootNodes.map(\.url)) { _, newURLs in
            // 新規追加フォルダを自動展開
            for url in newURLs where !expandedFolders.contains(url) {
                expandedFolders.insert(url)
            }
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .background(Color.accentColor.opacity(0.1))
                    .padding(4)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
        .alert("フォルダを削除", isPresented: Binding(
            get: { folderToRemove != nil },
            set: { if !$0 { folderToRemove = nil } }
        )) {
            Button("削除", role: .destructive) {
                if let url = folderToRemove {
                    viewModel.removeFolder(at: url)
                    folderToRemove = nil
                }
            }
            Button("キャンセル", role: .cancel) {
                folderToRemove = nil
            }
        } message: {
            if let url = folderToRemove {
                Text("「\(url.lastPathComponent)」をサイドバーから削除しますか？\nファイルは削除されません。")
            }
        }
    }

    private func folderExpandedBinding(for url: URL) -> Binding<Bool> {
        Binding(
            get: { expandedFolders.contains(url) },
            set: { isExpanded in
                if isExpanded {
                    expandedFolders.insert(url)
                } else {
                    expandedFolders.remove(url)
                }
            }
        )
    }

    /// ディレクトリ内のREADME.mdまたは最初のMarkdownファイルを探す
    private static func findFileInDirectory(_ url: URL) -> URL? {
        let readmeNames = ["README.md", "readme.md", "Readme.md", "README.markdown"]
        for name in readmeNames {
            let candidate = url.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        if let node = FileSystemService.scanDirectory(at: url) {
            return FileSystemService.findFirstMarkdownFile(in: node)
        }
        return nil
    }

    private struct TagGlassModifier: ViewModifier {
        let isSelected: Bool

        @ViewBuilder
        func body(content: Content) -> some View {
            if isSelected {
                content.glassEffect(.regular.interactive(), in: .capsule)
            } else {
                content
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                guard let data = data as? Data,
                      let urlString = String(data: data, encoding: .utf8),
                      let url = URL(string: urlString) else { return }
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return }
                DispatchQueue.main.async {
                    if isDir.boolValue {
                        viewModel.addFolderByURL(url)
                    } else {
                        let ext = url.pathExtension.lowercased()
                        if ext == "md" || ext == "markdown" {
                            onSelect(url)
                        }
                    }
                }
            }
        }
    }
}
