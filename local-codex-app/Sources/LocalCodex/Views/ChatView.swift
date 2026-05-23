import AppKit
import SwiftUI

struct ChatView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var runner: CodexProcessRunner
    @State private var activeAssistantMessageID: UUID?
    @State private var runStartedAt: Date?

    var body: some View {
        VStack(spacing: 0) {
            header
            if store.messages.isEmpty {
                emptyState
            } else {
                conversation
            }
        }
        .background(CodexTheme.background)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.selectedProject?.name ?? "No Project")
                    .font(.headline)
                Text(store.selectedProject?.displayPath ?? "Open a project to begin")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            ProviderBadge(provider: store.provider, health: store.providerHealth, isRunning: runner.isRunning)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 22) {
            Spacer()
            Text("What should we work on in \(store.selectedProject?.name ?? "this project")?")
                .font(.system(size: 28, weight: .medium))
                .multilineTextAlignment(.center)

            ComposerView(store: store, runner: runner, submit: submit)
                .frame(maxWidth: 760)

            quickActions

            VStack(spacing: 0) {
                ForEach(store.suggestions) { suggestion in
                    Button {
                        store.selectSuggestion(suggestion)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: suggestion.icon)
                                .frame(width: 18)
                                .foregroundStyle(.white.opacity(0.45))
                            Text(suggestion.title)
                                .foregroundStyle(.white.opacity(0.48))
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if suggestion.id != store.suggestions.last?.id {
                        Divider().opacity(0.18)
                    }
                }
            }
            .frame(maxWidth: 760)

            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 42)
    }

    private var quickActions: some View {
        HStack(spacing: 8) {
            ForEach(store.workspaceActions) { action in
                Button {
                    store.useQuickAction(action)
                } label: {
                    Label(action.title, systemImage: action.icon)
                        .lineLimit(1)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.58))
                .help(action.prompt)
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
    }

    private var conversation: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(store.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .frame(maxWidth: 900, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 28)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
                .onChange(of: store.messages) { _, messages in
                    guard let last = messages.last else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            ComposerView(store: store, runner: runner, isCompact: true, submit: submit)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 28)
                .padding(.bottom, 18)
        }
    }

    private func submit() {
        guard let project = store.selectedProject else {
            store.chooseProject()
            return
        }
        let prompt = store.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        guard FileManager.default.fileExists(atPath: project.path) else {
            store.messages.append(ChatMessage(
                role: .assistant,
                text: "I cannot find \(project.displayPath). Open the project again so I can use a valid workspace."
            ))
            return
        }

        store.messages.append(ChatMessage(role: .user, text: prompt))
        let assistant = ChatMessage(role: .assistant, text: "Checking \(store.provider.label)...", isThinking: true)
        store.messages.append(assistant)
        activeAssistantMessageID = assistant.id
        runStartedAt = Date()
        store.prompt = ""

        Task { @MainActor in
            replaceActiveAssistantText("Indexing \(project.name)...")
            let workspaceContext = await store.refreshedWorkspaceContext(for: project)
            let runPrompt = store.promptWithWorkspaceContext(
                prompt,
                project: project,
                projectFiles: workspaceContext.0,
                contextSources: workspaceContext.1
            )

            await store.refreshProviderHealth()
            if let failure = store.providerHealth.failureMessage {
                replaceActiveAssistantText(failure)
                setActiveAssistantThinking(false)
                activeAssistantMessageID = nil
                runStartedAt = nil
                return
            }

            replaceActiveAssistantText("Thinking...")
            runner.run(
                prompt: runPrompt,
                project: project,
                provider: store.provider,
                model: store.model,
                permissionMode: store.permissionMode,
                onActivity: { chunk in
                    updateActiveAssistantActivity(chunk)
                }
            ) { chunk in
                replaceActiveAssistantText(chunk)
                setActiveAssistantThinking(false)
            } onFinished: { status in
                if status != 0 {
                    appendToActiveAssistant("\n\nProcess exited with status \(status). See Terminal for logs.")
                }
                setActiveAssistantThinking(false)
                activeAssistantMessageID = nil
                runStartedAt = nil
            }
        }
    }

    private func appendToActiveAssistant(_ chunk: String) {
        guard let id = activeAssistantMessageID,
              let index = store.messages.firstIndex(where: { $0.id == id }) else {
            return
        }
        store.messages[index].text += chunk
    }

    private func replaceActiveAssistantText(_ text: String) {
        guard let id = activeAssistantMessageID,
              let index = store.messages.firstIndex(where: { $0.id == id }) else {
            return
        }
        store.messages[index].text = text
    }

    private func updateActiveAssistantActivity(_ chunk: String) {
        guard let id = activeAssistantMessageID,
              let index = store.messages.firstIndex(where: { $0.id == id }),
              store.messages[index].isThinking else {
            return
        }

        let summary = ThinkingOutputSummarizer.summary(from: chunk)
        guard !summary.isEmpty else { return }
        store.messages[index].text = summary
    }

    private func setActiveAssistantThinking(_ isThinking: Bool) {
        guard let id = activeAssistantMessageID,
              let index = store.messages.firstIndex(where: { $0.id == id }) else {
            return
        }
        store.messages[index].isThinking = isThinking
    }
}

