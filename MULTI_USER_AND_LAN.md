# BETA-5 — Multi-User, LAN Access, and the Kokoro Microservice

Answers to three real questions you raised, plus the BETA-5 skin integration.

## 1. Does the realm support multi-user?

**Yes — already.** It's not a future feature; it's how the realm is built.

What's going on under the hood:
- Every websocket connection receives a `user_guid` UUID, persisted as a cookie scoped to the host.
- Every bus event carries `user_guid` (the IntentClassifier propagates it through `prompt_text → intent_classified → query_processing → query_result → tts_*`).
- The Orchestrator keeps per-user state in `self.users: Dict[str, UserState]`. Each user gets independent `last_result` (for REPEAT), `active_query` (for STOP), and `active_tts_cancel`.
- The websocket relay (`ws_relay` in app.py) routes bus events back to the right user via `manager.safe_send(guid, payload)` — so user A's `query_result` lands in user A's browser, not user B's.
- The harness includes `test_per_user_isolation` (test_star_trek_realm.py): two simulated users in parallel, user A says STOP STOP, the test asserts user B's TTS completes unmolested. Green across every flake check.

**What sharing a session between tabs of the SAME browser means:**
Both tabs send the same cookie → same `user_guid` → both tabs subscribe to the same event stream. STOP STOP from tab A will cancel TTS in tab B. That's correct — it's one human with two windows open. If you want truly independent tabs, open one in Chrome and one in Incognito (different cookie jars).

**Multi-user on the LLM side:**
The SafeQueue in realm_core.py serializes queries through GPT4All (which can only handle one at a time on a single GPU). So two users asking at the same moment will see user A's answer first, then user B's. If you want true parallelism, you can run multiple GPT4All instances on different ports and round-robin between them in the chain — that's a chain change, not an architecture change.

## 2. Why does http://192.168.1.244:9999 fail with no mic prompt?

**Browser security rule, not a realm bug.**
Chrome's `getUserMedia()` requires a **secure origin**. The accepted origins are:
- `https://` anything
- `http://localhost`
- `http://127.0.0.1`
- file:// in some configurations

A plain LAN IP like `http://192.168.1.244` over HTTP is treated as an **insecure context**, and `getUserMedia()` rejects silently — no permission prompt, no error dialog, nothing visible to the user. The realm gets the page load, but mic access never happens.

This is by design from Chrome and isn't going away. Three real fixes:

### Option A — Cloudflare Tunnel (recommended, free, zero cert hassle)

```cmd
:: install cloudflared once
winget install --id Cloudflare.cloudflared

:: run a tunnel pointing at the realm
cloudflared tunnel --url http://localhost:9999
```

It prints a URL like `https://something-funny-words.trycloudflare.com`. That's a real HTTPS origin, mic access works, and you can share that URL with anyone on the planet — phone, tablet, friend's laptop. No port forwarding, no certs, no NAT mess.

### Option B — ngrok (also free, similar story)

```cmd
ngrok http 9999
```

Same idea, different vendor. ngrok's free tier has bandwidth limits and the URL rotates per session unless you sign up.

### Option C — uvicorn with self-signed HTTPS (local LAN only)

Edit `app.py`'s `uvicorn.run(...)` line:
```python
uvicorn.run(app, host=host, port=port,
            ssl_keyfile="key.pem", ssl_certfile="cert.pem",
            log_config=None, ws_ping_interval=None, ws_ping_timeout=None)
```

Generate cert + key with `openssl` or `mkcert`. Every browser on every device will warn about the self-signed cert and require a "proceed anyway" click. Painful for non-technical visitors but works. Not recommended unless you specifically need HTTPS without any external service.

**Recommendation:** Cloudflare Tunnel for anyone visiting from a different machine. Localhost stays HTTP because the browser explicitly trusts it.

## 3. The Kokoro Microservice (next session)

You're right that this is the right factoring, and I want to do it justice rather than rush it into this turn. Here's the shape, written down so we can build it cleanly next time:

### What it solves
- **Kokoro startup cost happens once**, not per realm-restart. The realm becomes restartable in seconds.
- **Concurrent synth.** Today, two users asking at the same instant share one Kokoro session — second user waits for first user's WAV. With the microservice running multi-worker uvicorn, both go in parallel on different worker processes.
- **GPU stays warm.** No model reload on idle.
- **Realm becomes pure CPU**, easier to compile to EXE.
- **Other apps can use it too.** Your news_reader.py becomes a one-line HTTP POST instead of a Kokoro import.

### Sketch

