import Foundation

enum GitDiffService {
    static func loadDiff(projectPath: String) async -> DiffSummary {
        await Task.detached(priority: .userInitiated) {
            let status = runGit(["-C", projectPath, "status", "--short"])
            if status.exitCode != 0 {
                return DiffSummary(statusText: status.output, files: [], rawDiff: "No git diff available for this project.\n\n\(status.output)")
            }

            let diff = runGit(["-C", projectPath, "diff", "--color=never", "--"])
            let trimmedStatus = status.output.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedDiff = diff.output.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedStatus.isEmpty && trimmedDiff.isEmpty {
                return DiffSummary(statusText: "", files: [], rawDiff: "No local changes.")
            }

            let files = parseFiles(from: trimmedDiff, statusText: trimmedStatus)
            let raw = trimmedDiff.isEmpty ? "Changed files:\n\(trimmedStatus)" : "Changed files:\n\(trimmedStatus)\n\n\(trimmedDiff)"
            return DiffSummary(statusText: trimmedStatus, files: files, rawDiff: raw)
        }.value
    }

    static func revertAllChanges(projectPath: String) async -> GitActionResult {
        await Task.detached(priority: .userInitiated) {
            let status = runGit(["-C", projectPath, "status", "--porcelain"])
            guard status.exitCode == 0 else {
                return GitActionResult(
                    succeeded: false,
                    message: status.output.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

            let changedPaths = parseChangedPaths(fromPorcelainStatus: status.output)
            guard !changedPaths.reset.isEmpty || !changedPaths.restore.isEmpty || !changedPaths.clean.isEmpty else {
                return GitActionResult(succeeded: true, message: "No local changes to revert.")
            }

            if !changedPaths.reset.isEmpty {
                var arguments = ["-C", projectPath, "reset", "--"]
                arguments.append(contentsOf: changedPaths.reset)
                let reset = runGit(arguments)
                guard reset.exitCode == 0 else {
                    return GitActionResult(
                        succeeded: false,
                        message: reset.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
            }

            if !changedPaths.restore.isEmpty {
                var arguments = ["-C", projectPath, "restore", "--worktree", "--"]
                arguments.append(contentsOf: changedPaths.restore)
                let restore = runGit(arguments)
                guard restore.exitCode == 0 else {
                    return GitActionResult(
                        succeeded: false,
                        message: restore.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
            }

            if !changedPaths.clean.isEmpty {
                var arguments = ["-C", projectPath, "clean", "-f", "--"]
                arguments.append(contentsOf: changedPaths.clean)
                let clean = runGit(arguments)
                guard clean.exitCode == 0 else {
                    return GitActionResult(
                        succeeded: false,
                        message: clean.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
            }

            return GitActionResult(succeeded: true, message: "Reverted \(changedPaths.count) changed file(s).")
        }.value
    }

    private static func parseFiles(from diff: String, statusText: String) -> [DiffFile] {
        guard !diff.isEmpty else {
            return statusText
                .split(separator: "\n")
                .map { line in
                    let text = String(line)
                    let path = text.dropFirst(min(3, text.count)).trimmingCharacters(in: .whitespaces)
                    return DiffFile(path: path, oldPath: nil, status: String(text.prefix(2)).trimmingCharacters(in: .whitespaces), additions: 0, deletions: 0, hunks: [], isBinary: false)
                }
        }

        var files: [DiffFile] = []
        var currentPath = ""
        var oldPath: String?
        var status = "Modified"
        var additions = 0
        var deletions = 0
        var hunks: [DiffHunk] = []
        var hunkHeader = ""
        var hunkLines: [DiffLine] = []
        var oldLine = 0
        var newLine = 0
        var hunkOldStart = 0
        var hunkNewStart = 0
        var isBinary = false

        func flushHunk() {
            guard !hunkHeader.isEmpty else { return }
            hunks.append(DiffHunk(header: hunkHeader, oldStart: hunkOldStart, newStart: hunkNewStart, lines: hunkLines))
            hunkHeader = ""
            hunkLines = []
        }

        func flushFile() {
            guard !currentPath.isEmpty else { return }
            flushHunk()
            files.append(DiffFile(path: currentPath, oldPath: oldPath, status: status, additions: additions, deletions: deletions, hunks: hunks, isBinary: isBinary))
            currentPath = ""
            oldPath = nil
            status = "Modified"
            additions = 0
            deletions = 0
            hunks = []
            hunkLines = []
            isBinary = false
        }

        for rawLine in diff.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if rawLine.hasPrefix("diff --git ") {
                flushFile()
                let parts = rawLine.split(separator: " ")
                if parts.count >= 4 {
                    oldPath = normalizeDiffPath(String(parts[2]))
                    currentPath = normalizeDiffPath(String(parts[3]))
                }
                continue
            }

            if rawLine.hasPrefix("new file mode") {
                status = "Added"
                continue
            }
            if rawLine.hasPrefix("deleted file mode") {
                status = "Deleted"
                continue
            }
            if rawLine.hasPrefix("rename from ") {
                status = "Renamed"
                oldPath = String(rawLine.dropFirst("rename from ".count))
                continue
            }
            if rawLine.hasPrefix("rename to ") {
                currentPath = String(rawLine.dropFirst("rename to ".count))
                continue
            }
            if rawLine.hasPrefix("Binary files ") {
                isBinary = true
                continue
            }
            if rawLine.hasPrefix("@@") {
                flushHunk()
                hunkHeader = rawLine
                let starts = parseHunkStarts(rawLine)
                oldLine = starts.old
                newLine = starts.new
                hunkOldStart = oldLine
                hunkNewStart = newLine
                continue
            }

            guard !hunkHeader.isEmpty else { continue }

            if rawLine.hasPrefix("+"), !rawLine.hasPrefix("+++") {
                additions += 1
                hunkLines.append(DiffLine(oldNumber: nil, newNumber: newLine, kind: .addition, text: String(rawLine.dropFirst())))
                newLine += 1
            } else if rawLine.hasPrefix("-"), !rawLine.hasPrefix("---") {
                deletions += 1
                hunkLines.append(DiffLine(oldNumber: oldLine, newNumber: nil, kind: .removal, text: String(rawLine.dropFirst())))
                oldLine += 1
            } else if rawLine.hasPrefix("\\") {
                hunkLines.append(DiffLine(oldNumber: nil, newNumber: nil, kind: .metadata, text: rawLine))
            } else {
                let text = rawLine.hasPrefix(" ") ? String(rawLine.dropFirst()) : rawLine
                hunkLines.append(DiffLine(oldNumber: oldLine, newNumber: newLine, kind: .context, text: text))
                oldLine += 1
                newLine += 1
            }
        }

        flushFile()
        return files
    }

    private static func parseChangedPaths(fromPorcelainStatus status: String) -> (reset: [String], restore: [String], clean: [String], count: Int) {
        var reset: [String] = []
        var restore: [String] = []
        var clean: [String] = []

        for rawLine in status.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            guard rawLine.count >= 4 else { continue }

            let code = String(rawLine.prefix(2))
            let indexStatus = rawLine[rawLine.startIndex]
            let pathText = String(rawLine.dropFirst(3))
            let paths = parsePorcelainPaths(pathText)

            if code == "??" {
                clean.append(paths.new)
            } else {
                let isStagedNewPath = indexStatus == "A" || indexStatus == "R" || indexStatus == "C"
                reset.append(paths.new)
                if let old = paths.old {
                    reset.append(old)
                    restore.append(old)
                }
                if !isStagedNewPath {
                    restore.append(paths.new)
                }
                if isStagedNewPath {
                    clean.append(paths.new)
                }
            }
        }

        let uniqueReset = Array(Set(reset)).sorted()
        let uniqueRestore = Array(Set(restore)).sorted()
        let uniqueClean = Array(Set(clean)).sorted()
        return (uniqueReset, uniqueRestore, uniqueClean, Set(uniqueReset + uniqueRestore + uniqueClean).count)
    }

    private static func parsePorcelainPaths(_ text: String) -> (old: String?, new: String) {
        if let range = text.range(of: " -> ") {
            let oldPath = unquotePorcelainPath(String(text[..<range.lowerBound]))
            let newPath = unquotePorcelainPath(String(text[range.upperBound...]))
            return (oldPath, newPath)
        }

        return (nil, unquotePorcelainPath(text))
    }

    private static func unquotePorcelainPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("\""), trimmed.hasSuffix("\"") else { return trimmed }
        let decoder = JSONDecoder()
        if let data = trimmed.data(using: .utf8),
           let decoded = try? decoder.decode(String.self, from: data) {
            return decoded
        }
        return String(trimmed.dropFirst().dropLast())
    }

    private static func normalizeDiffPath(_ path: String) -> String {
        var value = path
        if value.hasPrefix("a/") || value.hasPrefix("b/") {
            value = String(value.dropFirst(2))
        }
        return value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }

    private static func parseHunkStarts(_ header: String) -> (old: Int, new: Int) {
        let parts = header.split(separator: " ")
        let old = parts.first(where: { $0.hasPrefix("-") }).flatMap { Int($0.dropFirst().split(separator: ",").first ?? "1") } ?? 1
        let new = parts.first(where: { $0.hasPrefix("+") }).flatMap { Int($0.dropFirst().split(separator: ",").first ?? "1") } ?? 1
        return (old, new)
    }

    private static func runGit(_ arguments: [String]) -> (exitCode: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
        } catch {
            return (127, "Failed to run git: \(error.localizedDescription)")
        }
    }
}
