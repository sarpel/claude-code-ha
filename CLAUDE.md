# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Home Assistant **add-on repository** whose single add-on, **Claude Terminal Pro** (slug `claude_terminal_pro`, in `claude-terminal/`), runs the Claude Code CLI inside a browser-based terminal embedded in the Home Assistant dashboard. It adds an image-paste service, persistent package management, and persistent auth on top of the upstream add-on.

**Ownership:** maintained by `sarpel` at [github.com/sarpel/claude-code-ha](https://github.com/sarpel/claude-code-ha). Identity lives in `repository.yaml`, `claude-terminal/config.yaml` (`url`), `claude-terminal/build.yaml` (`labels`), and `LICENSE` — keep these consistent when rebranding. (Originally derived from an upstream Home Assistant add-on; prior attribution was removed by the maintainer's choice.)

## Built Locally, Not Pulled — Why Versions Matter

`config.yaml` has **no `image:` key** (and never has — verified in git history). Home Assistant therefore **builds the add-on locally on the user's device from the `Dockerfile`** on install/update. There is no prebuilt registry image for this add-on.

Implications:
- A clean build installs the **latest** Claude Code: the Dockerfile runs `install.sh | bash -s latest` (native/Bun installer) with an `npm install -g @anthropic-ai/claude-code@latest` fallback (the fallback exists for CPUs without AVX — see v2.0.10).
- The install layer is **cache-busted** by `ADD https://downloads.claude.ai/claude-code-releases/latest …` placed just before it (v2.1.0): that file's content changes on every new release, invalidating the install layer so rebuilds actually fetch the newest version instead of reusing a stale layer. This was the likely cause of versions appearing "stuck".
- Claude Code's CLI self-update is **disabled at runtime** (`DISABLE_AUTOUPDATER=1`, set in the process env and `/etc/profile.d/persistent-packages.sh`). The running version is whatever was baked at build time, unless the runtime override below replaces it.

### Two levers for the Claude Code version
1. **Build-time (baked into image):** the Dockerfile install, kept current by the cache-bust above. This is the default the add-on ships with; users get a new version by letting HA rebuild the add-on (e.g. on a version bump).
2. **Runtime override (no rebuild needed):** set add-on options `use_persistent_claude: true` + `auto_update_claude_on_start: true` (channel via `claude_channel`, default `latest`). `run.sh:setup_persistent_claude()` then runs the **native installer** (`install.sh | bash -s <channel>`) into `/data/home/.local/bin` — which is **first in `PATH`**, so it authoritatively supersedes the image-baked binary, and persists across restarts under `/data`. First-time manual seed if auto-update is off: `curl -fsSL https://claude.ai/install.sh | bash -s latest` from a terminal in the add-on.

> Why the override historically did nothing: pre-2.1.0 it `npm install`ed into `/data/npm` and symlinked `/usr/local/bin/claude`, but `/data/home/.local/bin` precedes `/usr/local/bin` in `PATH`, so the image-baked binary always shadowed it. Installing the override into `/data/home/.local/bin` is what makes it take effect. Note `auto_update_claude_on_start` is a **no-op unless `use_persistent_claude` is also true**.

## Runtime Architecture

Entry point is `claude-terminal/run.sh` → `main()`, which runs in order:
`run_health_check` → `init_environment` → `install_tools` (apk-installs `ttyd`) → `setup_persistent_claude` → `setup_session_picker` → `setup_persistent_packages` (+ auto-install from config) → `start_web_terminal`.

**Dual-port web stack** (note: ingress port differs from the terminal port):
- **7680** — Node/Express **image-service** (`image-service/server.js`). This is the HA **ingress port** (`ingress_port: 7680`). It serves the custom HTML UI (`image-service/public/index.html`), accepts image uploads (`POST /upload` → saved to `/data/images/`), and **proxies the embedded terminal** to ttyd.
- **7681** — **ttyd** terminal running `bash -c "$launch_command"`. Launched with `--ping-interval 30 --client-option reconnect=5` to survive idle disconnects.

What the terminal launches is decided by `get_claude_launch_command()` from the `auto_launch_claude` option: either start `claude` directly (falling back to the session picker on exit) or open `claude-session-picker` first. `dangerously_skip_permissions: true` adds `--dangerously-skip-permissions` and sets `IS_SANDBOX=1` (required to allow that flag as root).

**Everything persistent lives under `/data`** (the only HA-guaranteed-writable mount). `init_environment()` relocates HOME and all XDG dirs there and writes `/etc/profile.d/persistent-packages.sh` so **every** bash/ttyd session inherits the same env. Key variables:
- `HOME=/data/home` (the native Claude binary is symlinked to `/data/home/.local/bin/claude`)
- `ANTHROPIC_CONFIG_DIR=/data/.config/claude`, `ANTHROPIC_HOME=/data`
- `XDG_CONFIG_HOME=/data/.config`, `XDG_CACHE_HOME=/data/.cache`, `XDG_STATE_HOME=/data/.local/state`
- `GH_CONFIG_DIR=/data/.config/gh` (GitHub CLI auth persists)
- `PATH` is prefixed with `/data/packages/bin:/data/packages/python/venv/bin:/data/home/.local/bin` (persistent packages win)

> The older `/config/claude-config` and `HOME=/root` paths are **legacy**. `migrate_legacy_auth_files()` still one-time-migrates auth from those locations into `/data/.config/claude`, but new code should target `/data`.

Beyond Claude Code, the Dockerfile also bakes in the Home Assistant CLI (`ha`) and GitHub CLI (`gh`), both fetched at build time for the target arch from their latest GitHub releases. Multi-arch: `aarch64`, `amd64`, `armv7` off `ghcr.io/home-assistant/{arch}-base:3.19`.

## Persistent Package Management — Behavioral Rule

`apk add` / `pip install` write to the **ephemeral container layer and are lost on restart**. When a user asks to install ANY package, **never** call `apk add`/`pip install` directly — use the `persist-install` wrapper (sourced from `scripts/persist-install`, installed to `/usr/local/bin`), which installs into `/data/packages/` (survives restarts).

```bash
persist-install python3 py3-pip git vim     # APK packages
persist-install --python requests pandas     # pip into /data/packages/python/venv
persist-install --ha-cli                     # official ha command
persist-install --list                       # what's installed
```

Always verify after installing (`<tool> --version`) and tell the user it persists across reboots. Packages can also be auto-installed on startup via the `persistent_apk_packages` / `persistent_pip_packages` add-on options (parsed by `auto_install_packages()`). The bundled Claude Code skill at `claude-terminal/.claude/skills/persistent-package-manager/SKILL.md` encodes this same rule. Full reference: `claude-terminal/PERSISTENT_PACKAGES.md`.

## Development Commands

Dev shell is Nix-based (`flake.nix`); `nix develop` (or `direnv allow`) provides these aliases:
- `build-addon` — Podman build of the add-on
- `run-addon` — run locally on :7681 with `./config` mapped to `/config`
- `lint-dockerfile` — hadolint on the Dockerfile
- `test-endpoint` — `curl localhost:7681`

Manual local build/test loop (no aliases):
```bash
podman build --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.19 -t local/claude-terminal:test ./claude-terminal
mkdir -p /tmp/test-config/claude-config
podman run -d --name test-claude-dev -p 7681:7681 -v /tmp/test-config:/config local/claude-terminal:test
podman logs -f test-claude-dev          # web UI at http://localhost:7681
podman stop test-claude-dev && podman rm test-claude-dev
```
To iterate on a script without a full rebuild: `podman cp ./claude-terminal/scripts/<file> test-claude-dev:/opt/scripts/` then re-exec it.

Note: the dev environment has **no sudo**, and the runtime target is Alpine (HA OS base).

## Release Discipline (REQUIRED for any add-on change)

Every change to the add-on MUST, in the same commit:
1. **Bump `version`** in `claude-terminal/config.yaml` — patch (xx.X) for fixes, minor (x.X.0) for features, major for breaking changes. Keep the matching `org.opencontainers.image.version` in `claude-terminal/build.yaml` in sync.
2. **Prepend a changelog entry** to the TOP of `claude-terminal/CHANGELOG.md`:
   ```markdown
   ## X.Y.Z

   ### ✨ New Feature - Short title
   - **Bold summary**: detail of what changed and why
   ```
   Categories: ✨ New Feature · 🐛 Bug Fix · 🛠️ Improvement · 📚 Documentation · 🔧 Technical

Do not commit add-on changes without both. HA surfaces the version bump as the update trigger for users.

## Conventions

- Add-on shell scripts start with `#!/usr/bin/with-contenv bashio` and log via `bashio::log.*`; read options via `bashio::config`.
- Indentation: 2 spaces YAML, 4 spaces shell.
- Auth/credential files must be `chmod 600`.
- `.github/workflows/claude.yml` only runs the `@claude` GitHub Action on issues/PRs — it does **not** build or publish images (consistent with local-build above).
