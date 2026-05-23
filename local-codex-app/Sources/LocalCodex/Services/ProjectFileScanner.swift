import Foundation

enum ProjectFileScanner {
    private static let ignoredNames: Set<String> = [
        ".DS_Store",
        ".git",
        ".swiftpm",
        ".build",
        "build",
        "dist",
        "node_modules",
        "target",
        "DerivedData",
    ]

    static func scan(path: String, limit: Int = 260) async -> [ProjectFile] {
        await Task.detached(priority: .userInitiated) {
            let rootURL = URL(fileURLWithPath: path)
            let manager = FileManager.default
            guard manager.fileExists(atPath: rootURL.path) else { return [] }

            var files: [ProjectFile] = []
            walk(rootURL, rootURL: rootURL, depth: 0, manager: manager, files: &files, limit: limit)
            return files
        }.value
    }

    private static func walk(
        _ url: URL,
        rootURL: URL,
        depth: Int,
        manager: FileManager,
        files: inout [ProjectFile],
        limit: Int
    ) {
        guard files.count < limit, depth <= 5 else { return }

        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isHiddenKey]
        let children = (try? manager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsPackageDescendants]
        )) ?? []

        let sorted = children
            .filter { child in
                guard !ignoredNames.contains(child.lastPathComponent) else { return false }
                let values = try? child.resourceValues(forKeys: resourceKeys)
                return values?.isHidden != true || child.lastPathComponent.hasPrefix(".env")
            }
            .sorted { lhs, rhs in
                let leftValues = try? lhs.resourceValues(forKeys: [.isDirectoryKey])
                let rightValues = try? rhs.resourceValues(forKeys: [.isDirectoryKey])
                let leftDirectory = leftValues?.isDirectory == true
                let rightDirectory = rightValues?.isDirectory == true
                if leftDirectory != rightDirectory { return leftDirectory }
                return lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent) == .orderedAscending
            }

        for child in sorted {
            guard files.count < limit else { break }
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = values?.isDirectory == true
            let relativePath = child.path.replacingOccurrences(of: rootURL.path + "/", with: "")

            files.append(ProjectFile(
                name: child.lastPathComponent,
                relativePath: relativePath,
                path: child.path,
                isDirectory: isDirectory,
                depth: depth
            ))

            if isDirectory {
                walk(child, rootURL: rootURL, depth: depth + 1, manager: manager, files: &files, limit: limit)
            }
        }
    }
}
