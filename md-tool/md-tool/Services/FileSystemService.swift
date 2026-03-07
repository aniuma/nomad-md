import Foundation

struct FileSystemService {
    private static let markdownExtensions: Set<String> = ["md", "markdown"]
    private static let excludedDirectories: Set<String> = ["node_modules", ".git", ".svn", ".hg"]

    static func scanDirectory(at url: URL) -> FileNode? {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var children: [FileNode] = []

        for itemURL in contents {
            let name = itemURL.lastPathComponent
            let isDir = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

            if isDir {
                if excludedDirectories.contains(name) { continue }
                if let childNode = scanDirectory(at: itemURL) {
                    children.append(childNode)
                }
            } else {
                if markdownExtensions.contains(itemURL.pathExtension.lowercased()) {
                    children.append(FileNode(url: itemURL, isDirectory: false))
                }
            }
        }

        if children.isEmpty { return nil }

        children.sort { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }

        return FileNode(url: url, isDirectory: true, children: children)
    }

    static func collectAllMarkdownFiles(in node: FileNode) -> [URL] {
        var result: [URL] = []
        if !node.isDirectory {
            result.append(node.url)
        }
        if let children = node.children {
            for child in children {
                result.append(contentsOf: collectAllMarkdownFiles(in: child))
            }
        }
        return result
    }

    static func findFirstMarkdownFile(in node: FileNode) -> URL? {
        if !node.isDirectory { return node.url }
        guard let children = node.children else { return nil }
        for child in children {
            if !child.isDirectory { return child.url }
        }
        for child in children {
            if child.isDirectory, let found = findFirstMarkdownFile(in: child) {
                return found
            }
        }
        return nil
    }
}
