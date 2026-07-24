# Codex Terminal Pro — Design

Date: 2026-07-24
Status: Implemented (autonomous run; user review pending)

## Goal

Create a sibling Home Assistant add-on to **Claude Terminal Pro** that runs the
**OpenAI Codex CLI** in the same browser-terminal stack, installable side by side
from the same repository, with near-identical features:

- ttyd web terminal embedded in the HA dashboard (own sidebar panel)
- image paste/upload service with ingress proxy
- persistent auth, persistent packages (`persist-install`), persistent binary override
- session picker + auth helper menus
- `ha` and `gh` CLIs baked in

## Decisions

| Topic | Decision | Rationale |
| --- | --- | --- |
| Directory / slug | `codex-terminal/`, slug `codex_terminal_pro`, name "Codex Terminal Pro" | Mirrors existing naming; unique slug lets both add-ons coexist |
| CLI install (build) | Download `codex-<triple>-unknown-linux-musl.tar.gz` from the latest GitHub release; fallback `npm i -g @openai/codex` | Alpine base needs musl binaries; assets verified to exist (rust-v0.145.0). npm package vendors the same binaries as fallback |
| Cache-bust | `ADD https://api.github.com/repos/openai/codex/releases/latest` before the install layer | Same pattern as claude-terminal v2.1.0; content changes per release |
| Architectures | `aarch64`, `amd64` only | OpenAI ships no arm32 binary (verified in release assets) |
| Ports | container 7680 (ingress, image service) / 7681 (ttyd) — unchanged; **host** mappings 7690/7691 | Container ports are namespaced per add-on; host mappings must not collide with claude-terminal's 7680/7681 |
| Config home | `CODEX_HOME=/data/.config/codex` (created before use — Codex errors if `CODEX_HOME` points to a missing dir) | `auth.json`, `config.toml`, `sessions/` all persist under /data |
| Auth | (1) `openai_api_key` add-on option (schema `password?`) piped to `codex login --with-api-key` at startup when not yet logged in; (2) auth-helper menu for manual API key / status / logout; ChatGPT OAuth documented as SSH-forward-only (localhost:1455) | Browser OAuth callback cannot traverse ingress |
| Dangerous mode | option `dangerously_bypass_approvals` → `--dangerously-bypass-approvals-and-sandbox` | Codex's Linux sandbox (bubblewrap/landlock) is typically unavailable inside HA containers; this is the documented escape hatch. Default **false** |
| Persistent override | `use_persistent_codex` + `auto_update_codex_on_start` download the latest musl binary into `/data/home/.local/bin/codex` (PATH-first) | Same two-lever model as claude-terminal |
| Agent instructions | `codex-config/AGENTS.md` copied to `$CODEX_HOME/AGENTS.md` on first start | Codex reads global `AGENTS.md` instead of Claude skills; encodes the persist-install rule |
| Session picker | new / `codex resume --last` / `codex resume` (picker) / custom / auth helper / gh login / shell | Maps Claude's `-c` / `-r` semantics onto Codex equivalents |
| Icons | copied from claude-terminal for now | Placeholder; distinct art suggested as follow-up |
| Versioning | starts at 1.0.0 with its own CHANGELOG.md | New add-on |

## Architecture

Identical to claude-terminal: `run.sh:main()` →
health-check → init_environment (HOME/XDG/CODEX_HOME under /data, profile.d) →
install_tools (ttyd) → setup_persistent_codex → setup_openai_auth →
setup_session_picker → setup_persistent_packages → start_web_terminal
(Express image service on 7680 proxying ttyd on 7681).

## Out of scope

- Publishing prebuilt images (repo builds locally, same as claude-terminal)
- Distinct icon/logo artwork
- Sharing code between the two add-ons (HA add-ons must be self-contained dirs)
