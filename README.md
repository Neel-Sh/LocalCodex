# Local Codex

A native macOS workspace for running the Codex CLI with local models through Ollama or LM Studio. Select a project, add file context, run a coding task, and inspect terminal output and Git changes.

## Requirements

- macOS 14 or later and a Swift 5.9-compatible toolchain.
- A locally installed Codex CLI that supports `exec --oss --local-provider`.
- Ollama or LM Studio running locally, with a suitable model downloaded.

The app is a dependency-free SwiftPM executable. The CLI, model servers, and model weights are installed separately; this repository does not contain the upstream Codex source.

## Build

```sh
git clone https://github.com/Neel-Sh/LocalCodex.git
cd LocalCodex
swift build --package-path local-codex-app
```

To package and launch the desktop app:

```sh
cd local-codex-app
CODEX_BINARY=/absolute/path/to/codex ./script/build_and_run.sh
```

The script stops a running LocalCodex process, packages the app under `dist/`, copies it and the selected CLI to your Desktop, and opens it. Use the plain Swift build above when you only want a compile check.

## Workflow

1. Start your provider: Ollama at `127.0.0.1:11434`, or LM Studio at `127.0.0.1:1234`.
2. Open a project and choose a model available in that provider.
3. Pin files or use `@relative/path` to include context.
4. Run the task and review output and the Git diff before committing.

Workspace mode is the default. Full access disables the CLI's approvals and sandbox; the selected permission mode determines what a run can change. Project chat sessions are stored in UserDefaults, and the selected provider receives the assembled prompt context.

See the [app guide](local-codex-app/README.md) for configuration, shortcuts, storage, and troubleshooting, and [Contributing](CONTRIBUTING.md) for development checks. This is an independent app around the Codex CLI.
