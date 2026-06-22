# MTOR Federation: A Push-Driven, Self-Healing Mesh for Voice-First Local AI

**A technical white paper**
**Version 1.0 — June 2026**

Jim Ames (N2NHU Labs, Newburgh NY)
Engineering collaboration with Anthropic's Claude

---

## Abstract

MTOR Federation is the inter-realm mesh layer at the heart of **RENT-A-HAL Personal Edition** (MTOR — Multi Tronic Operating Realm). It enables independently-owned, self-hosted AI realms — each running on consumer-grade hardware — to share LLM and TTS capacity transparently with peer realms, with no central control plane and no dependence on cloud APIs.

The federation is built around four design commitments that distinguish it from prior local-LLM clustering work: **push-driven coordination** (no polling, peers self-report state), **strict cooperation** (a one-hop limit prevents cascades), **honest self-reporting** (a degraded realm announces its own degradation rather than passing the buck), and **bounded silent dependency** (a wall-clock watchdog prevents a dead-local realm from federating forever without operator awareness). All four are enforced in the wire protocol, the matrix logic, and the provider chain — they are not optional behaviors operators can disable to game the network.

This paper describes the architecture, wire format, failure modes, self-healing mechanisms, operator model, and known limitations. It is intended for engineers deploying or extending RENT-A-HAL Personal Edition, and as a reference document for future federation implementations in this design lineage.

---

## 1. Introduction

### 1.1 The problem

A single self-hosted AI realm — voice in, voice out, running locally on a consumer GPU — works well for a single user with a single task. It does not work well in two common cases:

1. **Burst capacity.** When the same operator's realm is asked to serve concurrent users (a household, a small business, a classroom), local model inference becomes the bottleneck. Query latencies climb. Token generation queues. The UX degrades.

2. **Engine failures.** When the local LLM (e.g., GPT4All) or local TTS (e.g., Kokoro) crashes, hangs, or is killed for maintenance, the realm has no graceful fallback short of "the system is currently unavailable."

Cloud APIs solve both problems by routing every query to a datacenter. **MTOR Federation solves both problems by letting a small number of independently-owned, self-hosted realms cooperate.** A realm experiencing burst load can transparently route excess queries to a less-loaded peer. A realm with a crashed engine can rescue queries from a healthy peer. When the local engine recovers, routing returns to local automatically — no operator intervention required.

The result is a **distributed substrate for local AI** that preserves the privacy, cost, and ownership characteristics of self-hosting while providing the elastic capacity and graceful degradation typically associated with cloud services.

### 1.2 What this is not

MTOR Federation is not a distributed inference system. Individual queries are not split across realms. Tokens are not streamed in parallel from multiple GPUs. There is no model sharding, no tensor parallelism, no shared parameter cache. **Each query runs on exactly one realm's local engine** — federation simply routes the query to a healthy realm when the originating realm cannot serve it well.

It is also not a marketplace. There are no payments, no quotas, no metering, no reciprocity tracking. The federation operates on a **cooperative, voluntary basis** — operators opt their realms in by setting `desire = on` in `federation.ini`. The watchdog described in Section 5 prevents one-sided dependency by capping how long a degraded realm can mooch off peers before being forced into honest fallback.

### 1.3 Design philosophy

Three principles guide every design decision:

**Operator control over defaults.** Anything potentially intrusive ships disabled. Operators consciously opt in. Federation participation, supporters page, ngrok auto-tunnel, custom branding — all default-off or default-empty. The shipping product is infrastructure, not promotion.

**Honest signal over silent rescue.** When something is broken, the operator must be able to tell. A federation that rescues queries forever from a dead-local realm is hiding the truth from its owner. The watchdog ensures that after a bounded period of continuous federation, the realm falls back to a visibly-degraded floor (Echo for LLM, pyttsx3 for TTS) that the operator cannot miss.

**Self-healing as the primary recovery mode.** Operators should not need to restart their realm, clear caches, or run recovery commands when a transient failure passes. The federation provider's pre-flight probe, the recovery dance, and the watchdog clear-on-recovery all combine so that **the first successful local query after a failure transparently restores normal operation** — no manual intervention, no downtime, no operator-visible state machine to manage.

---

## 2. Architecture overview

### 2.1 Component model

A federated MTOR deployment has three roles. A single realm can play multiple roles simultaneously.

