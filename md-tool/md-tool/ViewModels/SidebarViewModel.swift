import Foundation
import AppKit

@Observable
final class SidebarViewModel {
    var rootNode: FileNode?

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        if let folderURL = appState.registeredFolderURL {
            loadFolder(folderURL)
        }
    }

    func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Markdownファイルを含むフォルダを選択してください"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        appState.registerFolder(url)
        loadFolder(url)

        if let root = rootNode, let firstFile = FileSystemService.findFirstMarkdownFile(in: root) {
            appState.selectFile(firstFile)
        }
    }

    func removeFolder() {
        appState.unregisterFolder()
        rootNode = nil
    }

    func refreshTree() {
        guard let url = appState.registeredFolderURL else { return }
        loadFolder(url)
    }

    func selectFile(_ url: URL) {
        appState.selectFile(url)
    }

    private func loadFolder(_ url: URL) {
        rootNode = FileSystemService.scanDirectory(at: url)
    }
}
