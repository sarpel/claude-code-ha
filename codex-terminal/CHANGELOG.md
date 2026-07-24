# Changelog

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
