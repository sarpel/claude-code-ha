# Changelog

## 1.0.4

### 🛠️ Improvement - Bigger, nicer terminal typography
- **Font size 13 → 15**: ttyd's own default of 13px read too small inside the dashboard iframe.
- **Ubuntu Mono, bundled**: the font is rendered by the *browser*, not the container, so it is now self-hosted — the image is built with `UbuntuMono-Regular/Bold.ttf` (Ubuntu Font Licence) under `image-service/public/fonts/`, and the image-service injects the matching `@font-face` into the ttyd page before xterm.js initialises. A `resize` event after `document.fonts.ready` makes xterm re-measure with the real font metrics.
- **Fallback chain**: if the font fails to download at build time, the terminal falls back to `Cascadia Mono → DejaVu Sans Mono → Consolas → Liberation Mono → Menlo → monospace`, so nothing breaks.

## 1.0.3

### 🐛 Bug Fix - Add-on restart loop when `persistent_apk_packages` / `persistent_pip_packages` is set
- **Root cause**: `bashio::config` returns the **elements** of a list option, one per line (see bashio's `lib/config.sh`, which evaluates `.key[]`) — not a JSON array. `auto_install_packages()` piped that output back into `jq -r '.[]'`, so jq aborted with `parse error: Invalid literal at line 2, column 0`. Under `set -e` + `pipefail` that killed `run.sh` before the terminal ever started, and the Supervisor restarted the container in a loop. Any non-empty package list triggered it; an empty list did not.
- **Fix**: the configured packages are now read as plain lines (no second JSON parse), and the whole auto-install step can no longer abort startup — a failing package is logged and skipped.

## 1.0.2

### 🛠️ Improvement - Own artwork
- **Distinct icon and logo**: `icon.png` (128×128) and `logo.png` (256×256) now show the OpenAI mark in OpenAI teal on a transparent background instead of the artwork copied from Claude Terminal Pro, so the two sidebar panels are told apart at a glance in both light and dark themes.

## 1.0.1

### 🔧 Technical - Hardening and correctness fixes
- **No host ports published**: the `7690`/`7691` host mappings (and the `webui` link that depended on them) were removed. `ttyd` runs `--writable` without credentials, so publishing it exposed a root terminal to the local network; the add-on is reachable through Home Assistant ingress only. Side-by-side operation with Claude Terminal Pro is unaffected — each add-on has its own ingress panel.
- **Image service health check now watches the right process**: `$!` captured the log-reader subshell instead of `node`, so a crashed image service was still reported as running. Output is now forwarded through a process substitution.
- **`install-ha-cli.sh` validates before executing**: an unsupported architecture no longer builds a broken download URL (the `detect_arch` failure was masked by `local`), and the downloaded binary must pass the same size sanity check `persist-install` uses before it is made executable.
- **`persist-install --ha-cli` reports version failures again**: the smoke test piped into `head`, so the check always saw `head`'s exit status and the warning branch was unreachable.
- **`persistent-packages.sh` no longer aborts startup**: a failing package install is logged and skipped instead of killing the script through `set -e`, and the command dispatch is guarded so sourcing the file only defines its helpers.

### 📚 Documentation
- Corrected the API-key login example (`printenv OPENAI_API_KEY`), the add-on options path (Supervisor-generated `/data/options.json`, read-only), and the image-paste changelog date.

## 1.0.0

### ✨ New Feature - Initial release of Codex Terminal Pro
- **OpenAI Codex CLI in the Home Assistant dashboard**: browser terminal (ttyd) embedded via ingress with its own sidebar panel, running side by side with Claude Terminal Pro (host ports 7690/7691).
- **Static musl install with npm fallback**: the image downloads the latest `codex-*-unknown-linux-musl` binary from GitHub releases (cache-busted per release), falling back to `npm install -g @openai/codex`. Architectures: `amd64`, `aarch64` (OpenAI ships no arm32 binary).
- **Persistent everything under `/data`**: `CODEX_HOME=/data/.config/codex` (auth + sessions), persistent packages via `persist-install`, uploaded images in `/data/images`, GitHub CLI auth in `/data/.config/gh`.
- **Headless authentication**: optional `openai_api_key` option logs in via `codex login --with-api-key` on startup (never overwrites an existing login); interactive auth helper for API key/status/logout and ChatGPT-login guidance.
- **Self-updating override**: `use_persistent_codex` + `auto_update_codex_on_start` keep a persistent Codex binary in `/data/home/.local/bin` (first in `PATH`); manual `codex-update` helper included.
- **Session picker**: new session, `codex resume --last`, `codex resume` list, custom command, auth helpers, bash shell.
- **Image paste service**: paste/drag-drop/upload images through the web UI, saved to `/data/images` for use with Codex.
- **Batteries included**: `git`, `gh`, `ha`, `ripgrep`, Python 3, and Codex global instructions (`AGENTS.md`) encoding the persist-install rule.
