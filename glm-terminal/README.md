# GLM Terminal Pro

A web-based terminal with the Claude Code CLI pre-installed, wired to **Z.AI's Anthropic-compatible API** so it runs on **GLM models** (default `glm-5.3[1m]`) instead of api.anthropic.com. Runs directly inside your Home Assistant dashboard.

## What it does

GLM Terminal Pro is a copy of **Claude Terminal Pro** that points the Claude Code CLI at Z.AI. You get the same browser terminal with direct access to your Home Assistant `/config` — write and debug automations, fix YAML, manage entities, develop custom components — but billed through your Z.AI account.

It adds persistent authentication, persistent package management, image paste, and an optional self-updating CLI on top of a standard terminal add-on. Install it alongside Claude Terminal Pro and Codex Terminal Pro; each has its own dashboard panel.

## Quick start

The terminal launches Claude automatically when you open it:

```bash
# Ask a single question
claude "write an automation that turns on lights when motion is detected after sunset"

# Start an interactive session
claude

# See all options
claude --help
```

The terminal opens in `/config`, so Claude can read and edit your Home Assistant files directly.

## Installation

1. **Settings → Add-ons → Add-on Store**
2. Three-dots menu (⋮) → **Repositories** → add `https://github.com/sarpel/claude-code-ha`
3. Install **GLM Terminal Pro**
4. On the **Configuration** tab, paste your Z.AI API token into `zai_auth_token`, then start the add-on
5. Open the Web UI — Claude Code starts already authenticated against Z.AI (no OAuth prompt)

## Configuration

Set `zai_auth_token` before first start. Everything else is optional.

| Option | Default | Description |
| --- | --- | --- |
| `auto_launch_claude` | `true` | Auto-start Claude, or show the session picker when `false` |
| `dangerously_skip_permissions` | `false` | Run Claude with unrestricted file access |
| `persistent_terminal_session` | `true` | Keep the CLI running in a tmux session so a dropped connection (closed or backgrounded dashboard) resumes instead of restarting |
| `persistent_apk_packages` | `[]` | APK packages to auto-install on startup |
| `persistent_pip_packages` | `[]` | Python packages to auto-install on startup |
| `use_persistent_claude` | `false` | Use a self-updating Claude Code install kept in `/data/home/.local/bin` |
| `auto_update_claude_on_start` | `false` | With `use_persistent_claude`, fetch the channel on each startup |
| `claude_channel` | `latest` | `latest` or `stable` for the persistent override |
| `zai_auth_token` | `""` | **Required.** Z.AI API token, exported as `ANTHROPIC_AUTH_TOKEN`. Stored in `/data/options.json`, never in the image. |
| `zai_base_url` | `https://api.z.ai/api/anthropic` | Exported as `ANTHROPIC_BASE_URL` |
| `zai_model` | `glm-5.3[1m]` | Exported as `ANTHROPIC_MODEL` and every `ANTHROPIC_DEFAULT_*_MODEL` |

See [DOCS.md](DOCS.md) for full details and examples.

## How it works

- **Web UI / terminal** — port `7680` (container) serves the web interface (image upload + embedded terminal) over Home Assistant ingress; `ttyd` runs the terminal on `7681` behind it. Neither port is published on the host — access goes through ingress only, so the writable terminal is never exposed to the local network.
- **Z.AI endpoint** — `run.sh:configure_zai_endpoint()` exports `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_MODEL` and the `ANTHROPIC_DEFAULT_*_MODEL` overrides from the options above (plus `CLAUDE_CODE_EFFORT_LEVEL=max` and long stream/API timeouts), and writes them to `/etc/profile.d/zai-endpoint.sh` (chmod 600) so every shell inherits them. `ANTHROPIC_API_KEY` is unset so the token is used.
- **Persistence** — everything that must survive restarts lives under `/data`: CLI credentials/state (`/data/.config/claude`), installed packages (`/data/packages`), uploaded images (`/data/images`), and the optional CLI override (`/data/home/.local/bin`).
- **Pre-installed tools** — `git`, `gh` (GitHub CLI), `ha` (Home Assistant CLI), Python 3, and the `persist-install` helper.

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
claude doctor        # check installation and version
claude --version     # confirm the running version
```

- If the terminal disconnects, refresh the page (it auto-reconnects).
- Check the add-on **Logs** tab for startup details — it logs the active Z.AI base URL and model, and warns if `zai_auth_token` is empty.
- Auth errors (401/403): re-check `zai_auth_token` on the Configuration tab and restart the add-on.
- The token lives in `/data/options.json`; changing it takes effect on the next add-on restart.

## License

MIT — see [LICENSE](../LICENSE).
