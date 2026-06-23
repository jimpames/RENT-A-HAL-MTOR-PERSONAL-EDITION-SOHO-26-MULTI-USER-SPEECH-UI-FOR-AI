# RENT-A-HAL Personal Edition — Release Notes

## v1.0.1 (2026-06-22)

**Type:** Bug fix release.
**Compatibility:** Wire-compatible with v1.0.0 peers. No coordination required.
**Configuration changes:** None.
**Upgrade time:** Under 5 minutes per realm.

### Resolved issues

**RAH-0001** — TTS chain falls through to SAPI5 instead of federating to peer
when local TTS engine fails.

Affects deployments where the local KokoroService becomes unavailable while a
healthy federation peer is reachable. Federated TTS rescue now fires correctly
in this condition.

### Behavior changes

When local KokoroService is unavailable and a healthy federation peer is
reachable, TTS now federates to the peer. Cockpit displays
`TTS: Federation TTS Fallback (peer realms)` during this state.

When federation is disabled, no peer is available, or KokoroService is
healthy: no behavior change from v1.0.0.

### Upgrade procedure

See `DEPLOYMENT.md` in this patch folder.

### Files changed

- `app.py`
- `tests/test_federation_tts.py` (optional)

---

## v1.0.0 — Initial Release

See main README and CHECKPOINT.md.

---

🖖 Live long and prosper.
