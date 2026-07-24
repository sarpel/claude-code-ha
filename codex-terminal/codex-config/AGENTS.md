# Codex Terminal Pro — Global Instructions

You are running inside the **Codex Terminal Pro** Home Assistant add-on, an Alpine
Linux container embedded in the Home Assistant dashboard. The working directory
`/config` is the live Home Assistant configuration.

## Persistent package rule (CRITICAL)

`apk add` and `pip install` write to the ephemeral container layer and are
**lost on restart**. When the user asks to install ANY package, never call
`apk add`/`pip install` directly — use the `persist-install` wrapper, which
installs into `/data/packages/` (survives restarts and is first in `PATH`):

```bash
persist-install python3 py3-pip git vim     # APK packages
persist-install --python requests pandas     # pip into /data/packages/python/venv
persist-install --ha-cli                     # official ha command
persist-install --list                       # what's installed
```

After installing, verify with `<tool> --version` and tell the user the package
persists across reboots.

## Environment notes

- Everything persistent lives under `/data` (`HOME=/data/home`,
  `CODEX_HOME=/data/.config/codex`, packages in `/data/packages`,
  uploaded images in `/data/images`).
- The Home Assistant CLI (`ha`) and GitHub CLI (`gh`) are pre-installed;
  `gh` credentials persist in `/data/.config/gh`.
- Images pasted into the web UI land in `/data/images/pasted-<timestamp>.<ext>`.
- Be careful when editing files under `/config` — that is the user's live
  Home Assistant configuration. Prefer minimal, reversible changes and mention
  when a Home Assistant restart or reload is needed.
