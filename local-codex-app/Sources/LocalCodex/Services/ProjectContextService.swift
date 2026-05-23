import Foundation

enum ProjectContextService {
    private static let candidateNames: [String: ContextSourceKind] = [
        "AGENTS.md": .instructions,
        "README.md": .readme,
        "Package.swift": .manifest,
        "package.json": .manifest,
        "Cargo.toml": .manifest,
        "pyproject.toml": .manifest,
        "project.pbxproj": .manifest,
        "environment.toml": .codex,
    ]

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

    static func scan(projectPath: String) async -> [ContextSource] {
        await Task.detached(priority: .userInitiated) {
            let manager = FileManager.default
            let rootURL = URL(fileURLWithPath: projectPath)
            guard manager.fileExists(atPath: rootURL.path) else { return [] }

            var sources: [ContextSource] = []
            let urls = collectCandidateURLs(rootURL: rootURL, manager: manager)

            for url in urls {
                guard let kind = kind(for: url),
                      let text = try? String(contentsOf: url, encoding: .utf8) else {
                    continue
                }

                sources.append(ContextSource(
                    name: url.lastPathComponent,
                    relativePath: url.path.replacingOccurrences(of: rootURL.path + "/", with: ""),
                    path: url.path,
                    kind: kind,
                    preview: preview(from: text)
                ))
            }

            return sources.sorted { lhs, rhs in
                if lhs.kind.label != rhs.kind.label {
                    return lhs.kind.label < rhs.kind.label
                }
                return lhs.relativePath < rhs.relativePath
            }
        }.value
    }

    static func projectInstructions(from sources: [ContextSource]) -> String {
        sources
            .filter { $0.kind == .instructions }
            .compactMap { source in
                guard let text = try? String(contentsOfFile: source.path, encoding: .utf8) else { return nil }
                return "# \(source.relativePath)\n\(text.trimmingCharacters(in: .whitespacesAndNewlines))"
            }
            .joined(separator: "\n\n")
    }

    private static func collectCandidateURLs(rootURL: URL, manager: FileManager) -> [URL] {
        var urls: [URL] = []
        var seen = Set<String>()

        func append(_ url: URL) {
            guard !seen.contains(url.path), manager.fileExists(atPath: url.path) else { return }
            seen.insert(url.path)
            urls.append(url)
        }

        collectContextURLs(
            at: rootURL,
            rootURL: rootURL,
            depth: 0,
            manager: manager,
            append: append
        )

        let codexURL = rootURL.appendingPathComponent(".codex")
        if let enumerator = manager.enumerator(
            at: codexURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for case let url as URL in enumerator {
                if candidateNames[url.lastPathComponent] != nil {
                    urls.append(url)
                }
            }
        }

        return Array(Set(urls))
    }

    private static func collectContextURLs(
        at url: URL,
        rootURL: URL,
        depth: Int,
        manager: FileManager,
        append: (URL) -> Void
    ) {
        guard depth <= 3 else { return }

        if candidateNames[url.lastPathComponent] != nil {
            append(url)
        }

        if url.pathExtension == "xcodeproj" {
            append(url.appendingPathComponent("project.pbxproj"))
            return
        }

        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isHiddenKey]
        let children = (try? manager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsPackageDescendants]
        )) ?? []

        for child in children {
            guard !ignoredNames.contains(child.lastPathComponent) else { continue }
            let values = try? child.resourceValues(forKeys: resourceKeys)
            if values?.isHidden == true, child.lastPathComponent != ".codex" {
                continue
            }

            if candidateNames[child.lastPathComponent] != nil {
                append(child)
            }

            if values?.isDirectory == true {
                collectContextURLs(
                    at: child,
                    rootURL: rootURL,
                    depth: depth + 1,
                    manager: manager,
                    append: append
                )
            }
        }
    }

    private static func kind(for url: URL) -> ContextSourceKind? {
        if url.lastPathComponent == "environment.toml", url.path.contains("/.codex/") {
            return .codex
        }
        return candidateNames[url.lastPathComponent]
    }

    private static func preview(from text: String) -> String {
        let line = text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
        return String(line.prefix(90))
    }
}
