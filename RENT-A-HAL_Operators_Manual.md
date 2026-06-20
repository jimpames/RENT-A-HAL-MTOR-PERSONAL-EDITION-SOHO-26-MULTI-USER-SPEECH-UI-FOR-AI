# RENT-A-HAL Personal Edition — Operator's Manual

**Version:** v26.16.06 (Federation v1)
**Maintained by:** Jim Ames, N2NHU Lab, Newburgh NY USA
**Last updated:** June 19, 2026

---

## What RENT-A-HAL is

A voice-first, locally-hosted AI realm. You talk to it like the Star Trek
computer. It answers using local Llama 3 8B (free, private, your GPU) and
speaks responses through Kokoro TTS. Optional features include news,
weather, music, business search, and federation with peer realms over
the public internet.

**The 30-second mental model:**
- Browser opens `https://your-realm.com`
- You say "computer, [thing you want]"
- Browser sends transcribed text to your realm via WebSocket
- Realm classifies intent (ask / weather / news / music / service / roundup)
- Routes to the right handler (Llama for "ask", structured services for others)
- Streams synthesized voice back through your speakers

Everything runs on your hardware. No API keys. No cloud LLM. No tokens charged.

---

## Part 1: Quick start for users

### Talking to RENT-A-HAL

Wake word is **"computer"**. Say it, pause, ask your thing, say **"newline"**
(or "submit") to send. Examples:

| You say | What happens |
|---|---|
| `computer, what is the capital of France newline` | Llama answers "Paris" |
| `computer weather newline` | Weather panel opens for your location |
| `computer news newline` | News panel opens with NPR/Guardian/etc. headlines |
| `computer roundup newline` | Radio-style auto-shuffle of news stories |
| `computer music led zeppelin newline` | Music panel opens with YouTube embed |
| `computer find a pharmacy newline` | Service-finder shows nearby pharmacies on map |

### Stopping things

Two ways:
- **SILENCE button** (big red button): immediate hard stop — pauses TTS, clears music, ends roundup
- **Say "stop stop"** anytime, no "computer" wake word needed

### Buttons in the cockpit

| Button | What it does |
|---|---|
| **Enable wake word** | Turns on continuous voice listening |
| **Type a question** | Opens a text box if you don't want to speak |
| **STOP STOP** | Same as voice "stop stop" |
| **SILENCE** (red) | Hard kills all audio |
| **REPEAT REPEAT** | Replays the last answer |
| **News** | Opens interactive news panel |
| **ROUNDUP** (blue) | Starts radio-style auto-shuffle |
| **Weather** | Quick weather for your location |
| **Music** | Opens music search |
| **Services** | Opens service finder |
| **Help** | Shows in-app guide |

---

## Part 2: Installation and first boot

### Hardware requirements

| Component | Minimum | Recommended |
|---|---|---|
| OS | Windows 11 | Windows 11 |
| Python | 3.12 | 3.12 |
| RAM | 16 GB | 32 GB+ |
| GPU | RTX 2060+ with 8 GB VRAM | RTX 4060+ with 8 GB VRAM |
| Storage | 20 GB free | 50 GB+ free (for models, audio cache) |
| Network | Any home internet | Symmetric business circuit |

### First-time setup

```bat
REM Extract the ZIP somewhere — example: C:\Users\you\Desktop\RENTAHAL_FULL
cd C:\Users\you\Desktop\RENTAHAL_FULL\RENTAHAL_APP

REM Create virtual environment
python -m venv venv
venv\Scripts\activate

REM Install dependencies
pip install -r requirements.txt

REM Drop in operator-supplied static assets:
REM   static\bgimage.png         (cockpit background)
REM   static\startup.mp3         (boot tone)
REM   static\thinking.mp3        (thinking sound)
REM   static\newsroundupaudioalert.mp3  (ROUNDUP intro — optional, synth fallback)

REM Verify install
python smoke_test.py
REM Should report "24/24 checks passed"

REM Start the realm
python app.py
REM Listening on http://0.0.0.0:9999
```

Browser to `http://localhost:9999`. You should see the BETA-5 System Terminal.

