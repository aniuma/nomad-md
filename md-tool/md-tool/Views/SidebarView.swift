import SwiftUI

struct SidebarView: View {
    @Bindable var viewModel: SidebarViewModel
    let selectedFileURL: URL?
    let onSelect: (URL) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let root = viewModel.rootNode, let children = root.children {
                List(selection: Binding(
                    get: { selectedFileURL },
                    set: { if let url = $0 { onSelect(url) } }
                )) {
                    Section {
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
                    } header: {
                        Text(root.name)
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .listStyle(.sidebar)
            } else {
                Spacer()
                Text("Markdownファイルが見つかりません")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Spacer()
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

                if viewModel.rootNode != nil {
                    Button {
                        viewModel.removeFolder()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("フォルダの登録を解除")
                }
            }
            .padding(8)
        }
    }
}