**Member realm.** The default role. A member realm runs the standard RENT-A-HAL stack (FastAPI server, WebSocket cockpit, local LLM/TTS chains) plus federation client code. It periodically reports its state to a Federator and accepts inbound federation calls on `/api/ask` and `/api/speak`. Every realm with `[Federation] desire = on` is a member.

**Federator.** A coordinator realm that maintains the matrix of known members, receives push-driven check-ins, and on each check-in returns peer recommendations to the calling realm. A Federator is itself a member — the Federator role is purely additive (configured via `[Federator] enabled = true`). The reference deployment runs `rentahal.com` as the Federator for the public mesh, but anyone can spin up a private Federator for an internal mesh.

**Peer.** Any member realm whose state is reachable through the Federator's recommendations. From a given calling realm's perspective, every other member is a potential peer; the Federator advises which specific peer to use for the next overflow or rescue call.

### 2.2 Reference deployment topology

The production reference deployment runs two realms:

- **rentahal.com** — Gen 12 + RTX 4060, master Federator, primary public-facing realm
- **realnewslistener.com** — Gen 8 + RTX 2070 Super, second member, news-focused workload

Both realms federate to each other through `rentahal.com`'s Federator role. Either realm can rescue the other. Both have proven sub-second peer recommendations and proven sub-10-second rescue end-to-end (federated answer + return + render).

The same pattern scales to N realms. There are no architectural assumptions baked in about a two-realm topology specifically.

### 2.3 Source code module layout

| Module | Purpose |
|---|---|
| `realm/federation.py` | FederationConfig, FederationState, FederationMatrix, FederationClient, FederatorServer |
| `realm/federation_provider.py` | FederationLLMProvider (HEAD — overflow) and FederationLLMFallbackProvider (TAIL — rescue) |
| `realm/federation_tts_provider.py` | FederationTTSProvider + FederationTTSFallbackProvider — symmetric architecture for TTS |
| `realm/degraded_tracker.py` | Wall-clock watchdog preventing indefinite federation |
| `app.py` | Wiring — constructs trackers, attaches providers to chains, federation client lifecycle |

The federation layer is approximately 1,400 lines of Python (excluding tests). Test coverage is approximately 130 federation-specific test cases plus integration coverage through the orchestrator and chain modules.

---

## 3. The matrix: peer discovery and ranking

The Federator maintains a `FederationMatrix` — a phonebook of known members with their last-reported performance metrics. Every member check-in produces an upsert; the matrix is the authoritative source for peer recommendations.

### 3.1 Member record shape

Each entry contains:

- `self_url` — the canonical URL the member identifies itself by (used for self-exclusion when computing peer advice)
- `llm_avg_s` — the member's recent rolling-window LLM average service time, in seconds
- `tts_avg_s` — the member's recent rolling-window TTS average service time, in seconds
- `tokens_out` — cumulative tokens generated since member start (diagnostic, not used for ranking)
- `last_seen` — monotonic timestamp of most recent check-in

### 3.2 The DEGRADED_AVG_S sentinel

A central design decision: when a member's local engine is dead but the member is still running (e.g., GPT4All crashed but the realm process is healthy), the member **self-reports** a sentinel value for the relevant chain's average service time:

```python
DEGRADED_AVG_S = 1000.0          # realm/federation.py:68
```

This sentinel propagates through the matrix and through peer recommendations. A member with `llm_avg_s = 1000.0` will not be recommended as an LLM peer by the Federator, because the matrix ranks peers by `effective_avg` (lowest wins) and the sentinel sits at the top of any reasonable distribution.

Critically, **the sentinel is also applied retroactively to stale members** — any member whose `last_seen` is older than `missed_after_s` (default 60 seconds) is treated as having degraded averages, regardless of what value they last reported. A member that crashes mid-check-in is correctly excluded from peer recommendations within one minute, without requiring the matrix to model "alive" as a separate state.

### 3.3 Peer recommendation algorithm

On each member check-in, the Federator computes peer advice for that member:

```
best_llm_peer = argmin {
    m.effective_avg_for_llm(now, missed_after_s)
    for m in matrix.members
    if m.self_url != caller.self_url
       and m.effective_avg_for_llm(...) < DEGRADED_AVG_S
}
```

The result is one URL (or `None` if no live peer exists). The caller uses this URL as the destination for the next federated call, if it makes one. Repeating calls to a single best peer create natural concentration; the matrix's `peer_advice_bump` rotates equally-good peers to distribute load.

