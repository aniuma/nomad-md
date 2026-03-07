import Foundation
import AppKit

@Observable
final class SidebarViewModel {
    var rootNodes: [FileNode] = []

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        loadAllFolders()
    }

    func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Markdownファイルを含むフォルダを選択してください"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        // Duplicate check
        if appState.registeredFolderURLs.contains(where: { $0.path == url.path }) { return }

        appState.addFolder(url)
        if let node = FileSystemService.scanDirectory(at: url) {
            rootNodes.append(node)
            // Auto-select first markdown file if nothing is selected
            if appState.selectedFileURL == nil,
               let firstFile = FileSystemService.findFirstMarkdownFile(in: node) {
                appState.selectFile(firstFile)
            }
        }
    }

    func removeFolder(at url: URL) {
        rootNodes.removeAll { $0.url.path == url.path }
        appState.removeFolder(url)
    }

    func refreshAllFolders() {
        loadAllFolders()
    }

    func refreshFolder(at url: URL) {
        guard let index = rootNodes.firstIndex(where: { $0.url.path == url.path }) else { return }
        if let node = FileSystemService.scanDirectory(at: url) {
            rootNodes[index] = node
        } else {
            rootNodes.remove(at: index)
        }
    }

    func selectFile(_ url: URL) {
        appState.selectFile(url)
    }

    private func loadAllFolders() {
        rootNodes = appState.registeredFolderURLs.compactMap { url in
            FileSystemService.scanDirectory(at: url)
        }
    }
}
