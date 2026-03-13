import Foundation

@Observable
final class AIAssistantViewModel {

    enum Tab: String, CaseIterable {
        case summarize = "要約"
        case qa = "Q&A"
    }

    var selectedTab: Tab = .summarize
    var question: String = ""
    var result: String = ""
    var isProcessing: Bool = false
    var errorMessage: String?

    let llmService = LLMService.shared

    var isModelLoaded: Bool {
        llmService.state == .ready
    }

    var availableModels: [LLMService.LLMModel] {
        LLMService.LLMModel.defaultModels
    }

    var memoryInfo: String {
        let available = llmService.availableMemory()
        let gb = Double(available) / 1_000_000_000.0
        return String(format: "利用可能メモリ: %.1f GB", gb)
    }

    // MARK: - Actions

    func loadModel(_ model: LLMService.LLMModel) async {
        errorMessage = nil
        do {
            try await llmService.loadModel(model)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unloadModel() {
        llmService.unloadModel()
        result = ""
        errorMessage = nil
    }

    func summarize(markdown: String) async {
        guard !isProcessing else { return }
        isProcessing = true
        errorMessage = nil
        do {
            result = try await llmService.summarize(markdown)
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }

    func ask(question: String, context markdown: String) async {
        guard !isProcessing, !question.isEmpty else { return }
        isProcessing = true
        errorMessage = nil
        do {
            result = try await llmService.askQuestion(question, context: markdown)
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }
}
