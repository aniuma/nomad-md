import SwiftUI

struct WelcomeView: View {
    let onAddFolder: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Markdownプレビューア")
                .font(.title2)
                .fontWeight(.semibold)

            Text("フォルダを追加してMarkdownファイルを表示しましょう")
                .foregroundStyle(.secondary)

            Button("フォルダを追加...") {
                onAddFolder()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("o", modifiers: [.command, .shift])
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
