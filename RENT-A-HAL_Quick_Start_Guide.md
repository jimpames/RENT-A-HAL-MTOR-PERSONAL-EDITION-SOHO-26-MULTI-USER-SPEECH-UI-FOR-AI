# RENT-A-HAL SOHO Multi-User '26
## Quick Start Guide

**Version 1.0** | June 2026 | N2NHU Labs

---

## 1. About this guide

This guide walks a first-time operator from a clean Windows 11 system to a working multi-user voice AI realm in under thirty minutes. It assumes no prior familiarity with RENT-A-HAL, federation networking, or local large-language-model hosting.

You will install two components, run a one-screen configuration wizard, and have a working realm serving voice queries on your local network within the same session.

---

## 2. What you are installing

RENT-A-HAL Personal Edition consists of two independently installed Windows applications. Both must be present for full functionality.

| Installer | Purpose | Default port |
|---|---|---|
| **KOKORO RENT-A-HAL VOICE Microservice** | High-quality neural text-to-speech (TTS) backend. Runs as a persistent local service. | 9998 |
| **RENT-A-HAL SOHO Multi-User '26** | The realm itself: web cockpit, voice loop, LLM provider chain, federation client, boot wizard. | 9999 (realm) / 9100 (wizard) |

A third component is required but not bundled: a local large-language-model server (**GPT4All**, downloaded separately from gpt4all.io). GPT4All is the recommended local LLM engine; the realm's boot wizard verifies its presence before launch.

---

## 3. System requirements

| Component | Minimum | Recommended |
|---|---|---|
| Operating system | Windows 11 | Windows 11 (current build) |
| CPU | 4-core x64 | 6-core x64 or better |
| RAM | 16 GB | 32 GB |
| GPU | NVIDIA with CUDA support, 6 GB VRAM | NVIDIA RTX 4060 or better, 8 GB VRAM |
| Storage | 20 GB free | 40 GB free (allows multiple LLM models) |
| Network | Broadband residential connection | Symmetric fiber, optional |
| Browser (cockpit) | Chrome or Edge (current) | Chrome or Edge (current) |

A CUDA-capable NVIDIA GPU is required for usable local inference performance. Operators without a local GPU can run cloud-only with API keys for Claude or HuggingFace by setting `[Hardware] require_cuda = false` in `config.ini` after installation.

---

## 4. Pre-installation checklist

Before running either installer, complete the following:

1. **Install NVIDIA drivers.** Verify with `nvidia-smi` at a command prompt. The command must return a GPU listing.
2. **Install GPT4All.** Download from gpt4all.io. After installation, open GPT4All, download a model (Llama 3.2 3B Instruct is the recommended default), and enable the Local Server in **Settings → Application → Enable Local Server**.
3. **Verify GPT4All is reachable.** A browser visit to `http://localhost:4891/v1/models` should return a JSON listing of loaded models.
4. **(Optional) Install ngrok.** Download from ngrok.com. Required only if you intend to make your realm reachable from outside your local network or participate in the public federation. Free tier is sufficient for evaluation; a reserved domain (paid tier) is recommended for production.

---

## 5. Installation

### 5.1 Install the Kokoro voice microservice

1. Run **KOKORO RENT-A-HAL VOICE Microservice.exe**.
2. Accept the default installation path or choose your preferred location.
3. Allow the installer to register Kokoro as a Windows service. This ensures Kokoro starts automatically with the system.
4. On completion, verify the service is running: open Services (`services.msc`) and confirm **Kokoro RENT-A-HAL Voice** shows status **Running**.
5. Verify the API endpoint: a browser visit to `http://localhost:9998/health` should return a JSON status response.

The Kokoro microservice is now ready. It will be detected automatically by the realm.

### 5.2 Install the RENT-A-HAL realm

1. Run **RENT-A-HAL SOHO Multi-User '26.exe**.
2. Accept the default installation path or choose your preferred location.
3. The installer creates a Start Menu shortcut titled **RENT-A-HAL Wizard**.
4. On completion, the installer offers to launch the wizard immediately. Accept this option.

---

## 6. First boot: the wizard

