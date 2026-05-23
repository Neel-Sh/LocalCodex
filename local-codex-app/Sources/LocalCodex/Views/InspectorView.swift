import AppKit
import SwiftUI

struct InspectorView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var runner: CodexProcessRunner
    let closeInspector: () -> Void
    let showBottomTerminal: () -> Void
    @State private var showRevertConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(store.inspectorPanel.label)
                    .font(.headline)
                Spacer()
                panelPicker
                Button(action: closeInspector) {
                    Image(systemName: "sidebar.right")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.42))
                .help("Hide inspector")
            }

            switch store.inspectorPanel {
            case .info:
                infoFileStructure
            case .terminal:
                terminalPanel
            case .diff:
                diffPanel
            }

            Spacer()
        }
        .padding(18)
        .background(CodexTheme.background.opacity(0.98))
        .alert("Revert all workspace changes?", isPresented: $showRevertConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Revert", role: .destructive) {
                Task { await store.revertAllChanges() }
            }
        } message: {
            Text("This will discard tracked edits and delete untracked files in the selected git project.")
        }
    }

    private var infoFileStructure: some View {
        VStack(alignment: .leading, spacing: 12) {
            projectTitleRow
            contextSources
            fileBrowser
        }
    }

    private var sessionControls: some View {
        InspectorCard {
            DetailLine(title: "Status", value: runner.status)
            DetailLine(title: "Provider Health", value: store.providerHealth.label)

            VStack(alignment: .leading, spacing: 6) {
                Text("Provider")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.38))
                Picker("Provider", selection: $store.provider) {
                    ForEach(LocalProvider.allCases) { provider in
                        Text(provider.label).tag(provider)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Model")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.38))
                TextField("Model", text: $store.model)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Permissions")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.38))
                Picker("Permissions", selection: $store.permissionMode) {
                    ForEach(PermissionMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
        }
    }

    private var projectTitleRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: store.selectedProject?.name ?? "Project") {
                HStack(spacing: 9) {
                    Button {
                        store.revealSelectedProjectInFinder()
                    } label: {
                        Image(systemName: "arrow.up.forward.square")
                    }
                    .buttonStyle(.plain)
                    .help("Reveal project in Finder")

                    Button {
                        Task {
                            await store.refreshProjectFiles()
                            await store.refreshProjectContext()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .help("Refresh files")
                }
            }

            Text(store.selectedProject?.displayPath ?? "No project selected")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }

    private var panelPicker: some View {
        HStack(spacing: 4) {
            ForEach(InspectorPanel.allCases) { panel in
                Button {
                    store.inspectorPanel = panel
                    if panel == .terminal {
                        showBottomTerminal()
                    }
                    if panel == .diff {
                        Task { await store.refreshDiff() }
                    }
                } label: {
                    Image(systemName: panel.systemImage)
                        .frame(width: 24, height: 22)
                        .background(
                            store.inspectorPanel == panel ? Color.white.opacity(0.10) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 7)
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(store.inspectorPanel == panel ? .white.opacity(0.86) : .white.opacity(0.42))
                .help(panel.label)
            }
        }
    }

    private var projectControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Project") {
                Button {
                    store.revealSelectedProjectInFinder()
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                }
                .buttonStyle(.plain)
                .help("Reveal project in Finder")
            }

            Text(store.selectedProject?.displayPath ?? "No project selected")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(3)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Button {
                    store.chooseProject()
                } label: {
                    Label("Open", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await store.refreshProjectFiles() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.small)
        }
    }

    private var contextSources: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Sources") {
                if store.isLoadingContextSources {
                    ProgressView()
                        .scaleEffect(0.55)
                        .frame(width: 16, height: 16)
                } else {
                    Text("\(store.contextSources.count)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.38))
                }
            }

            VStack(spacing: 2) {
                ForEach(store.contextSources.prefix(5)) { source in
                    ContextSourceRow(source: source) {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: source.path)])
                    }
                }
            }
            .overlay {
                if store.contextSources.isEmpty {
                    Text("No AGENTS.md or manifests found")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.38))
                }
            }
        }
    }

    private var fileBrowser: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Files") {
                if store.isLoadingProjectFiles {
                    ProgressView()
                        .scaleEffect(0.55)
                        .frame(width: 16, height: 16)
                } else {
                    Text("\(store.projectFiles.count)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.38))
                }
            }

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.35))
                TextField("Filter files", text: $store.fileSearchText)
                    .textFieldStyle(.plain)
            }
            .font(.caption)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(store.visibleProjectFiles) { file in
                        FileRow(file: file) {
                            store.appendFileMention(file)
                        } reveal: {
                            store.revealInFinder(file)
                        } pin: {
                            if store.isPinnedContextFile(file) {
                                store.unpinContextFile(file)
                            } else {
                                store.pinContextFile(file)
                            }
                        }
                    }
                }
            }
            .overlay {
                if store.visibleProjectFiles.isEmpty {
                    Text(store.isLoadingProjectFiles ? "Loading..." : "No files found")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.38))
                }
            }

            Divider().opacity(0.18)

            DetailLine(title: "Local Runtime", value: CodexProcessRunner.codexBinaryPath())
        }
    }

    private var contextPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Agent Mode") {
                    Text(store.contextSummary)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.38))
                }

                Picker("Agent Mode", selection: $store.agentMode) {
                    ForEach(AgentMode.allCases) { mode in
                        Label(mode.label, systemImage: mode.systemImage).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)

                Picker("Context Budget", selection: $store.contextBudget) {
                    ForEach(ContextBudget.allCases) { budget in
                        Text(budget.label).tag(budget)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            Divider().opacity(0.18)

            SectionHeader(title: "Pinned Files") {
                Text("\(store.pinnedFilesForSelectedProject.count)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.38))
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(store.pinnedFilesForSelectedProject) { pinned in
                        PinnedFileRow(pinned: pinned) {
                            store.unpinContextFile(pinned)
                        }
                    }
                }
            }
            .overlay {
                if store.pinnedFilesForSelectedProject.isEmpty {
                    Text("Pin files from the Info file tree")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.38))
                }
            }

            Divider().opacity(0.18)

            VStack(alignment: .leading, spacing: 6) {
                Text("Included Automatically")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.42))
                Label("Workspace root", systemImage: "folder.badge.gearshape")
                Label("Mentioned @files", systemImage: "at")
                Label("AGENTS.md instructions", systemImage: "text.badge.checkmark")
                Label("Project memory", systemImage: "brain")
                Label("Selected agent mode", systemImage: "sparkles")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.58))
        }
    }

    private var terminalPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            InspectorCard {
                DetailLine(title: "Status", value: runner.status)
                DetailLine(title: "Command", value: runner.lastCommand)

                HStack(spacing: 8) {
                    Button {
                        runner.clearTerminal()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)

                    if runner.isRunning {
                        Button {
                            runner.stop()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .controlSize(.small)

                Button {
                    showBottomTerminal()
                } label: {
                    Label("Show Bottom Terminal", systemImage: "rectangle.bottomthird.inset.filled")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var diffPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            DiffSummaryBar(
                summary: store.diffSummary,
                isLoading: store.isLoadingDiff,
                isReverting: store.isRevertingDiff
            ) {
                store.diffActionMessage = nil
                Task { await store.refreshDiff() }
            } revert: {
                showRevertConfirmation = true
            }

            if let message = store.diffActionMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(2)
                    .textSelection(.enabled)
            }

            if store.diffSummary.files.isEmpty {
                EmptyDiffView(text: store.diffSummary.rawDiff)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(store.diffSummary.files) { file in
                            DiffFileView(file: file)
                        }
                    }
                }
            }
        }
    }

    private var memoryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            InspectorCard {
                Text("Project Memory")
                    .font(.headline)
                Text("Saved notes are added to future prompts for this project.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))

                TextEditor(text: $store.memoryDraft)
                    .scrollContentBackground(.hidden)
                    .font(.system(size: 13))
                    .frame(height: 82)
                    .padding(8)
                    .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(CodexTheme.border))

                Button {
                    store.addMemoryNote()
                } label: {
                    Label("Remember", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(store.memoriesForSelectedProject) { note in
                        MemoryNoteRow(note: note) {
                            store.deleteMemoryNote(note)
                        }
                    }
                }
            }
            .overlay {
                if store.memoriesForSelectedProject.isEmpty {
                    Text("No saved memory yet")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.38))
                }
            }
        }
    }
}

