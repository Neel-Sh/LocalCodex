# Local Codex App

Local Codex is a macOS SwiftUI shell for running the local Codex CLI against a selected project with an offline/local model provider. It is built as a Swift Package Manager executable and packaged by `script/build_and_run.sh` into a desktop app bundle named `Local Codex.app`.

The app is intentionally project-focused: pick a workspace folder, choose a local provider and model, ask for a coding task, and the app launches the local `codex` binary in non-interactive `exec` mode from that workspace.

## What It Does

- Runs on macOS 14 or newer.
- Provides a native SwiftUI chat interface for local Codex runs.
- Supports Ollama and LM Studio as local model providers.
- Runs Codex with `codex exec --oss --local-provider <provider> --model <model>`.
- Lets you open and switch between project folders.
- Keeps per-project chat sessions in `UserDefaults`.
- Scans selected projects for useful context such as `AGENTS.md`, `README.md`, manifests, Xcode project files, and `.codex/environment.toml`.
- Lets you pin files or mention files with `@relative/path` so their contents are included in the prompt context.
- Includes quick actions for code review, build/test repair, codebase mapping, and feature planning.
- Shows provider health, terminal output, project files, context sources, and Git diff information in an inspector.
- Can revert all local Git changes in the selected project after confirmation.
- Includes a settings window for provider, model, permission mode, runtime path, and Ollama model downloads.

## Project Structure

```text
local-codex-app/
├── Package.swift
├── Sources/LocalCodex/
│   ├── App/
│   ├── Models/
│   ├── Services/
│   ├── Stores/
│   ├── Support/
│   └── Views/
├── script/
│   └── build_and_run.sh
└── .codex/environments/
    └── environment.toml
```

Important files:

| Path                                                      | Purpose                                                                                                       |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `Package.swift`                                           | SwiftPM package definition for the `LocalCodex` executable.                                                   |
| `Sources/LocalCodex/App/LocalCodexApp.swift`              | App entry point, app delegate, window setup, settings scene, and Project menu.                                |
| `Sources/LocalCodex/Stores/AppStore.swift`                | Main app state, project/session persistence, prompt context assembly, file pinning, and diff refresh actions. |
| `Sources/LocalCodex/Services/CodexProcessRunner.swift`    | Launches the local Codex binary and streams stdout/stderr into the UI.                                        |
| `Sources/LocalCodex/Services/ProviderHealthService.swift` | Checks Ollama or LM Studio local server health.                                                               |
| `Sources/LocalCodex/Services/ModelDownloadService.swift`  | Runs `ollama pull <model>` from the settings window.                                                          |
| `Sources/LocalCodex/Services/ProjectContextService.swift` | Finds context sources such as `AGENTS.md`, manifests, and `.codex/environment.toml`.                          |
| `Sources/LocalCodex/Services/ProjectFileScanner.swift`    | Builds the project file list shown in the inspector.                                                          |
| `Sources/LocalCodex/Services/GitDiffService.swift`        | Reads Git status/diff and performs the confirmed revert operation.                                            |
| `Sources/LocalCodex/Views/ContentView.swift`              | Top-level layout with sidebar, chat, inspector, and bottom terminal.                                          |
| `Sources/LocalCodex/Views/ChatView.swift`                 | Chat transcript, empty state, quick actions, and submit flow.                                                 |
| `Sources/LocalCodex/Views/ComposerView.swift`             | Prompt editor, provider selector, permission selector, project selector, and run/stop button.                 |
| `Sources/LocalCodex/Views/InspectorView.swift`            | Info, Terminal, and Diff inspector panels.                                                                    |
| `Sources/LocalCodex/Views/SettingsView.swift`             | Provider/model settings and Ollama model download UI.                                                         |
| `script/build_and_run.sh`                                 | Builds, packages, copies to Desktop, and launches the app.                                                    |

## Requirements

