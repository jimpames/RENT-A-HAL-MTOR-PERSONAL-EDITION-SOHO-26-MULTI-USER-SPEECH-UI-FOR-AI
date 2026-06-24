# RENT-A-HAL Personal Edition — Release Notes

## v1.0.3 (2026-06-23)

**Type:** Observability release (no behavior change).
**Compatibility:** Wire-compatible with v1.0.x peers. No coordination required.
**Configuration changes:** Adds `[Debug] ui_verbose = true`.
**Upgrade time:** Under 5 minutes per realm.

### New diagnostics

**RAH-OBS-0001** — Browser console now logs `[music-diag]` and `[service-diag]`
lines 100ms after each music/service panel render. Captures iframe attachment,
panel display state, and container offsetHeight for diagnosing intermittent
"status text shows but content not visible" failures.

Gated on `[Debug] ui_verbose` (default true). Set false to silence.

### Behavior changes

None. Diagnostics are observation-only.

### Upgrade procedure

See `DEPLOYMENT.md` in this patch folder.

### Files changed

- `templates/index.html`
- `config.ini`
- `tests/test_chain_probe.py` (optional)

---

## v1.0.2 (2026-06-23)

TTS federation rescue now correctly fires when local Kokoro is unavailable.

---

## v1.0.1 (2026-06-22)

TTS federation fallback ordering correction.

---

## v1.0.0 — Initial Release

See main README and CHECKPOINT.md.

---

🖖 Live long and prosper.
