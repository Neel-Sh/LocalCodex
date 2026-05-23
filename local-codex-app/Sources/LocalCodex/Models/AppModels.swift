import Foundation
import SwiftUI

enum LocalProvider: String, CaseIterable, Identifiable, Codable {
    case ollama
    case lmstudio

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ollama: "Ollama"
        case .lmstudio: "LM Studio"
        }
    }

    var defaultModel: String {
        switch self {
        case .ollama: "gpt-oss:20b"
        case .lmstudio: "openai/gpt-oss-20b"
        }
    }

    var statusPort: Int {
        switch self {
        case .ollama: 11434
        case .lmstudio: 1234
        }
    }

    var healthURL: URL {
        switch self {
        case .ollama:
            URL(string: "http://127.0.0.1:11434/api/tags")!
        case .lmstudio:
            URL(string: "http://127.0.0.1:1234/v1/models")!
        }
    }

    var startHint: String {
        switch self {
        case .ollama:
            "Start Ollama, then make sure the model is available with `ollama pull \(defaultModel)`."
        case .lmstudio:
            "Start LM Studio, load a model, and turn on the local server."
        }
    }
}

enum ProviderHealth: Equatable {
    case unknown
    case checking
    case online
    case offline(String)

    var label: String {
        switch self {
        case .unknown: "Not checked"
        case .checking: "Checking"
        case .online: "Online"
        case .offline: "Offline"
        }
    }

    var indicatorColor: Color {
        switch self {
        case .online: CodexTheme.good
        case .checking: CodexTheme.warning
        case .offline: CodexTheme.danger
        case .unknown: Color.white.opacity(0.35)
        }
    }

    var failureMessage: String? {
        guard case .offline(let message) = self else { return nil }
        return message
    }
}

enum PermissionMode: String, CaseIterable, Identifiable, Codable {
    case workspaceWrite
    case fullAccess

    var id: String { rawValue }

    var label: String {
        switch self {
        case .workspaceWrite: "Workspace"
        case .fullAccess: "Full access"
        }
    }

    var systemImage: String {
        switch self {
        case .workspaceWrite: "folder.badge.gearshape"
        case .fullAccess: "shield.lefthalf.filled"
        }
    }
}

struct Project: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var path: String
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, path: String, updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.path = path
        self.updatedAt = updatedAt
    }

    var displayPath: String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}

struct ProjectFile: Identifiable, Hashable {
    var id: String { path }

    let name: String
    let relativePath: String
    let path: String
    let isDirectory: Bool
    let depth: Int

    var systemImage: String {
        if isDirectory { return "folder" }
        switch URL(fileURLWithPath: name).pathExtension.lowercased() {
        case "swift": return "swift"
        case "js", "jsx", "ts", "tsx": return "curlybraces"
        case "json", "toml", "yaml", "yml": return "slider.horizontal.3"
        case "md", "txt": return "doc.text"
        case "png", "jpg", "jpeg", "webp": return "photo"
        default: return "doc"
        }
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

struct ChatMessage: Identifiable, Codable, Equatable {
    var id: UUID
    var role: MessageRole
    var text: String
    var createdAt: Date
    var isThinking: Bool

    init(id: UUID = UUID(), role: MessageRole, text: String, createdAt: Date = Date(), isThinking: Bool = false) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.isThinking = isThinking
    }
}

struct ChatSession: Identifiable, Codable {
    var id: UUID
    var projectID: Project.ID
    var title: String
    var provider: LocalProvider
    var createdAt: Date
    var updatedAt: Date
    var messages: [ChatMessage]

    init(
        id: UUID = UUID(),
        projectID: Project.ID,
        title: String = "New offline chat",
        provider: LocalProvider,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messages: [ChatMessage] = []
    ) {
        self.id = id
        self.projectID = projectID
        self.title = title
        self.provider = provider
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New offline chat" : title
    }
}

enum InspectorPanel: String, CaseIterable, Identifiable, Codable {
    case info
    case terminal
    case diff

    var id: String { rawValue }

    var label: String {
        switch self {
        case .info: "Info"
        case .terminal: "Terminal"
        case .diff: "Diff"
        }
    }

