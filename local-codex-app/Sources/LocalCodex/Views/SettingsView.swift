import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AppStore
    @StateObject private var downloader = ModelDownloadService()

    private let models: [ModelRecommendation] = [
        ModelRecommendation(
            name: "qwen2.5-coder:7b",
            title: "Best daily coding model",
            size: "4.7 GB",
            fit: "Recommended",
            note: "Strong code generation, fixing, and reasoning without pushing a 16 GB Mac too hard.",
            recommended: true
        ),
        ModelRecommendation(
            name: "qwen2.5-coder:14b",
            title: "Higher quality, slower",
            size: "9.0 GB",
            fit: "Stretch",
            note: "Better reasoning than 7B, but leave other heavy apps closed on 16 GB RAM.",
            recommended: false
        ),
        ModelRecommendation(
            name: "gemma3:4b",
            title: "Fast general assistant",
            size: "3.3 GB",
            fit: "Light",
            note: "Good for summaries, explanations, and quick edits with a large context window.",
            recommended: false
        ),
        ModelRecommendation(
            name: "llama3.2:3b",
            title: "Smallest reliable fallback",
            size: "2.0 GB",
            fit: "Very light",
            note: "Useful on battery or when you need the app to stay responsive.",
            recommended: false
        ),
        ModelRecommendation(
            name: "gpt-oss:20b",
            title: "Agentic reasoning option",
            size: "14 GB",
            fit: "Tight",
            note: "Designed to fit 16 GB systems, but expect memory pressure with long context.",
            recommended: false
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                modelControls
                downloads
                runtime
            }
            .padding(24)
        }
        .frame(width: 720, height: 640)
        .background(CodexTheme.background)
        .foregroundStyle(.white.opacity(0.9))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Settings")
                .font(.title2.weight(.semibold))
            Text("Local model setup for an M2 Pro Mac with 16 GB RAM.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var modelControls: some View {
        SettingsCard {
            Text("Active Model")
                .font(.headline)

            Picker("Provider", selection: $store.provider) {
                ForEach(LocalProvider.allCases) { provider in
                    Text(provider.label).tag(provider)
                }
            }
            .pickerStyle(.segmented)

            TextField("Model", text: $store.model)
                .textFieldStyle(.roundedBorder)

            Picker("Default permission", selection: $store.permissionMode) {
                ForEach(PermissionMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var downloads: some View {
        SettingsCard {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Download Models")
                        .font(.headline)
                    Text("Uses Ollama pull. Downloaded models can be selected immediately.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
                if downloader.isDownloading {
                    Button {
                        downloader.stop()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(models) { model in
                    ModelDownloadCard(
                        model: model,
                        isActive: downloader.activeModel == model.name,
                        select: {
                            store.provider = .ollama
                            store.model = model.name
                        },
                        download: {
                            store.provider = .ollama
                            store.model = model.name
                            downloader.download(model.name)
                        }
                    )
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Download Output")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
                ScrollView {
                    Text(downloader.output)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.68))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(height: 110)
                .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(CodexTheme.border))
            }
        }
    }

    private var runtime: some View {
        SettingsCard {
            Text("Runtime")
                .font(.headline)
            Text(CodexProcessRunner.codexBinaryPath())
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(.white.opacity(0.58))
        }
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .background(CodexTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CodexTheme.border))
    }
}

private struct ModelDownloadCard: View {
    let model: ModelRecommendation
    let isActive: Bool
    let select: () -> Void
    let download: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.name)
                        .font(.system(.callout, design: .monospaced).weight(.semibold))
                        .lineLimit(1)
                    Text(model.title)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.52))
                }
                Spacer()
                Text(model.fit)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(model.recommended ? CodexTheme.good : .white.opacity(0.55))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.06), in: Capsule())
            }

            Text(model.note)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Label(model.size, systemImage: "internaldrive")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Button("Use", action: select)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button(isActive ? "Downloading" : "Download", action: download)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isActive)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(model.recommended ? CodexTheme.good.opacity(0.38) : CodexTheme.border))
    }
}
