# AI Terminal Add-ons for Home Assistant

Home Assistant add-ons that run AI coding CLIs inside a web-based terminal embedded in your dashboard — with persistent authentication, persistent package management, image paste, and self-updating CLIs. Two add-ons are available and can be installed side by side:

- **Claude Terminal Pro** (`claude-terminal/`) — Anthropic's Claude Code CLI
- **Codex Terminal Pro** (`codex-terminal/`) — OpenAI's Codex CLI

## Add the Repository

1. Go to **Settings → Add-ons → Add-on Store**
2. Open the three-dots menu (⋮) in the top-right and select **Repositories**
3. Add: `https://github.com/sarpel/claude-code-ha`
4. Install **Claude Terminal Pro** and/or **Codex Terminal Pro** from the store and start them
5. Open the Web UI (sidebar icon or **OPEN WEB UI**) and sign in on first use (OAuth for Claude; API key or ChatGPT login for Codex)

> Claude Code requires a Claude Pro/Max or Anthropic Console account; Codex CLI requires an OpenAI API key or ChatGPT plan. There is no `image:` key in the add-on configs, so Home Assistant **builds the add-ons locally from source** on your device — a fresh build always installs the latest CLI.

## Claude Terminal Pro — Features

- **Web terminal** — full bash + Claude Code CLI in the browser via `ttyd`, auto-launching Claude on open
- **Persistent authentication** — OAuth credentials live in `/data` and survive restarts and updates
- **Persistent packages** — `persist-install` installs APK/pip packages into `/data/packages` so they survive reboots (plain `apk add`/`pip install` do not)
- **Image paste** — paste (Ctrl+V), drag-drop, or upload images for Claude to analyze (stored in `/data/images`)
- **Self-updating Claude Code** — optional persistent override installs Claude Code via Anthropic's native installer and keeps it on the latest (or stable) channel without rebuilding
- **Batteries included** — `git`, `gh` (GitHub CLI), and `ha` (Home Assistant CLI) are pre-installed
- **Multi-architecture** — `amd64`, `aarch64`, `armv7`

## Configuration Options

| Option | Default | Description |
| --- | --- | --- |
| `auto_launch_claude` | `true` | Start Claude on open, or show the interactive session picker when `false` |
| `dangerously_skip_permissions` | `false` | Run Claude with `--dangerously-skip-permissions` (unrestricted file access) |
| `persistent_terminal_session` | `true` | Keep the CLI running in a tmux session so a dropped connection resumes instead of restarting |
| `persistent_apk_packages` | `[]` | APK packages to auto-install on startup |
| `persistent_pip_packages` | `[]` | Python packages to auto-install on startup |
| `use_persistent_claude` | `false` | Use a persistent Claude Code install in `/data` instead of the image-baked one |
| `auto_update_claude_on_start` | `false` | With `use_persistent_claude`, fetch the selected channel on each startup |
| `claude_channel` | `latest` | Release channel for the persistent override (`latest` or `stable`) |

## Codex Terminal Pro — Features

Same stack as Claude Terminal Pro (web terminal, persistent auth/packages, image paste, self-updating CLI, `git`/`gh`/`ha` included), adapted for OpenAI's Codex CLI:

- **Codex CLI** installed as a complete npm package so companion executables such as the Code Mode host stay version-matched; architectures `amd64` and `aarch64`
- **Persistent auth & sessions** in `/data/.config/codex` (`CODEX_HOME`)
- **Headless login** via the `openai_api_key` option or the built-in auth helper
- **Side-by-side** with Claude Terminal Pro — Codex is ingress-only (no host ports published), so there is no conflict

| Option | Default | Description |
| --- | --- | --- |
| `auto_launch_codex` | `true` | Start Codex on open, or show the interactive session picker when `false` |
| `dangerously_bypass_approvals` | `false` | Run Codex with `--dangerously-bypass-approvals-and-sandbox` |
| `openai_api_key` | `""` | Log in with this API key on startup (skipped when already logged in) |
| `persistent_terminal_session` | `true` | Keep the CLI running in a tmux session so a dropped connection resumes instead of restarting |
| `persistent_apk_packages` | `[]` | APK packages to auto-install on startup |
| `persistent_pip_packages` | `[]` | Python packages to auto-install on startup |
| `use_persistent_codex` | `false` | Use a persistent Codex install in `/data` instead of the image-baked one |
| `auto_update_codex_on_start` | `false` | With `use_persistent_codex`, fetch the latest release on each startup |

## Documentation

- Claude: [add-on docs](claude-terminal/DOCS.md) · [persistent packages](claude-terminal/PERSISTENT_PACKAGES.md) · [image paste](claude-terminal/IMAGE_PASTE.md)
- Codex: [add-on docs](codex-terminal/DOCS.md) · [persistent packages](codex-terminal/PERSISTENT_PACKAGES.md) · [image paste](codex-terminal/IMAGE_PASTE.md)

## License

MIT — see [LICENSE](LICENSE). Claude Code is subject to Anthropic's Commercial Terms of Service; Codex CLI is subject to OpenAI's terms of use.