### Optional: Kokoro TTS service (separate process)

Kokoro runs as a microservice on port 9998. From a second terminal:

```bat
cd ..\kokoro_service
venv\Scripts\activate
pip install -r requirements.txt
python service.py
```

Then in `RENTAHAL_APP\config.ini` set `[KokoroService] host = localhost`. The
realm proxies to it automatically.

### Critical CUDA gotcha

If you install both `onnxruntime` AND `onnxruntime-gpu` together, the CPU
version shadows GPU and Kokoro runs on CPU (slow). Fix:

```bat
pip uninstall -y onnxruntime onnxruntime-gpu
pip install onnxruntime-gpu
```

The realm logs a warning at boot if it detects this. Honor it.

---

## Part 3: Voice operations guide

### How the wake/listen state machine works

```
[wake off]  → click "Enable wake word" → [waiting for "computer"]
[waiting]   → hear "computer" → [listening, 10s silence timer running]
[listening] → say things → buffer fills, 10s silence timer resets on each word
[listening] → say "newline" or "submit" → submit buffer, → [waiting]
[listening] → 10s silence with no words → reprompt, → [waiting]
[listening] → say "stop stop" anywhere → cancel buffer, → [waiting]
```

### Valid submit words

Any of these end your phrase and submit it: `newline`, `submit`, `end`, `enter`,
`go`, `done`. Pick whichever feels natural.

### Voice commands cheat sheet

```
WAKE                  computer
SUBMIT                newline | submit | end | enter | go | done
STOP                  stop stop  (no wake needed)
REPEAT LAST           repeat repeat  (no wake needed)
HELP                  help help  (no wake needed)

INTENTS               (after wake word)
ask anything          computer, what is X newline
weather               computer weather newline
news (interactive)    computer news newline
news roundup          computer roundup newline
                      computer news roundup newline
                      computer play roundup newline
music search          computer music <song or artist> newline
service finder        computer find a <category> newline
                      computer find me a <category> newline
                      computer service finder <category> newline
gmail (if configured) computer gmail newline | computer email newline
```

### Doubled action words protect against false triggers

"Stop" alone won't fire (might appear in a sentence). "Stop stop" is required.
Same for "repeat repeat" and "help help". Designed-in protection — not a bug.

---

## Part 4: Configuration reference

### `config.ini` (main realm config)

Lives in `RENTAHAL_APP\config.ini`. Sections you'll touch:

#### `[Server]` — Where the realm listens
```ini
host = 0.0.0.0           # 0.0.0.0 = all interfaces; 127.0.0.1 = local only
port = 9999              # default; behind ngrok or Cloudflare Tunnel
```

#### `[LLM]` — Language model providers
```ini
providers = gpt4all      # priority list; first available wins
# Other options: claude, huggingface, echo (for testing)

[GPT4All]
host = localhost
port = 4891
model = Llama 3 8B Instruct
```

#### `[TTS]` — Text-to-speech providers
```ini
providers = kokoro_http  # chain order; first available wins
# Other options: kokoro, elevenlabs, openai, sapi5, pyttsx3, echo

[KokoroService]
host = localhost         # leave blank to disable
port = 9998
```

#### `[News]`, `[Weather]`, `[Music]`, `[Service]`
See in-file comments — each enables/disables a feature realm.

### `federation.ini` (federation config)

Lives in `RENTAHAL_APP\federation.ini`. Only loaded if the file exists.

```ini
[Federation]
desire = off                                       # opt-in switch
master_url = https://rentahal.com/api/federate     # the Federator URL
self_url =                                          # YOUR realm's public URL
prefer_federation_for_llm_avg_s = 31.0             # threshold to overflow
checkin_interval_s = 15.0                          # push frequency

[Federator]
enabled = false                                    # true on the Federator only
```

See Part 7 for full federation operations.

---

## Part 5: Public APIs and integration

These endpoints are public on your realm. CORS is `allow_origins="*"` by
default — any web page can call them. Designed this way intentionally
(see the "Little Johnny" demo at `https://rentahal.com/static/little_johnny_first_ai_app.html`).