private struct ProviderBadge: View {
    let provider: LocalProvider
    let health: ProviderHealth
    let isRunning: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isRunning ? CodexTheme.good : health.indicatorColor)
                .frame(width: 8, height: 8)
            Text(provider.label)
                .font(.caption.weight(.medium))
            Text(isRunning ? "Running" : health.label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.48))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.07), in: Capsule())
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user {
                Spacer(minLength: 150)
            }

            VStack(alignment: .leading, spacing: message.role == .assistant ? 12 : 8) {
                if message.role != .user && !message.isThinking {
                    HStack(alignment: .center, spacing: 10) {
                        AssistantHeader(isThinking: message.isThinking)

                        Spacer()

                        if !message.isThinking {
                            MessageActions(text: message.text)
                        }
                    }
                }
                if message.isThinking {
                    ThinkingView(text: message.text, startedAt: message.createdAt)
                } else if message.role == .assistant {
                    MarkdownMessageView(markdown: message.text.isEmpty ? "Working..." : message.text)
                } else {
                    Text(message.text.isEmpty ? "Working..." : message.text)
                        .font(.system(message.role == .assistant ? .body : .callout, design: .default))
                        .textSelection(.enabled)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineSpacing(message.role == .assistant ? 4 : 1)
                }
            }
            .padding(.horizontal, message.role == .assistant ? 0 : 14)
            .padding(.vertical, message.role == .assistant ? 2 : 11)
            .frame(maxWidth: message.role == .assistant ? 900 : 560, alignment: .leading)
            .background(
                message.role == .user ? CodexTheme.surfaceRaised : Color.clear,
                in: RoundedRectangle(cornerRadius: message.role == .user ? 13 : 0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: message.role == .user ? 13 : 0)
                    .stroke(message.role == .assistant ? Color.clear : CodexTheme.border)
            )

            if message.role != .user {
                Spacer(minLength: 120)
            }
        }
    }
}

private struct AssistantHeader: View {
    let isThinking: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: isThinking ? "sparkles" : "checkmark.seal.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isThinking ? CodexTheme.accent : CodexTheme.good.opacity(0.9))
                .frame(width: 22, height: 22)
                .background(
                    (isThinking ? CodexTheme.accent : CodexTheme.good).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 6)
                )

            Text("Local Codex")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))

            Text(isThinking ? "Thinking" : "Response")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.34))
        }
    }
}

private struct MessageActions: View {
    let text: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: 6) {
            Button {
                copyText()
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(copied ? 0.72 : 0.42))
            .help(copied ? "Copied" : "Copy response")
        }
        .padding(.horizontal, 4)
    }

    private func copyText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        withAnimation(.easeOut(duration: 0.15)) {
            copied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.15)) {
                copied = false
            }
        }
    }
}

private struct ThinkingView: View {
    let text: String
    let startedAt: Date
    @State private var phase = 0
    @State private var now = Date()
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                ThinkingDots(phase: phase)

