import SwiftUI

struct ComposerView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var runner: CodexProcessRunner
    var isCompact = false
    let submit: () -> Void

    private var canSubmit: Bool {
        !store.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && store.selectedProject != nil
    }

    private var editorHeight: ClosedRange<CGFloat> {
        isCompact ? 36...58 : 74...112
    }

    var body: some View {
        VStack(spacing: isCompact ? 2 : 0) {
            TextEditor(text: $store.prompt)
                .scrollContentBackground(.hidden)
                .font(.system(size: isCompact ? 14 : 15))
                .foregroundStyle(.white.opacity(0.90))
                .frame(minHeight: editorHeight.lowerBound, maxHeight: editorHeight.upperBound)
                .padding(.horizontal, isCompact ? 8 : 10)
                .padding(.top, isCompact ? 6 : 8)
                .overlay(alignment: .topLeading) {
                    if store.prompt.isEmpty {
                        Text("Do anything")
                            .font(.system(size: isCompact ? 14 : 15))
                            .foregroundStyle(.white.opacity(0.25))
                            .padding(.horizontal, isCompact ? 14 : 16)
                            .padding(.top, isCompact ? 12 : 16)
                    }
                }

            HStack(spacing: 12) {
                Button {
                    store.chooseProject()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.45))

                Menu {
                    Picker("Provider", selection: $store.provider) {
                        ForEach(LocalProvider.allCases) { provider in
                            Text(provider.label).tag(provider)
                        }
                    }
                    Divider()
                    Text("Model: \(store.model)")
                } label: {
                    Label(store.provider.label, systemImage: "cpu")
                        .foregroundStyle(CodexTheme.accent)
                }
                .menuStyle(.borderlessButton)

                Menu {
                    Picker("Permissions", selection: $store.permissionMode) {
                        ForEach(PermissionMode.allCases) { mode in
                            Label(mode.label, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                } label: {
                    Label(store.permissionMode.label, systemImage: store.permissionMode.systemImage)
                        .foregroundStyle(store.permissionMode == .fullAccess ? CodexTheme.accent : .white.opacity(0.68))
                }
                .menuStyle(.borderlessButton)

                Spacer()

                Menu {
                    ForEach(store.projects) { project in
                        Button(project.name) {
                            store.selectProject(project.id)
                        }
                    }
                    Divider()
                    Button("Open Project...") {
                        store.chooseProject()
                    }
                } label: {
                    Label(store.selectedProject?.name ?? "Project", systemImage: "folder")
                        .foregroundStyle(.white.opacity(0.55))
                }
                .menuStyle(.borderlessButton)

                Button {
                    if runner.isRunning {
                        runner.stop()
                    } else {
                        submit()
                    }
                } label: {
                    Image(systemName: runner.isRunning ? "stop.fill" : "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(CodexTheme.background)
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(runner.isRunning ? 0.55 : (canSubmit ? 0.82 : 0.28)), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!runner.isRunning && !canSubmit)
                .keyboardShortcut(.return, modifiers: [.command])
            }
            .font(.system(size: 13))
            .padding(.horizontal, isCompact ? 12 : 14)
            .padding(.bottom, isCompact ? 8 : 10)
        }
        .background(CodexTheme.surface, in: RoundedRectangle(cornerRadius: isCompact ? 16 : 18))
        .overlay(
            RoundedRectangle(cornerRadius: isCompact ? 16 : 18)
                .stroke(CodexTheme.border)
        )
        .shadow(color: .black.opacity(isCompact ? 0.14 : 0.18), radius: isCompact ? 12 : 16, y: isCompact ? 5 : 8)
    }
}