### `POST /api/ask` — One-shot text-in/text-out LLM

The simplest API. The whole demo is 20 lines of HTML.

**Request:**
```json
{"text": "What is the capital of France?"}
```

**Response:**
```json
{
  "intent": "ask",
  "answer": "Paris is the capital of France.",
  "provider": "GPT4All Llama 3 8B Instruct"
}
```

**Special header — `X-Federation-Hops: <n>`:** if present and ≥ 1, the
receiving realm bypasses its OWN federation provider (runs locally only).
This is the hop-limit protection — used by federated calls to prevent cascades.

**Example:**
```bash
curl -X POST https://your-realm.com/api/ask \
     -H "Content-Type: application/json" \
     -d '{"text":"Hello"}'
```

### `GET /api/setup_status` — Realm health check

Returns whether providers detected, models loaded, etc. Boring but essential.

### `GET /api/config` — Public configuration dump

Operator-visible knobs (sanitized — no secrets). Useful for diagnostics.

### `GET /api/news?source=<S>&category=<C>&limit=<N>` — News stories

Returns JSON of cached stories from the configured RSS feeds. Each story has
`title`, `source`, `audio_url` (pre-rendered Kokoro WAV), `link`.

```bash
curl https://your-realm.com/api/news?source=NPR&limit=10
```

### `GET /api/news/feeds` — Configured feeds

Returns the list of RSS sources the realm is ingesting.

### `GET /api/news/audio/<audio_id>` — Streamed news WAV

Streaming proxy from the Kokoro service. The browser plays via `<audio>` tag.

### `GET /api/news/roundup?count=<N>` — Shuffled radio-style roundup

Returns NPR + Guardian stories interleaved + shuffled, sliced to `count`
(default 20). Backs the ROUNDUP button and voice trigger.

### `WebSocket /ws` — Full conversation channel

The main two-way pipe. Browser opens, sends `{type: "prompt_text", text: "..."}`,
realm streams back events: `bus_query_processing`, `bus_query_result`,
`bus_tts_chunk` (base64 WAV), `bus_intent_classified`, etc.

**The "Hear Llama Through Kokoro" demo** at
`https://rentahal.com/static/hear_llama_through_kokoro.html` shows the
complete WebSocket pattern in under 100 lines of HTML.

### `GET /api/federation/status` — Federation cockpit data

Returns `{desire, master_url, self_url, state, best_llm_peer, best_tts_peer, ...}`.
The cockpit polls this every 20s for the badge in the metrics area.

### `POST /api/federate/checkin` *(only on the Federator)*

Members push their stats here. Federator responds with peer advice.
See Part 7 for protocol details.

### `GET /api/federate/matrix` *(only on the Federator)*

Operator-visible snapshot of the entire federation phonebook. JSON.

---

## Part 6: Building apps against the public APIs

### App #1 — One-button question asker

Save as `app1.html`, open in browser. **That's the whole app.**

```html
<input id="q" placeholder="Ask anything">
<button onclick="ask()">Ask Llama 3</button>
<div id="out"></div>
<script>
async function ask() {
  out.textContent = "thinking...";
  const r = await fetch("https://rentahal.com/api/ask", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ text: q.value })
  });
  const data = await r.json();
  out.textContent = data.answer;
}
</script>
```

### App #2 — News reader

```html
<button onclick="show()">Today's News</button>
<ul id="list"></ul>
<script>
async function show() {
  const r = await fetch("https://rentahal.com/api/news?limit=10");
  const data = await r.json();
  list.innerHTML = data.stories.map(s =>
    `<li>${s.title} — <em>${s.source}</em></li>`
  ).join("");
}
</script>
```

### App #3 — Voice-and-speech chat with TTS

Open a WebSocket, send text, receive streamed TTS audio chunks. See the
"Hear Llama Through Kokoro" demo for the full ~100-line pattern.

### App pattern — when to use what

