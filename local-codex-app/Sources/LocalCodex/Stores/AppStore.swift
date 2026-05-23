import AppKit
import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published var provider: LocalProvider {
        didSet {
            if model.isEmpty || model == oldValue.defaultModel {
                model = provider.defaultModel
            }
            persistPreferences()
            Task { await refreshProviderHealth() }
        }
    }
    @Published var model: String {
        didSet { persistPreferences() }
    }
    @Published var permissionMode: PermissionMode {
        didSet { persistPreferences() }
    }
    @Published var projects: [Project] {
        didSet { persistProjects() }
    }
    @Published var selectedProjectID: Project.ID? {
        didSet {
            persistPreferences()
            Task { await refreshProjectFiles() }
        }
    }
    @Published var selectedChatID: ChatSession.ID? {
        didSet {
            persistPreferences()
            loadSelectedChatMessages()
        }
    }
    @Published var chatSessions: [ChatSession] {
        didSet { persistChatSessions() }
    }
    @Published var memoryNotes: [MemoryNote] {
        didSet { persistMemoryNotes() }
    }
    @Published var pinnedContextFiles: [PinnedContextFile] {
        didSet { persistPinnedContextFiles() }
    }
    @Published var messages: [ChatMessage] = [] {
        didSet { syncSelectedChatMessages() }
    }
    @Published var prompt: String = ""
    @Published var searchText: String = ""
    @Published var fileSearchText: String = ""
    @Published var projectFiles: [ProjectFile] = []
    @Published var isLoadingProjectFiles = false
    @Published var contextSources: [ContextSource] = []
    @Published var projectInstructions = ""
    @Published var isLoadingContextSources = false
    @Published var providerHealth: ProviderHealth = .unknown
    @Published var inspectorPanel: InspectorPanel {
        didSet { persistPreferences() }
    }
    @Published var diffText = "No diff loaded."
    @Published var diffSummary: DiffSummary = .empty
    @Published var isLoadingDiff = false
    @Published var isRevertingDiff = false
    @Published var diffActionMessage: String?
    @Published var memoryDraft = ""
    @Published var agentMode: AgentMode {
        didSet { persistPreferences() }
    }
    @Published var contextBudget: ContextBudget {
        didSet { persistPreferences() }
    }

    private var isLoadingMessages = false

    let suggestions: [PromptSuggestion] = [
        PromptSuggestion(
            icon: "sparkles",
            title: "Find the next task",
            prompt: "Inspect this project and recommend the highest-impact next coding task."
        ),
        PromptSuggestion(
            icon: "hammer",
            title: "Fix build issues",
            prompt: "Run the relevant checks for this project, diagnose failures, and fix them."
        ),
        PromptSuggestion(
            icon: "doc.text.magnifyingglass",
            title: "Explain the codebase",
            prompt: "Map the main modules in this project and explain how they fit together."
        ),
        PromptSuggestion(
            icon: "checklist",
            title: "Create an implementation plan",
            prompt: "Create a practical implementation plan for the next feature in this project."
        ),
    ]

    let workspaceActions: [WorkspaceAction] = [
        WorkspaceAction(
            icon: "doc.text.magnifyingglass",
            title: "Review local changes",
            prompt: "Review the current local changes like a senior engineer. Focus on bugs, regressions, risky behavior, and missing tests. Start with findings ordered by severity."
        ),
        WorkspaceAction(
            icon: "wrench.and.screwdriver",
            title: "Fix build or test failures",
            prompt: "Run the relevant build or test command for this project, diagnose any failures, and fix them."
        ),
        WorkspaceAction(
            icon: "map",
            title: "Map this codebase",
            prompt: "Inspect this project and explain the main modules, entry points, and how changes should be made safely."
        ),
        WorkspaceAction(
            icon: "checklist",
            title: "Plan next feature",
            prompt: "Create an implementation plan for the next feature, including files to touch, risks, and verification steps."
        ),
    ]

    var selectedProject: Project? {
        projects.first(where: { $0.id == selectedProjectID }) ?? projects.first
    }

    var selectedChat: ChatSession? {
        chatSessions.first(where: { $0.id == selectedChatID })
    }

    var chatsForSelectedProject: [ChatSession] {
        guard let projectID = selectedProject?.id else { return [] }
        return chats(for: projectID)
    }

    func chats(for projectID: Project.ID) -> [ChatSession] {
        return chatSessions
            .filter { $0.projectID == projectID }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var memoriesForSelectedProject: [MemoryNote] {
        guard let projectID = selectedProject?.id else { return [] }
        return memoryNotes
            .filter { $0.projectID == projectID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var pinnedFilesForSelectedProject: [PinnedContextFile] {
        guard let projectID = selectedProject?.id else { return [] }
        return pinnedContextFiles
            .filter { $0.projectID == projectID }
            .sorted { $0.relativePath < $1.relativePath }
    }

    var contextSummary: String {
        var parts: [String] = []
        if !projectInstructions.isEmpty { parts.append("AGENTS.md") }
        let memoryCount = memoriesForSelectedProject.count
        if memoryCount > 0 { parts.append("\(memoryCount) memory") }
        let pinnedCount = pinnedFilesForSelectedProject.count
        if pinnedCount > 0 { parts.append("\(pinnedCount) pinned") }
        return parts.isEmpty ? "No extra context" : parts.joined(separator: " · ")
    }

    var visibleProjectFiles: [ProjectFile] {
        let query = fileSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return projectFiles }
        return projectFiles.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.relativePath.localizedCaseInsensitiveContains(query)
        }
    }

    init() {
        let defaults = UserDefaults.standard
        let savedProvider = defaults.string(forKey: "provider").flatMap(LocalProvider.init(rawValue:)) ?? .ollama
        provider = savedProvider
        model = defaults.string(forKey: "model") ?? savedProvider.defaultModel
        permissionMode = defaults.string(forKey: "permissionMode").flatMap(PermissionMode.init(rawValue:)) ?? .workspaceWrite
        inspectorPanel = defaults.string(forKey: "inspectorPanel").flatMap(InspectorPanel.init(rawValue:)) ?? .info
        agentMode = defaults.string(forKey: "agentMode").flatMap(AgentMode.init(rawValue:)) ?? .implement
        contextBudget = defaults.string(forKey: "contextBudget").flatMap(ContextBudget.init(rawValue:)) ?? .balanced

        if let data = defaults.data(forKey: "projects"),
           let decoded = try? JSONDecoder().decode([Project].self, from: data),
           !decoded.isEmpty {
            projects = decoded
        } else {
            projects = [
                Project(name: "LocalCode", path: "/Users/neelsharma/Desktop/LocalCode"),
                Project(name: "codex-main", path: "/Users/neelsharma/Desktop/LocalCode/codex-main"),
            ]
        }

        if let data = defaults.data(forKey: "chatSessions"),
           let decoded = try? JSONDecoder().decode([ChatSession].self, from: data) {
            chatSessions = decoded
        } else {
            chatSessions = []
        }

        if let data = defaults.data(forKey: "memoryNotes"),
           let decoded = try? JSONDecoder().decode([MemoryNote].self, from: data) {
            memoryNotes = decoded
        } else {
            memoryNotes = []
        }

        if let data = defaults.data(forKey: "pinnedContextFiles"),
           let decoded = try? JSONDecoder().decode([PinnedContextFile].self, from: data) {
            pinnedContextFiles = decoded
        } else {
            pinnedContextFiles = []
        }

        if let selected = defaults.string(forKey: "selectedProjectID").flatMap(UUID.init(uuidString:)) {
            selectedProjectID = selected
        } else {
            selectedProjectID = projects.first?.id
        }

        if let selected = defaults.string(forKey: "selectedChatID").flatMap(UUID.init(uuidString:)),
           chatSessions.contains(where: { $0.id == selected }) {
            selectedChatID = selected
        } else {
            selectedChatID = nil
        }

        ensureChatForSelectedProject()
        loadSelectedChatMessages()

        Task {
            await refreshProjectFiles()
            await refreshProjectContext()
            await refreshProviderHealth()
            await refreshDiff()
        }
    }

    func newChat() {
        guard let project = selectedProject else { return }
        let chat = ChatSession(projectID: project.id, provider: provider)
        chatSessions.insert(chat, at: 0)
        selectedChatID = chat.id
        messages = []
        prompt = ""
    }

    func chooseProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = selectedProject.map { URL(fileURLWithPath: $0.path) }

        if panel.runModal() == .OK, let url = panel.url {
            addProject(path: url.path)
        }
    }

    func addProject(path: String) {
        let name = URL(fileURLWithPath: path).lastPathComponent
        if let existing = projects.firstIndex(where: { $0.path == path }) {
            projects[existing].updatedAt = Date()
            selectProject(projects[existing].id, resetChat: true)
        } else {
            let project = Project(name: name, path: path)
            projects.insert(project, at: 0)
            selectProject(project.id, resetChat: true)
        }
    }

    func selectProject(_ projectID: Project.ID, resetChat: Bool = true) {
        guard selectedProjectID != projectID else { return }
        selectedProjectID = projectID
        ensureChatForSelectedProject()
        loadSelectedChatMessages()
        prompt = ""
        if let index = projects.firstIndex(where: { $0.id == projectID }) {
            projects[index].updatedAt = Date()
        }
        Task {
            await refreshProjectContext()
            await refreshDiff()
        }
    }

    func selectChat(_ chatID: ChatSession.ID) {
        guard selectedChatID != chatID else { return }
        selectedChatID = chatID
        prompt = ""
    }

    func removeProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        if selectedProjectID == project.id {
            selectedProjectID = projects.first?.id
            ensureChatForSelectedProject()
            loadSelectedChatMessages()
            prompt = ""
        }
    }

    func selectSuggestion(_ suggestion: PromptSuggestion) {
        prompt = suggestion.prompt
    }

    func addMemoryNote() {
        guard let project = selectedProject else { return }
        let text = memoryDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        memoryNotes.insert(MemoryNote(projectID: project.id, text: text), at: 0)
        memoryDraft = ""
    }

    func deleteMemoryNote(_ note: MemoryNote) {
        memoryNotes.removeAll { $0.id == note.id }
    }

    func pinContextFile(_ file: ProjectFile) {
        guard let project = selectedProject, !file.isDirectory else { return }
        let pinned = PinnedContextFile(
            projectID: project.id,
            relativePath: file.relativePath,
            path: file.path
        )
        guard !pinnedContextFiles.contains(where: { $0.id == pinned.id }) else { return }
        pinnedContextFiles.append(pinned)
    }

    func unpinContextFile(_ file: ProjectFile) {
        pinnedContextFiles.removeAll { $0.path == file.path }
    }

    func unpinContextFile(_ pinned: PinnedContextFile) {
        pinnedContextFiles.removeAll { $0.id == pinned.id }
    }

    func isPinnedContextFile(_ file: ProjectFile) -> Bool {
        pinnedContextFiles.contains { $0.path == file.path }
    }

    func promptWithWorkspaceContext(
        _ prompt: String,
        project explicitProject: Project? = nil,
        projectFiles explicitProjectFiles: [ProjectFile]? = nil,
        contextSources explicitContextSources: [ContextSource]? = nil
    ) -> String {
        let project = explicitProject ?? selectedProject
        let projectFiles = explicitProjectFiles ?? self.projectFiles
        let contextSources = explicitContextSources ?? self.contextSources
        let memories = memories(for: project).map { "- \($0.text)" }
        let instructions = ProjectContextService.projectInstructions(from: contextSources)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let workspaceSnapshot = workspaceSnapshotSnippet(
            project: project,
            projectFiles: projectFiles,
            contextSources: contextSources
        )
        let pinnedFiles = pinnedContextSnippets(for: project)
        let mentionedFiles = mentionedContextSnippets(
            in: prompt,
            project: project,
            projectFiles: projectFiles
        )
        let mode = inferredAgentMode(for: prompt)

        var sections: [String] = []
        if let project {
            sections.append("""
            Current workspace:
            - Project name: \(project.name)
            - Root directory: \(project.path)
            - The Codex process is launched from this root. Treat relative paths as relative to this directory, and inspect or edit files inside it unless the user says otherwise.
            - If the user asks about "this project", use this workspace instead of asking for the root directory.
            """)
        }

        sections.append("""
        Agent mode: \(mode.label)
        \(mode.instruction)
        """)

        sections.append("""
        Coding reliability rules:
        - The workspace snapshot below was generated from the selected project on disk just before this run. Use it as evidence, and do not describe files or frameworks that are not supported by the snapshot or by files you inspect.
        - Before answering architecture, module-map, build, review, or implementation questions, inspect the relevant files in the workspace with shell commands or file reads. Mention the concrete files you inspected in the answer.
        - Do not invent APIs, files, build commands, frameworks, databases, or behavior. Verify names and call sites from the workspace first.
        - Make the smallest correct change that satisfies the request, and preserve unrelated user changes.
        - Prefer structured parsers, framework APIs, and existing helpers over ad hoc text manipulation.
        - After editing, run the narrowest useful build, lint, or test command. If verification cannot run, explain the blocker.
        - Review the resulting diff before finalizing and call out risks or assumptions.
        Efficiency rules:
        - Start with the likely owning files, then widen only when evidence says to.
        - Avoid broad rewrites, new dependencies, and full test suites unless the change touches shared behavior.
        """)

        if !workspaceSnapshot.isEmpty {
            sections.append("""
            Workspace snapshot from disk:
            \(workspaceSnapshot)
            """)
        }

        if !instructions.isEmpty {
            sections.append("""
            Project instructions discovered from AGENTS.md:
            \(instructions)
            """)
        }

        if !memories.isEmpty {
            sections.append("""
            Saved project memory:
            \(memories.joined(separator: "\n"))
            """)
        }

        if !mentionedFiles.isEmpty {
            sections.append("""
            Files referenced in the user request:
            \(mentionedFiles)
            """)
        }

        if !pinnedFiles.isEmpty {
            sections.append("""
            Pinned context files:
            \(pinnedFiles)
            """)
        }

        return """
        Use this workspace context:
        \(sections.joined(separator: "\n\n"))

        User request:
        \(prompt)
        """
    }

    func promptWithProjectMemory(_ prompt: String) -> String {
        promptWithWorkspaceContext(prompt)
    }

    func refreshedWorkspaceContext(for project: Project) async -> ([ProjectFile], [ContextSource]) {
        async let files = ProjectFileScanner.scan(path: project.path)
        async let sources = ProjectContextService.scan(projectPath: project.path)
        let result = await (files, sources)

        if selectedProject?.id == project.id {
            projectFiles = result.0
            contextSources = result.1
            projectInstructions = ProjectContextService.projectInstructions(from: result.1)
        }

        return result
    }

    func useQuickAction(_ action: WorkspaceAction) {
        prompt = action.prompt
        agentMode = inferredAgentMode(for: action.prompt)
    }

    func appendFileMention(_ file: ProjectFile) {
        guard !file.isDirectory else { return }
        let mention = "@\(file.relativePath)"
        if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prompt = mention + " "
        } else if !prompt.contains(mention) {
            prompt += prompt.hasSuffix(" ") ? mention + " " : " " + mention + " "
        }
    }

    func revealSelectedProjectInFinder() {
        guard let project = selectedProject else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: project.path)])
    }

    func revealInFinder(_ file: ProjectFile) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)])
    }

    func refreshProjectFiles() async {
        guard let project = selectedProject else {
            projectFiles = []
            isLoadingProjectFiles = false
            return
        }

        isLoadingProjectFiles = true
        let files = await ProjectFileScanner.scan(path: project.path)
        guard selectedProject?.id == project.id else {
            isLoadingProjectFiles = false
            return
        }
        projectFiles = files
        isLoadingProjectFiles = false
    }

    func refreshProjectContext() async {
        guard let project = selectedProject else {
            contextSources = []
            projectInstructions = ""
            isLoadingContextSources = false
            return
        }

        isLoadingContextSources = true
        let sources = await ProjectContextService.scan(projectPath: project.path)
        guard selectedProject?.id == project.id else {
            isLoadingContextSources = false
            return
        }
        contextSources = sources
        projectInstructions = ProjectContextService.projectInstructions(from: sources)
        isLoadingContextSources = false
    }

    func refreshProviderHealth() async {
        providerHealth = .checking
        providerHealth = await ProviderHealthService.check(provider)
    }

    func refreshDiff() async {
        guard let project = selectedProject else {
            diffText = "Open a project to see a diff."
            return
        }

        isLoadingDiff = true
        let summary = await GitDiffService.loadDiff(projectPath: project.path)
        diffSummary = summary
        diffText = summary.rawDiff
        isLoadingDiff = false
    }

    func revertAllChanges() async {
        guard let project = selectedProject else {
            diffActionMessage = "Open a project before reverting changes."
            return
        }

        isRevertingDiff = true
        let result = await GitDiffService.revertAllChanges(projectPath: project.path)
        diffActionMessage = result.message.isEmpty
            ? (result.succeeded ? "Reverted local changes." : "Could not revert local changes.")
            : result.message
        await refreshDiff()
        isRevertingDiff = false
    }

    private func ensureChatForSelectedProject() {
        guard let project = selectedProject else { return }
        if let selectedChatID,
           chatSessions.contains(where: { $0.id == selectedChatID && $0.projectID == project.id }) {
            return
        }

        if let latest = chatSessions
            .filter({ $0.projectID == project.id })
            .max(by: { $0.updatedAt < $1.updatedAt }) {
            selectedChatID = latest.id
            return
        }

        let chat = ChatSession(projectID: project.id, provider: provider)
        chatSessions.insert(chat, at: 0)
        selectedChatID = chat.id
    }

    private func loadSelectedChatMessages() {
        guard !isLoadingMessages else { return }
        isLoadingMessages = true
        messages = selectedChat?.messages ?? []
        isLoadingMessages = false
    }

    private func syncSelectedChatMessages() {
        guard !isLoadingMessages,
              let selectedChatID,
              let index = chatSessions.firstIndex(where: { $0.id == selectedChatID }) else {
            return
        }

        chatSessions[index].messages = messages
        chatSessions[index].updatedAt = Date()
        chatSessions[index].provider = provider
        if let firstUserPrompt = messages.first(where: { $0.role == .user })?.text {
            chatSessions[index].title = Self.chatTitle(from: firstUserPrompt)
        }
    }

    private static func chatTitle(from prompt: String) -> String {
        let title = prompt
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.count > 34 else { return title.isEmpty ? "New offline chat" : title }
        return String(title.prefix(34)) + "..."
    }

    private func persistProjects() {
        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey: "projects")
        }
    }

    private func persistChatSessions() {
        if let data = try? JSONEncoder().encode(chatSessions) {
            UserDefaults.standard.set(data, forKey: "chatSessions")
        }
    }

    private func persistMemoryNotes() {
        if let data = try? JSONEncoder().encode(memoryNotes) {
            UserDefaults.standard.set(data, forKey: "memoryNotes")
        }
    }

    private func persistPinnedContextFiles() {
        if let data = try? JSONEncoder().encode(pinnedContextFiles) {
            UserDefaults.standard.set(data, forKey: "pinnedContextFiles")
        }
    }

    private func pinnedContextSnippets(for project: Project? = nil) -> String {
        let files = pinnedFiles(for: project)
        guard !files.isEmpty else { return "" }

        var remaining = contextBudget.fileCharacterLimit
        var snippets: [String] = []

        for file in files where remaining > 0 {
            guard let text = try? String(contentsOfFile: file.path, encoding: .utf8) else { continue }
            let clipped = String(text.prefix(remaining))
            remaining -= clipped.count
            snippets.append("""
            --- \(file.relativePath) ---
            \(clipped)
            """)
        }

        return snippets.joined(separator: "\n\n")
    }

    private func mentionedContextSnippets(
        in prompt: String,
        project: Project? = nil,
        projectFiles: [ProjectFile]? = nil
    ) -> String {
        let projectFiles = projectFiles ?? self.projectFiles
        let mentions = mentionedRelativePaths(in: prompt, projectFiles: projectFiles)
        guard !mentions.isEmpty, let project = project ?? selectedProject else { return "" }

        var remaining = contextBudget.fileCharacterLimit
        var snippets: [String] = []
        var includedPaths = Set<String>()

        for relativePath in mentions where remaining > 0 {
            guard let path = resolvedProjectFilePath(relativePath: relativePath, projectPath: project.path),
                  !includedPaths.contains(path),
                  let text = try? String(contentsOfFile: path, encoding: .utf8) else {
                continue
            }

            includedPaths.insert(path)
            let clipped = String(text.prefix(remaining))
            remaining -= clipped.count
            snippets.append("""
            --- \(relativePath) ---
            \(clipped)
            """)
        }

        return snippets.joined(separator: "\n\n")
    }

    private func mentionedRelativePaths(
        in prompt: String,
        projectFiles: [ProjectFile]? = nil
    ) -> [String] {
        let projectFiles = projectFiles ?? self.projectFiles
        let knownRelativePaths = Set(projectFiles.filter { !$0.isDirectory }.map(\.relativePath))
        var matches: [String] = []

        for file in projectFiles where !file.isDirectory {
            let mention = "@\(file.relativePath)"
            if prompt.contains(mention), !matches.contains(file.relativePath) {
                matches.append(file.relativePath)
            }
        }

        let delimiters = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: ",;()[]{}<>\"'`"))
        for token in prompt.components(separatedBy: delimiters) {
            guard token.hasPrefix("@") else { continue }
            let relativePath = String(token.dropFirst())
                .trimmingCharacters(in: CharacterSet(charactersIn: ".:"))
            if knownRelativePaths.contains(relativePath), !matches.contains(relativePath) {
                matches.append(relativePath)
            }
        }

        return matches
    }

    private func workspaceSnapshotSnippet(
        project: Project?,
        projectFiles: [ProjectFile],
        contextSources: [ContextSource]
    ) -> String {
        guard let project else { return "" }

        var sections: [String] = []
        sections.append("""
        Root:
        \(project.path)
        """)

        let fileMap = projectFileMapSnippet(projectFiles)
        if !fileMap.isEmpty {
            sections.append("""
            File map:
            \(fileMap)
            """)
        }

        let context = discoveredContextSnippets(from: contextSources)
        if !context.isEmpty {
            sections.append("""
            Discovered README, manifest, and Codex context:
            \(context)
            """)
        }

        return sections.joined(separator: "\n\n")
    }

    private func projectFileMapSnippet(_ projectFiles: [ProjectFile]) -> String {
        guard !projectFiles.isEmpty else {
            return "No files were discovered under this root."
        }

        let maxEntries = 220
        let lines = projectFiles.prefix(maxEntries).map { file in
            let indentation = String(repeating: "  ", count: file.depth)
            return "\(indentation)- \(file.relativePath)\(file.isDirectory ? "/" : "")"
        }

        if projectFiles.count > maxEntries {
            return (lines + ["- ... \(projectFiles.count - maxEntries) more entries not shown"]).joined(separator: "\n")
        }

        return lines.joined(separator: "\n")
    }

    private func discoveredContextSnippets(from sources: [ContextSource]) -> String {
        let includedKinds: Set<ContextSourceKind> = [.readme, .manifest, .codex]
        let includedSources = sources
            .filter { includedKinds.contains($0.kind) }
            .sorted { lhs, rhs in
                if lhs.kind.label != rhs.kind.label {
                    return lhs.kind.label < rhs.kind.label
                }
                return lhs.relativePath < rhs.relativePath
            }
        guard !includedSources.isEmpty else { return "" }

        let maxCharacters = min(contextBudget.fileCharacterLimit / 2, 16_000)
        var remaining = maxCharacters
        var snippets: [String] = []

        for source in includedSources where remaining > 0 {
            guard let text = try? String(contentsOfFile: source.path, encoding: .utf8) else {
                continue
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let clipped = String(trimmed.prefix(remaining))
            remaining -= clipped.count
            snippets.append("""
            --- \(source.relativePath) (\(source.kind.label)) ---
            \(clipped)
            """)
        }

        return snippets.joined(separator: "\n\n")
    }

    private func memories(for project: Project?) -> [MemoryNote] {
        guard let project else { return memoriesForSelectedProject }
        return memoryNotes
            .filter { $0.projectID == project.id }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func pinnedFiles(for project: Project?) -> [PinnedContextFile] {
        guard let project else { return pinnedFilesForSelectedProject }
        return pinnedContextFiles
            .filter { $0.projectID == project.id }
            .sorted { $0.relativePath < $1.relativePath }
    }

    private func resolvedProjectFilePath(relativePath: String, projectPath: String) -> String? {
        let rootURL = URL(fileURLWithPath: projectPath, isDirectory: true).standardizedFileURL
        let fileURL = URL(fileURLWithPath: relativePath, relativeTo: rootURL).standardizedFileURL
        guard fileURL.path.hasPrefix(rootURL.path + "/") else { return nil }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return nil
        }

        return fileURL.path
    }

    private func inferredAgentMode(for prompt: String) -> AgentMode {
        let lowercased = prompt.lowercased()
        if lowercased.contains("review") || lowercased.contains("find bugs") {
            return .review
        }
        if lowercased.contains("plan") || lowercased.contains("implementation plan") {
            return .plan
        }
        if lowercased.contains("explain") || lowercased.contains("map") || lowercased.contains("understand") {
            return .explore
        }
        return .implement
    }

    private func persistPreferences() {
        let defaults = UserDefaults.standard
        defaults.set(provider.rawValue, forKey: "provider")
        defaults.set(model, forKey: "model")
        defaults.set(permissionMode.rawValue, forKey: "permissionMode")
        defaults.set(selectedProjectID?.uuidString, forKey: "selectedProjectID")
        defaults.set(selectedChatID?.uuidString, forKey: "selectedChatID")
        defaults.set(inspectorPanel.rawValue, forKey: "inspectorPanel")
        defaults.set(agentMode.rawValue, forKey: "agentMode")
        defaults.set(contextBudget.rawValue, forKey: "contextBudget")
    }
}
