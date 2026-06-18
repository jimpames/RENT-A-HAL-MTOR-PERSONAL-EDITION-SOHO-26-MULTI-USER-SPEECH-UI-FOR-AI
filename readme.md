# RENT-A-HAL Personal Edition API Multi-User Speech UI for AI FOR WINDOWS 11 AND RTX
## User Manual & Theory of Operation

*"Bringing the future to the present"* — N2NHU Lab for Applied AI

Version 26.16.06 · Summer 2026 · Newburgh, NY

status: beta - race bugs 

will I be making this available???? yes. binary only. when bugs are dealt with. before summer I hope.

note the BAT file and the HTML file !!! 
an API demo to PROVE it is real...

What this lets you do

Send the .bat to skeptics: "Run this. Tell me what you see." They get 10 live AI calls in 60 seconds.
Send the HTML to little Johnnys: "Save this file. Open it. You just built an AI app."
Send both to operators: "This is what your system would expose if you ran one. No SDK. No cloud. No keys."
Use them yourself for diagnostics: Demo #10 (latency timing) is genuinely useful — if Saturn responses start taking 30 seconds, the timing breakdown tells you whether it's network, DNS, TLS, or the LLM itself.

🖖 Test it from your Win11 box, Captain. The .bat double-click experience is going to be a real wow moment for first-timers — 10 demos, automatic pacing, real Llama 3 talking back from a 4060 in your basement. No API keys. No cloud. No middlemen. Just curl and a household GPU bringing the future to the present. ✨

api endpoints:
<img width="832" height="793" alt="api-endpoints" src="https://github.com/user-attachments/assets/426deaa5-a923-4749-a60d-3e77934a5358" />


bat demo:
<img width="843" height="798" alt="demo" src="https://github.com/user-attachments/assets/a5b4591a-4d2f-4870-9631-ce31c5aad1a0" />

html demo:
<img width="786" height="487" alt="html-demo" src="https://github.com/user-attachments/assets/ca5fb001-c050-4dd5-86af-c00260e0cd59" />



a product many man-years in the making:
- three years - three books - three redesigns - 1000s of builds - six AI and one human
  
PUBLIC LIVE DEMO:

HTTPS://RENTAHAL.COM

API DEMO:
https://rentahal.com/static/little_johnny_first_ai_app.html

KOKORO app demo:
https://rentahal.com/static/hear_llama_through_kokoro.html

MAIN PANEL:
<img width="1357" height="997" alt="rentahal-pe" src="https://github.com/user-attachments/assets/7da95d2d-4a28-4ff5-b6cb-5cb2cac1e025" />

AI ANSWERS POWERED BY FREE LOCAL GPT4ALL AND LLAMA 3 8B INSTRUCT

<img width="1338" height="990" alt="AI-answers-by-llama-3-" src="https://github.com/user-attachments/assets/d1eb0afb-47d1-4d58-8ff6-1f8bb97b83bd" />


VOICE SERVICE FINDER:
<img width="1365" height="974" alt="voice-service-finder" src="https://github.com/user-attachments/assets/a6505b73-fc2b-4ed3-9e91-7b916f100b73" />

VOICE VIDEO PLAYER:
<img width="1361" height="970" alt="music-videos-on-demand-by-voice" src="https://github.com/user-attachments/assets/99676c95-1d3b-4299-ae3c-75c47345c5c1" />

VOICE WEATHER:
<img width="1308" height="983" alt="voice-weather" src="https://github.com/user-attachments/assets/232098a2-050e-454d-b926-5ed320080ccf" />

VOICE NEWS:
<img width="1262" height="979" alt="news-by-voice" src="https://github.com/user-attachments/assets/f35d441a-7438-4de9-9a82-49f05aa0d435" />

VOICE HELP HELP: tip - click foto to make it realbig(tm) so you see all commands...
<img width="1303" height="977" alt="help-help-voice-commands" src="https://github.com/user-attachments/assets/1ceb4249-2ea8-47b6-878b-cbd3d64c639a" />


BETA DEMO VIDEO:

https://youtu.be/UXO1vZaK8FI?si=pUpjnRkyXe08rVjX
---

