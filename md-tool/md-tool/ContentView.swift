import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()
    @State private var sidebarVM: SidebarViewModel?
    @State private var previewVM = PreviewViewModel()

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
            } else if appState.registeredFolderURL != nil {
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
        .onAppear {
            if appState.registeredFolderURL != nil {
                initSidebarVM()
                if let url = appState.selectedFileURL {
                    previewVM.loadFile(at: url)
                } else if let root = sidebarVM?.rootNode,
                          let first = FileSystemService.findFirstMarkdownFile(in: root) {
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
