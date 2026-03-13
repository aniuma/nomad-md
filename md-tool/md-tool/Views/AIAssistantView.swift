import SwiftUI

/// AIアシスタントサイドパネル（.inspector）
struct AIAssistantView: View {
    @State var viewModel = AIAssistantViewModel()
    @State private var modelManager = LLMModelManager()
    let markdownContent: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            modelSection
            Divider()
            tabPicker
            contentArea
        }
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(NomadColors.sandGold)
            Text("AI アシスタント")
                .font(.headline)
            Spacer()
            Text(viewModel.memoryInfo)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    // MARK: - Model Section

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isModelLoaded {
                HStack {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text(viewModel.llmService.currentModel?.name ?? "モデル")
                        .font(.caption)
                    Spacer()
                    Button("オフ") {
                        viewModel.unloadModel()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            } else if viewModel.llmService.state.isLoading {
                HStack {
                    ProgressView(value: viewModel.llmService.downloadProgress)
                        .frame(width: 100)
                    Text("読み込み中 \(Int(viewModel.llmService.downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("モデルを選択")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(viewModel.availableModels) { model in
                        let cached = modelManager.isModelCached(model)
                        Button {
                            Task { await viewModel.loadModel(model) }
                        } label: {
                            HStack {
                                Text(model.name)
                                    .font(.caption)
                                Spacer()
                                if cached {
                                    Text("ロード")
                                        .font(.caption2)
                                        .foregroundStyle(Color.accentColor)
                                } else {
                                    Text("DL+ロード")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Text(model.size)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if !viewModel.llmService.canLoadModel(model) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.caption2)
                                        .foregroundStyle(.yellow)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        Picker("", selection: $viewModel.selectedTab) {
            ForEach(AIAssistantViewModel.Tab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                switch viewModel.selectedTab {
                case .summarize:
                    summarizeContent
                case .qa:
                    qaContent
                }
            }
            .padding(12)
        }
    }

    private var summarizeContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task { await viewModel.summarize(markdown: markdownContent) }
            } label: {
                HStack {
                    Image(systemName: "text.justify.leading")
                    Text("ドキュメントを要約")
                }
            }
            .disabled(!viewModel.isModelLoaded || viewModel.isProcessing)

            resultView
        }
    }

    private var qaContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("質問を入力...", text: $viewModel.question)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task {
                            await viewModel.ask(
                                question: viewModel.question,
                                context: markdownContent
                            )
                        }
                    }
                Button {
                    Task {
                        await viewModel.ask(
                            question: viewModel.question,
                            context: markdownContent
                        )
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                }
                .disabled(!viewModel.isModelLoaded || viewModel.isProcessing || viewModel.question.isEmpty)
            }

            resultView
        }
    }

    @ViewBuilder
    private var resultView: some View {
        if viewModel.isProcessing {
            HStack {
                ProgressView()
                    .scaleEffect(0.7)
                Text("生成中...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        if !viewModel.result.isEmpty {
            Text(viewModel.result)
                .font(.callout)
                .textSelection(.enabled)
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}
