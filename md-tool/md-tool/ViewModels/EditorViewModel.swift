import Foundation

enum ConflictAction {
    case reload
    case keepLocal
}

@Observable
final class EditorViewModel {
    var text: String = ""
    var isDirty: Bool = false
    var hasConflict: Bool = false
    var fileTooLarge: Bool = false

    private var currentURL: URL?
    private var saveTask: Task<Void, Never>?
    private var lastKnownModDate: Date?
    private let fileWatcher = FileWatcher()

    var currentFileURL: URL? { currentURL }

    func loadFile(at url: URL?) {
        saveImmediately()
        hasConflict = false
        fileTooLarge = false
        guard let url = url else {
            currentURL = nil
            text = ""
            isDirty = false
            stopWatching()
            return
        }
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        if fileSize > 10_000_000 {
            fileTooLarge = true
            currentURL = nil
            text = ""
            isDirty = false
            return
        }
        currentURL = url
        text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        lastKnownModDate = fileModificationDate(url)
        isDirty = false
        watchCurrentFile()
    }

    func textDidChange(_ newText: String) {
        text = newText
        isDirty = true
        scheduleSave()
    }

    func saveImmediately() {
        saveTask?.cancel()
        saveTask = nil
        guard isDirty, let url = currentURL else { return }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            lastKnownModDate = fileModificationDate(url)
            isDirty = false
            hasConflict = false
        } catch {
            print("Save failed: \(error)")
        }
    }

    func resolveConflict(_ action: ConflictAction) {
        hasConflict = false
        switch action {
        case .reload:
            guard let url = currentURL else { return }
            text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            lastKnownModDate = fileModificationDate(url)
            isDirty = false
        case .keepLocal:
            lastKnownModDate = currentURL.flatMap { fileModificationDate($0) }
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.saveImmediately()
        }
    }

    private func fileModificationDate(_ url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }

    private func watchCurrentFile() {
        guard let url = currentURL else { return }
        let dir = url.deletingLastPathComponent()
        let fileName = url.lastPathComponent
        fileWatcher.start(paths: [dir]) { [weak self] changedPaths in
            guard let self, let currentURL = self.currentURL else { return }
            let relevant = changedPaths.isEmpty || changedPaths.contains { $0.hasSuffix(fileName) }
            guard relevant, self.isDirty else { return }
            let newDate = self.fileModificationDate(currentURL)
            if let last = self.lastKnownModDate, let new = newDate, new > last {
                self.hasConflict = true
            }
        }
    }

    private func stopWatching() {
        fileWatcher.stop()
    }
}