## What This Is

RENT-A-HAL Personal Edition is a **voice-first, multi-user AI realm** that runs on a single Windows 11 box with an NVIDIA GPU. One machine, sitting on your desk, serving an entire home or small office. Voice in, voice out, all local, all yours.

You wake it by saying **"computer"**. You ask your question. You say **"newline"** to submit. The answer arrives spoken in a natural voice, with structured visual results when relevant — news tiles, music videos, business listings, weather summaries. Multiple users can hit it at once, each in their own session, each with their own state.

This document is the manual. It explains what RENT-A-HAL does, how it's built, and how you can extend it. There is no magic here — only careful engineering, told plainly.

---

## The Hook: What You Get on Day One

| You ask | What happens |
|---|---|
| "Computer, tell me about Apollo 11. Newline." | Llama 3 8B Instruct answers, Kokoro speaks it back in seconds |
| "Computer, weather in Tokyo. Newline." | OpenWeatherMap looked up, spoken summary, no LLM tokens spent |
| "Computer, news. Newline." | Today's headlines, tappable tiles, pre-cached audio for instant playback |
| "Computer, music London Calling. Newline." | YouTube embed of the Clash track, plays in-page |
| "Computer, service finder haircut. Newline." | Real barbershops near you, distance, hours, phone, map — from OpenStreetMap |
| "Stop stop." | Halts everything — TTS, music, services |
| "Help help." | Shows every voice command on screen |

All of that runs on **one Win11 box** with an NVIDIA GeForce RTX 4060 (or better), accessed by any browser on your LAN — or from anywhere, via Cloudflare Tunnel or ngrok. iPhone Safari works. Android Chrome works. Desktop Edge works. Tested on hardware as old as **iPhone 8+ over LTE**.

---

## Theory of Operation

### The big picture

```
   Browser (Chrome / Safari / Edge)
   ┌───────────────────────────────────────────┐
   │  • Web Speech API → text                  │
   │  • WebSocket to realm                     │
   │  • <audio> element for TTS playback       │
   │  • Card panels (news/music/services/help) │
   └────────────────────┬──────────────────────┘
                        │ WebSocket (text in,
                        │ audio bytes out)
                        ▼
   ┌───────────────────────────────────────────┐
   │           THE REALM (FastAPI)             │
   │  ┌─────────────────────────────────────┐  │
   │  │  Intent Classifier                  │  │
   │  │   ↓                                 │  │
   │  │  Event Bus  ── publish/subscribe    │  │
   │  │   ↓                                 │  │
   │  │  Orchestrator (queue + workers)     │  │
   │  │   ↓                                 │  │
   │  │  Realms: ask / weather / news /     │  │
   │  │          music / service / stop /   │  │
   │  │          repeat / help              │  │
   │  └─────────────────────────────────────┘  │
   └─────┬──────────────────────────────┬──────┘
         │                              │
         ▼                              ▼
   GPT4All Local                Kokoro TTS Microservice
   (Llama 3 8B)                 (GPU-accelerated, port 9998)
```

Every piece is replaceable. The intent classifier is regex + n-gram scoring (no model needed). The orchestrator is plain async Python with a careful queue. The LLM is whatever provider you wire in — GPT4All is just the default. The TTS is its own process so it can be GPU-pinned and updated independently.

### The Event Bus

The heart of the realm is a publish/subscribe **event bus**. Everything is a typed event with a payload. Nothing in the system calls anything else directly — components publish events, and other components subscribe.

```python
await bus.publish("intent_classified",
                  user_guid=guid, kind="weather",
                  slots={"city": "tokyo"}, text=raw)
```

A handler that cares about weather subscribes once at startup:

```python
await bus.subscribe("intent_classified", on_intent)
```

This decoupling is why the system is honest. Every realm minds its own business. Adding a new realm doesn't require touching any existing one. The browser sees the same events the realm does — every bus event is relayed to connected WebSockets prefixed with `bus_`, so the browser receives `bus_query_processing`, `bus_query_result`, `bus_tts_chunk`, `bus_metrics_snapshot`, and so on. The UI's job is to react to these events.

