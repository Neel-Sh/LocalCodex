<p align="center"><strong>Codex CLI</strong> is a local coding agent from OpenAI that helps you understand, edit, test, and ship code from your terminal.</p>

<p align="center">
  <img src="https://github.com/openai/codex/blob/main/.github/codex-cli-splash.png" alt="Codex CLI splash" width="80%" />
</p>

<p align="center">
  <a href="https://developers.openai.com/codex">Documentation</a>
  ·
  <a href="https://developers.openai.com/codex/ide">IDE extension</a>
  ·
  <a href="https://chatgpt.com/codex?app-landing-page=true">Desktop app</a>
  ·
  <a href="https://chatgpt.com/codex">Codex Web</a>
  ·
  <a href="https://github.com/openai/codex/releases">Releases</a>
</p>

---

## What Codex Is

Codex CLI is an agentic development tool that runs on your computer. You start
it inside a project, describe what you want in natural language, and Codex can
inspect files, explain code, propose edits, apply patches, run commands, execute
tests, and iterate with you until the task is complete.

This repository contains the open source implementation of the CLI, the
supporting Rust workspace, package wrappers, SDKs, app-server protocol pieces,
sandboxing utilities, and development tooling used to build and test Codex.

Use Codex when you want to:

- explore an unfamiliar codebase and ask grounded questions about it;
- make targeted code changes with an agent that can read and edit local files;
- run tests, linters, formatters, and project-specific commands during the same
  conversation;
- automate coding tasks in scripts or CI-like workflows through non-interactive
  mode;
- embed Codex into another application through the TypeScript or Python SDKs;
- experiment with Model Context Protocol integrations, app-server APIs, and
  local agent workflows.

