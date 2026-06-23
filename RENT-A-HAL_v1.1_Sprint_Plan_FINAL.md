# RENT-A-HAL v1.1: The Single-Purpose Realm Extension
## Staycation Sprint Plan — July 4-7, 2026

**Author:** Jim Ames (N2NHU Labs) + Claude (Anthropic)
**Sprint window:** 4 working days, July 4-7
**Release target:** v1.1.0 by July 8, 2026
**Architectural shift:** None. v1.1 is a parameterization of v1.0, not a redesign.

---

## 0. What this plan is

This document supersedes the previous 10-day "capability mesh" sprint plan.
That plan was overengineered. In four exchanges on a lunch break, the
operator simplified the v1.1 architecture by approximately 75% by removing
assumptions about complexity that wasn't needed.

The remaining v1.1 work is genuinely small: add a function label to the
realm, add two new local providers (Vision and Imagine), specialize the
cockpit per function, and let the existing federation machinery route
between same-function realms via a single filter. **No new wire protocol,
no new federation chains, no new watchdog code, no new schemas.**

A small business that wants AI + Vision + Imagine deploys three small
single-purpose realms — `rentahal.com`, `llava.rentahal.com`,
`imagine.rentahal.com` — each running the same software with a different
`node_realm_function` setting. The federation mesh aggregates them. Each
realm fits comfortably on an 8GB consumer GPU because it serves one model.

---

## 1. Architecture — final form

### 1.1 The single-purpose realm principle

**One box. One RTX. One RAH. One function.**

Every realm is a single-purpose appliance. At install time, the operator
chooses one of:

| node_realm_function | Local provider | Cockpit specialization | Default |
|---|---|---|---|
| `aichat` | GPT4All (Llama 3.2 3B) | Voice chat, intents (weather/news/music/service) | YES |
| `vision` | LLaVA-class via local API | Webcam capture → description → spoken | NO |
| `imagine` | Automatic1111 via local API | Voice prompt → image render → speak ack | NO |

A realm cannot be in two functions simultaneously. The wizard refuses to
launch unless exactly one is selected. To run multiple functions on the
same physical hardware, the operator runs multiple realm processes on
different ports — each declaring its own `node_realm_function`.

### 1.2 The federation extension — one field

The federation matrix gains exactly one field per member record:

```python
@dataclass
class MemberRecord:
    url: str
    llm_avg_s: float = DEGRADED_AVG_S
    tts_avg_s: float = DEGRADED_AVG_S
    tokens_out: int = 0
    last_seen: float = 0.0
    node_realm_function: str = "aichat"   # NEW — default for v1.0.x peers
```

The check-in payload gains one field. v1.0.x peers don't send it; the
Federator defaults their record to `aichat`. **Zero coordination needed
for rollout** — v1.0.x and v1.1 peers federate correctly with each other
through this default.

The Federator's peer-advice function gains one filter:

```python
def best_peer_for(self, caller_url: str) -> Optional[str]:
    caller = self.find(caller_url)
    if caller is None:
        return None
    candidates = [
        m for m in self.members
        if m.url != caller.url
        and m.node_realm_function == caller.node_realm_function
        and m.effective_avg(now) < DEGRADED_AVG_S
    ]
    if not candidates:
        return None
    return min(candidates, key=lambda m: m.effective_avg(now)).url
```

A vision realm asking for a peer gets a vision peer. An imagine realm
gets an imagine peer. An aichat realm gets an aichat peer (or a v1.0.x
peer with the default). **Three lines added to one existing function.**

### 1.3 The cockpit specialization

The cockpit (`templates/index.html`) is shared across all three function
modes. At boot, it reads `node_realm_function` from `/api/config` and
shows the appropriate UI:

- `aichat` cockpit: existing UI (voice loop, intents, conversation, music/service panels)
- `vision` cockpit: voice loop + webcam preview + capture button + "describe what you see" handler + description display
- `imagine` cockpit: voice loop + prompt entry + most-recent-image display + image gallery (session only)

All three share the wake-word loop, the status bar, the federation
strip, and the watchdog signaling. The only differences are the
realm-specific content panels.

### 1.4 What does NOT change

This is the section that matters most. We have learned from four rounds
of operator simplification: **every assumption about "what v1.1 needs
to add" should be examined twice for whether it's actually needed.**

- ❌ The federation protocol — no wire change
- ❌ The check-in payload shape — only one new field, default-tolerant
- ❌ The matrix schema — one new field with safe default
- ❌ The degraded watchdog — same code, same thresholds
- ❌ The probe_local floor-skip (rev-4 fix) — same code
- ❌ The recovery dance — same code
- ❌ The hop limit — same protocol
- ❌ The HEAD/FALLBACK federation provider classes — reused unchanged
- ❌ The cockpit voice loop — reused
- ❌ The intent classification — extended with two new intent verbs only
- ❌ The TTS chain — Kokoro speaks the responses across all three function modes
- ❌ The five wizard hard gates — extended with a "function selected" gate
- ❌ The config schema annotations — one new key with `@scope: backend`

---

## 2. The 4-day sprint