There are no callbacks, no chained promises, no shared mutable state. Just events.

### The Orchestrator

The orchestrator is a single async worker loop reading from a bounded queue. When the intent classifier identifies a query, the orchestrator queues it (`pending`), pulls it (`in-flight`), routes it to the correct realm handler, captures the result, publishes `query_result`, then calls the TTS subsystem to speak it.

Three things make this clean:

1. **Per-user state isolation.** Each connected user has a `UserState` keyed by GUID — their location, their last result, their active TTS cancellation token. One user's "stop stop" never affects another user's playback.

2. **Bounded concurrency.** Only one query per user at a time. The queue has a hard cap. The orchestrator can't be overwhelmed by a single user pasting 50 prompts.

3. **Metrics that tell the truth.** Queue depth, in-flight count, rolling average service time, cumulative tokens generated — all tracked atomically, broadcast to every connected browser every 2 seconds as a `metrics_snapshot` event. **Everyone sees what everyone else is queuing.** Transparency is the default.

### Realms: small, focused, swappable

A "realm" is what RENT-A-HAL calls a domain handler. The seven realms in Personal Edition:

| Realm | Backend | Tokens? |
|---|---|---|
| **ask** | Llama 3 8B Instruct via GPT4All local API | Yes (LLM) |
| **weather** | OpenWeatherMap | No |
| **news** | RSS feeds + Kokoro pre-cached audio | No |
| **music** | DuckDuckGo HTML scrape → YouTube embed | No |
| **service** | BizData (OpenStreetMap) + Nominatim geocoder | No |
| **stop** | Doubled wake word — halts TTS and YouTube | No |
| **repeat** | Doubled wake word — replays last answer | No |

Only **ask** uses LLM tokens. Everything else is structured data plus a brief spoken summary. This is why the metrics panel shows "Tokens out: X" — it tracks **real local AI usage**, the kind that would cost you money if you were paying a cloud provider. Service Finder and Weather don't inflate the number, because they didn't call the LLM.

### Compartmentalization & isolation

The realm process and the Kokoro TTS microservice are **separate operating system processes**. They communicate over HTTP localhost. This isn't an accident — it lets you:

- Restart Kokoro without dropping user sessions
- Pin Kokoro to GPU 0 and the LLM to GPU 1 (or both to the same GPU with VRAM headroom)
- Upgrade the TTS model independently of the realm
- Replace Kokoro entirely (Coqui, ElevenLabs, OpenAI TTS) by changing one config line

Inside the realm, the LLM and TTS are abstracted as **engine chains**. Each chain has a primary provider and unlimited fallbacks. If GPT4All goes down, you can list `openai → anthropic → gpt4all` and the chain tries them in order. Same pattern for TTS.

Every config knob lives in `config.ini` with declarative `@label`, `@type`, `@scope` tags so a future setup UI can render them automatically. There are zero hardcoded magic numbers in the realm code.

---

## API-First Design: Little Johnny Writes His First AI App

Little Johnny is nine years old and wants to write an AI app that asks the household robot for jokes. His parents have RENT-A-HAL running in the basement. Here is his first AI app — five lines of HTML.

```html
<!doctype html>
<button onclick="askJoke()">Tell me a joke!</button>
<div id="answer"></div>
<script>
async function askJoke() {
  const r = await fetch("http://homehal.local:9999/api/ask?prompt=tell+me+a+joke");
  const j = await r.json();
  document.getElementById("answer").textContent = j.text;
}
</script>
```

That's it. That's the first AI app. Llama 3 8B is doing the work in the basement. Johnny's browser is showing the result. He doesn't need an OpenAI API key. He doesn't need to install anything. He needs `homehal.local:9999` and a script tag.

### What Johnny gets when he's ready for more

When Johnny is ten he learns about WebSockets and writes an app that streams the answer as it's generated:

