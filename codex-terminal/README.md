# Codex Terminal Pro

A web-based terminal with OpenAI's Codex CLI pre-installed, running directly inside your Home Assistant dashboard.

## What it does

Codex Terminal Pro gives you Codex — OpenAI's AI coding agent — in a browser terminal with direct access to your Home Assistant `/config`. Use it to write and debug automations, fix YAML, manage entities, or develop custom components, all from the dashboard.

It adds persistent authentication, persistent package management, image paste, and an optional self-updating Codex CLI on top of a standard terminal add-on. It is the sibling of **Claude Terminal Pro** from the same repository — both can be installed side by side.

## Quick start

The terminal launches Codex automatically when you open it:

```bash
# Ask a single question (non-interactive)
codex exec "write an automation that turns on lights when motion is detected after sunset"

# Start an interactive session
codex

# See all options
codex --help
```

The terminal opens in `/config`, so Codex can read and edit your Home Assistant files directly.

## Installation

1. **Settings → Add-ons → Add-on Store**
2. Three-dots menu (⋮) → **Repositories** → add `https://github.com/sarpel/claude-code-ha`
3. Install **Codex Terminal Pro** and start it
4. Open the Web UI and sign in on first use (see Authentication below)

## Authentication

Codex supports two account types:

- **OpenAI API key** (recommended in containers) — set the `openai_api_key` add-on option, or use the session picker's auth helper, or run `printenv OPENAI_API_KEY | codex login --with-api-key` manually. Credentials persist in `/data/.config/codex/auth.json`.
- **ChatGPT plan login** (`codex login`) — uses a browser OAuth flow that redirects to `localhost:1455`, which cannot traverse Home Assistant ingress. It only works with SSH port forwarding; the auth helper explains the steps.

## Configuration

All options are optional; the add-on works out of the box (you still need to authenticate once).

| Option | Default | Description |
| --- | --- | --- |
| `auto_launch_codex` | `true` | Auto-start Codex, or show the session picker when `false` |
| `dangerously_bypass_approvals` | `false` | Run Codex with `--dangerously-bypass-approvals-and-sandbox` |
| `openai_api_key` | `""` | If set, logs in with this API key on startup (skipped when already logged in) |
| `persistent_terminal_session` | `true` | Keep the CLI running in a tmux session so a dropped connection (closed or backgrounded dashboard) resumes instead of restarting |
| `persistent_apk_packages` | `[]` | APK packages to auto-install on startup |
| `persistent_pip_packages` | `[]` | Python packages to auto-install on startup |
| `use_persistent_codex` | `false` | Use a persistent complete Codex package kept under `/data/home/.local` |
| `auto_update_codex_on_start` | `false` | With `use_persistent_codex`, install the latest complete package from npm on each startup |

See [DOCS.md](DOCS.md) for full details and examples.

## How it works

- **Web UI / terminal** — port `7680` (container) serves the web interface (image upload + embedded terminal) over Home Assistant ingress; `ttyd` runs the terminal on `7681` behind it. Neither port is published on the host — access goes through ingress only, so the terminal is never exposed to the local network, and Claude Terminal Pro can run at the same time (each add-on gets its own ingress panel).
- **Persistence** — everything that must survive restarts lives under `/data`: credentials and sessions (`/data/.config/codex`), installed packages (`/data/packages`), uploaded images (`/data/images`), and the optional complete Codex package (`/data/home/.local`, with its launcher in `bin/`).
- **Pre-installed tools** — `git`, `gh` (GitHub CLI), `ha` (Home Assistant CLI), `ripgrep`, Python 3, and the `persist-install` helper.

## Installing packages

Use `persist-install` so packages survive restarts (plain `apk add`/`pip install` are lost on restart):

```bash
persist-install git vim htop          # APK packages
persist-install --python requests pandas
persist-install --list
```

See [PERSISTENT_PACKAGES.md](PERSISTENT_PACKAGES.md).

## Troubleshooting

```bash
codex --version      # confirm the running version
codex login status   # check authentication
```

- If the terminal disconnects, refresh the page (it auto-reconnects).
- Check the add-on **Logs** tab for startup details.
- Codex's Linux command sandbox (bubblewrap/Landlock) is typically unavailable inside the add-on container; Codex then asks for approval before running commands. Enable `dangerously_bypass_approvals` only if you accept unrestricted execution.
- Credentials persist across restarts; you should not need to re-authenticate.

## License

MIT — see [LICENSE](../LICENSE). Codex CLI itself is subject to OpenAI's terms of use.