private struct InspectorCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(14)
        .background(CodexTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CodexTheme.border))
    }
}

private struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.42))
            Spacer()
            trailing
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

private struct FileRow: View {
    let file: ProjectFile
    let mention: () -> Void
    let reveal: () -> Void
    let pin: () -> Void

    var body: some View {
        Button {
            if file.isDirectory {
                reveal()
            } else {
                mention()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: file.systemImage)
                    .frame(width: 15)
                    .foregroundStyle(file.isDirectory ? .white.opacity(0.48) : .white.opacity(0.36))
                Text(file.name)
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(file.isDirectory ? 0.68 : 0.58))
                Spacer(minLength: 0)
            }
            .font(.caption)
            .padding(.leading, CGFloat(file.depth) * 10)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !file.isDirectory {
                Button("Mention in Prompt", action: mention)
                Button("Pin to Context", action: pin)
            }
            Button("Reveal in Finder", action: reveal)
        }
        .help(file.relativePath)
    }
}

private struct PinnedFileRow: View {
    let pinned: PinnedContextFile
    let unpin: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "pin.fill")
                .frame(width: 15)
                .foregroundStyle(CodexTheme.accent.opacity(0.72))
            Text(pinned.relativePath)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.white.opacity(0.72))
            Spacer()
            Button(action: unpin) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.42))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct DiffSummaryBar: View {
    let summary: DiffSummary
    let isLoading: Bool
    let isReverting: Bool
    let refresh: () -> Void
    let revert: () -> Void

    private var canRevert: Bool {
        summary.changedFileCount > 0 && !isLoading && !isReverting
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Workspace changes")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.52))
                Spacer()
                Text("+\(summary.additions)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CodexTheme.good)
                Text("-\(summary.deletions)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CodexTheme.danger)
            }

            HStack(spacing: 8) {
                DiffStatPill(title: "Files", value: "\(summary.changedFileCount)")
                DiffStatPill(title: "Added", value: "\(summary.additions)", color: CodexTheme.good)
                DiffStatPill(title: "Removed", value: "\(summary.deletions)", color: CodexTheme.danger)
                Spacer()
                Button(action: revert) {
                    Image(systemName: isReverting ? "hourglass" : "arrow.uturn.backward.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(canRevert ? CodexTheme.danger.opacity(0.86) : .white.opacity(0.28))
                .disabled(!canRevert)
                .help("Revert workspace changes")

                Button(action: refresh) {
                    Image(systemName: isLoading ? "hourglass" : "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .help("Refresh diff")
            }
        }
        .padding(.bottom, 4)
    }
}

private struct DiffStatPill: View {
    let title: String
    let value: String
    var color: Color = .white.opacity(0.62)

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.34))
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct DiffFileView: View {
    let file: DiffFile
    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                expanded.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.38))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.path)
                            .font(.caption.weight(.medium))
                            .lineLimit(2)
                            .foregroundStyle(.white.opacity(0.82))
                        Text(file.status)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.38))
                    }
                    Spacer()
                    Text("+\(file.additions)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CodexTheme.good)
                    Text("-\(file.deletions)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CodexTheme.danger)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                if file.isBinary {
                    Text("Binary file changed")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.48))
                        .padding(10)
                } else if file.hunks.isEmpty {
                    Text("File changed without textual diff")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.48))
                        .padding(10)
                } else {
                    ForEach(file.hunks) { hunk in
                        DiffHunkView(hunk: hunk)
                    }
                }
            }
        }
        .background(CodexTheme.surface.opacity(0.52), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(CodexTheme.border))
    }
}

