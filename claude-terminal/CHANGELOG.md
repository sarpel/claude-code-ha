# Changelog

## 2.1.5

### ✨ New Feature - The session survives a closed dashboard
- **`persistent_terminal_session` (new option, default `true`)**: Claude now runs inside a tmux session. ttyd starts a *new* process for every websocket connection, so closing the dashboard - or a background tab being throttled until the socket drops - used to kill the running session and drop you into a fresh one on reconnect. The tmux session keeps running in the background and a reconnect re-attaches to it, with scrollback and state intact. `--ping-interval`/`reconnect` only ever restored the *connection*; this restores the *session*.
- **Invisible by default**: a minimal `~/.tmux.conf` (no status bar, mouse on, 50k scrollback, true colour) is written on first start and never overwrites an existing one. `tmux` is now part of the image.
- Set the option to `false` for the previous behaviour.

## 2.1.4

### 🛠️ Improvement - Bigger, nicer terminal typography
- **Font size 13 → 15**: ttyd's own default of 13px read too small inside the dashboard iframe.
- **Ubuntu Mono, bundled**: the font is rendered by the *browser*, not the container, so it is now self-hosted — the image is built with `UbuntuMono-Regular/Bold.ttf` (Ubuntu Font Licence) under `image-service/public/fonts/`, and the image-service injects the matching `@font-face` into the ttyd page before xterm.js initialises. A `resize` event after `document.fonts.ready` makes xterm re-measure with the real font metrics.
- **Fallback chain**: if the font fails to download at build time, the terminal falls back to `Cascadia Mono → DejaVu Sans Mono → Consolas → Liberation Mono → Menlo → monospace`, so nothing breaks.

## 2.1.3

### 🐛 Bug Fix - Add-on restart loop when `persistent_apk_packages` / `persistent_pip_packages` is set
- **Root cause**: `bashio::config` returns the **elements** of a list option, one per line (see bashio's `lib/config.sh`, which evaluates `.key[]`) — not a JSON array. `auto_install_packages()` piped that output back into `jq -r '.[]'`, so jq aborted with `parse error: Invalid literal at line 2, column 0`. Under `set -e` + `pipefail` that killed `run.sh` before the terminal ever started, and the Supervisor restarted the container in a loop. Any non-empty package list triggered it; an empty list did not, which is why the add-on worked until packages were configured.
- **Fix**: the configured packages are now read as plain lines (no second JSON parse), and the whole auto-install step can no longer abort startup — a failing package is logged and skipped.

## 2.1.2

### 🔧 Technical - Hardening and correctness fixes (parity with Codex Terminal Pro 1.0.1)
- **No host ports published**: the `7680`/`7681` host mappings (and the `webui` link that depended on them) were removed. `ttyd` runs `--writable` without credentials, so publishing it exposed a root terminal to anyone on the local network. The add-on is reachable through Home Assistant ingress only — the sidebar panel and **OPEN WEB UI** are unaffected. If you relied on `http://<ha-host>:7680/`, use the ingress panel instead.
- **Image service health check now watches the right process**: `$!` captured the log-reader subshell instead of `node`, so a crashed image service was still reported as running. Output is now forwarded through a process substitution.
- **`install-ha-cli.sh` validates before executing**: an unsupported architecture no longer builds a broken download URL (the `detect_arch` failure was masked by `local`), and the downloaded binary must pass the same size sanity check `persist-install` uses before it is made executable.
- **`persist-install --ha-cli` reports version failures again**: the smoke test piped into `head`, so the check always saw `head`'s exit status and the warning branch was unreachable.
- **`persistent-packages.sh` no longer aborts startup**: a failing package install is logged and skipped instead of killing the script through `set -e`, and the command dispatch is guarded so sourcing the file only defines its helpers.

### 📚 Documentation
- The add-on options path is now documented as the Supervisor-generated, read-only `/data/options.json` (the old `/config/claude-terminal/options.json` path never existed).

## 2.1.1

### 🐛 Bug Fix - Claude Code Won't Start (musl/statx) — Base Image Bumped to Alpine 3.21
- **Root cause found on-device**: current Claude Code binaries reference the `statx` symbol, which Alpine **3.19**'s musl 1.2.4 does not export. Both the native installer binary and the npm-delivered binary therefore crash at launch with `Error relocating … statx: symbol not found`. This — not the build cache — is why Claude appeared "stuck on an old version" and why `claude update` produced a version that would no longer launch.
- **Fix**: bumped `build_from` from `*-base:3.19` to `*-base:3.21` (musl 1.2.5). Verified directly on the device: 3.19/musl-1.2.4 fails; 3.20/3.21/3.22 (musl-1.2.5) run `claude --version` → `2.1.185` cleanly.
- **Action required**: rebuild the add-on (update from the store, or uninstall + reinstall) so the new base image takes effect. There is no in-container workaround on a 3.19 image.
- Restored `repository.yaml` (required for Home Assistant to recognize the add-on repository).

## 2.1.0

### ✨ New Feature - Native-Installer Persistent Claude Code Override
- **Switched the persistent override from npm to Anthropic's native installer**: `setup_persistent_claude` installs Claude Code into `/data/home/.local/bin` (first in `PATH`, persistent under `/data`), so it authoritatively supersedes the image-baked binary. Removed the dead `/data/npm` path that was silently shadowed and never took effect.
- **Session picker respects the override**: launch paths resolve `claude` via `PATH` instead of a hardcoded `/usr/local/bin/claude`, so the override applies even with `auto_launch_claude: false`.
- **New `claude_channel` option** (`latest` or `stable`, default `latest`).

### 🛠️ Improvement - Builds Track the Latest Claude Code
- Dockerfile installs the latest channel via the native installer (`install.sh | bash -s latest`) with an npm `@latest` fallback, plus an `ADD` of the latest-version manifest to cache-bust rebuilds.
- Added `libgcc`/`libstdc++` for the native installer.

### 🔧 Technical - Rebrand
- Repository rebranded to `sarpel/claude-code-ha` (URLs, maintainer, image labels, license holder).
