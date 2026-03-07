import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var appState = AppState()
    @State private var sidebarVM: SidebarViewModel?
    @State private var previewVM = PreviewViewModel()
    @State private var showQuickOpen = false
    @State private var showSearch = false

    var body: some View {
        NavigationSplitView {
            if let vm = sidebarVM {
                SidebarView(
                    viewModel: vm,
                    selectedFileURL: appState.selectedFileURL,
                    onSelect: { url in
                        appState.selectFile(url)
                        previewVM.loadFile(at: url)
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
                PreviewView(
                    htmlContent: previewVM.htmlContent,
                    baseURL: fileURL.deletingLastPathComponent(),
                    onInternalLink: { url in
                        appState.selectFile(url)
                        previewVM.loadFile(at: url)
                    }
                )
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
                                appState.selectFile(url)
                                previewVM.loadFile(at: url)
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
                                appState.selectFile(url)
                                previewVM.loadFile(at: url)
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
        .onAppear {
            if !appState.registeredFolderURLs.isEmpty {
                initSidebarVM()
                if let url = appState.selectedFileURL {
                    previewVM.loadFile(at: url)
                } else if let firstRoot = sidebarVM?.rootNodes.first,
                          let first = FileSystemService.findFirstMarkdownFile(in: firstRoot) {
                    appState.selectFile(first)
                    previewVM.loadFile(at: first)
                }
            }
        }
    }

    private func initSidebarVM() {
        if sidebarVM == nil {
            sidebarVM = SidebarViewModel(appState: appState)
        }
    }
}
