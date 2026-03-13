import Foundation
#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
#endif

/// LLMモデルのダウンロード・キャッシュ管理
/// MLXLLM (HubApi) のキャッシュ: ~/Library/Caches/models/{model.id}/
@Observable
final class LLMModelManager {

    enum DownloadState: Equatable {
        case idle
        case downloading(modelId: String, progress: Double)
        case preparing(modelId: String)
        case completed(modelId: String)
        case error(String)

        /// DL/準備中のモデルID
        var activeModelId: String? {
            switch self {
            case .downloading(let id, _), .preparing(let id), .completed(let id):
                return id
            default:
                return nil
            }
        }

        var isBusy: Bool {
            switch self {
            case .downloading, .preparing: return true
            default: return false
            }
        }
    }

    var downloadState: DownloadState = .idle
    var cachedModelIds: Set<String> = []

    private let cacheBase: URL

    init() {
        // MLXLLM の defaultHubApi は ~/Library/Caches/models/ を使う
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheBase = cachesDir.appendingPathComponent("models")
        refreshCache()
    }

    // MARK: - キャッシュ確認

    /// 実際のキャッシュパス: ~/Library/Caches/models/mlx-community/ModelName
    private func cacheDir(for model: LLMService.LLMModel) -> URL {
        cacheBase.appendingPathComponent(model.id)
    }

    func isModelCached(_ model: LLMService.LLMModel) -> Bool {
        cachedModelIds.contains(model.id)
    }

    func refreshCache() {
        var ids: Set<String> = []
        for model in LLMService.LLMModel.defaultModels {
            let dir = cacheDir(for: model)
            // config.json の存在でDL完了を判定
            let configPath = dir.appendingPathComponent("config.json")
            if FileManager.default.fileExists(atPath: configPath.path) {
                ids.insert(model.id)
            }
        }
        cachedModelIds = ids
    }

    func modelCacheSize(_ model: LLMService.LLMModel) -> UInt64 {
        let dir = cacheDir(for: model)
        guard let enumerator = FileManager.default.enumerator(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += UInt64(size)
            }
        }
        return total
    }

    // MARK: - ダウンロード

    func downloadModel(_ model: LLMService.LLMModel) async {
        guard !downloadState.isBusy else { return }
        #if canImport(MLXLLM)
        downloadState = .downloading(modelId: model.id, progress: 0)
        do {
            let config = ModelConfiguration(id: model.id)
            let _ = try await LLMModelFactory.shared.loadContainer(
                configuration: config
            ) { [weak self] progress in
                let fraction = progress.fractionCompleted
                Task { @MainActor in
                    if fraction >= 1.0 {
                        self?.downloadState = .preparing(modelId: model.id)
                    } else {
                        self?.downloadState = .downloading(
                            modelId: model.id,
                            progress: fraction
                        )
                    }
                }
            }
            refreshCache()
            downloadState = .completed(modelId: model.id)
            try? await Task.sleep(for: .seconds(2))
            if case .completed = downloadState {
                downloadState = .idle
            }
        } catch {
            downloadState = .error(error.localizedDescription)
        }
        #else
        downloadState = .error("MLXLLMパッケージが未統合です")
        #endif
    }

    // MARK: - 削除

    func deleteModel(_ model: LLMService.LLMModel) {
        let dir = cacheDir(for: model)
        try? FileManager.default.removeItem(at: dir)
        refreshCache()
    }

    func totalCacheSize() -> UInt64 {
        LLMService.LLMModel.defaultModels.reduce(0) { $0 + modelCacheSize($1) }
    }
}