### 3.4 Persistence and recovery

The matrix persists to `federation_state.json` on each upsert. On Federator restart, the file is loaded. Members whose `last_seen` is older than `missed_after_s` are correctly excluded from peer advice through the sentinel mechanism — there is no separate "stale removal" sweep needed. The matrix is eventually consistent under restart.

---

## 4. The wire protocol

### 4.1 Push-driven check-in

The fundamental coordination primitive is the member-to-Federator check-in. Every `checkin_interval_s` (default 15 seconds), each member POSTs to the Federator:

**Request: `POST /api/federate/checkin`**
```json
{
  "self_url": "https://rentahal.com",
  "llm_avg_s": 5.96,
  "tts_avg_s": 7.97,
  "tokens_out": 12450
}
```

**Response (200 OK):**
```json
{
  "best_llm_peer": "https://realnewslistener.com",
  "best_tts_peer": "https://realnewslistener.com",
  "your_state": "HEALTHY"
}
```

There is no separate "register" or "discover" call. The first check-in from a new member implicitly registers it. The Federator returns the same payload regardless of registration history — the member doesn't need to track its own onboarding state.

**Why push-driven, not poll.** A polling Federator would need a member list, retry logic, timeout handling, and per-member state tracking. A push-driven Federator only needs to receive packets, update the matrix, and return advice. **Members are the source of truth about their own state.** The Federator is a coordinator, not a probe.

### 4.2 Federated query: LLM

When a member's LLM federation provider decides to route a query to a peer, it makes a standard HTTP call to the peer's public API:

**Request: `POST /api/ask`**
```
Content-Type: application/json
X-Federation-Hops: 1
X-Federation-Token: <optional shared secret>

{"text": "what's the weather like on mars", "max_tokens": 1500}
```

**Response (200 OK):**
```json
{
  "answer": "Mars has a thin CO2 atmosphere with surface...",
  "provider": "GPT4All (Llama 3.2 3B Instruct)"
}
```

The peer answers from its own LLM chain (whichever provider its own chain selects). Critically, the `X-Federation-Hops: 1` header tells the peer **not to re-federate**. If the peer's own LLM is unavailable, it returns Echo's "no LLM online" message rather than calling out to a third realm.

### 4.3 Federated query: TTS

Symmetric architecture:

**Request: `POST /api/speak`**
```
Content-Type: application/json
X-Federation-Hops: 1

{"text": "Mars has a thin CO2 atmosphere"}
```

**Response (200 OK):**
```json
{
  "audio_b64": "<base64-encoded WAV data>",
  "provider": "Kokoro Service"
}
```

The peer synthesizes locally and returns base64-encoded audio. Same hop-limit semantics: if the peer's own TTS chain is in trouble, it returns its pyttsx3 robot-voice floor rather than re-federating.

### 4.4 Cascade prevention

The single most important property of the wire protocol is **cascades are impossible by construction**. A federated call carries `X-Federation-Hops: 1`. The receiver reads it. If `hops >= max_federation_hops` (default 1), the receiver runs `allow_federation=False` through its provider chain. The federation providers on the receiver check `allow_federation` first in their `should_federate()` gates and return False.

This means:
- A federated call from A→B is served by B's local chain or falls to Echo/pyttsx3
- A→B→C is impossible — B will not call C
- A→B→A is impossible for the same reason
- A→B→A→B... loops are impossible
- A query can survive the death of at most one realm in the path

The cooperation is **opt-in but mandatory**. A misbehaving peer could in principle ignore the hop header and re-federate anyway, but doing so would be visible in logs and would damage the misbehaving peer's reputation in the federation. The protocol assumes good-faith participation; the matrix mechanics provide soft enforcement via peer ranking.

---

## 5. Failure modes and self-healing

Federation v1 handles three distinct failure modes, each with its own self-healing mechanism. Understanding the interaction between these mechanisms is the key to understanding the federation's reliability properties.

### 5.1 Failure mode 1: Local engine slow (overflow)

**Symptom:** Local LLM (or TTS) is responding, but rolling-window average service time has climbed above the configured threshold (`prefer_federation_for_llm_avg_s`, default 31 seconds).

**Mechanism:** The HEAD federation provider sits at position zero of the LLM chain. Its `is_available()` method reads the current local average from `FederationState.get_stats()`. When the average exceeds the threshold AND a healthy peer is available, `is_available` returns True, and the chain calls `generate()` on this provider before reaching local providers.