If you want Codex in VS Code, Cursor, or Windsurf, install the
[Codex IDE extension](https://developers.openai.com/codex/ide). If you want the
desktop app experience, run `codex app` after installing the CLI or visit the
[Codex App page](https://chatgpt.com/codex?app-landing-page=true). If you are
looking for OpenAI's cloud-based agent experience, go to
[Codex Web](https://chatgpt.com/codex).

## Quickstart

### Install on macOS or Linux

```shell
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

### Install on Windows

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"
```

Windows support is intended for Windows 11 through WSL2. See
[Installing & building](./docs/install.md) for system requirements.

### Install with npm

```shell
npm install -g @openai/codex
```

### Install with Homebrew

```shell
brew install --cask codex
```

### Install from a GitHub release

You can also download a platform-specific archive from the
[latest GitHub release](https://github.com/openai/codex/releases/latest).
Common choices are:

| Platform            | Archive                                   |
| ------------------- | ----------------------------------------- |
| macOS Apple Silicon | `codex-aarch64-apple-darwin.tar.gz`       |
| macOS Intel         | `codex-x86_64-apple-darwin.tar.gz`        |
| Linux x86_64        | `codex-x86_64-unknown-linux-musl.tar.gz`  |
| Linux arm64         | `codex-aarch64-unknown-linux-musl.tar.gz` |

Each archive contains a single executable with the platform in the filename.
After extracting it, rename it to `codex` if you want the standard command name.

### Start Codex

```shell
codex
```

For a first useful prompt, open a project and ask Codex to orient itself:

```shell
cd /path/to/your/project
codex "explain this codebase to me"
```

## Authentication

On first launch, Codex prompts you to sign in. The recommended path is
**Sign in with ChatGPT**, which lets you use Codex through supported ChatGPT
plans such as Plus, Pro, Business, Edu, and Enterprise. See
[Codex in ChatGPT plans](https://help.openai.com/en/articles/11369540-codex-in-chatgpt)
for plan details.

Codex can also run with an API key. That path requires additional configuration;
see the [Codex authentication documentation](https://developers.openai.com/codex/auth)
and this repository's [authentication notes](./docs/authentication.md).

## Common Ways To Use Codex

### Interactive terminal UI

Run `codex` from a repository to start the fullscreen terminal experience:

```shell
codex
```

The interactive UI is best for exploratory work, multi-step changes, debugging,
reviewing diffs, approving commands, and collaborating with Codex in a loop.

### One-shot prompts

You can pass a prompt directly:

```shell
codex "find the source of this failing test and suggest a fix"
```

This still launches the normal local agent experience, but starts it with your
initial instruction already provided.

### Non-interactive mode

Use `codex exec` when you want Codex to run programmatically and print its
result to stdout:

```shell
codex exec "summarize the current git diff"
```

You can also pipe input through stdin:

```shell
git diff -- src tests | codex exec "review this diff for correctness risks"
```

If both a prompt argument and stdin are provided, Codex appends stdin as a
`<stdin>` block after the prompt. Use `--ephemeral` when you do not want the run
to persist session rollout files:

```shell
codex exec --ephemeral "check whether this repository has obvious setup issues"
```

For more detail, see [Non-interactive mode](./docs/exec.md).

### Desktop app

After installing Codex CLI, run:

```shell
codex app
```

The desktop app provides a richer local interface while using the same Codex
foundation.

### MCP server

Codex can run as an experimental Model Context Protocol server:

```shell
codex mcp-server
```

You can inspect it with the MCP inspector:

```shell
npx @modelcontextprotocol/inspector codex mcp-server
```

Use `codex mcp` to add, list, inspect, and remove MCP server launchers defined
in `config.toml`.

### Sandbox diagnostics

Codex includes a `sandbox` subcommand for running commands under the same
host-specific sandbox machinery used by the agent:

```shell
codex sandbox [COMMAND]...
```

On macOS, the sandbox uses Seatbelt. On Linux, it uses the Linux sandbox. On
Windows, it uses a restricted token. You can also pick a sandbox policy for a
normal Codex session:

```shell
codex --sandbox read-only
codex --sandbox workspace-write
codex --sandbox danger-full-access
```

See [Sandbox & approvals](./docs/sandbox.md) for the user-facing security model.

## Configuration

Codex uses TOML configuration. The Rust CLI reads `config.toml`, not the legacy
`config.json` format. Configuration controls model selection, sandbox policy,
approval behavior, MCP servers, notifications, logging, provider settings, and
other advanced behaviors.

Useful starting points:

- [Basic configuration](https://developers.openai.com/codex/config-basic)
- [Advanced configuration](https://developers.openai.com/codex/config-advanced)
- [Full configuration reference](https://developers.openai.com/codex/config-reference)
- [Repository configuration notes](./docs/config.md)
- [Example configuration](./docs/example-config.md)

You can also override individual settings at the command line:

```shell
codex -c log_dir=./.codex-log
codex -c sandbox_workspace_write.network_access=true
```

## Logging And Diagnostics

Codex is written primarily in Rust, so it honors `RUST_LOG` for logging control.

The TUI stores diagnostics in bounded local stores by default. To enable a
plaintext TUI log for a specific run:

```shell
codex -c log_dir=./.codex-log
tail -F ./.codex-log/codex-tui.log
```

`codex exec` defaults to `RUST_LOG=error` and prints messages inline, so most
non-interactive runs do not require a separate log file.

## Repository Layout

This is a monorepo. The most important top-level areas are:

| Path                                          | Purpose                                                        |
| --------------------------------------------- | -------------------------------------------------------------- |
| [`codex-rs/`](./codex-rs)                     | Main Rust workspace for the maintained Codex CLI.              |
| [`codex-cli/`](./codex-cli)                   | npm package wrapper for the `@openai/codex` executable.        |
| [`sdk/typescript/`](./sdk/typescript)         | TypeScript SDK for embedding Codex workflows.                  |
| [`sdk/python/`](./sdk/python)                 | Experimental Python SDK for `codex app-server` JSON-RPC v2.    |
| [`sdk/python-runtime/`](./sdk/python-runtime) | Runtime packaging support for Python SDK use.                  |
| [`docs/`](./docs)                             | Repository-local setup, contribution, config, and policy docs. |
| [`scripts/`](./scripts)                       | Release, packaging, and maintenance helpers.                   |
| [`tools/`](./tools)                           | Repo-specific developer tools and linters.                     |
| [`third_party/`](./third_party)               | Vendored third-party code used by the workspace.               |
| [`local-codex-app/`](./local-codex-app)       | Local Swift package for the macOS app surface.                 |

The Rust workspace under `codex-rs/` is the core of the project. Crate names are
prefixed with `codex-`, and each crate owns a focused part of the system.

Important Rust crates include:

| Path                                                              | Crate / role                                 |
| ----------------------------------------------------------------- | -------------------------------------------- |
| [`codex-rs/cli/`](./codex-rs/cli)                                 | Top-level CLI binary and subcommand routing. |
| [`codex-rs/core/`](./codex-rs/core)                               | Core agent logic and shared behavior.        |
| [`codex-rs/tui/`](./codex-rs/tui)                                 | Fullscreen terminal UI built with Ratatui.   |
| [`codex-rs/exec/`](./codex-rs/exec)                               | Headless `codex exec` mode for automation.   |
| [`codex-rs/app-server/`](./codex-rs/app-server)                   | Local app-server implementation.             |
| [`codex-rs/app-server-protocol/`](./codex-rs/app-server-protocol) | JSON-RPC protocol types.                     |
| [`codex-rs/codex-mcp/`](./codex-rs/codex-mcp)                     | MCP client integration support.              |
| [`codex-rs/mcp-server/`](./codex-rs/mcp-server)                   | Experimental MCP server.                     |
| [`codex-rs/sandboxing/`](./codex-rs/sandboxing)                   | Shared sandbox policy abstractions.          |
| [`codex-rs/linux-sandbox/`](./codex-rs/linux-sandbox)             | Linux sandbox implementation.                |
| [`codex-rs/file-search/`](./codex-rs/file-search)                 | CLI-accessible repository file search.       |
| [`codex-rs/thread-store/`](./codex-rs/thread-store)               | Conversation/thread persistence.             |

When you are looking for implementation details, start in `codex-rs/README.md`
and then follow crate-level README files where available.

## Building From Source

### Requirements

| Requirement      | Details                                                            |
| ---------------- | ------------------------------------------------------------------ |
| Operating system | macOS 12+, Ubuntu 20.04+/Debian 10+, or Windows 11 via WSL2.       |
| Git              | Optional but recommended; 2.23+ is needed for built-in PR helpers. |
| RAM              | 4 GB minimum, 8 GB recommended.                                    |
| Rust             | Installed through `rustup`; this workspace uses Rust 2024 edition. |
| Node.js          | Node 22+ for repo-level maintenance tooling.                       |
| pnpm             | pnpm 10.33.0 or compatible with the pinned package manager.        |
| just             | Used by the root development workflow.                             |
| cargo-nextest    | Used by the default Rust test command.                             |

### Clone and prepare the workspace

```shell
git clone https://github.com/openai/codex.git
cd codex

# Install Rust if needed.
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
rustup component add rustfmt
rustup component add clippy

# Install helper tools.
cargo install --locked just
cargo install --locked cargo-nextest
```

### Build the Rust CLI

```shell
cd codex-rs
cargo build
```

### Run Codex from source

From the repository root, the `justfile` automatically runs commands from
`codex-rs/`:

```shell
just codex "explain this repository"
just exec "summarize the current workspace"
```

You can also run Cargo directly:

```shell
cd codex-rs
cargo run --bin codex -- "explain this repository"
```

### Build with Bazel

The repository includes Bazel support for release and CI-style workflows:

```shell
just bazel-codex "explain this repository"
just bazel-test
```

To update or check the Bazel module lockfile after dependency changes:

```shell
just bazel-lock-update
just bazel-lock-check
```

## Development Workflow

The root `justfile` is the main local command surface. It sets
`codex-rs/` as the working directory for most Rust tasks.

| Command                        | What it does                                                    |
| ------------------------------ | --------------------------------------------------------------- |
| `just help`                    | Lists available recipes.                                        |
| `just codex [args]`            | Runs the Codex CLI from source.                                 |
| `just exec [args]`             | Runs `codex exec` from source.                                  |
| `just fmt`                     | Formats Rust and Python SDK code.                               |
| `just fix -p <crate>`          | Runs Clippy fixes for a specific crate.                         |
| `just clippy -p <crate>`       | Runs Clippy checks for a specific crate.                        |
| `just test -p <crate>`         | Runs tests for one crate through `cargo nextest`.               |
| `just test`                    | Runs the default workspace test suite and benchmark smoke test. |
| `just bench-smoke`             | Verifies benchmark targets start successfully.                  |
| `just mcp-server-run [args]`   | Runs the MCP server from source.                                |
| `just write-config-schema`     | Regenerates the config schema fixture.                          |
| `just write-app-server-schema` | Regenerates app-server protocol schema artifacts.               |
| `just argument-comment-lint`   | Runs the repo-specific Rust argument comment lint.              |
| `just log [args]`              | Tails logs from the state SQLite database.                      |

For repo-wide Markdown, JSON, workflow YAML, and JavaScript formatting:

```shell
pnpm install
pnpm format
pnpm format:fix
```

### Recommended loop for Rust changes

```shell
just fmt
just fix -p <crate-you-touched>
just test -p <crate-you-touched>
```

Run the full `just test` suite when you touch shared behavior or when you need a
complete local sweep. Avoid routine `--all-features` runs unless you are
specifically validating feature combinations.

### Snapshot tests

The TUI uses [`insta`](https://insta.rs/) snapshot tests for rendered output. If
you intentionally change terminal UI output:

```shell
just test -p codex-tui
cargo insta pending-snapshots -p codex-tui
cargo insta show -p codex-tui path/to/file.snap.new
cargo insta accept -p codex-tui
```

Install the tool if needed:

```shell
cargo install --locked cargo-insta
```

## SDKs

### TypeScript SDK

The TypeScript SDK lives in [`sdk/typescript/`](./sdk/typescript). It wraps the
`codex` CLI from `@openai/codex`, spawns it as a child process, and exchanges
JSONL events over stdin/stdout.

Install it with:

```shell
npm install @openai/codex-sdk
```

Minimal usage:

```typescript
import { Codex } from "@openai/codex-sdk";

const codex = new Codex();
const thread = codex.startThread();
const turn = await thread.run("Diagnose the test failure and propose a fix");

console.log(turn.finalResponse);
```

The SDK supports repeated turns on the same thread, streamed events, structured
JSON output schemas, local image attachments, working-directory controls,
environment overrides, and `--config` overrides. See
[`sdk/typescript/README.md`](./sdk/typescript/README.md).

### Python SDK

The experimental Python SDK lives in [`sdk/python/`](./sdk/python). It targets
`codex app-server` JSON-RPC v2 over stdio and exposes ergonomic sync and async
client APIs with Pydantic protocol models.

Local setup:

```shell
cd sdk/python
uv sync
source .venv/bin/activate
```

Minimal usage:

```python
from openai_codex import Codex

with Codex() as codex:
    thread = codex.thread_start(model="gpt-5")
    result = thread.run("Say hello in one sentence.")
    print(result.final_response)
```

See [`sdk/python/README.md`](./sdk/python/README.md) and
[`sdk/python/examples/README.md`](./sdk/python/examples/README.md).

## Security Model

Codex is designed to operate on local projects with explicit controls around
filesystem access, command execution, network access, and approvals. The exact
policy depends on your chosen sandbox mode and host platform.

At a high level:

- `read-only` lets Codex inspect files but prevents writes;
- `workspace-write` lets Codex write inside the workspace while restricting
  broader system access;
- `danger-full-access` disables sandboxing and should only be used when you are
  already operating inside an isolated environment.

For security guidance, see:

- [Sandbox & approvals](./docs/sandbox.md)
- [Codex security documentation](https://developers.openai.com/codex/security)
- [Repository security policy](./SECURITY.md)

To report a vulnerability or responsible AI concern, email
[security@openai.com](mailto:security@openai.com).

## Documentation Map

| Topic                 | Link                                                     |
| --------------------- | -------------------------------------------------------- |
| Official Codex docs   | <https://developers.openai.com/codex>                    |
| Install and build     | [`docs/install.md`](./docs/install.md)                   |
| Authentication        | [`docs/authentication.md`](./docs/authentication.md)     |
| Configuration         | [`docs/config.md`](./docs/config.md)                     |
| Example config        | [`docs/example-config.md`](./docs/example-config.md)     |
| Non-interactive mode  | [`docs/exec.md`](./docs/exec.md)                         |
| Sandbox and approvals | [`docs/sandbox.md`](./docs/sandbox.md)                   |
| Skills                | [`docs/skills.md`](./docs/skills.md)                     |
| Slash commands        | [`docs/slash_commands.md`](./docs/slash_commands.md)     |
| AGENTS.md guidance    | [`docs/agents_md.md`](./docs/agents_md.md)               |
| Contributing          | [`docs/contributing.md`](./docs/contributing.md)         |
| Open source fund      | [`docs/open-source-fund.md`](./docs/open-source-fund.md) |
| License details       | [`docs/license.md`](./docs/license.md)                   |
| Changelog             | [`CHANGELOG.md`](./CHANGELOG.md)                         |

## Contributing

External code contributions are currently by invitation only. Unsolicited pull
requests may be closed without review.

The most useful community contributions are:

- detailed bug reports with reproduction steps;
- issue comments that narrow root cause or describe expected behavior;
- enhancement requests that explain the workflow and why it matters;
- documentation feedback when setup or behavior is unclear.

If a Codex maintainer invites a pull request, follow
[`docs/contributing.md`](./docs/contributing.md). In short: start from an issue,
keep changes focused, add meaningful tests, update user-facing docs when
behavior changes, and run the relevant local checks before requesting review.

## License

This repository is licensed under the [Apache-2.0 License](./LICENSE).
