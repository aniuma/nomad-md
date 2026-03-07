import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var appState = AppState()
    @State private var sidebarVM: SidebarViewModel?
    @State private var previewVM = PreviewViewModel()
    @State private var editorVM = EditorViewModel()
    @State private var isEditing = false
    @State private var showQuickOpen = false
    @State private var showSearch = false
    @State private var showTOC = UserDefaults.standard.object(forKey: "showTOC") as? Bool ?? true

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
            if let fileURL = appState.selectedFileURL {
                if isEditing {
                    EditorView(
                        text: $editorVM.text,
                        onTextChange: { editorVM.textDidChange($0) }
                    )
                } else {
                    PreviewView(
                        htmlContent: previewVM.htmlContent,
                        baseURL: fileURL.deletingLastPathComponent(),
                        showTOC: showTOC,
                        onInternalLink: { url in
                            selectFile(url)
                        }
                    )
                }
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
        .onReceive(NotificationCenter.default.publisher(for: .toggleTOC)) { _ in
            showTOC.toggle()
            UserDefaults.standard.set(showTOC, forKey: "showTOC")
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveFile)) { _ in
            if isEditing {
                editorVM.saveImmediately()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleEditMode)) { _ in
            guard appState.selectedFileURL != nil else { return }
            if isEditing {
                editorVM.saveImmediately()
                previewVM.loadFile(at: appState.selectedFileURL)
            } else {
                editorVM.loadFile(at: appState.selectedFileURL)
            }
            isEditing.toggle()
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

    private func selectFile(_ url: URL) {
        if isEditing {
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
