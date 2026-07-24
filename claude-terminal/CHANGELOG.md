# Changelog

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
