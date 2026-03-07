import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()
    @State private var sidebarVM: SidebarViewModel?
    @State private var previewVM = PreviewViewModel()
    @State private var showQuickOpen = false

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
            if appState.selectedFileURL != nil {
                PreviewView(htmlContent: previewVM.htmlContent)
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
        .onReceive(NotificationCenter.default.publisher(for: .quickOpen)) { _ in
            if sidebarVM != nil {
                showQuickOpen.toggle()
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
