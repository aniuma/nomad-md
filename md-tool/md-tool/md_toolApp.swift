import SwiftUI

@main
struct md_toolApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1000, height: 700)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("フォルダを追加...") {
                    NotificationCenter.default.post(name: .addFolder, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .saveItem) {
                Button("保存") {
                    NotificationCenter.default.post(name: .saveFile, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)
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
}
