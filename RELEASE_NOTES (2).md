# RENT-A-HAL Personal Edition — Release Notes

## v1.0.2 (2026-06-23)

**Type:** Bug fix release.
**Compatibility:** Wire-compatible with v1.0.0 / v1.0.1 peers. No coordination required.
**Configuration changes:** None.
**Upgrade time:** Under 5 minutes per realm.

### Resolved issues

**RAH-0002** — TTS federation rescue does not fire when local KokoroService is
unavailable, despite v1.0.1 chain reordering.

`TTSChain.probe_local()` returned floor providers (SAPI5, pyttsx3) as if they
were real local TTS recovery. The federation FALLBACK provider then aborted
the rescue and the chain fell through to SAPI5. Symptom: cockpit displayed
`TTS: SAPI5 (Windows TTS)` during a failover that should have shown
`TTS: Federation TTS Fallback (peer realms)`.

Behavior is now symmetric with the LLM chain, which has always correctly
skipped Echo (its floor provider) during local probing.

### Behavior changes

When local KokoroService is unavailable and a healthy federation peer is
reachable, TTS now federates to the peer rather than falling through to SAPI5.

No behavior change when KokoroService is healthy, federation is disabled, or
no peer is available.

### Upgrade procedure

See `DEPLOYMENT.md` in this patch folder.

### Files changed

- `realm/engine_chain.py`
- `tests/test_chain_probe.py` (optional)

---

## v1.0.1 (2026-06-22)

See v1.0.1 release notes.

---

## v1.0.0 — Initial Release

See main README and CHECKPOINT.md.

---

🖖 Live long and prosper.