```javascript
const ws = new WebSocket("ws://homehal.local:9999/ws");
ws.onmessage = (e) => {
  const msg = JSON.parse(e.data);
  if (msg.type === "bus_query_result") {
    document.getElementById("answer").textContent = msg.text;
  }
  if (msg.type === "bus_tts_chunk") {
    // Audio bytes are base64 in msg.audio_b64 — playable in any <audio>
  }
};
ws.send(JSON.stringify({type: "prompt", text: "tell me a joke"}));
```

That's the full protocol. Every bus event is a JSON object. Every JSON object has a `type`. Johnny knows JavaScript — he can read the events as they arrive and react however he wants. He's now writing event-driven distributed AI software at the age of ten.

### When Johnny is eleven and wants his own realm

He decides he wants RENT-A-HAL to know about his pet hamster. He opens `realm/intent.py` and adds:

```python
PHRASE_INTENTS["hamster"] = "hamster"
```

He adds a handler in `app.py`:

```python
async def hamster_handler(slots, guid, bus):
    return "Mr. Whiskers is sleeping. He always sleeps. He's a hamster."
```

He wires it into the orchestrator:

```python
orchestrator = Orchestrator(bus, llm, tts,
    hamster_handler=hamster_handler,
    ...)
```

He says **"computer hamster newline"** and the realm answers. He has just built a custom voice-controlled AI feature. He is eleven.

This is what API-first design means: the boundary between "using the system" and "extending the system" is thin enough for a curious kid to cross.

---

## Multi-User Design

RENT-A-HAL was built from day one to serve multiple users at once. The design choices that make this work are visible throughout the codebase:

### Per-user identity

Every browser session generates a UUID (`user_guid`) stored in `localStorage`. The realm uses this to:
- Route TTS audio to the right user (no cross-talk)
- Track which user submitted which query
- Cache the user's location so service finder works on the first try
- Honor "stop stop" — Alice's stop doesn't silence Bob's playback

### Per-user state, per-user queue

The orchestrator's queue is global but the in-flight tracker is per-user. Alice and Bob can both have queries running simultaneously. The metrics panel shows everyone the aggregate — *"AI queue: 2"* tells Bob that two people are using the system right now.

### Connection management

A `ConnectionManager` keeps track of every connected WebSocket, pings them every 20 seconds, and reaps stale ones after 75 seconds. Dead sockets can't hurt anyone else. Restarting the realm boots everyone cleanly; they reconnect automatically when the server is back.

### Honest multi-user transparency

When the AI queue is 0, the metric is green. When 1-2 queries are pending, it's amber. When 3+, it's red. Every user sees this in real time. **The system doesn't hide its busy state.** If grandma is asking about a recipe and grandpa wants to ask about Apollo 11, grandpa sees "AI queue: 1" before he even taps the wake button. He knows what to expect.

### Tested under real conditions

The chaos test suite simulates dozens of users sending queries simultaneously, with deliberate failures injected into the LLM and TTS chains, to verify the orchestrator doesn't lose state, doesn't leak memory, doesn't crash. Tested. Passed.

---

## The Hardware Story

**One Windows 11 box.** That's it.

- **GPU:** NVIDIA GeForce RTX 4060 (8 GB VRAM). Anything Pascal or newer with at least 6 GB VRAM works.
- **CPU:** Whatever you have. The realm itself is light Python.
- **RAM:** 16 GB recommended.
- **Disk:** 30 GB for GPT4All's Llama 3 8B model + Kokoro voice files + the rest of the stack.
- **Network:** Any LAN. Optional: Cloudflare Tunnel or ngrok to expose to the public internet (rentahal.com runs this way).

This serves **an entire household or a small office** without breaking a sweat. Multiple iPhones, laptops, desktops — all hitting the same backend, getting answers in seconds.

### The LLM: Meta's Llama 3 8B Instruct

The default model is **Llama 3 8B Instruct**, a state-of-the-art open-weights instruction-tuned model from Meta. It runs entirely on your GPU via GPT4All. Inference speeds of ~20 tokens/second on a 4060. Real conversational AI, in your own house, with no API costs and no data leaving your machine.

The realm doesn't care which LLM you use. Llama 3 is just the default because it's a fantastic balance of quality and footprint. Swap in Mistral, Phi-3, Qwen, or whatever else GPT4All supports — change one config line.