The wizard is the recommended path for all first-time launches. It is also recommended for ongoing operation — it surfaces operational state, gates the realm launch behind a series of health checks, and provides single-button HALT for clean shutdown.

### 6.1 What the wizard does

The wizard runs as a small web application on port 9100. It opens automatically in your default browser when launched. The wizard performs the following functions:

- **Verifies the local environment** before allowing realm launch
- **Probes all required components** (CUDA GPU, GPT4All API, model availability, model functionality)
- **Configures the realm** through a single-screen form covering federation, branding, voice loop, and API keys
- **Launches the realm** as a managed child process
- **Manages the ngrok tunnel** as a child process (when configured)
- **Provides HALT control** for clean shutdown of both realm and tunnel
- **Surfaces operator-visible state** during operation

### 6.2 The five hard gates

The wizard's GO button is disabled until all of the following conditions are satisfied. Each failed gate displays an actionable error message indicating what to fix.

| Gate | Verifies | Common remediation |
|---|---|---|
| **1. CUDA detected** | `nvidia-smi -L` returns at least one GPU device | Install or update NVIDIA drivers |
| **2. GPT4All API reachable** | `GET http://localhost:4891/v1/models` returns 200 OK | Start GPT4All; enable Local Server in Settings |
| **3. Model loaded** | The API returns at least one model in its response | Download a model in GPT4All; recommended: Llama 3.2 3B Instruct |
| **4. Model functional** | A test prompt to the selected model returns non-empty text within 15 seconds | Select a different model; broken model files load but do not generate |
| **5. Federation URL configured** | If federation is enabled, the ngrok reserved URL is provided | Either set the URL or disable federation for standalone operation |

The fourth gate — **completion probe** — distinguishes RENT-A-HAL from typical installer-based AI stacks. Many model files load successfully but do not produce output. The wizard sends a deterministic test prompt and verifies a real response before permitting launch.

### 6.3 The wizard configuration form

A single screen surfaces all common configuration:

| Section | Fields | Purpose |
|---|---|---|
| **Hardware** | CUDA gate status | Live indicator of GPU detection |
| **Local AI Engine** | Endpoint, model selection, test prompt result | Select which model the realm will use |
| **Federation** | Participate (on/off), Federator URL, realm public URL, overflow thresholds, request timeout | Configure peer participation |
| **Voice Loop** | Wake timer default, privacy beacon | Set wake-word behavior and ambient signaling |
| **Identity** | Realm name, cockpit tagline | Customize the cockpit branding |
| **API Keys (Optional)** | OpenWeather, ngrok auth token, ngrok reserved URL | Enable optional integrations |

All values persist to `config.ini` and `federation.ini` immediately on save, using a comment-preserving writer. Schema annotations in the INI files document every field. Power operators may edit the INI files directly; the wizard reads and writes the same file consistently.

### 6.4 Launching

Once all five gates are green, the GO button activates. Clicking GO performs the following sequence:

1. Persists all wizard form values to `config.ini` and `federation.ini`
2. Launches the realm process as a child of the wizard
3. Launches the ngrok tunnel as a child of the wizard (if configured)
4. Re-renders the wizard page as a dashboard showing realm status, cockpit URL, and a HALT button

The cockpit is then accessible at `http://localhost:9999` (or your configured port). On the same network, other devices reach it at `http://<host-ip>:9999`. If ngrok is configured, your reserved public URL routes through to the same cockpit.

### 6.5 HALT

Clicking HALT in the wizard cleanly terminates both the realm subprocess and the ngrok subprocess. SIGTERM is sent first; SIGKILL is used as a fallback if processes do not exit within three seconds. This is the recommended shutdown procedure. Closing the wizard browser tab does **not** stop the realm; the realm continues running until HALT is invoked or the wizard process itself is terminated.

---

## 7. Federation from first bringup

The federation is the design feature that distinguishes RENT-A-HAL from single-instance local AI hosting. **Operators are encouraged to enable federation from first bringup** for the following reasons.

### 7.1 What federation provides

Federation allows independently-owned RENT-A-HAL realms to share LLM and TTS capacity transparently. Each realm runs its own local engine on its own hardware; federation activates only when a query exceeds local capacity or when local engines have failed.

