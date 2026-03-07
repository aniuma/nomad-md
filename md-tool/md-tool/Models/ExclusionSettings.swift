import Foundation

enum ExclusionSettings {
    private static let key = "excludedDirectoryNames"
    static let defaultPatterns = ["node_modules", ".git", ".svn", ".hg", ".build", "Pods", "DerivedData"]

    static var patterns: [String] {
        get {
            UserDefaults.standard.stringArray(forKey: key) ?? defaultPatterns
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
            NotificationCenter.default.post(name: .exclusionSettingsChanged, object: nil)
        }
    }

    static var patternSet: Set<String> {
        Set(patterns)
    }
}

extension Notification.Name {
    static let exclusionSettingsChanged = Notification.Name("exclusionSettingsChanged")
}