| Need | Use |
|---|---|
| Just text in / text out | `POST /api/ask` |
| Show news headlines | `GET /api/news` |
| Play news audio | `<audio src="/api/news/audio/...">` |
| Full conversation with TTS | WebSocket `/ws` |
| Realm health monitoring | `GET /api/setup_status` |
| Federation observability | `GET /api/federation/status` and `/matrix` |

---

## Part 7: Federation operations

### When to enable federation

Federation lets multiple RENT-A-HAL realms share LLM capacity. When YOUR
local LLM is slow (queue depth > threshold), your realm temporarily
borrows a peer's `/api/ask` endpoint. The borrowed call's latency feeds
back into your rolling average, creating natural backoff and reapproach.

**Enable it when:**
- You have a second realm online (yours or a friend's)
- You want overflow capacity during burst load
- You want to contribute capacity to the public federation

**Don't enable it when:**
- Your realm runs alone in a closed network
- You need every query to be local for compliance / privacy reasons
- You haven't set a public URL for `self_url` yet

### Becoming the Federator

If you're hosting the federation coordinator (only ONE per network):

```ini
[Federation]
desire = on
master_url = https://yourdomain.com/api/federate
self_url = https://yourdomain.com

[Federator]
enabled = true
state_file = federation_state.json
missed_after_s = 60.0
peer_advice_bump_s = 0.01
```

Restart. Federator endpoints come live at `/api/federate/checkin` and
`/api/federate/matrix`. The matrix persists to `federation_state.json`
between restarts.

### Joining as a member

```ini
[Federation]
desire = on
master_url = https://the-federator.example.com/api/federate
self_url = https://your-realm.example.com

[Federator]
enabled = false
```

Restart. The cockpit federation badge appears within ~25 seconds with
`Fed: ON · Master: the-federator.com · State: HEALTHY`.

### The check-in protocol

Every 15 seconds (+ random startup jitter), members POST to the Federator:

```json
{
  "member_url": "https://your-realm.com",
  "llm_avg_s": 4.2,
  "tts_avg_s": 1.8,
  "tokens_out": 12345,
  "token": ""
}
```

Federator updates the matrix and responds:

```json
{
  "best_llm_peer": "https://faster-peer.example.com",
  "best_tts_peer": null,
  "your_state": "HEALTHY",
  "matrix_size": 3
}
```

The member stores `best_llm_peer`. When local LLM avg exceeds
`prefer_federation_for_llm_avg_s` (default 31s), the next LLM call routes
to that peer's `/api/ask`.

### Cockpit federation badge

```
Fed: ON · Master: rentahal.com · State: HEALTHY · (LLM→peer.example.com)
```

- **Fed**: ON / OFF — your `desire` setting
- **Master**: short hostname of the Federator (hover for full URL)
- **State**: HEALTHY (recent successful check-in) / DEGRADED (4+ failed) / OFF
- **Peers**: currently suggested peer URL(s) for overflow

### Failure modes and recovery

| Symptom | Cause | Fix |
|---|---|---|
| State stuck on OFF | `desire = off` or `self_url` blank | Set both, restart |
| State stuck on DEGRADED | Can't reach Federator | Check master URL, network, ngrok |
| State HEALTHY but no peer in badge | Only 1 member in matrix (you) | Wait for another to join |
| Federated calls timing out | Peer overloaded | Automatic — local fallback kicks in |
| Endless federation cascade | Hop limit bug | Won't happen — protocol enforces `max_federation_hops` |

### Observability

```bash
# See the matrix from the Federator
curl https://the-federator.com/api/federate/matrix

# See your own federation state
curl https://your-realm.com/api/federation/status
```

---

## Part 8: Feature matrix

### What's in v26.16.06

| Feature | Status | Voice trigger | Button | API endpoint |
|---|---|---|---|---|
| **Ask anything** (Llama) | ✅ Production | `computer <question> newline` | "Type a question" | `POST /api/ask` |
| **Weather** | ✅ Production | `computer weather newline` | "Weather" | (inline in `/api/ask`) |
| **News (interactive)** | ✅ Production | `computer news newline` | "News" | `GET /api/news` |
| **News ROUNDUP** | ✅ Production | `computer roundup newline` | 📻 ROUNDUP | `GET /api/news/roundup` |
| **Music search** | ✅ Production | `computer music <q> newline` | "Music" | (WebSocket event) |
| **Service finder** | ✅ Production | `computer find a <X> newline` | "Services" | (WebSocket event) |
| **TTS streaming** | ✅ Production | (automatic) | — | WebSocket `bus_tts_chunk` |
| **Wake word** | ✅ Production | "computer" | "Enable wake word" | — |
| **STOP STOP** | ✅ Production | `stop stop` | "STOP STOP" / 🔇 SILENCE | — |
| **REPEAT REPEAT** | ✅ Production | `repeat repeat` | "REPEAT REPEAT" | — |
| **HELP HELP** | ✅ Production | `help help` | "Help" | — |
| **ACK protocol** | ✅ Production | (under hood) | — | (under hood) |
| **Federation v1 (LLM)** | ✅ Production | (automatic overflow) | (cockpit badge) | `POST /api/federate/checkin` |
| **Federation v2 (TTS)** | 🟡 Architected | — | — | (matrix carries `tts_avg_s` already) |
| **Multilingual TTS** | 🟡 Future | — | — | — |
| **Solana payment gate** | 🟡 Future | — | — | — |
| **Nuitka EXE compile** | 🟡 Future | — | — | — |

### Audio playback features

| Feature | Trigger | Stop |
|---|---|---|
| TTS response streaming | Automatic on every answer | SILENCE / stop stop |
| Boot tone | Page load | (one-shot) |
| Thinking sound | Long-running queries | (auto-stops on result) |
| News story play | Tap ▶ on a story card | SILENCE / pause |
| ROUNDUP intro tones | Start ROUNDUP | (one-shot) |
| ROUNDUP auto-advance | After each story ends | SILENCE / stop stop |
| Music (YouTube embed) | Music intent | SILENCE / stop stop |

### iOS / mobile support

| Capability | iOS Safari | Android Chrome | Desktop |
|---|---|---|---|
| Wake word | ✅ | ✅ | ✅ |
| TTS playback | ✅ (after first tap) | ✅ | ✅ |
| News audio | ✅ | ✅ | ✅ |
| ROUNDUP | ✅ | ✅ | ✅ |
| Music (YouTube) | ✅ | ✅ | ✅ |
| Geolocation (for services) | ✅ (after permit) | ✅ | ✅ |
| Background play | ❌ (browser limit) | ❌ (browser limit) | ✅ |

iOS audio is unlocked by the first user tap on the page. The realm
deliberately plays a silent WAV at first-tap to credit the gesture
before the visible startup tone runs.

---

## Part 9: Comparison matrix

### RENT-A-HAL Personal Edition vs alternatives

| Capability | RENT-A-HAL | OpenAI ChatGPT | Google Assistant | Alexa | LocalGPT/Ollama UIs |
|---|---|---|---|---|---|
| Voice in (STT) | Browser native | App / web | Native | Native | Usually none |
| Voice out (TTS) | Local Kokoro GPU | App TTS / cloud | Cloud | Cloud | Usually none |
| LLM | Local Llama 3 8B | Cloud GPT-4 / o3 | Cloud Gemini | Cloud | Local — varies |
| Cost per query | $0 (electricity) | $0.01-0.50+ | $0 (data harvested) | $0 (data harvested) | $0 |
| Privacy | Stays on your box | Sent to OpenAI | Google | Amazon | Stays local |
| Internet required | Only for federation | Yes | Yes | Yes | No |
| Customizable | Full source access | Closed | Closed | Closed | Varies |
| Multi-user | Yes (per-GUID state) | Per-account | Per-account | Per-account | Usually no |
| Federated overflow | ✅ v1 production | (cloud is the overflow) | N/A | N/A | ❌ |
| Offline-capable | ✅ (no fed required) | ❌ | ❌ | ❌ | ✅ |
| Wake word | "computer" | App-specific | "Hey Google" | "Alexa" | None |
| News/music/services | ✅ built-in | Via plugins | ✅ | ✅ | ❌ |
| Public API | Open `/api/ask` | $$/key | Limited | Limited | Sometimes |
| Cost to operate | One-time hardware | Monthly subscription | Free (you're product) | Free (you're product) | One-time |
| Looks like Star Trek | ✅ | ❌ | ❌ | ❌ | ❌ |

### LLM provider options inside RENT-A-HAL

| Provider | Cost | Speed | Privacy | When to use |
|---|---|---|---|---|
| GPT4All (Llama 3 8B local) | $0 | ~20 tok/s on 4060 | Total | Default — production |
| Claude API | $$ | Fast | Anthropic processes | Cloud burst capacity |
| HuggingFace API | $ | Varies | HF processes | Specialty models |
| Echo (test stub) | $0 | Instant | Total | CI testing only |
| Federation (peer realm) | $0 | Network + peer | Trust peer | Automatic overflow |

### TTS provider options

| Provider | Cost | Quality | Speed | GPU? |
|---|---|---|---|---|
| Kokoro (HTTP service) | $0 | Excellent | Fast | Yes (recommended) |
| Kokoro (inline) | $0 | Excellent | Slow on CPU | Yes |
| ElevenLabs API | $$$ | Best-in-class | Network-bound | No |
| OpenAI TTS API | $$ | Very good | Network-bound | No |
| Windows SAPI5 | $0 | OK | Instant | No |
| pyttsx3 | $0 | OK | Instant | No |
| Echo (test stub) | $0 | None | Instant | No |

---

## Part 10: Troubleshooting

### "Page loads but no audio plays"

iOS only allows audio after a user gesture. **Tap anywhere on the page once.**
After that all subsequent audio plays. The realm tries to unlock audio on
the very first tap by playing a silent WAV; you should see "audio unlocked"
in the browser console.

### "Card displays randomly fail"

Was a real bug, fixed in this version. ACK protocol now confirms every
user-visible event reaches the browser. If you see `ACK MISSING` warnings
in `webgui_detailed.log`, that's the diagnostic — share that line with
support.

### "Federation badge stuck on DEGRADED"

Your check-ins to the Federator are failing. Check:

1. Is `master_url` correct? `curl https://master/api/federate/matrix` should return JSON.
2. Is `self_url` set? Blank = client doesn't even start.
3. Is your firewall blocking outbound HTTPS to the Federator?
4. Does your realm log show "Federation check-in failed" messages?

### "Kokoro produces no audio"

Most common cause: both `onnxruntime` and `onnxruntime-gpu` installed.
The CPU package shadows GPU. Fix:

```bat
pip uninstall -y onnxruntime onnxruntime-gpu
pip install onnxruntime-gpu
```

Look for `[boot] CUDA active: True` in the Kokoro service log.

### "Music plays but YouTube iframe is gone after SILENCE"

That's by design. SILENCE removes the iframe entirely because YouTube's
postMessage API isn't loaded (deliberate choice to avoid YouTube developer
registration). To resume music, search again.

