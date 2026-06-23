# DEPLOYMENT — probe_local TTS Fix Hot-Patch
## 2026-06-23 rev 4 — Resolves RNL failover bug

Single-file replacement. Restart realm. No config changes.

---

## What's in this patch

```
probe_local_fix_hotpatch/
├── realm/
│   └── engine_chain.py             ← REPLACE existing
├── tests/
│   └── test_chain_probe.py         ← OPTIONAL (regression tests)
└── DEPLOYMENT.md                   ← This file
```

---

## Deployment

### 1. Back up

```cmd
cd path\to\RENTAHAL_APP
copy realm\engine_chain.py realm\engine_chain.py.bak_rev3
```

### 2. Replace

```cmd
copy /Y probe_local_fix_hotpatch\realm\engine_chain.py realm\engine_chain.py
copy /Y probe_local_fix_hotpatch\tests\test_chain_probe.py tests\test_chain_probe.py
```

### 3. Restart

HALT in the wizard, then GO.

---

## Verification

Repeat the RNL failover test:

1. Kill BOTH GPT4All AND Kokoro on RNL
2. Ask a question on RNL's cockpit
3. **Expected:**
   - `LLM: Federation (peer realms)` ✅
   - `TTS: Federation TTS Fallback (peer realms)` ✅ (previously fell to SAPI5)
4. Restart Kokoro on RNL
5. Ask another question
6. **Expected:** TTS returns to local Kokoro via pre-flight probe

---

## Rollback

```cmd
copy /Y realm\engine_chain.py.bak_rev3 realm\engine_chain.py
```

Restart.

---

## Compatibility

Wire-compatible with v1.0.0 / v1.0.1 / v1.0.2 peers. Roll out one realm at a time.

---

🖖