private struct DiffHunkView: View {
    let hunk: DiffHunk

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(hunk.header)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.045))

            ForEach(hunk.lines) { line in
                DiffLineView(line: line)
            }
        }
    }
}

private struct DiffLineView: View {
    let line: DiffLine

    private var background: Color {
        switch line.kind {
        case .addition: CodexTheme.good.opacity(0.16)
        case .removal: CodexTheme.danger.opacity(0.16)
        case .metadata: Color.white.opacity(0.035)
        case .context: Color.clear
        }
    }

    private var marker: String {
        switch line.kind {
        case .addition: "+"
        case .removal: "-"
        case .metadata: "\\"
        case .context: " "
        }
    }

    private var markerColor: Color {
        switch line.kind {
        case .addition: CodexTheme.good
        case .removal: CodexTheme.danger
        default: .white.opacity(0.35)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(line.oldNumber.map(String.init) ?? "")
                .frame(width: 24, alignment: .trailing)
                .foregroundStyle(.white.opacity(0.28))
            Text(line.newNumber.map(String.init) ?? "")
                .frame(width: 24, alignment: .trailing)
                .foregroundStyle(.white.opacity(0.28))
            Text(marker)
                .frame(width: 10)
                .foregroundStyle(markerColor)
            Text(line.text.isEmpty ? " " : line.text)
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .font(.system(.caption2, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(background)
        .textSelection(.enabled)
    }
}

private struct EmptyDiffView: View {
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 24))
                .foregroundStyle(CodexTheme.good.opacity(0.72))
            Text(text.isEmpty ? "No local changes." : text)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.52))
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }
}

private struct ContextSourceRow: View {
    let source: ContextSource
    let reveal: () -> Void

    var body: some View {
        Button(action: reveal) {
            HStack(spacing: 8) {
                Image(systemName: source.kind.systemImage)
                    .frame(width: 15)
                    .foregroundStyle(.white.opacity(0.42))
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.relativePath)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.white.opacity(0.68))
                    if !source.preview.isEmpty {
                        Text(source.preview)
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundStyle(.white.opacity(0.36))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(source.kind.label)
    }
}

private struct DetailLine: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.38))
            Text(value)
                .font(title == "Local Runtime" || title == "Command" ? .system(.caption, design: .monospaced) : .callout)
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(title == "Local Runtime" || title == "Command" ? 5 : 2)
                .textSelection(.enabled)
        }
    }
}

private struct MemoryNoteRow: View {
    let note: MemoryNote
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.text)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.74))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text(note.createdAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.36))
                Spacer()
                Button(action: delete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.44))
            }
        }
        .padding(10)
        .background(CodexTheme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(CodexTheme.border))
    }
}
