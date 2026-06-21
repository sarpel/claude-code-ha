# Claude Terminal Pro — Documentation

A web-based terminal with Anthropic's Claude Code CLI, running inside Home Assistant with persistent auth, persistent packages, and image paste.

## Installation

1. **Settings → Add-ons → Add-on Store**
2. Three-dots menu (⋮) → **Repositories** → add `https://github.com/sarpel/claude-code-ha`
3. Install **Claude Terminal Pro** and start it
4. Open the Web UI and follow the OAuth prompts on first use

No API key configuration is required — authentication uses OAuth with your Anthropic account, and credentials persist in `/data/.config/claude` across restarts and updates.

## Usage

Claude launches automatically when you open the terminal. You can also run it manually:

```bash
claude                 # interactive session
claude "your prompt"   # one-shot question
claude -c              # continue the most recent conversation
claude -r              # resume from a conversation list
claude --help          # all options
```

The terminal starts in `/config`, giving Claude direct access to your Home Assistant configuration.

### Example Home Assistant tasks

```bash
# Create an automation
claude "create an automation that turns on the porch light at sunset"

# Debug YAML
claude "what's wrong with this configuration? <paste yaml>"

# Manage entities
claude "suggest better names for these entities: <paste list>"
```

## Configuration

### Auto Launch Claude — `auto_launch_claude` (default `true`)
Starts Claude automatically. When `false`, an interactive session picker is shown instead (new / continue / resume / custom / auth helpers / shell).

### Dangerously Skip Permissions — `dangerously_skip_permissions` (default `false`)
Runs Claude with `--dangerously-skip-permissions` for unrestricted filesystem access. Only enable if you understand the implications.

### Persistent Packages — `persistent_apk_packages` / `persistent_pip_packages` (default `[]`)
APK and pip packages to auto-install on startup. Stored in `/data/packages`, so they survive restarts. You can also install on demand with `persist-install`.

### Persistent Claude Code override — `use_persistent_claude` (default `false`)
When enabled, the add-on uses a Claude Code binary kept in `/data/home/.local/bin` (persistent storage) instead of the version baked into the image. It is installed with Anthropic's **native installer** and takes priority in `PATH`, so it supersedes the baked version and survives restarts.

### Startup updates — `auto_update_claude_on_start` (default `false`)
Only relevant with `use_persistent_claude`. When enabled, the native installer runs on each startup to fetch the selected channel. Requires network access at startup; on failure it falls back to the existing version.

### Channel — `claude_channel` (default `latest`)
`latest` ships every release immediately; `stable` is roughly a week behind and skips releases with major regressions. Applies to the persistent override.

### Example configuration

```yaml
auto_launch_claude: true
dangerously_skip_permissions: false
persistent_apk_packages:
  - htop
persistent_pip_packages:
  - requests
use_persistent_claude: true
auto_update_claude_on_start: true
claude_channel: latest
```

If you enable `use_persistent_claude` but leave auto-update off, seed it once from a terminal in the add-on:

```bash
curl -fsSL https://claude.ai/install.sh | bash -s latest
```

## Keeping Claude Code up to date

There are two independent ways to update Claude Code:

1. **Rebuild the add-on** — the build always installs the latest release. Let Home Assistant rebuild on a version update.
2. **Persistent override** — set `use_persistent_claude: true` + `auto_update_claude_on_start: true`. Each startup fetches the latest (or `stable`) release into `/data` via the native installer, with no rebuild.

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
claude doctor      # diagnose the installation
claude --version   # confirm the running version
```

- **Terminal disconnects** — refresh the page; the terminal auto-reconnects.
- **Authentication** — credentials persist in `/data/.config/claude`; you should not need to log in again after the first time. Use the session picker's auth helper or run `claude` to re-authenticate.
- **Logs** — check the add-on **Logs** tab for startup and runtime details.
- **Wrong version after enabling the override** — make sure both `use_persistent_claude` and `auto_update_claude_on_start` are `true`; the latter has no effect on its own.

## License

This project is licensed under the MIT License — see the [LICENSE](../LICENSE) file. Claude Code itself is subject to Anthropic's Commercial Terms of Service.
