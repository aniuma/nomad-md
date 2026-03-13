import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// コールドスタート時にUIが準備完了する前に届いたURLをバッファリング
    var pendingURLs: [URL] = []
    var isUIReady = false

    func application(_ application: NSApplication, open urls: [URL]) {
        // 既存ウィンドウを前面に出す
        if let window = NSApp.windows.first(where: { $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)

        for url in urls {
            guard url.isFileURL else { continue }
            let fm = FileManager.default
            guard fm.fileExists(atPath: url.path) else { continue }

            if isUIReady {
                deliverURL(url)
            } else {
                pendingURLs.append(url)
            }
        }
    }

    /// 新規ウィンドウ作成を抑制（Cmd+Nやメニューからの「新規ウィンドウ」を無効化）
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag {
            // 既にウィンドウがあればそれを前面に
            NSApp.windows.first { $0.isVisible }?.makeKeyAndOrderFront(nil)
            return false
        }
        return true
    }

    func flushPendingURLs() {
        isUIReady = true
        for url in pendingURLs {
            deliverURL(url)
        }
        pendingURLs.removeAll()
    }

    private func deliverURL(_ url: URL) {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)

        if isDirectory.boolValue {
            NotificationCenter.default.post(name: .openFolderByURL, object: url)
        } else {
            NotificationCenter.default.post(name: .openFileByURL, object: url)
        }
    }
}

@main
struct NomadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleURLScheme(url)
                }
        }
        .handlesExternalEvents(matching: ["*"])
        .windowStyle(.automatic)
        .defaultSize(width: 1000, height: 700)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("新規Markdownファイル") {
                    NotificationCenter.default.post(name: .createNewFile, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("フォルダを追加...") {
                    NotificationCenter.default.post(name: .addFolder, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Divider()

                Button("最近使った項目") {
                    NotificationCenter.default.post(name: .showRecentFiles, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .saveItem) {
                Button("保存") {
                    NotificationCenter.default.post(name: .saveFile, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)

                Divider()

                Button("タブを閉じる") {
                    NotificationCenter.default.post(name: .closeTab, object: nil)
                }
                .keyboardShortcut("w", modifiers: .command)
            }
            CommandGroup(replacing: .printItem) {
                Button("クイックオープン") {
                    NotificationCenter.default.post(name: .quickOpen, object: nil)
                }
                .keyboardShortcut("p", modifiers: .command)

                Button("全文検索") {
                    NotificationCenter.default.post(name: .fullTextSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])

                Button("索引") {
                    NotificationCenter.default.post(name: .showIndex, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }
            CommandGroup(after: .saveItem) {
                Divider()
                Button("HTMLとして保存...") {
                    NotificationCenter.default.post(name: .exportHTML, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button("PDFとして保存...") {
                    NotificationCenter.default.post(name: .exportPDF, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift, .option])
            }
            CommandGroup(after: .toolbar) {
                Button("編集モード切替") {
                    NotificationCenter.default.post(name: .toggleEditMode, object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)

                Button("分割表示切替") {
                    NotificationCenter.default.post(name: .toggleSplitMode, object: nil)
                }
                .keyboardShortcut("\\", modifiers: .command)

                Button("目次を表示") {
                    NotificationCenter.default.post(name: .toggleTOC, object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
        }
    }
}

extension NomadApp {
    func handleURLScheme(_ url: URL) {
        // file:// scheme — Finder double-click or "Open With"
        if url.isFileURL {
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: url.path) else { return }

            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)

            if isDirectory.boolValue {
                NotificationCenter.default.post(name: .openFolderByURL, object: url)
            } else {
                NotificationCenter.default.post(name: .openFileByURL, object: url)
            }
            return
        }

        // nomad:// custom URL scheme
        guard url.scheme == "nomad",
              url.host == "open",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let pathItem = components.queryItems?.first(where: { $0.name == "path" }),
              let pathValue = pathItem.value else {
            return
        }

        let fileURL = URL(fileURLWithPath: pathValue)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory)

        if isDirectory.boolValue {
            NotificationCenter.default.post(name: .openFolderByURL, object: fileURL)
        } else {
            NotificationCenter.default.post(name: .openFileByURL, object: fileURL)
        }
    }
}

extension Notification.Name {
    static let addFolder = Notification.Name("addFolder")
    static let quickOpen = Notification.Name("quickOpen")
    static let fullTextSearch = Notification.Name("fullTextSearch")
    static let toggleTOC = Notification.Name("toggleTOC")
    static let toggleEditMode = Notification.Name("toggleEditMode")
    static let saveFile = Notification.Name("saveFile")
    static let toggleSplitMode = Notification.Name("toggleSplitMode")
    static let themeChanged = Notification.Name("themeChanged")
    static let showIndex = Notification.Name("showIndex")
    static let exportHTML = Notification.Name("exportHTML")
    static let exportPDF = Notification.Name("exportPDF")
    static let openFileByURL = Notification.Name("openFileByURL")
    static let openFolderByURL = Notification.Name("openFolderByURL")
    static let closeTab = Notification.Name("closeTab")
    static let showRecentFiles = Notification.Name("showRecentFiles")
    static let appearanceChanged = Notification.Name("appearanceChanged")
    static let createNewFile = Notification.Name("createNewFile")
}
