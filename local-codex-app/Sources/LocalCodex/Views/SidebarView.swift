import AppKit
import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: AppStore
    let toggleSidebar: () -> Void
    @Environment(\.openSettings) private var openSettings

    private var filteredProjects: [Project] {
        let query = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.projects }
        return store.projects.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.path.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topChrome
            navItems
            searchField
            ScrollView(showsIndicators: false) {
                projectSection
            }
            Spacer()
            bottomItems
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .background(CodexTheme.sidebar)
    }

    private var topChrome: some View {
        HStack(spacing: 14) {
            Button(action: toggleSidebar) {
                Image(systemName: "sidebar.left")
            }
            .buttonStyle(.plain)
            .help("Hide sidebar")
            Image(systemName: "chevron.left")
            Image(systemName: "chevron.right")
            Spacer()
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white.opacity(0.58))
        .padding(.bottom, 17)
    }

    private var navItems: some View {
        VStack(spacing: 2) {
            SidebarAction(title: "New chat", icon: "square.and.pencil") {
                store.newChat()
            }
            SidebarAction(title: "Search", icon: "magnifyingglass") {}
            SidebarAction(title: "Plugins", icon: "circle.grid.2x2") {}
            SidebarAction(title: "Automations", icon: "clock") {}
        }
        .padding(.bottom, 17)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CodexTheme.sidebarMuted)
            TextField("Search projects", text: $store.searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .padding(.bottom, 16)
    }

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Projects")
                    .font(.caption)
                    .foregroundStyle(CodexTheme.sidebarMuted)
                Spacer()
                Button {
                    store.chooseProject()
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 3)

            ForEach(filteredProjects) { project in
                ProjectBlock(
                    project: project,
                    isSelected: project.id == store.selectedProjectID,
                    chats: store.chats(for: project.id),
                    selectedChatID: store.selectedChatID,
                    selectProject: {
                        store.selectProject(project.id)
                    },
                    selectChat: { chatID in
                        if project.id != store.selectedProjectID {
                            store.selectProject(project.id)
                        }
                        store.selectChat(chatID)
                    }
                )
                .contextMenu {
                    Button("New Chat in \(project.name)") {
                        store.selectProject(project.id)
                        store.newChat()
                    }
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: project.path)])
                    }
                    Button("Remove from Sidebar") {
                        store.removeProject(project)
                    }
                }
            }
        }
        .padding(.bottom, 16)
    }

    private var bottomItems: some View {
        VStack(spacing: 2) {
            SidebarAction(title: "Open Project...", icon: "folder") {
                store.chooseProject()
            }
            SidebarAction(title: "Settings", icon: "gearshape") {
                openSettings()
            }
        }
        .padding(.bottom, 12)
    }
}

private struct SidebarAction: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 16)
                Text(title)
                    .lineLimit(1)
                Spacer()
            }
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ProjectBlock: View {
    let project: Project
    let isSelected: Bool
    let chats: [ChatSession]
    let selectedChatID: ChatSession.ID?
    let selectProject: () -> Void
    let selectChat: (ChatSession.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(action: selectProject) {
                HStack(spacing: 10) {
                    Image(systemName: "folder")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.58))
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.name)
                            .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                            .lineLimit(1)
                            .foregroundStyle(.white.opacity(isSelected ? 0.88 : 0.68))
                        Text(project.displayPath)
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundStyle(CodexTheme.sidebarMuted.opacity(0.86))
                    }
                    Spacer()
                    if !chats.isEmpty {
                        Text("\(chats.count)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(CodexTheme.sidebarMuted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.06), in: Capsule())
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
                .background(
                    Color.clear,
                    in: RoundedRectangle(cornerRadius: 8)
                )
            }
            .buttonStyle(.plain)

            if isSelected {
                VStack(spacing: 1) {
                    ForEach(chats) { chat in
                        ChatRow(
                            chat: chat,
                            isSelected: chat.id == selectedChatID
                        ) {
                            selectChat(chat.id)
                        }
                    }
                }
                .padding(.leading, 22)
                .padding(.bottom, 6)
            }
        }
    }
}

private struct ChatRow: View {
    let chat: ChatSession
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.44))
                    .frame(width: 14)
                Text(chat.displayTitle)
                    .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(isSelected ? 0.88 : 0.72))
                Spacer()
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                isSelected ? Color.white.opacity(0.085) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
    }
}