### The TTS: Kokoro Microserver (N2NHU Labs build)

Kokoro is an open-source neural TTS model. We package it as a **standalone microservice** that runs on a separate port (9998) with its own GPU pinning. The realm sends it text over localhost HTTP, gets back WAV audio bytes, ships them to the browser as base64 chunks over the WebSocket.

What's good about the Kokoro microserver setup:

- **GPU acceleration**: synthesis at roughly real-time speed or faster on a 4060
- **Voice quality**: natural, clear, no robotic artifacts
- **Queue serialization**: requests are handled one at a time so the GPU isn't thrashed
- **LRU audio cache**: repeated phrases return instantly from cache, no re-synth
- **News pre-encoding**: morning, noon, and evening headlines are synthesized in the background so when you say "computer news," playback starts immediately

The microserver has its own test suite (37 tests, independent of the realm). It can be replaced by any HTTP-speaking TTS service that takes text and returns audio.

### A real cost comparison

If you used a cloud LLM at $0.50 per million tokens and asked it 100 questions a day at 500 tokens per answer, you'd spend about $7/year on inference. Not much. But RENT-A-HAL serves a whole household of users at higher throughput and **never sends a single character of your data to anyone**. Your conversations stay in your house. That's the actual point.

---

## How the Browser Side Works

The UI is one HTML file — about 2,200 lines including all JavaScript and CSS. No framework. No build step. No npm. Open it in any editor. It runs.

### Wake-word state machine

```
idle  ── hears "computer" ─→  armed (accumulating text into buffer)
armed ── hears "newline" ──→  submit buffer to realm, back to idle
armed ── silence 8s ──────→   timeout, back to idle
any   ── "stop stop" ─────→   halt TTS + YouTube, back to idle
any   ── "help help" ─────→   open help panel
any   ── "wake word off" ─→   disable wake entirely
```

### Privacy controls

You can say:
- **"Wake word short"** — auto-disable wake in 15 seconds
- **"Wake word medium"** — 30 seconds
- **"Wake word long"** — 1 minute
- **"Wake word infinite"** — run until you say off
- **"Wake word off"** — disable immediately

When the timer expires, the wake word turns off automatically. RENT-A-HAL stops listening. Privacy by default for ambient computing in a household.

### The destroy-and-recreate pattern

When a new query produces card results (news / music / services), the relevant container is destroyed and recreated as a fresh DOM element. Not cleared — destroyed. This eliminates layout cache, lingering YouTube bindings, and any stale state. Every render is a clean slate.

### The 🔇 SILENCE button

A big red button always visible. One click and **everything stops**: audio, music video, thinking sound, and the realm gets told to halt any further TTS chunks. The safety valve for runaway audio.

### Compatibility tested in the field

- iPhone 8+ on Verizon LTE — full functionality
- Win11 Chrome — full functionality
- macOS Safari — full functionality
- Android Chrome — full functionality

The speech recognition uses the browser's native **Web Speech API**. On Chrome and Edge, that means Google's cloud STT. On Safari, that means Apple's STT. We don't ship audio bytes anywhere — only text. The realm never decodes a single byte of speech.

---

## What RENT-A-HAL Is NOT

In the spirit of honest engineering:

- **It's not a chatbot pretending to be a person.** It's a structured assistant. It speaks plainly about what it found.
- **It's not a cloud service.** Your data stays on your hardware. The trade-off is you have to keep that hardware running.
- **It's not a substitute for a search engine on every query.** Music and services use the open web; news uses RSS; weather uses OpenWeatherMap; "ask" uses the local LLM only.
- **It's not bulletproof.** It's a Personal Edition. It's tested heavily, but it's not a battle-tested enterprise SaaS. You're an operator. You get to fix things if they break.
- **It's not infinitely scalable on one box.** A 4060 happily serves a household. For an office of 20 simultaneous active users, you'd want a bigger GPU and probably a load-balanced setup.

---

## Setting It Up (Five Minutes)