| Condition on your realm | Without federation | With federation |
|---|---|---|
| Local engine is fast | Local serves the query | Local serves the query (identical behavior) |
| Local engine is busy | Query queues; user waits | Excess routed to a peer; user sees no delay |
| Local engine has crashed | "No LLM online" message | A peer serves the query; user sees no interruption |
| Local engine has been dead for >5 minutes | Indefinite error state | Watchdog signals operator; realm falls to Echo floor |
| Local engine recovers | Restart required to clear error state | Automatic on next query; routing returns to local |

The federation is a **pure improvement** over single-instance operation. No query is sent to a peer that local can serve well. No identifying information is transmitted beyond the query text itself.

### 7.2 Recommended federation configuration

For first-time operators:

| Field | Recommended value | Rationale |
|---|---|---|
| **Participate in the federation** | On | All benefits above |
| **Federator URL** | `https://rentahal.com/api/federate` | Public Federator maintained by N2NHU Labs |
| **Your public realm URL** | Your ngrok reserved domain | Required if you want to contribute capacity |
| **LLM overflow threshold** | 31.0 seconds | Standard for the public mesh |
| **TTS overflow threshold** | 31.0 seconds | Standard for the public mesh |
| **Federated call timeout** | 59.0 seconds | Generous timeout, prevents premature fallback |

Operators may participate as **consumers only** (receive rescues, do not serve peers) by leaving the public realm URL blank. Federator advice will route to other peers but no peer will send queries to your realm. This is appropriate for laptops, intermittent connections, or evaluation environments.

### 7.3 Cooperative behavior is enforced, not assumed

The federation is built on three protocol-level guarantees that protect all participants:

- **One-hop limit.** A federated call cannot itself trigger further federation. Cascades are impossible by construction.
- **Honest self-reporting.** A realm with a crashed engine announces its own degradation, so peers do not route to it.
- **Bounded silent dependency.** A realm whose local engine is dead cannot federate forever — the watchdog enforces a maximum continuous federation period (default 5 minutes) before forcing fallback to a visibly degraded local floor. This protects peer capacity and ensures operator awareness.

These protections operate automatically. No operator action is required to benefit from them or to comply with them.

### 7.4 Privacy considerations

When federation is enabled and your realm receives a federated call from a peer, **your local LLM or TTS will generate the response**. The text of that query crosses the federation. No user identity, no session state, no browser context, and no audio is transmitted. Operators with privacy-sensitive workloads who do not want their realm's hardware to serve other operators' queries should disable federation in the wizard.

---

## 8. Operating the realm

### 8.1 The cockpit

Open `http://localhost:9999` in Chrome or Edge. The cockpit presents:

| Element | Function |
|---|---|
| **Status strip** | Live indicators for WebSocket, LLM provider, TTS provider, wake state, query queue depth, average response times, token throughput |
| **Federation strip** | Federation state (HEALTHY / DEGRADED / OFF), Federator URL, current peer recommendations |
| **Microphone visualization** | Audio waveform and recognition state |
| **Conversation area** | User queries and realm responses, with per-query metadata (tokens, throughput, provider) |
| **Action buttons** | Enable wake word, type a question, stop, silence, repeat, news, roundup, weather, music, services, help |

The cockpit is multi-user. Multiple browser tabs or devices may connect simultaneously; each has its own session state and outbound queue.

### 8.2 The voice loop

Click **Enable wake word**. The browser requests microphone permission. Once granted, the wake-word recognizer listens locally (browser-side speech recognition; no audio is sent to the realm until the wake word is detected).

Say **"computer"**, then your query. The realm transcribes, classifies the intent, dispatches to the appropriate handler (weather, news, music, service finder, or general LLM query), generates a response, and speaks the response through your selected TTS provider.

Doubled action words — **"stop stop"**, **"repeat repeat"**, **"cancel cancel"** — provide interruption control without false-positive triggers from incidental speech.

### 8.3 Intent realms

The realm classifies each query into an intent and dispatches accordingly:

