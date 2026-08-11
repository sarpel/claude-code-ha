# Codex Terminal Pro — Documentation

A web-based terminal with OpenAI's Codex CLI, running inside Home Assistant with persistent auth, persistent packages, and image paste.

## Installation

1. **Settings → Add-ons → Add-on Store**
2. Three-dots menu (⋮) → **Repositories** → add `https://github.com/sarpel/claude-code-ha`
3. Install **Codex Terminal Pro** and start it
4. Open the Web UI and authenticate on first use (see below)

## Authentication

Credentials persist in `/data/.config/codex` across restarts and updates. Two paths:

### API key (recommended in containers)

- Easiest: put your key in the `openai_api_key` add-on option; the add-on logs in automatically on startup (it never overwrites an existing login).
- Or use the session picker → **OpenAI authentication helper** → API key login.
- Or manually: `printenv OPENAI_API_KEY | codex login --with-api-key`

### ChatGPT plan login

`codex login` starts an OAuth flow that redirects to `localhost:1455` inside the container, so it cannot complete through the Home Assistant UI. It works only with SSH port forwarding (forward port 1455 to the add-on host); the auth helper prints the exact steps. Most users should prefer the API key path.

## Usage

Codex launches automatically when you open the terminal. You can also run it manually:

```bash
codex                    # interactive session
codex exec "your prompt" # one-shot, non-interactive
codex resume --last      # resume the most recent session
codex resume             # pick a session from a list
codex --help             # all options
```

The terminal starts in `/config`, giving Codex direct access to your Home Assistant configuration.

### Example Home Assistant tasks

```bash
codex exec "create an automation that turns on the porch light at sunset"
codex exec "what's wrong with this configuration? <paste yaml>"
codex exec "suggest better names for these entities: <paste list>"
```

## Configuration

### Auto Launch Codex — `auto_launch_codex` (default `true`)
Starts Codex automatically. When `false`, an interactive session picker is shown instead (new / resume last / resume list / custom / auth helpers / shell).

### Dangerously Bypass Approvals — `dangerously_bypass_approvals` (default `false`)
Runs Codex with `--dangerously-bypass-approvals-and-sandbox`: no command approvals and no sandbox. Inside the add-on container Codex's own sandbox (bubblewrap/Landlock) is usually unavailable anyway, so the default behavior is that Codex asks for approval before running commands. Only enable this if you accept unrestricted execution in the container.

### OpenAI API key — `openai_api_key` (default empty)
When set, the add-on runs `codex login --with-api-key` on startup **only if no login exists yet**. A manual ChatGPT login is never overwritten. The key is stored by Home Assistant in the add-on options and by Codex in `/data/.config/codex/auth.json` (chmod 600).

### Persistent Terminal Session — `persistent_terminal_session` (default `true`)
Runs Codex inside a tmux session. ttyd starts a new process per websocket connection, so closing the dashboard or losing the connection would otherwise kill the running session; with tmux, a reconnect re-attaches to the same session with scrollback and state intact. Set to `false` for the previous behavior (a fresh process on every reconnect).

### Persistent Packages — `persistent_apk_packages` / `persistent_pip_packages` (default `[]`)
APK and pip packages to auto-install on startup. Stored in `/data/packages`, so they survive restarts. You can also install on demand with `persist-install`.

### Persistent Codex override — `use_persistent_codex` (default `false`)
When enabled, the add-on uses a complete Codex package kept under `/data/home/.local` (persistent storage) instead of the version baked into the image. Its launcher in `/data/home/.local/bin` takes priority in `PATH`, so it supersedes the baked version and survives restarts. Installing the complete package keeps companion executables such as `codex-code-mode-host` on the same version as the CLI.

### Startup updates — `auto_update_codex_on_start` (default `false`)
Only relevant with `use_persistent_codex`. When enabled, the latest complete Codex package is installed from npm on each startup. Requires access to the npm registry; if installation or Code Mode host validation fails, the broken override is removed and the add-on falls back to the image-baked version.

Existing persistent overrides created by older add-on versions are checked at startup. If the CLI is present but its Code Mode host is missing, the add-on performs a one-time package repair even when automatic updates are disabled.

### Example configuration

```yaml
auto_launch_codex: true
dangerously_bypass_approvals: false
openai_api_key: "sk-..."
persistent_terminal_session: true
persistent_apk_packages:
  - htop
persistent_pip_packages:
  - requests
use_persistent_codex: true
auto_update_codex_on_start: true
```

If you enable `use_persistent_codex` but leave auto-update off, seed it once from a terminal in the add-on:

```bash
codex-update
```

## Keeping Codex CLI up to date

There are two independent ways to update Codex:

1. **Rebuild the add-on** — the build always installs the latest complete Codex npm package (the install layer is cache-busted by the GitHub latest-release metadata). Let Home Assistant rebuild on a version update.
2. **Persistent override** — set `use_persistent_codex: true` + `auto_update_codex_on_start: true`. Each startup installs the latest complete package into `/data`, with no rebuild. You can also run `codex-update` manually at any time.

## Persistent packages

Always use `persist-install` instead of `apk add` / `pip install` so packages survive restarts:

```bash
persist-install git vim htop
persist-install --python requests pandas
persist-install --ha-cli
persist-install --list
```

Packages install into `/data/packages` and are added to `PATH` automatically. See [PERSISTENT_PACKAGES.md](PERSISTENT_PACKAGES.md).

## Troubleshooting

```bash
codex --version      # confirm the running version
codex login status   # check authentication
```

- **Terminal disconnects** — refresh the page; the terminal auto-reconnects.
- **Authentication** — credentials persist in `/data/.config/codex`; you should not need to log in again after the first time. Use the session picker's auth helper to re-authenticate.
- **"approval required" on every command** — expected when the sandbox is unavailable in the container; approve per command or enable `dangerously_bypass_approvals`.
- **Logs** — check the add-on **Logs** tab for startup and runtime details.
- **Wrong version after enabling the override** — make sure both `use_persistent_codex` and `auto_update_codex_on_start` are `true`; the latter has no effect on its own.

## License

This project is licensed under the MIT License — see the [LICENSE](../LICENSE) file. Codex CLI itself is subject to OpenAI's terms of use.