    var systemImage: String {
        switch self {
        case .info: "info.circle"
        case .terminal: "terminal"
        case .diff: "square.split.2x1"
        }
    }
}

enum AgentMode: String, CaseIterable, Identifiable, Codable {
    case explore
    case plan
    case implement
    case review

    var id: String { rawValue }

    var label: String {
        switch self {
        case .explore: "Explore"
        case .plan: "Plan"
        case .implement: "Build"
        case .review: "Review"
        }
    }

    var systemImage: String {
        switch self {
        case .explore: "map"
        case .plan: "checklist"
        case .implement: "hammer"
        case .review: "doc.text.magnifyingglass"
        }
    }

    var instruction: String {
        switch self {
        case .explore:
            "First understand the codebase. Prefer reading and explaining before editing. Do not make changes unless the user explicitly asks."
        case .plan:
            "Create a concrete implementation plan before editing. Call out files, risks, and verification steps."
        case .implement:
            "Implement the requested change end-to-end. Make focused edits, run relevant verification, and report what changed."
        case .review:
            "Take a code-review stance. Lead with bugs, regressions, risks, and missing tests, ordered by severity."
        }
    }
}

enum ContextBudget: String, CaseIterable, Identifiable, Codable {
    case compact
    case balanced
    case deep

    var id: String { rawValue }

    var label: String {
        switch self {
        case .compact: "Compact"
        case .balanced: "Balanced"
        case .deep: "Deep"
        }
    }

    var fileCharacterLimit: Int {
        switch self {
        case .compact: 8_000
        case .balanced: 24_000
        case .deep: 60_000
        }
    }
}

struct PinnedContextFile: Identifiable, Codable, Hashable {
    var id: String { path }

    let projectID: Project.ID
    let relativePath: String
    let path: String
}

enum DiffLineKind: String, Codable {
    case context
    case addition
    case removal
    case metadata
}

struct DiffLine: Identifiable, Hashable {
    let id = UUID()
    let oldNumber: Int?
    let newNumber: Int?
    let kind: DiffLineKind
    let text: String
}

struct DiffHunk: Identifiable, Hashable {
    let id = UUID()
    let header: String
    let oldStart: Int
    let newStart: Int
    let lines: [DiffLine]
}

struct DiffFile: Identifiable, Hashable {
    var id: String { path }

    let path: String
    let oldPath: String?
    let status: String
    let additions: Int
    let deletions: Int
    let hunks: [DiffHunk]
    let isBinary: Bool
}

struct DiffSummary: Hashable {
    let statusText: String
    let files: [DiffFile]
    let rawDiff: String

    var additions: Int {
        files.reduce(0) { $0 + $1.additions }
    }

    var deletions: Int {
        files.reduce(0) { $0 + $1.deletions }
    }

    var changedFileCount: Int {
        files.count
    }

    static let empty = DiffSummary(statusText: "", files: [], rawDiff: "No diff loaded.")
}

struct GitActionResult: Hashable {
    let succeeded: Bool
    let message: String
}

struct MemoryNote: Identifiable, Codable, Equatable {
    var id: UUID
    var projectID: Project.ID
    var text: String
    var createdAt: Date

    init(id: UUID = UUID(), projectID: Project.ID, text: String, createdAt: Date = Date()) {
        self.id = id
        self.projectID = projectID
        self.text = text
        self.createdAt = createdAt
    }
}

enum ContextSourceKind: String, Codable {
    case instructions
    case readme
    case manifest
    case codex

    var label: String {
        switch self {
        case .instructions: "Instructions"
        case .readme: "README"
        case .manifest: "Manifest"
        case .codex: "Codex"
        }
    }

    var systemImage: String {
        switch self {
        case .instructions: "text.badge.checkmark"
        case .readme: "book"
        case .manifest: "shippingbox"
        case .codex: "sparkles"
        }
    }
}

struct ContextSource: Identifiable, Hashable {
    var id: String { path }

    let name: String
    let relativePath: String
    let path: String
    let kind: ContextSourceKind
    let preview: String
}

struct ModelRecommendation: Identifiable {
    let id = UUID()
    let name: String
    let title: String
    let size: String
    let fit: String
    let note: String
    let recommended: Bool
}

struct PromptSuggestion: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let prompt: String
}

struct WorkspaceAction: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let prompt: String
}