### "Cockpit shows AI avg of 0 forever"

Either no queries have completed yet (ask one) or the realm is restarting
after each query (check log for crashes). Federation won't activate
without a non-zero local avg.

### "ROUNDUP plays no intro tone"

If `static/newsroundupaudioalert.mp3` is missing, the system synthesizes a
3-tone BONG-BONG-BONG sequence via Web Audio API. Both work. To use a
custom intro, drop your own mp3 at that path.

### "Tests pass locally but I see failures after deployment"

Always run `python smoke_test.py` after deploying. If smoke fails but tests
pass, the deployment is missing a config or asset. Check the smoke output
for the specific failure.

---

## Part 11: Where files live

```
RENTAHAL_APP/
├── app.py                    Main launcher
├── config.ini                Edit this for engines, ports, knobs
├── federation.ini            Edit this for federation participation
├── webgui_detailed.log       Boot log + runtime — your friend for debugging
├── federation_state.json     Federator persistence (auto-generated)
├── static/                   Operator-supplied assets (mp3, png)
├── templates/index.html      The cockpit
├── realm/                    Core modules
│   ├── intent.py             Intent classifier (vocabulary lives here)
│   ├── orchestrator.py       Routes intents to handlers
│   ├── engine_chain.py       LLM/TTS provider chains
│   ├── federation.py         Federation matrix + client
│   ├── federation_provider.py LLM provider that wraps peer /api/ask
│   └── realm_core.py         ConnectionManager + ACK protocol
└── tests/                    948 assertions, 24 layers — keep them green
```

