# DEPLOYMENT — UI Diagnostic Hot-Patch
## 2026-06-23 rev 5 — Production observability for intermittent UI render

Drop-in replacement of two files. No federation impact. No wire protocol change.

---

## What's in this patch

```
ui_diag_hotpatch/
├── templates/
│   └── index.html              ← REPLACE existing
├── config.ini                  ← MERGE [Debug] section (or replace)
├── tests/
│   └── test_chain_probe.py     ← OPTIONAL (adds 3 config-flag tests)
└── DEPLOYMENT.md               ← This file
```

---

## Deployment

### 1. Back up

```cmd
cd path\to\RENTAHAL_APP
copy templates\index.html templates\index.html.bak_rev4
copy config.ini config.ini.bak_rev4
```

### 2. Replace

```cmd
copy /Y ui_diag_hotpatch\templates\index.html templates\index.html
```

### 3. Merge the [Debug] section into config.ini

Either replace `config.ini` entirely (the shipped one is identical to your
rev-4 config except for the new section), OR add this block manually
between [Hardware] and [ngrok Tunnel]:

```ini
; @section-label: Debug
; Operator-toggleable diagnostic logging. Defaults to ON for v1.0.x while
; we hunt down intermittent UI render issues (music iframe / service cards).
; Set false to silence the diagnostic console.log lines once your deployment
; has been stable for some time and you no longer need the observability.
[Debug]
; @label: Verbose UI Logging @type: bool @scope: frontend @help: Logs music/service panel render diagnostics to browser console 100ms after render. Filter console with "[music-diag]" or "[service-diag]". Zero performance impact. Set false to silence.
ui_verbose = true
```

### 4. Restart the realm

HALT in the wizard, then GO.

---

## Verification

1. Open the cockpit. Open browser console (F12).
2. Ask a music or service query via voice.
3. ~100ms after the panel renders, you should see one of:
   ```
   [music-diag] 100ms post-append: iframe-attached=true iframe-in-doc=true ...
   ```
   or
   ```
   [service-diag] 100ms post-render: cards=3 results-in-doc=true ...
   ```

If you see these lines, the diagnostic is working.

If the bug reproduces (status shows but content not visible), the diagnostic
output will reveal which of three failure modes is happening:

| Diagnostic shows | Means |
|---|---|
| `iframe-in-doc=false` | Container got detached after render |
| `iframe-size=0px x 0px` or `iframe-display=none` | CSS overriding inline style |
| All values look correct but iframe not visible | Higher-layer browser rendering issue |

---

## Silencing diagnostics (when you no longer need them)

Edit `config.ini`:

```ini
[Debug]
ui_verbose = false
```

Restart realm. Console output goes silent.

---

## Compatibility

Wire-compatible with v1.0.x peers. No federation impact. Operator can
deploy to RAH or RNL independently with no coordination.

---

## Rollback

```cmd
copy /Y templates\index.html.bak_rev4 templates\index.html
copy /Y config.ini.bak_rev4 config.ini
```

Restart.

---

🖖
