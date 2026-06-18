# RENT-A-HAL Personal Edition — Snapshot Manifest

**Snapshot:** Working checkpoint for repo commit
**Date:** 2026-06-17
**Version tag in code:** 26.16.06
**Status:** Production — live at https://rentahal.com

---

## Verification at snapshot time

All test layers passing, last triple-run zero flakes:

| Layer | Count |
|---|---|
| realm pytest | **333** |
| smoke | 24 |
| syntax | 3 |
| thinking-sound | 6 |
| browser state machine | 17 |
| iOS audio unlock | 8 |
| music panel | 26 |
| music robustness | 20 |
| service panel | 33 |
| voice-path service | 22 |
| service re-render | 14 |
| panel scroll | 14 |
| panel mutex | 21 |
| wake-timer/help/footer | 49 |
| answer scroll | 13 |
| metrics display | 25 |
| silence button | 16 |
| destroy-recreate | 17 |
| STT normalize | 9 |
| kokoro microservice | 37 |
| **TOTAL** | **707** |

---

## What's in this snapshot

### Realms shipping
- **Ask** — Llama 3 8B Instruct via GPT4All
- **Weather** — OpenWeatherMap
- **News** — RSS + Kokoro pre-cached audio
- **Music** — DuckDuckGo HTML scrape → YouTube embed (no API key)
- **Service Finder** — BizData (OpenStreetMap) + Nominatim, 75+ categories
- **Stop** — doubled wake word, halts TTS + YouTube
- **Repeat** — doubled wake word, replays last answer
- **Help** — doubled wake word, opens onscreen reference

### Browser features
- Wake-word state machine (idle → armed → submit)
- Wake-word privacy timer (short/medium/long/infinite/off)
- Help panel with full voice-command reference
- Footer with full copyright/credits boilerplate
- 🔇 SILENCE button (emergency kill for runaway audio)
- Cockpit metrics row (5 gauges: AI queue, TTS queue, AI avg, TTS avg, tokens)
- destroyAndRecreate pattern for card containers (news/music/services)
- nukeAllCardPanels mutex (one card area at a time)
- iOS audio unlock + autoplay handling
- Echo guard with multi-chunk TTS support

### Realm features
- Event bus (publish/subscribe, every event relayed to browser as bus_*)
- Orchestrator with per-user state isolation + bounded queue
- Metrics class (rolling-window averages, cumulative tokens, atomic counters)
- Engine chains (LLM + TTS abstraction with fallbacks)
- Intent classifier with phrase/single/doubled-word patterns
- STT punctuation sanitizer (handles browser-injected punctuation)
- Service finder with 75+ category map and Nominatim geocoder
- Gate verification module (off by default, optional payment gating)
  - Session token signing/verification (HMAC-SHA256)
  - Replay protection cache
  - Solana RPC client with fallback
  - All sabotage-verified

### Kokoro microservice
- GPU-accelerated TTS synthesis
- Queue-serialized requests (no GPU thrashing)
- LRU audio cache
- Pre-cached news WAVs (morning/noon/evening)
- HTTP API on port 9998
- 37 microservice tests

---

## Known limits at snapshot time

These are honest scope notes, not bugs:

1. **Federation not yet implemented** — designed but deferred per operator decision
2. **Payment gate is off by default** — `realm/gate.py` exists, tested (42 tests), but not wired into app.py or browser yet (Turn 1 of 3 complete; Turns 2-3 deferred)
3. **Speech recognition** — relies on browser's Web Speech API; Chrome uses Google cloud, Safari uses Apple. No on-device STT.
4. **Single-box capacity** — RTX 4060 comfortably serves a household; for >20 simultaneous active users, larger GPU needed.

---

## Field-tested deployment context

- **Hardware:** Windows 11 + NVIDIA GeForce RTX 4060
- **Public access:** https://rentahal.com via Cloudflare Tunnel or ngrok
- **Backend host:** Jim Ames @ N2NHU Lab for Applied AI, Newburgh NY 12550 USA
- **Confirmed working on:** Win11 Chrome, Win11 Edge, macOS Safari, iPhone 8+ Safari over LTE (yes, 2017 hardware over cellular)
- **Demoed via voice to:** India team over video call (Service Finder), curbside parking spot picking up daughter from grandma's house (full voice control)

---

## Files NOT included in the zip

For a clean repo checkpoint, the following are excluded:

- `__pycache__/` directories
- `*.pyc` compiled files
- `.pytest_cache/` directories
- `.git/` (if present — caller manages git)
- Any uploaded model files (GPT4All Llama 3 8B must be installed separately via GPT4All; Kokoro ONNX model installed via kokoro_service setup)

---

## Restore instructions

1. Unzip `RENTAHAL_FULL_snapshot_2026-06-17.zip`
2. Create Python 3.12 venv
3. `pip install -r RENTAHAL_APP/requirements.txt`
4. `pip install -r kokoro_service/requirements.txt`
5. Install GPT4All separately, pull Llama 3 8B Instruct, enable API server (port 4891)
6. Start Kokoro: `python kokoro_service/service.py`
7. Start realm: `python RENTAHAL_APP/app.py`
8. Verify: `python -m pytest RENTAHAL_APP/tests/` — expect 333 passed

---

## Credits

- **Design:** Jim Ames, N2NHU Lab for Applied AI
- **Implementation:** Claude (Anthropic), in collaboration with Jim
- **LLM:** Meta Llama 3 8B Instruct (via GPT4All)
- **TTS:** Kokoro ONNX
- **STT:** Web Speech API (browser-native)

© Copyright 2026, Jim Ames. All rights reserved.

🖖 *Live long and prosper.*