                Text("Thinking")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))

                Text("for \(elapsedText)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.38))

                Text(displayPhase)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(phaseColor.opacity(0.86))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(phaseColor.opacity(0.10), in: Capsule())
            }

            Text(displayText)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.58))
                .lineSpacing(2)
                .textSelection(.enabled)
                .padding(.leading, 33)
        }
        .padding(.vertical, 3)
        .frame(maxWidth: 720, alignment: .leading)
        .onReceive(timer) { _ in
            now = Date()
            withAnimation(.easeInOut(duration: 0.25)) {
                phase = (phase + 1) % 3
            }
        }
    }

    private var displayText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "Working...", trimmed != "Thinking..." else {
            return "Running Codex in the selected workspace"
        }
        return trimmed
    }

    private var displayPhase: String {
        let lowered = text.lowercased()
        if lowered.contains("apply_patch") || lowered.contains("patch") {
            return "Editing"
        }
        if lowered.contains("swift build") || lowered.contains("build") || lowered.contains("test") {
            return "Verifying"
        }
        if lowered.contains("rg ") || lowered.contains("sed ") || lowered.contains("find ") {
            return "Reading"
        }
        return "Live"
    }

    private var phaseColor: Color {
        switch displayPhase {
        case "Reading":
            return Color(hex: 0x7DD3FC)
        case "Editing":
            return CodexTheme.accent
        case "Verifying":
            return CodexTheme.good
        default:
            return .white.opacity(0.48)
        }
    }

    private var elapsedText: String {
        let seconds = max(0, Int(now.timeIntervalSince(startedAt)))
        guard seconds >= 60 else { return "\(seconds)s" }
        return "\(seconds / 60)m \(seconds % 60)s"
    }
}

private enum ThinkingOutputSummarizer {
    static func summary(from chunk: String) -> String {
        let cleaned = chunk
            .components(separatedBy: .newlines)
            .map(cleanLine)
            .filter { !$0.isEmpty }

        guard let line = cleaned.last else { return "" }

        if line.contains("Compiling ") {
            return line.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
        }
        if line.localizedCaseInsensitiveContains("building") {
            return "Building the app"
        }
        if line.localizedCaseInsensitiveContains("running") {
            return "Running the local Codex task"
        }
        if line.localizedCaseInsensitiveContains("applying") {
            return "Applying the latest changes"
        }
        if line.localizedCaseInsensitiveContains("error") {
            return line
        }

        return line.count > 96 ? String(line.prefix(93)) + "..." : line
    }

    private static func cleanLine(_ line: String) -> String {
        let withoutControlCodes = line.replacingOccurrences(
            of: "\u{001B}\\[[0-9;?]*[ -/]*[@-~]",
            with: "",
            options: .regularExpression
        )
        return withoutControlCodes.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ThinkingStatusPill: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(CodexTheme.good)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(.white.opacity(0.58))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 6))
    }
}

private enum ThinkingActivityState {
    case complete
    case active
    case pending
}

private struct ThinkingActivity: Identifiable {
    var id: String { title }
    let icon: String
    let title: String
    let detail: String
    let state: ThinkingActivityState
}

private struct ThinkingActivityRow: View {
    let row: ThinkingActivity

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: rowIcon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 16)

            Text(row.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(row.state == .pending ? 0.38 : 0.64))
                .frame(width: 72, alignment: .leading)

            Text(row.detail)
                .font(.caption)
                .foregroundStyle(.white.opacity(row.state == .pending ? 0.34 : 0.48))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }

    private var rowIcon: String {
        switch row.state {
        case .complete:
            return "checkmark.circle.fill"
        case .active:
            return row.icon
        case .pending:
            return "circle"
        }
    }

    private var iconColor: Color {
        switch row.state {
        case .complete:
            return CodexTheme.good.opacity(0.82)
        case .active:
            return CodexTheme.accent.opacity(0.86)
        case .pending:
            return .white.opacity(0.26)
        }
    }
}

private struct ThinkingDots: View {
    let phase: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index == phase % 3 ? CodexTheme.accent : Color.white.opacity(0.24))
                    .frame(width: 5, height: 5)
                    .scaleEffect(index == phase % 3 ? 1.16 : 0.86)
                    .animation(.easeInOut(duration: 0.25), value: phase)
            }
        }
        .frame(width: 24)
    }
}
