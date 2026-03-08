import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Bindable var viewModel: SidebarViewModel
    let selectedFileURL: URL?
    let onSelect: (URL) -> Void

    @State private var folderToRemove: URL?
    @State private var isDropTargeted = false
    @State private var isTagSectionExpanded = true

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
                            let readmeNames = ["README.md", "readme.md", "Readme.md", "README.markdown"]
                            for name in readmeNames {
                                let candidate = url.appendingPathComponent(name)
                                if FileManager.default.fileExists(atPath: candidate.path) {
                                    onSelect(candidate)
                                    return
                                }
                            }
                            return
                        }
                        onSelect(url)
                    }
                )) {
                    ForEach(viewModel.rootNodes, id: \.url) { root in
                        Section {
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
                                            .foregroundStyle(node.isDirectory ? .orange : .secondary)
                                            .opacity(isFiltered ? 0.3 : 1.0)
                                    }
                                    .tag(node.url)
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
                                                .foregroundStyle(viewModel.selectedTag == tag ? .white : .secondary)
                                            Text(tag)
                                                .font(.system(size: 12))
                                                .foregroundStyle(viewModel.selectedTag == tag ? .white : .primary)
                                                .lineLimit(1)
                                            Spacer()
                                            Text("\(viewModel.allTags[tag]?.count ?? 0)")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(viewModel.selectedTag == tag ? .white : .secondary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(
                                                    Capsule()
                                                        .fill(viewModel.selectedTag == tag
                                                            ? Color.white.opacity(0.3)
                                                            : Color.secondary.opacity(0.15))
                                                )
                                        }
                                        .padding(.vertical, 2)
                                        .padding(.horizontal, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(viewModel.selectedTag == tag
                                                    ? Color.accentColor
                                                    : Color.clear)
                                        )
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
            }
            .padding(8)
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