- macOS 14 or newer.
- Xcode command line tools or a Swift toolchain with SwiftPM.
- A Codex CLI binary. The app can find one from `CODEX_BINARY`, a local sibling `codex-rs/target/debug/codex` checkout, a `codex` executable next to the packaged app, or `codex` on PATH.
- One local model provider:
  - Ollama running on `http://127.0.0.1:11434`.
  - LM Studio local server running on `http://127.0.0.1:1234`.

The package itself is dependency-free SwiftUI/AppKit code. It does not declare third-party Swift package dependencies.

## Make Codex Available

The app launches a local Codex binary. There are three supported ways to make that binary available.

Use an installed CLI:

```shell
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

Or point the build script at a specific binary:

```shell
CODEX_BINARY=/path/to/codex ./script/build_and_run.sh
```

For development with a separately obtained Codex source checkout, build the CLI there and pass the resulting binary through `CODEX_BINARY`. This repository contains only the Swift app; it does not include `codex-rs`:

```shell
cd /path/to/codex/codex-rs
cargo build -p codex-cli
```

The app checks these locations in order:

1. `CODEX_BINARY`, if set.
2. A local development binary at `../codex-rs/target/debug/codex`.
3. A `codex` executable next to the packaged app.
4. `codex` on PATH.

## Run The App

From this folder:

```shell
./script/build_and_run.sh
```

The script:

1. Stops any currently running `LocalCodex` process.
2. Resolves a Codex binary from `CODEX_BINARY`, a local `codex-rs` checkout, or PATH.
3. Runs `swift build --package-path local-codex-app`.
4. Creates `local-codex-app/dist/Local Codex.app`.
5. Generates an app icon when `../LocalChatImage.icon/Assets/Image.png` is available.
6. Copies the app bundle to `~/Desktop/Local Codex.app`.
7. Copies the resolved Codex binary to `~/Desktop/codex` when one is available.
8. Opens the desktop copy.

## Script Modes

`script/build_and_run.sh` accepts a mode argument:

| Command                                 | Behavior                                                      |
| --------------------------------------- | ------------------------------------------------------------- |
| `./script/build_and_run.sh`             | Build, package, copy to Desktop, and open the app.            |
| `./script/build_and_run.sh run`         | Same as the default behavior.                                 |
| `./script/build_and_run.sh --verify`    | Open the app and verify that a `LocalCodex` process starts.   |
| `./script/build_and_run.sh --debug`     | Build/package and launch the app binary under `lldb`.         |
| `./script/build_and_run.sh --logs`      | Open the app and stream logs for the `LocalCodex` process.    |
| `./script/build_and_run.sh --telemetry` | Open the app and stream logs for subsystem `dev.local.codex`. |

## Provider Setup

### Ollama

Install and start Ollama, then pull a model:

```shell
ollama pull qwen2.5-coder:7b
```

The app defaults Ollama to:

```text
gpt-oss:20b
```

The settings window also includes buttons for several recommended Ollama models:

- `qwen2.5-coder:7b`
- `qwen2.5-coder:14b`
- `gemma3:4b`
- `llama3.2:3b`
- `gpt-oss:20b`

### LM Studio

Start LM Studio, load a model, and turn on the local server. The app checks:

```text
http://127.0.0.1:1234/v1/models
```

The default LM Studio model string is:

```text
openai/gpt-oss-20b
```

Update the model name in Settings or from the composer menu if your local LM Studio model uses a different identifier.

## How Codex Is Launched

`CodexProcessRunner` builds a command like this:

```shell
codex exec \
  --oss \
  --local-provider ollama \
  --model qwen2.5-coder:7b \
  --cd /path/to/project \
  --skip-git-repo-check \
  --color never \
  --output-last-message /tmp/local-codex-...-last-message.txt \
  --sandbox workspace-write \
  "<prompt with workspace context>"
