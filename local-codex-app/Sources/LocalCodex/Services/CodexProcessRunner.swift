import Foundation

@MainActor
final class CodexProcessRunner: ObservableObject {
    @Published var isRunning = false
    @Published var status = "Ready"
    @Published var terminalOutput = ""
    @Published var lastCommand = "No command run yet."

    private var process: Process?
    private var outputFileURL: URL?

    func run(
        prompt: String,
        project: Project,
        provider: LocalProvider,
        model: String,
        permissionMode: PermissionMode,
        onActivity: @escaping @MainActor (String) -> Void = { _ in },
        onOutput: @escaping @MainActor (String) -> Void,
        onFinished: @escaping @MainActor (Int32) -> Void
    ) {
        guard !isRunning else {
            terminalOutput += "A Codex task is already running.\n"
            onFinished(1)
            return
        }

        let codexPath = Self.codexBinaryPath()
        guard FileManager.default.isExecutableFile(atPath: codexPath) else {
            let message = "Could not find the local Codex binary at \(codexPath).\n"
            terminalOutput += message
            onOutput(message)
            status = "Codex binary missing"
            onFinished(127)
            return
        }

        isRunning = true
        status = "Running on \(provider.label)"
        terminalOutput = ""
        outputFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("local-codex-\(UUID().uuidString)-last-message.txt")

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let task = Process()
        task.executableURL = URL(fileURLWithPath: codexPath)
        task.arguments = arguments(
            prompt: prompt,
            project: project,
            provider: provider,
            model: model,
            permissionMode: permissionMode,
            outputFileURL: outputFileURL
        )
        task.currentDirectoryURL = URL(fileURLWithPath: project.path, isDirectory: true)
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe
        task.environment = Self.processEnvironment()
        lastCommand = ([codexPath] + (task.arguments ?? [])).joined(separator: " ")

        let appendData: @Sendable (FileHandle) -> Void = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else {
                return
            }
            Task { @MainActor in
                self.terminalOutput += text
                onActivity(text)
            }
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = appendData
        stderrPipe.fileHandleForReading.readabilityHandler = appendData

        task.terminationHandler = { [weak self] process in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            Task { @MainActor in
                self?.isRunning = false
                self?.process = nil
                self?.status = process.terminationStatus == 0
                    ? "Finished"
                    : "Exited \(process.terminationStatus)"
                if let outputURL = self?.outputFileURL,
                   let text = try? String(contentsOf: outputURL, encoding: .utf8),
                   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    onOutput(text)
                    try? FileManager.default.removeItem(at: outputURL)
                }
                self?.outputFileURL = nil
                onFinished(process.terminationStatus)
            }
        }

        do {
            try task.run()
            process = task
        } catch {
            isRunning = false
            status = "Launch failed"
            let message = "Failed to launch Codex: \(error.localizedDescription)\n"
            terminalOutput += message
            onOutput(message)
            onFinished(127)
        }
    }

    func stop() {
        process?.terminate()
        status = "Stopping"
        terminalOutput += "\nStopping Codex...\n"
    }

    func clearTerminal() {
        terminalOutput = ""
    }

    private func arguments(
        prompt: String,
        project: Project,
        provider: LocalProvider,
        model: String,
        permissionMode: PermissionMode,
        outputFileURL: URL?
    ) -> [String] {
        var args = [
            "exec",
            "--oss",
            "--local-provider", provider.rawValue,
            "--model", model,
            "--cd", project.path,
            "--skip-git-repo-check",
            "--color", "never",
        ]

        if let outputFileURL {
            args.append(contentsOf: ["--output-last-message", outputFileURL.path])
        }

        switch permissionMode {
        case .workspaceWrite:
            args.append(contentsOf: ["--sandbox", "workspace-write"])
        case .fullAccess:
            args.append("--dangerously-bypass-approvals-and-sandbox")
        }

        args.append(prompt)
        return args
    }

    static func codexBinaryPath() -> String {
        let bundlePath = Bundle.main.bundlePath as NSString
        let distDir = bundlePath.deletingLastPathComponent as NSString
        let appRoot = distDir.deletingLastPathComponent as NSString
        let projectRoot = appRoot.deletingLastPathComponent
        let projectBinary = "\(projectRoot)/codex-rs/target/debug/codex"
        if FileManager.default.isExecutableFile(atPath: projectBinary) {
            return projectBinary
        }

        let appBundleParent = bundlePath.deletingLastPathComponent
        let siblingBinary = "\(appBundleParent)/codex"
        if FileManager.default.isExecutableFile(atPath: siblingBinary) {
            return siblingBinary
        }

        return "/Users/neelsharma/Desktop/LocalCode/codex-main/codex-rs/target/debug/codex"
    }

    private static func processEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let currentPath = environment["PATH"] ?? ""
        environment["PATH"] = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            currentPath,
        ].joined(separator: ":")
        return environment
    }
}