```
RENTAHAL_APP/
├── app.py                       # realm (port 9999) — no kokoro_onnx import at all
├── kokoro_service/
│   ├── service.py               # tiny FastAPI: POST /tts {text, voice} → audio/wav
│   ├── config.ini               # model paths, GPU options, worker count
│   ├── run.bat                  # uvicorn --workers 4 service:app --port 9998
│   └── tests/
│       ├── test_unit.py         # single-request correctness
│       ├── test_concurrent.py   # 10 simultaneous synths, all distinct, all <Xs
│       └── test_warmup.py       # first request slow, subsequent fast
└── realm/engine_chain.py
    └── KokoroHTTPProvider       # NEW: replaces in-process KokoroTTSProvider
                                 #      when [Kokoro] host/port are set
```

### Config additions (preview)

```ini
[Kokoro]
; Set host+port to use a remote Kokoro microservice. Empty = in-process.
host = localhost
port = 9998
timeout = 30
```

The factory dispatches: if host/port set → `KokoroHTTPProvider`; else → `KokoroTTSProvider` (in-process). Both implement the same interface. The chain doesn't know which it's talking to.

### Concurrency
The microservice will run uvicorn with N workers. Each worker loads Kokoro once at startup. Requests round-robin between workers. A request is one HTTP call, blocking on the worker for ~0.3-2s (depending on text length and GPU). N=4 workers = 4 concurrent synths.

### Tests to write
- **Unit**: POST /tts → 200, body is valid WAV, sample rate sane.
- **Concurrent**: 10 simultaneous requests, all complete, all distinct audio.
- **Warmup**: first request after start is slower than steady-state requests (proves model is hot).
- **Graceful degradation**: if the microservice is down, realm's KokoroHTTPProvider reports unavailable, chain falls through to ElevenLabs/OpenAI/SAPI5. Zero crashes.

When you're ready to build this, attach your news_reader.py one more time (so I have the exact Kokoro init pattern in front of me, instead of going by memory) and we'll knock it out in a focused session.

## What changed in THIS drop

Just the index.html skin merge:
- BETA-5 background image overlay (CSS `.background-wrapper`, fixed top-left, 28%×28%, opacity 0.75, z-index -1)
- BETA-5 banner (`<div class="beta-banner">BETA-5 System Terminal</div>` above the controls)
- Startup MP3 click handler in the boot IIFE (one-shot, fails silent if file missing or autoplay blocked)
- Everything else preserved: metrics display, buffered dictation, NEWLINE submit, STOP STOP, REPEAT REPEAT, waveform canvas, setup card

Drop the new `index.html` into `RENTAHAL_APP\templates\`. Drop `bgimage.png` and `startup.mp3` into `RENTAHAL_APP\static\`. Hard-refresh.

The full harness still passes: **66 pytest + 21 smoke + 10 browser × 3 runs, zero flakes.**

## Troubleshooting — known gotchas

### Kokoro speaks but slowly (CPU instead of GPU)

**Symptom:** "She spoke, it was perfect, but I had a VERY long wait."
TTS works but takes 5-15+ seconds instead of the expected 0.3-1.5s.

**Most common cause (verified by Jim Ames on Win11, 2026-06):** both
`onnxruntime` and `onnxruntime-gpu` Python packages installed in the
same venv. The CPU one shadows the GPU one; CUDA never activates.

**How to check:** look at your service boot log for this line:
```
Available ONNX providers: [...]
```
If you see `['AzureExecutionProvider', 'CPUExecutionProvider']` (or any
list missing `CUDAExecutionProvider`), GPU is not active.

**Fix — the exact sequence that worked:**
```cmd
pip uninstall -y onnxruntime onnxruntime-gpu
pip install onnxruntime-gpu
```

Then restart the service. The provider list should now include
`'CUDAExecutionProvider'` and TTS should be near-instant.

The service detects this case and logs an explicit `GPU NOT ACTIVE`
error with the fix command at startup, so you don't have to remember it.

### Mic access fails silently from a LAN IP

**Symptom:** http://localhost:9999 works perfectly, but visiting
http://192.168.1.X:9999 (or any LAN IP) shows the page but the mic
prompt never appears and voice doesn't work.

**Cause:** Chrome's `getUserMedia()` requires a secure origin. Plain
HTTP on a LAN IP doesn't count; only `https://`, `localhost`, or
`127.0.0.1` are trusted.

**Fix:** see the Cloudflare Tunnel / ngrok / self-signed-HTTPS section
above. Easiest answer is `cloudflared tunnel --url http://localhost:9999`
which gives you a free HTTPS URL that works from anywhere.

### Realm boots but TTS provider list is empty

**Symptom:** boot log shows all TTS providers as `False`.

**Cause:** depends which providers you have configured. Common ones:
- Kokoro service not running yet → start it first, in a separate shell
- Kokoro model files in the wrong folder → check service log for the
  "model not found" message; the service tells you exactly where it
  looked
- pyttsx3 disabled on Windows (intentional — SAPI5 takes over) →
  install pywin32 if SAPI5 isn't loading either
