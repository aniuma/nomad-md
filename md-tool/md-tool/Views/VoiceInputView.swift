import SwiftUI

/// フローティング録音ボタン
struct VoiceInputView: View {
    @State private var whisperService = WhisperService()
    var onTextReady: (String) -> Void

    var body: some View {
        Button {
            handleTap()
        } label: {
            ZStack {
                Circle()
                    .fill(whisperService.isRecording ? Color.red : NomadColors.sandGold)
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)

                if whisperService.isRecording {
                    // 録音中パルスアニメーション
                    Circle()
                        .stroke(Color.red.opacity(0.4), lineWidth: 2)
                        .frame(width: 44, height: 44)
                }

                Image(systemName: whisperService.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .help(whisperService.isRecording ? "録音停止" : "音声入力")
        .task {
            await whisperService.setup()
        }
    }

    private func handleTap() {
        if whisperService.isRecording {
            let text = whisperService.stopRecording()
            if !text.isEmpty {
                onTextReady(text)
            }
        } else {
            try? whisperService.startRecording()
        }
    }
}