**Self-healing:** Before committing to the federated call, the HEAD provider runs a **pre-flight local probe** — it asks the local LLM chain's `probe_local()` method whether any local provider is currently responding. If the local LLM is actually fast right now (and the elevated rolling average was a stale signal from recent federated calls), the probe returns the local provider; the HEAD provider returns None; the chain falls through to local; **no federation call happens**.

On probe success, the HEAD provider also fires the **recovery dance**:
- `metrics.reset_ai_window_to_local_recovery()` — clears the stale rolling average
- `bus.publish("status_update", channel="llm", state="recovered")` — flashes the cockpit badge back to the local provider name
- `federation_client.immediate_checkin()` — pushes the recovered state to the Federator out-of-band so peer advice updates within seconds instead of waiting for the next 15s interval

The combined effect: a transient slowdown can fire a single federated call, immediately self-correct, and never fire another. The rolling average resets; the operator sees the badge flash; the federation matrix updates. Total operator intervention: zero.

### 5.2 Failure mode 2: Local engine dead (rescue)

**Symptom:** Local LLM is not responding at all. `is_available()` on every local provider returns False. The chain walks past local providers entirely.

**Mechanism:** The TAIL federation provider (`FederationLLMFallbackProvider`) sits between the local providers and the Echo floor. It has no threshold check — being reached is itself the signal. When `is_available()` returns True (peer exists, federation healthy), the chain calls `generate()` and the query is rescued from a peer.

This is **distinct from overflow** in two ways: there is no avg-vs-threshold check, and the dead-local realm self-reports `DEGRADED_AVG_S` for its own LLM channel in the next check-in, so the Federator will not recommend this realm as a peer for OTHER realms during the outage.

**Self-healing:** Same pre-flight probe pattern. The TAIL provider also calls `chain.probe_local()` before federating. On success, it fires the recovery dance — and crucially, because the chain has already walked past local providers, the chain re-walk doesn't happen automatically; **this specific query** still falls to Echo. But the recovery side effects (cleared rolling avg, Federator check-in, badge flash) ensure that the **next** query routes correctly to local.

### 5.3 Failure mode 3: Bounded silent dependency (the watchdog)

**Symptom:** Local engine has been dead for an extended period. Federation has been rescuing every query. From the user's perspective, the realm is "working" — they get answers. From the operator's perspective, the realm is silently mooching off peers, and no signal has been raised that local needs attention.

**Mechanism:** The `DegradedTracker` (`realm/degraded_tracker.py`) is a wall-clock watchdog with three states: Initial, Federating, Degraded. The first `mark_federated()` call after boot or after a recovery starts a monotonic timer. After `local_degraded_after_s` (default 300 seconds = 5 minutes) of continuous federation, the tracker's `is_degraded()` flips to True. Both HEAD and FALLBACK federation providers consult `is_degraded()` in their `should_federate()` gates. When True, they refuse to federate.

The chain then falls through to **Echo** (LLM) or **pyttsx3** (TTS) — the operator-visible degraded floor.

On transition into degraded:
- An ERROR-level log line fires once: `LOCAL LLM DEGRADED — federated continuously for 300s. Falling through to Echo. Operator: check local engine.`
- A `bus_status_update` flashes the cockpit badge to `LocalSystemLLMDegraded.xpy` (and `LocalSystemTTSDegraded.xpy` for TTS)
- Subsequent queries surface the floor provider's output until local recovers

**Self-healing:** The pre-flight probe in both federation providers still runs on every query (it executes inside the `generate()` body before the federated call would happen, and the watchdog gate is checked separately in `should_federate()`). On any successful local probe — i.e., the first query after the local engine returns — the watchdog's `mark_local_recovered()` clears the degraded flag, fires the recovery dance, and the next query routes to local at full performance.

**Production validation:** This mechanism was smoke-tested in production by deliberately killing both GPT4All and Kokoro on rentahal.com, observing 5 minutes of successful federation to realnewslistener.com, observing the transition to degraded floor at exactly the 5-minute mark, restarting the local engines, and observing single-query recovery to full local performance on the very next query. All transitions logged correctly. No operator intervention beyond restarting the local engines.

### 5.4 Design rationale: wall-clock, not call-count

