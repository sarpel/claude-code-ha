# Changelog

## 1.0.0

### ✨ New Feature - GLM Terminal Pro
- **New sibling add-on**: a copy of Claude Terminal Pro that runs the stock Claude Code CLI against **Z.AI's Anthropic-compatible API** (GLM models) instead of api.anthropic.com.
- **Endpoint via `configure_zai_endpoint()` in `run.sh`**: exports `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_MODEL` / `ANTHROPIC_SMALL_FAST_MODEL` / `ANTHROPIC_DEFAULT_{HAIKU,SONNET,OPUS}_MODEL`, plus `CLAUDE_CODE_EFFORT_LEVEL=max`, `API_TIMEOUT_MS`/`CLAUDE_STREAM_IDLE_TIMEOUT_MS=3000000`, `CLAUDE_CODE_RETRY_WATCHDOG=1`, `CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000`. `ANTHROPIC_API_KEY` is unset so the bearer token wins. The same values are written to `/etc/profile.d/zai-endpoint.sh` (chmod 600) for every login shell / new ttyd tab.
- **New options**: `zai_auth_token` (password, stored in `/data/options.json`, never in the image), `zai_base_url` (default `https://api.z.ai/api/anthropic`), `zai_model` (default `glm-5.3[1m]`).
- **Branding**: slug `glm_terminal_pro`, panel title "GLM Terminal Pro", icon `mdi:alpha-z-box`, tmux session `glm`. Runs side by side with Claude / Codex Terminal Pro through its own ingress panel.
- Everything else (persistent auth, `persist-install`, image paste, `use_persistent_claude` override, `git`/`gh`/`ha`) is inherited unchanged from Claude Terminal Pro.
