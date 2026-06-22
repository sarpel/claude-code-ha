# Claude Terminal Pro for Home Assistant

A Home Assistant add-on that runs Anthropic's **Claude Code CLI** inside a web-based terminal embedded in your dashboard — with persistent authentication, persistent package management, image paste, and self-updating Claude Code.

## Add the Repository

1. Go to **Settings → Add-ons → Add-on Store**
2. Open the three-dots menu (⋮) in the top-right and select **Repositories**
3. Add: `https://github.com/sarpel/claude-code-ha`
4. Install **Claude Terminal Pro** from the store and start it
5. Open the Web UI (sidebar icon or **OPEN WEB UI**) and follow the OAuth prompt to sign in to your Anthropic account

> Claude Code requires a Claude Pro/Max or Anthropic Console account. There is no `image:` key in the add-on config, so Home Assistant **builds the add-on locally from source** on your device — a fresh build always installs the latest Claude Code.

## Features

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
| `persistent_apk_packages` | `[]` | APK packages to auto-install on startup |
| `persistent_pip_packages` | `[]` | Python packages to auto-install on startup |
| `use_persistent_claude` | `false` | Use a persistent Claude Code install in `/data` instead of the image-baked one |
| `auto_update_claude_on_start` | `false` | With `use_persistent_claude`, fetch the selected channel on each startup |
| `claude_channel` | `latest` | Release channel for the persistent override (`latest` or `stable`) |

## Documentation

- [Add-on documentation](claude-terminal/DOCS.md) — usage, configuration, troubleshooting
- [Persistent packages](claude-terminal/PERSISTENT_PACKAGES.md)
- [Image paste](claude-terminal/IMAGE_PASTE.md)

## License

MIT — see [LICENSE](LICENSE). Claude Code itself is subject to Anthropic's Commercial Terms of Service.
