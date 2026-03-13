import SwiftUI

/// AI設定ビュー（モデル管理）
struct AISettingsView: View {
    @State private var modelManager = LLMModelManager()
    @State private var showDeleteConfirm = false
    @State private var modelToDelete: LLMService.LLMModel?

    var body: some View {
        Form {
            Section {
                ForEach(LLMService.LLMModel.defaultModels) { model in
                    modelRow(model)
                }
            } header: {
                Text("LLMモデル")
            } footer: {
                let totalMB = modelManager.totalCacheSize() / 1_000_000
                if totalMB > 0 {
                    Text("キャッシュ合計: \(totalMB) MB — ~/Library/Caches/huggingface/hub/")
                        .foregroundStyle(.secondary)
                } else {
                    Text("モデルをダウンロードすると、ローカルで要約・Q&Aが使えます。")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .alert("モデルを削除", isPresented: $showDeleteConfirm, presenting: modelToDelete) { model in
            Button("削除", role: .destructive) {
                modelManager.deleteModel(model)
            }
            Button("キャンセル", role: .cancel) {}
        } message: { model in
            Text("\(model.name) のキャッシュを削除しますか？再度使用するにはダウンロードが必要です。")
        }
    }

    private func modelState(for model: LLMService.LLMModel) -> ModelRowState {
        switch modelManager.downloadState {
        case .downloading(let id, let p) where id == model.id:
            return .downloading(progress: p)
        case .preparing(let id) where id == model.id:
            return .preparing
        case .completed(let id) where id == model.id:
            return .completed
        default:
            return modelManager.isModelCached(model) ? .cached : .notCached
        }
    }

    private enum ModelRowState {
        case notCached, cached, downloading(progress: Double), preparing, completed
    }

    @ViewBuilder
    private func modelRow(_ model: LLMService.LLMModel) -> some View {
        let rowState = modelState(for: model)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.name)
                    switch rowState {
                    case .cached:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    case .completed:
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("完了")
                                .foregroundStyle(.green)
                        }
                        .font(.caption)
                    default:
                        EmptyView()
                    }
                }
                HStack(spacing: 8) {
                    Text("パラメータ: \(model.size)")
                    Text("必要メモリ: \(model.memoryRequired / 1_000_000_000)GB")
                    if case .cached = rowState {
                        let sizeMB = modelManager.modelCacheSize(model) / 1_000_000
                        Text("キャッシュ: \(sizeMB)MB")
                    }
                    if case .completed = rowState {
                        let sizeMB = modelManager.modelCacheSize(model) / 1_000_000
                        Text("キャッシュ: \(sizeMB)MB")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            switch rowState {
            case .downloading(let progress):
                VStack(spacing: 2) {
                    ProgressView(value: progress)
                        .frame(width: 80)
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            case .preparing:
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("準備中...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            case .completed:
                Text("使用可能")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .cached:
                Button("削除") {
                    modelToDelete = model
                    showDeleteConfirm = true
                }
                .font(.caption)
                .foregroundStyle(.red)
            case .notCached:
                Button("ダウンロード") {
                    Task { await modelManager.downloadModel(model) }
                }
                .font(.caption)
                .disabled(modelManager.downloadState.isBusy)
            }
        }
        .padding(.vertical, 2)
    }
}