Each day has a morning intent and an end-of-day verification gate. Day 3
is the polish day. Day 4 is documentation + release.

### Day 1 — Friday July 4 — node_realm_function plumbing

*Theme: Add the function label everywhere. No new providers yet.*

**Morning (3 hrs):**
- Add `[Realm] node_realm_function = aichat` to `config.ini` with single-line
  annotation (per the v1.0.3 lesson about the multi-line annotation parser bug)
- Extend `MemberRecord` dataclass with `node_realm_function: str = "aichat"`
- Extend matrix `to_dict()` / `from_dict()` for persistence
- Extend `upsert()` to accept and store the field, defaulting to `aichat`
- Extend check-in payload to include the field
- Extend Federator peer-advice with the function filter (3 lines)
- Add the new `[Realm]` section to the wizard form with a single-select
  dropdown: AI Chat (default) / Vision / Imagine

**Afternoon (3 hrs):**
- Tests:
  - `[Realm]` section parses correctly with single-line annotation
  - `node_realm_function` defaults to `aichat` when missing
  - Matrix accepts v1.0.x check-ins (no function field) and defaults to `aichat`
  - Matrix accepts v1.1 check-ins (with function field) and stores correctly
  - Peer advice filters by function (vision asks → only vision peers offered)
  - Backward-compat: v1.0.x peer (no field) appears in `aichat` peer advice

**Verification gate (end of day):**
- All existing 687 tests still pass
- ~8 new tests for the function plumbing
- Production RAH and RNL still federate correctly because they default to `aichat`
- No realm process actually does anything new yet — this is pure schema work

**Status at EOD:** Schema is in. Federation routing is function-aware. No
new capabilities are visible to users yet. Production is unaffected.

### Day 2 — Saturday July 5 — Vision realm

*Theme: Make `node_realm_function = vision` actually do something.*

**Morning (3 hrs):**
- Create `realm/vision_provider.py` — talks to local LLaVA-class API
- The provider replaces the GPT4All slot in the LLM chain when
  `node_realm_function = vision`. **This is the matrix transformation
  insight**: same federation code, different local provider.
- Browser-side: vision cockpit variant
  - Webcam preview area
  - Capture button (snaps single frame)
  - "describe" intent trigger via voice — handler captures frame, ships
    base64 to local realm, realm calls LLaVA API, returns description
  - Description spoken via Kokoro (existing TTS path)

**Afternoon (3 hrs):**
- Realm-side: when `node_realm_function = vision`, `/api/ask` interprets
  the request body as `{"image_b64": "...", "prompt": "describe"}` instead
  of plain text
- Federation rescue path: a busy/dead vision realm federates to peer
  vision realms (because the Federator only offers vision peers to
  vision realms) — same machinery as today
- Tests:
  - Vision realm boots in vision mode
  - Vision intent triggers webcam capture
  - Vision request returns description text
  - Vision federation routes only to vision peers (verified via the Day 1 filter)

**Verification gate:**
- Vision realm running standalone: "computer describe what you see" →
  webcam captures → LLaVA returns description → Kokoro speaks it
- Federation: kill local LLaVA, vision realm federates to peer vision realm
- Existing AI realm (rentahal.com) unaffected — it's `aichat` mode, gets
  `aichat` peer advice, never sees vision requests

**Status at EOD:** Vision is a working single-purpose realm function. The
operator can build a Vision realm using the same Inno installer with a
different wizard selection.

### Day 3 — Sunday July 6 — Imagine realm

*Theme: Make `node_realm_function = imagine` actually do something.*

Symmetric to Day 2:

**Morning:**
- `realm/imagine_provider.py` — talks to Automatic1111 API
- Browser-side: imagine cockpit variant
  - Prompt entry box + voice prompt support
  - Image display area (most recent generation, session-history below)
  - "imagine" intent trigger
- Acknowledgment audio: "Here's your kitten" via Kokoro

**Afternoon:**
- Realm-side: when `node_realm_function = imagine`, `/api/ask` interprets
  the request as `{"prompt": "..."}` and returns `{"image_b64": "..."}`
- Federation rescue: dead-local imagine realm federates to peer imagine
- Tests for the imagine path
- Sabotage: kill local A1111, verify rescue works; restart, verify recovery

**Verification gate:**
- Imagine realm: "computer imagine a kitten in a teacup" → A1111 generates
  → image displays in cockpit → Kokoro speaks acknowledgment
- Federation rescue verified
- Recovery verified

**Status at EOD:** All three function modes (aichat, vision, imagine) work
end-to-end. Federation routes between same-function realms. No federation
crosstalk between functions.

### Day 4 — Monday July 7 — Documentation + Release

*Theme: Update the documentation set, ship v1.1.0.*

**Morning (3 hrs):**
- Update **Quick Start Guide**: add the realm function selector to the
  wizard walkthrough. Note that running multiple functions = multiple
  realms. Approximately 300 words added.
- Update **MTOR Federation White Paper**: add §3.5 "Single-purpose realm
  appliances" describing the node_realm_function field and how the
  federation matrix filters by it. Approximately 400 words added.
