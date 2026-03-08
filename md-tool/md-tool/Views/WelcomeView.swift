import SwiftUI

struct WelcomeView: View {
    let onAddFolder: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // 砂丘モチーフ
            ZStack {
                Circle()
                    .fill(NomadColors.deepNightBlue.opacity(0.08))
                    .frame(width: 100, height: 100)
                Image(systemName: "compass.drawing")
                    .font(.system(size: 44, weight: .thin))
                    .foregroundStyle(NomadColors.sandGold)
            }

            VStack(spacing: 8) {
                Text("Nomad")
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(NomadColors.deepNightBlue)
                Text("フォルダを追加してMarkdownファイルを表示しましょう")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button {
                onAddFolder()
            } label: {
                Label("フォルダを追加...", systemImage: "folder.badge.plus")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("o", modifiers: [.command, .shift])
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