An early design proposal used a call-count cap ("after N federated calls, declare degraded"). This was rejected for two reasons:

1. **Traffic-dependent false positives.** A busy realm doing 60 queries/minute hits a 15-call cap in 15 seconds — far below any reasonable cooldown window. The realm would oscillate between rescue and degraded on transient load spikes.

2. **Traffic-dependent missed signals.** A quiet realm doing 1 query / 10 minutes takes 2.5 hours to hit the same 15-call cap. The operator would not know local was broken for an entire afternoon.

Wall-clock time is the correct unit because **the question being asked is "how long has local been unhealthy?", not "how many queries have we forwarded."** A 5-minute wall-clock cap is the same 5 minutes regardless of the calling pattern. The cap correctly fires when local genuinely needs operator attention and correctly does not fire when local is recovering through transient slowdowns.

### 5.5 Independence of LLM and TTS chains

LLM and TTS chains fail independently. GPT4All can crash while Kokoro is healthy; Kokoro can crash while GPT4All is fine. Two separate `DegradedTracker` instances are constructed at startup, one per chain, with independent thresholds (`[LLMChain] local_degraded_after_s` and `[TTSChain] local_degraded_after_s`). They are wired to the four federation providers via the `attach()` method's `degraded_tracker` parameter. The cockpit badge reflects each chain's state separately. The dead-local sentinel reports each chain separately.

---

## 6. Operator model

The federation is **transparent by design**. Every state the realm is in is visible to the operator without requiring a log dive, a separate dashboard, or an external monitoring tool.

### 6.1 Cockpit badge as the source of truth

The cockpit displays the current effective LLM and TTS providers in real time. Per-query, the badge updates from the `bus_query_result` event with the actual provider that served the query:

```
LLM: GPT4All (Llama 3.2 3B Instruct)         ← normal local operation
LLM: Federation (peer realms)                  ← overflow active
LLM: Federation Fallback (peer realms)         ← rescue active
LLM: Echo                                      ← degraded floor
LLM: LocalSystemLLMDegraded.xpy                ← watchdog tripped
```

The TTS badge updates symmetrically. No status is hidden; no state is implicit; no operator interpretation is required. **The badge says what the chain just did.**

### 6.2 Federation strip

A persistent strip below the badges shows current federation state:

```
Fed: ON · Master: rentahal.com · State: HEALTHY · (LLM→realnewslistener.com, TTS→realnewslistener.com)
```

The strip reflects the most recent check-in response. The hints `(LLM→..., TTS→...)` are advisory — they show what the Federator currently recommends, not what the realm is actually doing right now. The badge above is the per-query truth; the strip is the federation context.

### 6.3 Configuration

All federation knobs live in two INI files with self-documenting schema:

**`config.ini`:**
- `[LLMChain] local_degraded_after_s` — watchdog threshold for LLM chain
- `[TTSChain] local_degraded_after_s` — watchdog threshold for TTS chain

**`federation.ini`:**
- `[Federation] desire` — opt in or out of the federation (on/off)
- `[Federation] master_url` — Federator endpoint URL
- `[Federation] self_url` — this realm's canonical public URL
- `[Federation] prefer_federation_for_llm_avg_s` — overflow threshold for LLM
- `[Federation] prefer_federation_for_tts_avg_s` — overflow threshold for TTS
- `[Federation] request_timeout_s` — timeout per federated call
- `[Federation] checkin_interval_s` — push-driven check-in period
- `[Federation] missed_after_s` — staleness threshold for matrix entries
- `[Federation] max_federation_hops` — cascade limit (default 1)
- `[Federator] enabled` — promote this realm to Federator role

Every knob has a sensible default. A first-time operator opting into the federation needs to set only `master_url` and `self_url`. Everything else can be tuned later, in production, without code changes.

### 6.4 Privacy properties

The federation transmits **query text and response text** between participating realms. It does not transmit:

- User account information (realms have no concept of user identity beyond per-WebSocket session)
- Conversation history (federated calls are stateless — each query is independent)
- Cookies, headers from the original browser request, or any browser-side context
- Recordings of the original audio (STT happens browser-side; only text crosses the wire)

Operators participating in the federation should understand that **queries asked of their realm may be answered by a peer realm's local LLM**, and **queries asked of their peers may be answered by their own realm's local LLM**. This is the entire point of the federation. Operators with privacy-sensitive workloads who do not want their realm's hardware to serve other operators' queries should set `[Federation] desire = off` and run standalone.

