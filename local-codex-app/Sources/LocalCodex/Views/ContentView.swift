import SwiftUI

struct ContentView: View {
    @ObservedObject var store: AppStore
    @StateObject private var runner = CodexProcessRunner()
    @SceneStorage("sidebarVisible") private var sidebarVisible = true
    @SceneStorage("inspectorVisible") private var inspectorVisible = true
    @SceneStorage("bottomTerminalVisible") private var bottomTerminalVisible = false
    @AppStorage("sidebarWidth") private var sidebarWidth = 292.0
    @AppStorage("inspectorWidth") private var inspectorWidth = 300.0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if sidebarVisible {
                    SidebarView(store: store) {
                        sidebarVisible = false
                    }
                    .frame(width: sidebarWidth)

                    ResizeHandle(
                        edge: .left,
                        value: $sidebarWidth,
                        range: 220...420
                    )
                } else {
                    CollapsedSidebarButton(systemImage: "sidebar.left", help: "Show sidebar") {
                        sidebarVisible = true
                    }
                }

                ChatView(store: store, runner: runner)
                    .frame(minWidth: 620)

                if inspectorVisible {
                    ResizeHandle(
                        edge: .right,
                        value: $inspectorWidth,
                        range: 260...560
                    )

                    InspectorView(
                        store: store,
                        runner: runner,
                        closeInspector: {
                            inspectorVisible = false
                        },
                        showBottomTerminal: {
                            bottomTerminalVisible = true
                        }
                    )
                    .frame(width: inspectorWidth)
                } else {
                    CollapsedSidebarButton(systemImage: "sidebar.right", help: "Show inspector") {
                        inspectorVisible = true
                    }
                }
            }

            if bottomTerminalVisible {
                Divider().opacity(0.2)
                BottomTerminalView(runner: runner) {
                    bottomTerminalVisible = false
                }
                .frame(height: 230)
            }
        }
        .background(CodexTheme.background)
        .foregroundStyle(.white.opacity(0.92))
        .onReceive(NotificationCenter.default.publisher(for: .openProjectRequested)) { _ in
            store.chooseProject()
        }
        .animation(.easeInOut(duration: 0.18), value: sidebarVisible)
        .animation(.easeInOut(duration: 0.18), value: inspectorVisible)
        .animation(.easeInOut(duration: 0.18), value: bottomTerminalVisible)
    }
}

private enum ResizeEdge {
    case left
    case right
}

private struct ResizeHandle: View {
    let edge: ResizeEdge
    @Binding var value: Double
    let range: ClosedRange<Double>
    @State private var startValue: Double?
    @State private var hovering = false

    var body: some View {
        Rectangle()
            .fill(hovering ? Color.white.opacity(0.14) : Color.white.opacity(0.08))
            .frame(width: 5)
            .overlay {
                Rectangle()
                    .fill(Color.white.opacity(hovering ? 0.24 : 0.12))
                    .frame(width: 1)
            }
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if startValue == nil {
                            startValue = value
                        }
                        let start = startValue ?? value
                        let delta = edge == .left ? gesture.translation.width : -gesture.translation.width
                        value = min(max(start + delta, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in
                        startValue = nil
                    }
            )
            .help("Drag to resize")
    }
}

private struct CollapsedSidebarButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        VStack {
            Button(action: action) {
                Image(systemName: systemImage)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.64))
            .help(help)
            .padding(.top, 12)
            Spacer()
        }
        .frame(width: 44)
        .background(CodexTheme.background)
    }
}

private struct BottomTerminalView: View {
    @ObservedObject var runner: CodexProcessRunner
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Label("Terminal", systemImage: "terminal")
                    .font(.system(size: 13, weight: .semibold))
                Text(runner.status)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Button {
                    runner.clearTerminal()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("Clear terminal")

                if runner.isRunning {
                    Button {
                        runner.stop()
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .buttonStyle(.plain)
                    .help("Stop command")
                }

                Button(action: close) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help("Close terminal")
            }
            .foregroundStyle(.white.opacity(0.72))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)

            ScrollView {
                Text(runner.terminalOutput.isEmpty ? "Terminal output will appear here when Codex runs." : runner.terminalOutput)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(runner.terminalOutput.isEmpty ? .white.opacity(0.36) : .white.opacity(0.74))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
        }
        .background(Color.black.opacity(0.18))
    }
}