1. Install **GPT4All** on your Windows 11 box. Pull the Llama 3 8B Instruct model. Enable the local API server (port 4891).
2. Unzip `RENTAHAL_FULL.zip` somewhere — for example `C:\rentahal\`.
3. Create a Python 3.12 virtualenv. Run `pip install -r requirements.txt`.
4. Start the Kokoro microserver: `python kokoro_service/service.py`
5. Start the realm: `python RENTAHAL_APP/app.py`
6. Open `http://localhost:9999` in any browser on your LAN.
7. Click **Enable wake word**. Grant microphone permission. Grant location (if you want service finder).
8. Say: *"Computer. Tell me about Apollo 11. Newline."*

That's it. Done.

To expose to the public internet, run an ngrok tunnel or Cloudflare Tunnel pointing at `localhost:9999`. That's how rentahal.com works.

---

## Quick Reference: Voice Commands

| Command | Effect |
|---|---|
| `computer <question> newline` | Ask the LLM |
| `computer weather newline` | Weather at your location |
| `computer weather in <city> newline` | Weather elsewhere |
| `computer news newline` | Today's headlines |
| `computer music <song> newline` | Play a song via YouTube |
| `computer service finder <category> newline` | Find local businesses |
| `stop stop` | Halt everything |
| `repeat repeat` | Replay the last answer |
| `help help` | Show all voice commands |
| `wake word short/medium/long/infinite/off` | Privacy timer for wake word |

Service Finder supports **75+ categories**: haircut, gas station, coffee, pharmacy, bank, ATM, restaurant, hotel, gym, dentist, doctor, lawyer, bakery, bar, mechanic, hospital, parking, bookstore, florist, pet shop, museum, cinema, and many more.

---

## Quick Reference: HTTP / API Endpoints

| Endpoint | Purpose |
|---|---|
| `GET /` | The main UI |
| `GET /api/config` | Returns the runtime configuration |
| `GET /api/ask?prompt=<text>` | One-shot LLM query (for simple integrations like Johnny's) |
| `GET /api/weather?city=<name>` | Weather for any city |
| `GET /api/news` | Current headlines as JSON |
| `WS /ws` | The WebSocket — everything happens here |

Every WebSocket event is a JSON object with `type` and a payload. The same events the realm publishes internally are the events the browser sees, prefixed with `bus_`. Read the protocol once, write any client you want.

---

## What Makes This Project Different

A few things that I'd want a skeptic to notice:

**One file for the entire frontend.** No build step, no bundler, no transpilation. Open it in Notepad. Edit it. Refresh the browser. Done.

**Honest metrics broadcast to every user.** When the system is busy, every connected browser sees the queue depth go from green to amber to red. Transparency is built in.

**No audio ever crosses the realm-to-browser boundary.** The realm receives text. The browser sends text. Audio only flows out (the TTS synthesis). This asymmetry makes the system simple and robust.

**Every config knob is declared.** `config.ini` has `@label`, `@type`, `@scope` tags on every value. A setup wizard can be generated from these tags.

**The test suite is the proof.** 700+ tests across 20 test layers, run three times in a row with zero flakes before any release. Each new feature ships with sabotage-verified regression tests so a future change that breaks the feature is caught immediately.

**Designed for a real household.** Multiple devices. Different browsers. Variable network. Real noise. Real distractions. Tested on an iPhone 8+ over LTE from a parked car, picking up a kid from grandma's house. It worked.

---

## Credits

- **Design:** Jim Ames, N2NHU Lab for Applied AI, Newburgh, NY 12550 USA
- **Implementation:** Claude (Anthropic), in collaboration with Jim
- **LLM:** Meta Llama 3 8B Instruct (via GPT4All)
- **TTS:** Kokoro ONNX (microservice by N2NHU Labs)
- **STT:** Web Speech API (browser-native)

RENT-A-HAL™ and MTOR™ are trademarks of Jim Ames and N2NHU Lab for Applied AI.
© Copyright 2026, Jim Ames. All rights reserved.

This build is based on the open-source RENT-A-HAL MTOR Reference Implementation.

**Designed and built in the United States of America.**
*— Always bet America for Win, Place, and Show —*

---

🖖 *Live long and prosper.*
