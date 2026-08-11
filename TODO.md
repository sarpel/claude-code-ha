# TODO — Codex Terminal Pro add-on (OpenAI Codex CLI kopyası)

> Historical implementation checklist for the original `1.0.0` release. All
> items are complete; later installation, networking, artwork, and persistence
> changes are documented in `codex-terminal/CHANGELOG.md` and `DOCS.md`.

Görev: `claude-terminal/` eklentisinin OpenAI Codex CLI kullanan bir kopyasını
`codex-terminal/` olarak oluşturmak; HA yan menüsünde ayrı bir panel uygulaması
olarak, neredeyse aynı özelliklerle.

## Etki haritası
- YENİ: `codex-terminal/**` (tam eklenti: config, build, Dockerfile, run.sh, scripts, image-service, dokümanlar)
- DEĞİŞİR: `README.md` (kök — iki eklentiyi listele)
- DEĞİŞİR: `CLAUDE.md` (ikinci eklenti notu)
- DEĞİŞİR: `repository.yaml` (depo adı iki eklentiyi kapsayacak şekilde)
- DEĞİŞMEZ: `claude-terminal/**`

## Sıralı görevler
- [x] 1. Mevcut eklentinin tüm dosyalarını oku (config, Dockerfile, run.sh, scripts, image-service, docs)
- [x] 2. Codex CLI kurulum/auth/CODEX_HOME/bayrak bilgilerini doğrula (Context7 + GitHub release asset listesi)
- [x] 3. Tasarım dokümanı yaz (`docs/superpowers/specs/2026-07-24-codex-terminal-addon-design.md`)
- [x] 4. Dizin iskeleti + verbatim kopyalar (icon.png, logo.png, install-ha-cli.sh, ha-api-examples.sh, persistent-packages.sh)
- [x] 5. `config.yaml`, `build.yaml` (slug codex_terminal_pro, v1.0.0, aarch64+amd64, ingress-only — host portu yayınlanmıyor)
- [x] 6. `Dockerfile` (musl release ikilisi + npm fallback, cache-bust, ha/gh CLI blokları)
- [x] 7. `run.sh` (CODEX_HOME, persistent override, API key login, launch command)
- [x] 8. `scripts/codex-session-picker.sh` + `scripts/codex-auth-helper.sh` + `scripts/health-check.sh` + `scripts/persist-install`
- [x] 9. `image-service/` (server.js, package.json, index.html — rebrand)
- [x] 10. `codex-config/AGENTS.md` (persist-install kuralı, Codex'in global talimatı)
- [x] 11. Dokümanlar: README.md, DOCS.md, CHANGELOG.md (1.0.0), PERSISTENT_PACKAGES.md, IMAGE_PASTE.md
- [x] 12. Kök README.md + CLAUDE.md güncelle
- [x] 13. Doğrulama: `bash -n` tüm shell script'ler, `node --check` server.js, YAML/JSON parse, kaçırılmış "claude" referansı taraması
- [x] 14. Missed-spot audit + rapor

## Doğrulama planı
- `bash -n` codex-terminal/run.sh ve scripts/*.sh
- `node --check` image-service/server.js; `jq` package.json
- Python yaml ile config.yaml/build.yaml parse
- `grep -ri claude codex-terminal/` → yalnız bilinçli referanslar kalmalı (ör. karşılaştırma notları)
- Port/slug çakışması kontrolü (claude_terminal_pro ile)