```

For full access mode, the app uses:

```shell
--dangerously-bypass-approvals-and-sandbox
```

The default permission mode is Workspace. Full access should only be used when you intentionally want Codex to operate without sandbox restrictions.

## Workspace Context

Before each run, the app refreshes context for the selected project and wraps the user request with:

- project name and root directory;
- selected agent mode instructions;
- coding reliability rules;
- a project file snapshot;
- discovered `AGENTS.md` instructions;
- saved project memory notes;
- files referenced with `@relative/path`;
- pinned context files.

Context files are clipped according to the selected budget:

| Budget   | Character limit |
| -------- | --------------: |
| Compact  |           8,000 |
| Balanced |          24,000 |
| Deep     |          60,000 |

Ignored folders include `.git`, `.swiftpm`, `.build`, `build`, `dist`, `node_modules`, `target`, and `DerivedData`.

## UI Overview

### Sidebar

The sidebar lists projects and chat sessions. It supports:

- opening a project with `Command-O` or the folder buttons;
- switching projects;
- starting a new chat;
- filtering projects;
- revealing or removing projects from the context menu.

### Chat

The chat view includes:

- a provider health badge;
- quick actions for common coding workflows;
- streamed status updates while Codex runs;
- Markdown-style assistant messages;
- copy controls for assistant output.

Submit with `Command-Return`. The same button becomes Stop while a Codex process is running.

### Composer

The composer controls:

- the current prompt;
- provider selection;
- permission mode;
- selected project;
- run/stop behavior.

### Inspector

The inspector has three panels:

- Info: project path, context sources, file browser, file mentions, pinned files, and runtime path.
- Terminal: raw Codex stdout/stderr and last command.
- Diff: Git status/diff summary and a confirmed revert-all-changes action.

### Settings

Settings include:

- active provider;
- active model string;
- default permission mode;
- Ollama model recommendations and downloads;
- download output;
- detected Codex runtime path.

## Persistence

The app stores preferences in `UserDefaults`, including:

- provider;
- model;
- permission mode;
- selected project;
- selected chat;
- inspector panel;
- agent mode;
- context budget;
- projects;
- chat sessions and messages;
- memory notes;
- pinned context files;
- sidebar and inspector widths.

There is no database or remote sync layer.

## Troubleshooting

### Codex binary missing

Install Codex, set `CODEX_BINARY`, or build the CLI from source:

```shell
CODEX_BINARY=/path/to/codex ./script/build_and_run.sh
```

For local source development, first build the CLI in your separate Codex checkout. Then, from this app directory, use its absolute binary path:

```shell
CODEX_BINARY=/path/to/codex/codex-rs/target/debug/codex ./script/build_and_run.sh
```

### Provider is offline

For Ollama:

```shell
ollama list
ollama pull qwen2.5-coder:7b
```

For LM Studio, confirm the local server is enabled and reachable at port `1234`.

### Model name does not work

The app passes the model string directly to Codex. Confirm the exact local model name in your provider and update Settings.

### App opens but no answer appears

Open the Terminal inspector or bottom terminal panel. The raw Codex output and exit status are shown there.

### Revert removed files unexpectedly

The Diff panel's revert action runs Git reset/restore/clean operations for the selected project after confirmation. It can delete untracked files. Use it only when you are comfortable discarding local workspace changes.

## Development Notes

- Keep source code under `Sources/LocalCodex/`.
- Keep generated SwiftPM build output out of source control.
- Keep packaged app output under `dist/` out of source control unless you intentionally want to commit build artifacts.
- The app currently has no automated test target.
- The build script writes `Info.plist` during packaging and uses bundle id `dev.local.codex`.
- The app uses `NSOpenPanel` for project selection and `NSWorkspace` for Finder reveal actions.

## Git Hygiene

The source files that matter are `Package.swift`, `Sources/LocalCodex/**`, `script/build_and_run.sh`, `.codex/environments/environment.toml`, and this README.

Generated or machine-local files such as `.build/`, `dist/`, and `.DS_Store` should normally stay untracked.
