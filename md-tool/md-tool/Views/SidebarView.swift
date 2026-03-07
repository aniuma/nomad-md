import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Bindable var viewModel: SidebarViewModel
    let selectedFileURL: URL?
    let onSelect: (URL) -> Void

    @State private var folderToRemove: URL?
    @State private var isDropTargeted = false

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
                                    Label {
                                        Text(node.name)
                                            .font(node.isDirectory
                                                ? .system(size: 14, weight: .semibold)
                                                : .system(size: 13))
                                            .lineLimit(1)
                                    } icon: {
                                        Image(systemName: node.isDirectory ? "folder.fill" : "doc.text")
                                            .foregroundStyle(node.isDirectory ? .orange : .secondary)
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
                }
                .listStyle(.sidebar)
            }

            Divider()

            HStack {
                Button {
                    viewModel.addFolder()
                } label: {
                    Label("フォルダを追加", systemImage: "plus")
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
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
                      isDir.boolValue else { return }
                DispatchQueue.main.async {
                    viewModel.addFolderByURL(url)
                }
            }
        }
    }
}