- Update **What Makes RENT-A-HAL Different**: add vision and imagine to
  the capability matrix where applicable. Add a row to the comparison
  table noting that vision and imagine are single-purpose realms by
  design — no consumer voice AI offers this deployment model.

**Afternoon (3 hrs):**
- Update **Cluster Deployment Paper**: add a new section showing the
  small-business heterogeneous cluster topology — `ai.theirdomain.com`
  (Heavy tier), `llava.theirdomain.com` (Standard tier),
  `imagine.theirdomain.com` (Heavy tier). Document hardware sizing
  per function.
- Triple-run the full test battery (target ~720 tests post-extensions)
- Stage v1.1.0 hot-patch / installer / Inno bundle
- Cisco-terse release notes (~250 words)
- Deploy to RNL → verify → deploy to RAH → verify
- Tag v1.1.0 in git, build release ZIP

**Verification gate (end of sprint):**
- 720+ tests pass triple-run zero flakes
- Production realms running v1.1
- A test deployment of a Vision realm (could be a smaller eval rig in
  the lab) federates correctly with rentahal.com
- All four shipping documents updated and consistent

---

## 3. Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| LLaVA API or A1111 API differs from operator's lab version | Medium | Medium | Day 2/3 morning is reading the actual API. If different, found before lunch. |
| Schema change to MemberRecord breaks matrix persistence | Low | High | Day 1 ends with passing tests including backward-compat for v1.0.x records. |
| Function filter breaks v1.0.x federation | Low | High | Tests on Day 1 explicitly verify v1.0.x peers (no field, defaulted to aichat) continue to be offered as peers to other aichat realms. |
| Cockpit specialization adds rendering bugs | Medium | Low | The vision/imagine cockpits start from the aichat cockpit. New panels are additive; existing panels are removed (not modified). |
| Time slip — staycation has fewer working hours than planned | Medium | Medium | The plan IS 4 working days, not 10. Two slack days remain. If Day 3 slips, Imagine ships as v1.1.1 next month. |
| Wizard form complexity grows | Low | Low | One new dropdown (Function selector) with three options. |

---

## 4. Decisions Captain pre-confirmed (verified pre-sprint)

These were the four yes/no questions resolved on June 23, 2026:

| # | Decision | Resolution |
|---|---|---|
| **D1** | Field name | `node_realm_function` |
| **D2** | What does a wrong-type request to a function realm do? | Impossible by design — a vision realm only receives vision requests because federation only routes vision requests to it |
| **D3** | Federator response shape | Existing `best_llm_peer` and `best_tts_peer` fields, just filtered by function — no new fields |
| **D4** | v1.0.x peer backward compat | Default to `aichat` if no field reported |

---

## 5. What's NOT in v1.1

Deferred to v1.2 or beyond:

- Multi-frame Vision streams (single-frame is v1.1)
- Image-to-image Imagine (img2img)
- Vision-driven autonomous behavior ("tell me when someone walks in")
- Server-side image persistence and gallery
- Real-time webcam preview without explicit capture
- Cross-function intent routing (e.g., AI realm forwards "describe what
  you see" to a sibling vision realm via HTTP) — operators connect to
  the right cockpit for the right function
- Multi-Federator consensus
- Per-function watchdog threshold tuning (uses the LLM defaults)

None of these are blockers. All would extend the architecture additively.

---

## 6. Sprint commitment summary

By Monday July 7, 2026:

✅ Three realm function modes: aichat (default), vision, imagine
✅ Single new INI field: `[Realm] node_realm_function`
✅ Single new matrix field: `MemberRecord.node_realm_function`
✅ Single new check-in payload field, backward-compat with v1.0.x peers
✅ Single new Federator filter on peer advice
✅ Vision provider (LLaVA-class API client)
✅ Imagine provider (Automatic1111 API client)
✅ Two new intents (vision describe, imagine generate)
✅ Two new cockpit specializations (vision and imagine variants)
✅ Wizard extended with realm function selector
✅ Four shipping documents updated for v1.1
✅ v1.1.0 deployed to production

**Effort: 4 working days. Other 6 staycation days are actually staycation.**

---

## 7. The architectural insight at the heart of v1.1

In four messages, the operator simplified v1.1 by removing successive
assumed complexity:

1. **Subdomain encodes capability** → removed per-class config toggles, removed matrix schema extensions
2. **Matrix transformation** → removed parallel chain code, reused existing federation
3. **One box one function** → removed multi-function realm complexity entirely
4. **Fake subdomain in HEALTH ACK (i.e., one new field in check-in)** → removed real DNS subdomain coordination

The remaining v1.1 IS the irreducible minimum: a label, two providers,
two intents, two cockpit panels. **The federation machinery from v1.0
handles everything else without modification.**

The methodology lesson: when adding a feature seems to require many new
parallel systems, look for the single primitive that makes the new
systems unnecessary. v1.0 already provides that primitive — federation
between same-purpose realms. v1.1 just extends the label-space the
primitive operates over.

🖖 Live long and prosper. The realm endures because the operator keeps
removing things.
