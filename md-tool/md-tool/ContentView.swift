import SwiftUI
import UniformTypeIdentifiers

enum ViewMode {
    case preview
    case edit
    case split
}

struct ContentView: View {
    @State private var appState = AppState()
    @State private var sidebarVM: SidebarViewModel?
    @State private var previewVM = PreviewViewModel()
    @State private var editorVM = EditorViewModel()
    @State private var viewMode: ViewMode = .preview
    @State private var showQuickOpen = false
    @State private var showSearch = false
    @State private var showTOC = UserDefaults.standard.object(forKey: "showTOC") as? Bool ?? true
    @State private var previewTheme = UserDefaults.standard.string(forKey: "previewTheme") ?? "default"

    var body: some View {
        NavigationSplitView {
            if let vm = sidebarVM {
                SidebarView(
                    viewModel: vm,
                    selectedFileURL: appState.selectedFileURL,
                    onSelect: { url in
                        selectFile(url)
                    }
                )
            } else {
                WelcomeView {
                    initSidebarVM()
                    sidebarVM?.addFolder()
                }
            }
        } detail: {
            if let fileURL = appState.selectedFileURL, fileURL.hasDirectoryPath {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("「\(fileURL.lastPathComponent)」にREADME.mdがありません")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("フォルダをクリックすると、README.mdがあれば自動的に表示します。\nMarkdownファイルをサイドバーから選択してください。")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let fileURL = appState.selectedFileURL {
                VStack(spacing: 0) {
                if let warning = previewVM.fileSizeWarning, warning != .tooLarge {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text(warning == .veryLarge ? "大きなファイルです（10MB超）。表示に時間がかかる場合があります。" : "大きなファイルです（1MB超）。")
                            .font(.callout)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                }
                switch viewMode {
                case .preview:
                    PreviewView(
                        htmlContent: previewVM.htmlContent,
                        baseURL: fileURL.deletingLastPathComponent(),
                        showTOC: showTOC,
                        theme: previewTheme,
                        onInternalLink: { url in
                            selectFile(url)
                        }
                    )
                case .edit:
                    if editorVM.fileTooLarge {
                        Text("ファイルサイズが10MBを超えています。編集できません。")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        EditorView(
                            text: $editorVM.text,
                            onTextChange: { editorVM.textDidChange($0) }
                        )
                    }
                case .split:
                    HSplitView {
                        EditorView(
                            text: $editorVM.text,
                            onTextChange: { newText in
                                editorVM.textDidChange(newText)
                                previewVM.renderFromText(newText, baseURL: fileURL.deletingLastPathComponent())
                            }
                        )
                        .frame(minWidth: 300)
                        PreviewView(
                            htmlContent: previewVM.htmlContent,
                            baseURL: fileURL.deletingLastPathComponent(),
                            showTOC: showTOC,
                            theme: previewTheme,
                            onInternalLink: { url in
                                selectFile(url)
                            }
                        )
                        .frame(minWidth: 300)
                    }
                }
                } // VStack
            } else if !appState.registeredFolderURLs.isEmpty {
                Text("Markdownファイルを選択してください")
                    .foregroundStyle(.secondary)
            } else {
                WelcomeView {
                    initSidebarVM()
                    sidebarVM?.addFolder()
                }
            }
        }
        .navigationTitle(windowTitle)
        .navigationSplitViewColumnWidth(min: 140, ideal: 200, max: 320)
        .overlay {
            if showQuickOpen, let vm = sidebarVM {
                ZStack {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .onTapGesture { showQuickOpen = false }
                    VStack {
                        QuickOpenView(
                            files: vm.rootNodes.flatMap { FileSystemService.collectAllMarkdownFiles(in: $0) },
                            onSelect: { url in
                                selectFile(url)
                            },
                            onDismiss: { showQuickOpen = false }
                        )
                        .padding(.top, 80)
                        Spacer()
                    }
                }
            }
        }
        .overlay {
            if showSearch, let vm = sidebarVM {
                ZStack {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .onTapGesture { showSearch = false }
                    VStack {
                        SearchView(
                            files: vm.rootNodes.flatMap { FileSystemService.collectAllMarkdownFiles(in: $0) },
                            onSelect: { url in
                                selectFile(url)
                            },
                            onDismiss: { showSearch = false }
                        )
                        .padding(.top, 80)
                        Spacer()
                    }
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                    guard let data = data as? Data,
                          let urlString = String(data: data, encoding: .utf8),
                          let url = URL(string: urlString) else { return }
                    var isDir: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
                          isDir.boolValue else { return }
                    DispatchQueue.main.async {
                        initSidebarVM()
                        sidebarVM?.addFolderByURL(url)
                    }
                }
            }
            return true
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickOpen)) { _ in
            if sidebarVM != nil {
                showSearch = false
                showQuickOpen.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .fullTextSearch)) { _ in
            if sidebarVM != nil {
                showQuickOpen = false
                showSearch.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .themeChanged)) { _ in
            previewTheme = UserDefaults.standard.string(forKey: "previewTheme") ?? "default"
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleTOC)) { _ in
            showTOC.toggle()
            UserDefaults.standard.set(showTOC, forKey: "showTOC")
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveFile)) { _ in
            if viewMode == .edit || viewMode == .split {
                editorVM.saveImmediately()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleEditMode)) { _ in
            guard appState.selectedFileURL != nil else { return }
            switch viewMode {
            case .preview:
                editorVM.loadFile(at: appState.selectedFileURL)
                viewMode = .edit
            case .edit:
                editorVM.saveImmediately()
                previewVM.loadFile(at: appState.selectedFileURL)
                viewMode = .preview
            case .split:
                editorVM.saveImmediately()
                previewVM.loadFile(at: appState.selectedFileURL)
                viewMode = .preview
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSplitMode)) { _ in
            guard appState.selectedFileURL != nil else { return }
            if viewMode == .split {
                editorVM.saveImmediately()
                previewVM.loadFile(at: appState.selectedFileURL)
                viewMode = .preview
            } else {
                if viewMode == .edit {
                    editorVM.saveImmediately()
                }
                editorVM.loadFile(at: appState.selectedFileURL)
                previewVM.loadFile(at: appState.selectedFileURL)
                viewMode = .split
            }
        }
        .alert("ファイルが外部で変更されました", isPresented: Binding(
            get: { editorVM.hasConflict },
            set: { if !$0 { editorVM.resolveConflict(.keepLocal) } }
        )) {
            Button("外部の変更を読み込む") {
                editorVM.resolveConflict(.reload)
                if viewMode == .split {
                    previewVM.loadFile(at: appState.selectedFileURL)
                }
            }
            Button("ローカルの編集を維持", role: .cancel) {
                editorVM.resolveConflict(.keepLocal)
            }
        } message: {
            Text("編集中のファイルが別のアプリで変更されました。どちらの内容を使いますか？")
        }
        .onAppear {
            if !appState.registeredFolderURLs.isEmpty {
                initSidebarVM()
                if let url = appState.selectedFileURL {
                    previewVM.loadFile(at: url)
                } else if let firstRoot = sidebarVM?.rootNodes.first,
                          let first = FileSystemService.findFirstMarkdownFile(in: firstRoot) {
                    selectFile(first)
                }
            }
        }
    }

    private var windowTitle: String {
        guard let url = appState.selectedFileURL else { return "md-tool" }
        let name = url.lastPathComponent
        let dirty = (viewMode == .edit || viewMode == .split) && editorVM.isDirty
        return dirty ? "● \(name)" : name
    }

    private func selectFile(_ url: URL) {
        if viewMode == .edit || viewMode == .split {
            editorVM.saveImmediately()
            editorVM.loadFile(at: url)
        }
        appState.selectFile(url)
        previewVM.loadFile(at: url)
    }

    private func initSidebarVM() {
        if sidebarVM == nil {
            sidebarVM = SidebarViewModel(appState: appState)
        }
    }
}