| Intent trigger | Behavior |
|---|---|
| **Weather** | OpenWeatherMap one-call lookup at the browser's geolocation |
| **News** | Multi-source news aggregation with ROUNDUP playlist option |
| **Music** | DuckDuckGo search for matching YouTube video, embedded in cockpit |
| **Service finder** | OpenStreetMap-based local business lookup at browser geolocation |
| **General query** | Routed to the LLM provider chain |

Each intent has its own configuration section in `config.ini` and can be disabled independently.

### 8.4 The federation badge

Below the LLM and TTS indicators, the cockpit shows the federation state. This includes the current Federator URL, your realm's health state, and the most recent peer recommendations. The per-query badge updates with the actual provider that served each query — operators can immediately distinguish queries served by local engines, by overflow federation, by rescue federation, or by the degraded floor.

---

## 9. Operational tasks

### 9.1 Stopping the realm

Open the wizard (Start Menu → RENT-A-HAL Wizard). Click HALT. Both the realm and the ngrok tunnel terminate cleanly.

### 9.2 Restarting the realm

Open the wizard. Click GO. The wizard re-runs all five health gates and launches the realm.

### 9.3 Changing the model

Stop the realm. In the wizard, select a new model from the dropdown (populated from GPT4All's loaded models). Click GO. The new model is verified by the completion probe before launch.

### 9.4 Updating configuration

Configuration changes via the wizard form take effect on the next launch. For configuration changes not exposed in the wizard, edit `config.ini` or `federation.ini` directly (they are well-commented and schema-annotated) and restart the realm.

### 9.5 Monitoring federation health

The cockpit's federation strip is the primary indicator. The realm's log file (`webgui_detailed.log`) records every check-in, every federation event, every degraded transition, and every recovery. ERROR-level lines indicate operator-actionable issues.

### 9.6 Diagnosing a degraded state

If the cockpit shows `LocalSystemLLMDegraded.xpy` or `LocalSystemTTSDegraded.xpy`, the watchdog has detected that your local engine has been continuously federated to peers for longer than the configured threshold. Check that GPT4All (for LLM degradation) or the Kokoro service (for TTS degradation) is running and responsive. The watchdog will clear automatically on the first successful local query.

---

## 10. Where to get help

| Resource | Location |
|---|---|
| Configuration schema | Comments in `config.ini` and `federation.ini` |
| Wizard error messages | Each failed gate provides specific remediation guidance |
| Detailed log | `webgui_detailed.log` in the installation directory |
| Federation architecture | MTOR Federation White Paper (separate document) |
| Project page | The realm's `/supporters` page, when operator-enabled |

---

## 11. Quick reference

### 11.1 Default ports

| Component | Port |
|---|---|
| Realm cockpit | 9999 |
| Boot wizard | 9100 |
| Kokoro voice microservice | 9998 |
| GPT4All API (external) | 4891 |

### 11.2 Default configuration files

| File | Purpose |
|---|---|
| `config.ini` | Master realm configuration |
| `federation.ini` | Federation client and Federator configuration |

### 11.3 Recommended first-bringup sequence

1. Install NVIDIA drivers; verify with `nvidia-smi`
2. Install GPT4All; download a model; enable Local Server
3. Install KOKORO RENT-A-HAL VOICE Microservice
4. Install RENT-A-HAL SOHO Multi-User '26
5. Launch the wizard from the Start Menu
6. Confirm all five hard gates show green
7. Enable federation; set the public Federator URL
8. Click GO
9. Open the cockpit at `http://localhost:9999`
10. Click **Enable wake word**; say "computer, what's the weather"

If step 10 produces a spoken answer, the realm is operational.

---

## 12. Acknowledgments

RENT-A-HAL Personal Edition is developed at N2NHU Labs (Newburgh NY).

The MTOR designation references Dr. Daystrom's M-5 Multitronic Unit from *Star Trek: The Original Series*, "The Ultimate Computer" (1968). The system aims to fulfill the M-5 design vision — a self-contained intelligent realm capable of autonomous operation — while preserving operator oversight.

---

*This document is the v1.0 quick start guide. Subsequent revisions will be available with each release.*

🖖 Live long and prosper.