There is no encryption layer at the federation level beyond HTTPS termination at each realm's edge (typically ngrok). An optional shared secret (`[Federation] token`) provides modest authentication of inbound federated calls but is not a substitute for transport-level confidentiality.

---

## 7. Comparison to existing approaches

### 7.1 Versus cloud LLM APIs

Cloud APIs (OpenAI, Anthropic, Google) solve the burst-capacity and graceful-degradation problems by running every query on rented datacenter GPUs. They impose per-token billing, conversation logging by default, rate limits, and a hard dependency on the provider's uptime.

MTOR Federation solves the same problems differently. There is no billing, no logging at the federation level, no rate limits beyond what the peer realms can serve, and no single point of failure. The trade is: cloud APIs have higher peak throughput; MTOR Federation has zero marginal cost and stronger privacy properties.

### 7.2 Versus local-LLM clustering frameworks

Distributed inference systems (vLLM tensor-parallel, Petals, distributed-llama) split the work of a single query across multiple machines. This is a fundamentally different design point. They optimize for serving a larger model than any single machine can hold; they require tight coupling, low-latency interconnects, and careful synchronization.

MTOR Federation does not split queries. Each query runs on exactly one realm's local engine. The cooperation is at the **query** level, not the **token** level. The trade: distributed inference can run bigger models; MTOR Federation can run on consumer hardware over residential internet with no coordination overhead per query.

### 7.3 Versus other federated-LLM proposals

Several proposals for federated LLM hosting exist in the open-source ecosystem (LocalAI clusters, Ollama hosts behind load balancers, Horde-style distributed pools). MTOR Federation's distinguishing properties are:

- **Push-driven coordination.** Members report state; the Federator does not poll. This makes the Federator stateless about member health beyond what members tell it.
- **Strict hop limit.** Cascades are impossible by construction, not by convention.
- **Self-reporting of degradation.** A dead-local realm announces its own degradation rather than relying on the coordinator to infer it.
- **Bounded silent dependency.** The watchdog prevents a realm from being silently dependent on peers indefinitely.
- **Operator-first transparency.** Every state is visible in the cockpit without external tooling.

None of these properties is individually novel. The combination is, to our knowledge, novel in the local-LLM space.

---

## 8. Known limitations

Honest limitations of the current design:

**No partial-answer streaming across federation.** A federated query is a single round-trip: peer generates the full answer, returns it, requester returns to user. This adds latency to long answers. Streaming federation is a feasible extension; it was deprioritized for v1 because the latency cost is small (a few hundred milliseconds of perceived "first-token" delay) and the protocol simplicity is worth the trade.

**No model-aware routing.** The Federator does not know which models each member realm has loaded. A realm with Llama 3 8B and a realm with Llama 3.2 3B are treated as equivalent peers. In practice this is fine because the federation is overflow rescue, not model selection — but operators who care about which model answers a federated query currently have no way to express that preference.

**No quotas or rate limiting.** Operators implicitly trust each other not to flood the federation. A misbehaving member realm could in principle issue thousands of federated calls per second to a single peer. The watchdog protects the misbehaving realm from itself but does not protect the peer from being flooded. Per-peer rate limits at the receiver are an obvious extension.

**Single Federator topology.** The reference deployment runs one Federator (rentahal.com). A Federator outage stops new member onboarding and stops peer-advice updates. Member-to-peer federation calls continue working with stale advice. A multi-Federator topology (consensus across multiple coordinators) is a straightforward extension; it was deprioritized for v1 because the operational complexity outweighs the benefit at the current federation size.

**No model warm-up coordination.** When a member restarts its local LLM (model loads cold from disk), the first few queries are slow. The federation provider currently has no signal to distinguish "model loading" from "model crashed" — both look like dead-local. The watchdog correctly forgives this on recovery, but during the warm-up the peer's LLM unnecessarily serves queries that local could serve once warmed.

**No transport-level encryption requirement.** The protocol assumes HTTPS at each edge but does not enforce it. A misconfigured realm could expose `/api/ask` and `/api/speak` over plain HTTP. The reference deployment uses ngrok reserved domains with TLS termination; operators running on raw IPs should configure HTTPS themselves.

---

## 9. Future work

The federation is feature-complete for v1.0. Plausible v1.x extensions:

