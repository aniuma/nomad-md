import Foundation
import Speech
import AVFoundation

/// 音声入力サービス（macOS標準 Speech フレームワーク）
@Observable
final class WhisperService {

    enum WhisperState: Equatable {
        case idle
        case ready
        case recording
        case error(String)
    }

    var state: WhisperState = .idle
    var transcribedText: String = ""
    var isRecording: Bool { state == .recording }

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: - セットアップ

    func setup() async {
        // 日本語優先、フォールバックでシステムロケール
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
            ?? SFSpeechRecognizer()

        guard recognizer?.isAvailable == true else {
            state = .error("音声認識が利用できません")
            return
        }

        // 認証リクエスト
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        switch status {
        case .authorized:
            state = .ready
        case .denied:
            state = .error("音声認識の権限が拒否されました。システム設定から許可してください。")
        case .restricted:
            state = .error("音声認識が制限されています")
        case .notDetermined:
            state = .error("音声認識の権限が未設定です")
        @unknown default:
            state = .error("不明なエラー")
        }
    }

    // MARK: - 録音 + リアルタイム認識

    func startRecording() throws {
        guard state == .ready else { return }
        guard let recognizer = recognizer, recognizer.isAvailable else {
            state = .error("音声認識が利用できません")
            return
        }

        // 既存タスクをキャンセル
        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // オンデバイス認識を優先（利用可能なら）
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        transcribedText = ""

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.transcribedText = result.bestTranscription.formattedString
            }
            if error != nil || (result?.isFinal == true) {
                self.stopAudioEngine()
            }
        }

        // オーディオ入力設定
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        state = .recording
    }

    func stopRecording() -> String {
        recognitionRequest?.endAudio()
        stopAudioEngine()
        state = .ready
        return transcribedText
    }

    func cancelRecording() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        stopAudioEngine()
        transcribedText = ""
        state = .ready
    }

    private func stopAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest = nil
        recognitionTask = nil
    }
}
