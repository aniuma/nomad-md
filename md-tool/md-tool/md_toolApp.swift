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
            CommandGroup(replacing: .printItem) {
                Button("クイックオープン") {
                    NotificationCenter.default.post(name: .quickOpen, object: nil)
                }
                .keyboardShortcut("p", modifiers: .command)

                Button("全文検索") {
                    NotificationCenter.default.post(name: .fullTextSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
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
}