- **Token streaming across federation** for sub-second perceived latency on long answers
- **Per-peer rate limits** at the receiver to protect against misbehaving members
- **Federation-level shared secrets enforcement** by default (currently optional)
- **Multi-Federator consensus** for high-availability coordinator topologies
- **Model-aware routing hints** so operators can express preferences
- **Warm-up detection** so the watchdog and overflow gates distinguish cold-start from crash
- **Per-realm capability advertisement** (image generation, web search, etc.) for non-LLM/TTS workloads

None of these are blockers for current operators. All would extend the architecture additively without changing the core invariants (push-driven, strict hop limit, honest self-reporting, bounded silent dependency).

---

## 10. Conclusion

MTOR Federation provides a working substrate for cooperative, self-hosted AI realms. It has been validated in production across two independently-owned realms (`rentahal.com` and `realnewslistener.com`) running on consumer-grade hardware with residential symmetric fiber. End-to-end query latency for federated rescue calls has been measured at approximately 3.5 seconds for a 555-token Apollo program summary, including peer model inference and return.

The design commitments — push-driven, strict hop limit, honest self-reporting, bounded silent dependency — produce a federation that is **operator-friendly by default**. Federations of one realm work. Federations of two realms work. Federations of N realms should work for any N within the bandwidth and matrix scaling characteristics of the chosen Federator hardware.

This document is the architectural reference for the v1.0 federation. Future revisions will extend it as the protocol evolves.

---

## 11. References

### Source code (RENT-A-HAL Personal Edition, v1.0)

- `realm/federation.py` — FederationConfig, FederationState, FederationMatrix, FederationClient, FederatorServer
- `realm/federation_provider.py` — FederationLLMProvider (HEAD), FederationLLMFallbackProvider (TAIL)
- `realm/federation_tts_provider.py` — FederationTTSProvider, FederationTTSFallbackProvider
- `realm/degraded_tracker.py` — Wall-clock degraded watchdog
- `app.py` — Construction and wiring of all federation components

### Related documents

- **RENT-A-HAL Operator's Manual** — operational deployment guide
- **RENT-A-HAL Design and Capabilities Paper** — broader product context
- **MTOR: Welcome to the Realm** (Jim Ames, Amazon B0F6BDXZYH) — narrative background on the MTOR project

### Constants of interest (canonical values)

| Constant | Value | Where defined |
|---|---|---|
| `DEGRADED_AVG_S` | 1000.0 | `realm/federation.py:68` |
| `checkin_interval_s` default | 15.0 | `realm/federation.py:78` |
| `missed_after_s` default | 60.0 | `realm/federation.py:88` |
| `max_federation_hops` default | 1 | `realm/federation.py:81` |
| `prefer_federation_for_llm_avg_s` default | 31.0 | `realm/federation.py:76` |
| `prefer_federation_for_tts_avg_s` default | 31.0 | `federation.ini` |
| `local_degraded_after_s` default (LLM) | 300 | `config.ini [LLMChain]` |
| `local_degraded_after_s` default (TTS) | 300 | `config.ini [TTSChain]` |

### Naming

**MTOR** = **M**ulti **T**ronic **O**perating **R**ealm — a deliberate reference to Dr. Daystrom's M-5 Multitronic Unit from *Star Trek: The Original Series*, "The Ultimate Computer" (1968). The system aims to fulfill the M-5 design vision (a self-contained intelligent realm capable of autonomous operation) while explicitly avoiding the M-5 design failure (autonomous operation without human oversight). The federation is the substrate that lets multiple MTOR realms cooperate as a mesh while each remains under its own operator's control. **The realm does what M-5 was supposed to do, with humans in the loop.**

---

## Acknowledgments

Built by Jim Ames at N2NHU Labs (Newburgh NY). Engineering collaboration with Anthropic's Claude over approximately seven months of sustained pair-engineering. Production validation conducted at the N2NHU lab on the rentahal.com and realnewslistener.com realms.

The shower-thought that produced the degraded watchdog (Section 5.3) was had on the morning of June 22, 2026, before the v1.0 compile freeze. It is included in this document as evidence that careful pre-release thinking finds bugs that no test suite will.

🖖 Live long and prosper.

---

*This document is released under the same license as the RENT-A-HAL Personal Edition codebase. It is intended as a technical reference for operators, deployers, and engineers extending the federation. Comments, corrections, and proposed extensions are welcome via the project's GitHub issues.*