---

## Part 12: Operator philosophy

A few principles that show up throughout this codebase. They're not laws,
just patterns that have worked:

1. **Provenance over guessing.** When something breaks, the log line that
   explains it should be findable. The ACK protocol's `ACK MISSING` warning
   is a good example — when an event doesn't reach the browser, you know
   exactly which event for which user.

2. **Configuration over code.** Federation thresholds, feed URLs, intent
   vocabularies, and matrix knobs all live in INI files. Code changes
   require restarts; INI tweaks require re-reads.

3. **Test before you ship.** The clean-room ZIP extract test (extract,
   run all tests, confirm green) is the validation bar. "It works on
   my machine" doesn't count.

4. **Triple-run for zero flakes.** Tests that pass once and fail twice
   are worse than tests that always fail. Run three times, demand
   identical results.

5. **Sabotage-verify critical invariants.** If a test couldn't fail when
   the protection is removed, it isn't really testing the protection.

6. **Honest disclosure.** When you find an old hidden bug, surface it.
   Operators downstream are running on what you've shipped.

7. **Open by default.** `/api/ask` is public for a reason — see the
   Little Johnny demo. Federation works because the surface is already
   shared.

---

## Part 13: Support and escalation

| Issue type | Where |
|---|---|
| Voice features broken | Check `webgui_detailed.log` for the exact event |
| Federation not connecting | `curl /api/federation/status` on both ends |
| Kokoro not running | Check `kokoro_service` log + CUDA install |
| Performance degradation | Check Cockpit AI avg + TTS avg trend |
| New feature requests | (project decision tree — operator's call) |

When asking for help, include:
- Realm version (`v26.16.06`)
- Last 50 lines of `webgui_detailed.log`
- Browser console output
- Cockpit metrics screenshot

---

## Appendix A: The complete intent vocabulary

### Single-word triggers (after "computer" wake)

```
weather, forecast       → weather realm
gmail, email, mail      → gmail realm (if configured)
news                    → news realm (interactive cards)
music                   → music realm
roundup                 → ROUNDUP (auto-shuffle)
```

Anything else after "computer" goes to the `ask` realm (Llama).

### Phrase triggers (checked first, longer matches win)

```
service finder          → service finder
find a <category>       → service finder
find me <category>      → service finder
find nearby <category>  → service finder
news roundup            → ROUNDUP
play roundup            → ROUNDUP
start roundup           → ROUNDUP
start the roundup       → ROUNDUP
play the roundup        → ROUNDUP
```

### Wake-independent commands

```
stop stop               → cancel current operation
repeat repeat           → replay last answer
help help               → show in-app help
```

---

## Appendix B: Quick API reference card

```
PUBLIC ENDPOINTS (CORS open by default)
  GET    /api/setup_status                  → realm health
  GET    /api/config                        → config dump (sanitized)
  POST   /api/ask                           → text in / text out
       headers: X-Federation-Hops (optional)
  GET    /api/news?source=&category=&limit= → news stories JSON
  GET    /api/news/feeds                    → configured feeds
  GET    /api/news/audio/{id}               → streamed WAV
  GET    /api/news/roundup?count=           → shuffled radio playlist
  GET    /api/federation/status             → cockpit federation state
  WS     /ws                                → conversation channel

FEDERATOR-ONLY ENDPOINTS (when [Federator] enabled = true)
  POST   /api/federate/checkin              → push stats, get advice
  GET    /api/federate/matrix               → matrix snapshot
```

---

🖖 **Live long and prosper.**

Built by Jim Ames at N2NHU Lab, Newburgh NY USA.
RENT-A-HAL Personal Edition is open-source voice-first AI for one operator
to run from one box and serve one household — or many, via federation.
