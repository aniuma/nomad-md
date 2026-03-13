import Foundation
#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
import Tokenizers
#endif

/// ローカルLLM統合サービス（mlx-swift-lm）
/// アプリ全体で共有（shared singleton）— モデルのロード状態を保持
@Observable
final class LLMService {

    static let shared = LLMService()

    enum LLMState: Equatable {
        case unloaded
        case loading(progress: Double)
        case ready
        case generating
        case error(String)

        static func == (lhs: LLMState, rhs: LLMState) -> Bool {
            switch (lhs, rhs) {
            case (.unloaded, .unloaded), (.ready, .ready), (.generating, .generating):
                return true
            case (.loading(let a), .loading(let b)):
                return a == b
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }

        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }
    }

    enum LLMError: Error, LocalizedError {
        case modelNotLoaded
        case insufficientMemory(available: UInt64, required: UInt64)
        case generationFailed(String)

        var errorDescription: String? {
            switch self {
            case .modelNotLoaded: return "モデルが読み込まれていません"
            case .insufficientMemory(let available, let required):
                return "メモリ不足: 利用可能 \(available / 1_000_000)MB, 必要 \(required / 1_000_000)MB"
            case .generationFailed(let msg): return "生成失敗: \(msg)"
            }
        }
    }

    struct LLMModel: Identifiable, Hashable {
        let id: String
        let name: String
        let size: String
        let memoryRequired: UInt64

        static let defaultModels: [LLMModel] = [
            LLMModel(
                id: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
                name: "Qwen2.5 0.5B",
                size: "0.5B",
                memoryRequired: 500_000_000
            ),
            LLMModel(
                id: "mlx-community/gemma-3-1b-it-4bit",
                name: "Gemma 3 1B",
                size: "1B",
                memoryRequired: 800_000_000
            ),
            LLMModel(
                id: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
                name: "Qwen2.5 1.5B",
                size: "1.5B",
                memoryRequired: 1_200_000_000
            ),
        ]
    }

    var state: LLMState = .unloaded
    var currentModel: LLMModel?
    var generatedText: String = ""
    var isStreaming: Bool = false
    var downloadProgress: Double = 0

    #if canImport(MLXLLM)
    private var modelContainer: ModelContainer?
    #endif

    // MARK: - メモリチェック

    func availableMemory() -> UInt64 {
        var pageSize = vm_size_t(0)
        host_page_size(mach_host_self(), &pageSize)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        if result == KERN_SUCCESS {
            let free = UInt64(stats.free_count) * UInt64(pageSize)
            let inactive = UInt64(stats.inactive_count) * UInt64(pageSize)
            return free + inactive
        }
        return ProcessInfo.processInfo.physicalMemory / 2
    }

    func canLoadModel(_ model: LLMModel) -> Bool {
        availableMemory() > model.memoryRequired
    }

    // MARK: - モデル操作

    func loadModel(_ model: LLMModel) async throws {
        guard canLoadModel(model) else {
            throw LLMError.insufficientMemory(
                available: availableMemory(),
                required: model.memoryRequired
            )
        }

        #if canImport(MLXLLM)
        state = .loading(progress: 0)
        downloadProgress = 0

        do {
            let config = ModelConfiguration(id: model.id)
            let container = try await LLMModelFactory.shared.loadContainer(
                configuration: config
            ) { progress in
                Task { @MainActor in
                    self.downloadProgress = progress.fractionCompleted
                    self.state = .loading(progress: progress.fractionCompleted)
                }
            }
            self.modelContainer = container
            self.currentModel = model
            self.state = .ready
        } catch {
            self.state = .error(error.localizedDescription)
            throw LLMError.generationFailed(error.localizedDescription)
        }
        #else
        state = .error("MLXLLMパッケージが未統合です")
        throw LLMError.generationFailed("MLXLLMパッケージが未統合です")
        #endif
    }

    func unloadModel() {
        #if canImport(MLXLLM)
        modelContainer = nil
        #endif
        currentModel = nil
        generatedText = ""
        isStreaming = false
        state = .unloaded
    }

    // MARK: - 生成

    func summarize(_ markdown: String) async throws -> String {
        let prompt = "以下のMarkdownドキュメントを日本語で簡潔に要約してください（3-5行）:\n\n\(String(markdown.prefix(4000)))"
        return try await generate(prompt: prompt)
    }

    func askQuestion(_ question: String, context markdown: String) async throws -> String {
        let prompt = "以下のドキュメントの内容に基づいて、質問に日本語で答えてください。\n\nドキュメント:\n\(String(markdown.prefix(4000)))\n\n質問: \(question)"
        return try await generate(prompt: prompt)
    }

    /// Qwen3等の<think>...</think>タグを除去
    nonisolated static func stripThinkTags(_ text: String) -> String {
        text.replacingOccurrences(
            of: "<think>[\\s\\S]*?</think>\\s*",
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func generate(prompt: String) async throws -> String {
        #if canImport(MLXLLM)
        guard state == .ready, let container = modelContainer else {
            throw LLMError.modelNotLoaded
        }

        state = .generating
        generatedText = ""
        isStreaming = true

        do {
            let result = try await container.perform { context in
                let input = try await context.processor.prepare(input: .init(prompt: prompt))
                var params = GenerateParameters(temperature: 0.7, topP: 0.9)
                params.maxTokens = 1024
                return try MLXLMCommon.generate(
                    input: input,
                    parameters: params,
                    context: context
                ) { tokens in
                    let text = context.tokenizer.decode(tokens: tokens)
                    Task { @MainActor in
                        self.generatedText = text
                    }
                    return tokens.count < 1024 ? .more : .stop
                }
            }

            let finalText = Self.stripThinkTags(result.output)
            generatedText = finalText
            isStreaming = false
            state = .ready
            return finalText
        } catch {
            isStreaming = false
            state = .ready
            throw LLMError.generationFailed(error.localizedDescription)
        }
        #else
        throw LLMError.generationFailed("MLXLLMパッケージが未統合です")
        #endif
    }
}
