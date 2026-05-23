import Foundation

@MainActor
final class ModelDownloadService: ObservableObject {
    @Published var activeModel: String?
    @Published var output = "Choose a model to download with Ollama."

    private var process: Process?

    var isDownloading: Bool {
        activeModel != nil
    }

    func download(_ model: String) {
        guard activeModel == nil else { return }

        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["ollama", "pull", model]
        task.standardOutput = pipe
        task.standardError = pipe
        task.environment = Self.processEnvironment()

        activeModel = model
        output = "Downloading \(model)...\n"

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.output += text
            }
        }

        task.terminationHandler = { [weak self] process in
            pipe.fileHandleForReading.readabilityHandler = nil
            Task { @MainActor in
                self?.output += "\nFinished with status \(process.terminationStatus)."
                self?.activeModel = nil
                self?.process = nil
            }
        }

        do {
            try task.run()
            process = task
        } catch {
            output = "Could not start Ollama. Install or open Ollama, then try again.\n\n\(error.localizedDescription)"
            activeModel = nil
        }
    }

    func stop() {
        process?.terminate()
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
