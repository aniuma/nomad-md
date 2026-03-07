import Foundation

@Observable
final class EditorViewModel {
    var text: String = ""
    var isDirty: Bool = false

    private var currentURL: URL?
    private var saveTask: Task<Void, Never>?

    var currentFileURL: URL? { currentURL }

    func loadFile(at url: URL?) {
        saveImmediately()
        guard let url = url else {
            currentURL = nil
            text = ""
            isDirty = false
            return
        }
        currentURL = url
        text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        isDirty = false
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
            isDirty = false
        } catch {
            print("Save failed: \(error)")
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
}
