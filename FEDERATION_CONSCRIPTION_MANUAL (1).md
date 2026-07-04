# RENT-A-HAL — Multi-Mode, Federation, Conscription & Economic Layer Manual

Everything you need to run a realm as chat, vision, or imagine primary;
join it to a federation; let it lend or borrow idle capacity via
conscription; and, if you want it, charge for usage and pay donors for
confirmed work. Companion to `README.md` (quickstart) and
`MULTI_USER_AND_LAN.md` (multi-user/LAN specifics) — this doc covers
everything added since v1.0.0, including the full economic layer
(proof-of-work anti-abuse gate, tamper-evident ledger, consumer
billing, donor payout).

**Nothing here is required.** Every feature in this manual is off by
default except the anti-abuse gate (§5), and a realm that ignores this
entire document runs exactly as it always has: one chat realm,
standalone, no federation, no billing. Read only the sections you
actually want to turn on.

---

## Table of contents

1. [Multi-mode realms — chat, vision, imagine](#1-multi-mode-realms--chat-vision-imagine)
2. [The setup wizard](#2-the-setup-wizard)
3. [Federation](#3-federation)
4. [Conscription](#4-conscription)
5. [Proof-of-work anti-abuse gate](#5-proof-of-work-anti-abuse-gate)
6. [The ledger](#6-the-ledger)
7. [Consumer billing](#7-consumer-billing)
8. [Donor payout](#8-donor-payout)
9. [Config cheat sheet](#9-config-cheat-sheet)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Multi-mode realms — chat, vision, imagine

A realm can now do three things beyond plain chat:

| Say this | Realm does | Config section |
|---|---|---|
| "computer what is the capital of France" | Chat (unchanged) | `[LLMChain]` / `[GPT4All]` / `[Claude]` / `[HuggingFace]` |
| "computer take a look" / "what do you see" | Vision — grabs a webcam frame, describes it | `[VisionChain]` / `[LLaVA]` |
| "computer imagine a kitten wearing a hat" / "draw a sunset" | Imagine — generates an image | `[ImagineChain]` / `[Automatic1111]` |

None of this requires anything. A realm with no `[LLaVA]`/`[Automatic1111]`
backend running still answers vision/imagine questions — it just falls
through to a friendly, always-available floor (more below).

### 1.1 Setting up Vision (LLaVA via Ollama)

1. Install [Ollama](https://ollama.com).
2. `ollama pull llava` (or `llava:13b` for a larger/slower/better model).
3. `ollama serve` (or just leave it running — Ollama usually stays up as
   a background service after install).
4. In `config.ini`:
   ```ini
   [VisionChain]
   vision_order = llava,echo

   [LLaVA]
   host = localhost
   port = 11434
   model = llava
   timeout = 60
   ```
5. Restart the realm. No further setup — the realm re-probes Ollama on
   every request, so starting/stopping Ollama later doesn't need a
   restart.

Say **"computer take a look"** or **"what do you see"**. The browser
grabs a *single* webcam frame at the moment you ask (not a live feed —
the camera is released immediately after) and sends it along with the
question. The description lands in the same answer box as every other
AI response.

Other phrases that work: "what can you see", "can you see", "look at
this", "look at that". Bare "look" is deliberately **not** a trigger —
it would misfire on "look up the weather".

### 1.2 Setting up Imagine (AUTOMATIC1111)

1. Install [AUTOMATIC1111's webui](https://github.com/AUTOMATIC1111/stable-diffusion-webui).
2. Launch it with the `--api` flag (e.g. edit `webui-user.bat` to add
   `--api` to `COMMANDLINE_ARGS`).
3. In `config.ini`:
   ```ini
   [ImagineChain]
   imagine_order = automatic1111,echo

   [Automatic1111]
   host = localhost
   port = 7860
   steps = 20
   width = 512
   height = 512
   sampler = Euler a
   timeout = 120
   ```
4. Restart the realm.

Say **"computer imagine a kitten wearing a hat"** or **"draw a sunset
over the mountains"**. The image appears in its own panel; a short
spoken confirmation plays through TTS.

### 1.3 The Echo floor — what happens with nothing configured

Both Vision and Imagine always have a floor provider (`echo`) at the
end of their provider order, so `vision_order` / `imagine_order` should
always end in `,echo` (the shipped defaults already do). If Ollama or
AUTOMATIC1111 isn't running — or isn't configured at all — the floor
answers instead of erroring:

- **Vision floor**: a polite "no vision model is currently online"
  message, *plus* a Mr. Magoo clip on the video panel — instantly
  recognizable to any operator watching that nothing is online.
- **Imagine floor**: same polite message, *plus* the well-known
  rickroll video on the panel.

Both floors share **one** bus event (`easter_egg_video
{youtube_id, source}`) — the client has a single code path for both,
not two.

This isn't a joke feature bolted on for fun (though it is fun) — it's
the actual production behavior when a backend is down, and it's
designed so an operator glancing at the screen knows *immediately*
"nothing is online" without reading log files.

### 1.4 Declaring a realm's primary mode

Independent of what's configured above, a realm can *declare* which
mode is its main job via `federation.ini`:

```ini
[Federation]
node_type = chat      # or: vision, imagine
```

This matters for two things:
- **The setup wizard's gate** (§2) — a `vision`-primary realm is gated
  on Ollama/LLaVA being up, not on GPT4All.
- **Federation/conscription** (§3–4) — `node_type` tells the Federator
  who's "native" to a rank vs. who'd be moonlighting.

`node_type` is **purely descriptive** — it doesn't limit what a realm
can actually do. A `chat`-primary realm can still answer vision/imagine
questions if LLaVA/AUTOMATIC1111 are configured; `node_type` only
affects the wizard gate and federation bookkeeping.

---

## 2. The setup wizard

`python wizard.py` walks through first-run setup with live probes and a
GO button that only lights up once everything required is actually
working.

### 2.1 What's gated, and by what

| Your `node_type` | GO requires | GPT4All required? |
|---|---|---|
| `chat` (default) | GPT4All up, a model loaded, a model selected, and it actually answers a test prompt | **Yes** |
| `vision` | Ollama up, at least one model installed (`ollama pull llava`) | No |
| `imagine` | AUTOMATIC1111 up, at least one checkpoint loaded | No |

**CUDA is checked regardless of mode** (unless `[Hardware] require_cuda
= false` for a cloud-only setup with API keys) — vision/imagine
backends typically want a GPU at least as much as GPT4All does.

**Federation's own gate is independent**: if `[Federation] desire = on`
but `self_url` is blank, GO stays blocked regardless of mode, with a
message pointing at the missing URL.

### 2.2 Vision/Imagine panels in the wizard

The wizard now shows two more panels, mirroring the existing GPT4All
one:

- **Vision (optional — LLaVA via Ollama)**: status badge, host/port
  fields, a live model dropdown populated from whatever Ollama actually
  has installed.
- **Imagine (optional — Automatic1111)**: status badge, host/port
  fields, a checkpoint count.

Both are labeled "optional" and colored neutral grey (not alarming red)
when nothing's running — unlike GPT4All, an unconfigured Vision/Imagine
backend is a completely normal, valid state for a `chat`-primary realm.
These panels **never block GO** unless your `node_type` is `vision` or
`imagine` respectively (see the table above).

### 2.3 Saving

The wizard writes to `config.ini` and `federation.ini` when you click
GO. Vision/Imagine fields save regardless of whether you've picked a
GPT4All model — a vision-primary or imagine-primary realm may
legitimately have no GPT4All model selected at all.

---

## 3. Federation

### 3.1 What it is

Realms can help each other. If your local LLM/TTS gets slow or dies,
the realm automatically overflows the next request to a healthier
peer; when local recovers, routing flips back with zero operator
action. It's **fully opt-in** (`desire = off` by default) and works
whether or not you have a public URL.

The Federator is just a phonebook + router — every 15 seconds a member
checks in and gets told who the fastest peer currently is. Actual query
traffic goes **directly** between realms, peer to peer — it never
passes through the Federator itself.

### 3.2 Joining a federation as a member

Edit `federation.ini`:

```ini
[Federation]
desire = on
master_url = https://rentahal.com/api/federate    # or your own Federator
self_url = https://your-realm.ngrok.app            # blank = consumer-only
```

That's it. Restart. The realm now checks in every 15 seconds
(`checkin_interval_s`) and starts reporting its own health.

**Leave `self_url` blank to be a consumer only** — you can overflow to
faster peers, but nobody can overflow to you (you're not advertised as
reachable). Fill it in with a real, reachable URL (ngrok, Cloudflare
Tunnel, or a real domain) to also help others.

### 3.3 How routing actually works

Every check-in, this realm reports:
- `llm_avg_s` / `tts_avg_s` — rolling averages of your own recent query
  times (self-reported honestly — see §3.5 for why this matters)
- `capability_avg_s` — same idea for vision/imagine, sparse (only
  reported when a real, non-Echo provider is actually configured — see
  §1.3; an Echo floor never gets to look like the fastest real peer)
- `node_type` — your declared primary role

The Federator replies with `best_llm_peer` / `best_tts_peer` /
`best_peer` (generalized for vision/imagine) — the URL of whichever
alive peer currently has the lowest reported average, excluding you.

Your realm overflows to that peer **only** when your own local average
crosses `prefer_federation_for_llm_avg_s` (default 31.0s). Below that
threshold, local is always preferred — federation is a rescue/overflow
mechanism, not a replacement for local inference.

**Hop limiting**: a federated call carries `X-Federation-Hops: 1`. The
receiving realm sees that header and answers *locally*, never
re-forwarding — this is what stops a slow-peer cascade when several
realms are struggling at once. `max_federation_hops` (default 1)
controls this.

### 3.4 Becoming a Federator

Most realms are members, not Federators. One realm per federation runs
the coordinator:

```ini
[Federator]
enabled = true
state_file = federation_state.json
missed_after_s = 60.0
```

`GET /api/federate/matrix` dumps the current phonebook (every member's
self-reported stats) for observability — see §5 for the full endpoint
list.

### 3.5 The DEGRADED sentinel — why self-reporting matters

If your local LLM dies and a federated rescue call is answering
instead, your *rolling average* would otherwise reflect the **remote**
peer's latency — which can look "healthy enough" to be advertised to
*other* realms, even though you can't actually serve federated traffic
yourself (your own hop limit blocks re-forwarding). To prevent this,
a realm whose local LLM/TTS is dead self-reports the `DEGRADED_AVG_S`
sentinel (1000.0) instead of the real number, so the Federator
naturally stops recommending it. This is fully automatic — nothing to
configure.

### 3.6 Securing federation with a token

By default, **every federation endpoint is open** — no token required,
same as it's always behaved. Set one to lock it down:

```ini
[Federation]
token = some-shared-secret
```

Once set, it's enforced consistently on:
- `POST /api/federate/checkin`
- `GET /api/federate/matrix`, `GET /api/federate/contracts`
- `POST /api/federate/contracts/revoke`
- Federated forwards into `/api/ask` and `/api/speak`

**Direct callers to `/api/ask`/`/api/speak` are never gated** by this,
regardless of whether a token is set — a curious person running curl
against your realm never sees a token prompt. Only calls that identify
themselves as federated (carrying `X-Federation-Hops`) are checked.
This value plays both roles symmetrically: what you *send* when
federating out, what you *require* when others federate in.

---

## 4. Conscription

### 4.1 The idea

A realm running as, say, `vision`-primary has idle chat/LLM capacity
most of the time — nobody's asking it chat questions, that's not its
job. Conscription lets the Federator temporarily route **overflow
chat demand** from a struggling chat-native realm to that idle vision
box's spare capacity — always time-boxed, always under the donor's
explicit consent, never silent.

The receiving realm doesn't need to know or care that a request was
"conscripted" — it just answers locally like any ordinary federated
call.

Two **independent** layers of consent must both agree, or nothing
happens:
1. The **donor's own** `[FederationConscription]` settings (this
   section) — "I'm willing to lend capacity."
2. The **Federator operator's** `[Federator]` settings — "I allow this
   feature to operate at all."

### 4.2 Donor setup — "I'm willing to help"

```ini
[FederationConscription]
allow_federation_conscription = on
permitted_conscription_ranks = chat
max_conscription_minutes = 15
```

- **`allow_federation_conscription`** — master switch for lending *your*
  idle capacity. Doesn't affect your own ability to overflow *your*
  work to others (that's ordinary federation, §3).
- **`permitted_conscription_ranks`** — which ranks (`chat`, `vision`,
  `imagine`) you permit yourself to be conscripted *into*. **Empty is
  the default and means opt-in required** — `allow_federation_
  conscription = on` by itself volunteers nothing. Special values:
  - `none` — explicit synonym for empty
  - `any` — permit every rank you happen to have a real provider for
  - `chat,vision` — permit exactly these ranks
- **`max_conscription_minutes`** — your preferred contract length. The
  Federator respects whichever is *shorter*: your preference, or its
  own ceiling — you can shorten a contract, never lengthen it past what
  the Federator allows.

**A rank only actually matters if you have a real provider for it.**
Setting `permitted_conscription_ranks = chat` on a box with no GPT4All
configured makes you eligible for nothing — consent alone isn't
enough, you also need the actual capability (this is checked
automatically; you don't need to reason about it yourself).

### 4.3 Federator setup — "I allow this feature to run"

```ini
[Federator]
conscription_enabled = true
conscription_trigger_avg_s = 10.0
conscription_idle_avg_s = 2.0
default_conscription_max_minutes = 15
max_donors_per_rank = 2
```

- **`conscription_enabled`** — master switch. Off means the check-in
  response's contract field is always empty, regardless of any
  member's own consent.
- **`conscription_trigger_avg_s`** — if the best *native* peer for a
  rank (a realm whose own `node_type` IS that rank) is slower than
  this, demand is considered high enough to look for a donor.
- **`conscription_idle_avg_s`** — a donor candidate's *own* native-duty
  average must be at or below this to count as "idle enough to spare."
  This is a **separate** number from the trigger above — one is about
  the shortage side, the other the spare-capacity side.
- **`default_conscription_max_minutes`** — fallback contract length
  used when a donor doesn't report its own preference.
- **`max_donors_per_rank`** — how many donors one rank can have
  simultaneously (default 2). Donors are added **incrementally** — at
  most one new donor per 15-second check-in cycle while demand
  persists, never all at once.

### 4.4 What happens automatically

Once both sides consent and demand genuinely exceeds capacity, the
Federator assigns a contract. From here, everything is automatic:

- The struggling realm gets told about the donor and starts routing
  overflow chat traffic there (it tries ordinary federation first —
  the genuinely-fastest peer if one exists — falling back to the
  conscripted donor only if that wasn't enough).
- If more than one donor is contracted for the same rank, the realm
  tries them **in order**, falling through to the next on any failure
  (timeout, error, empty answer) before finally giving up to its own
  Echo floor.
- The donor learns it's currently helping (via its own check-in
  response) — so its operator can see "I'm moonlighting as chat" on
  their own cockpit, not just infer it from a traffic spike.
- Contracts don't reassign every 15 seconds even if a marginally
  better donor appears — that would thrash a donor's workload for no
  real benefit. A **new** donor only gets added if demand still
  persists on a later check-in and there's room under the cap.
- Contracts expire naturally (see `max_conscription_minutes`), and the
  Federator re-evaluates from scratch at that point — demand or
  idleness may have changed.

**Nothing on the receiving realm needs to know it's a "conscripted"
request** — it just answers locally, exactly like any other federated
call. (A diagnostic-only `X-Federation-Conscripted` header rides along
for anyone reading their own logs, but nothing reads it programmatically.)

### 4.5 Watching it happen

`GET /api/federate/contracts` (Federator side) dumps every active
contract, grouped by rank:

```json
{
  "contracts": {
    "chat": [
      {"peer_url": "https://vision-box.example", "native_role": "vision",
       "conscripted_as": "chat", "assigned_at": 1234.5, "expires_at": 2134.5}
    ]
  }
}
```

Each realm's own `/api/federation/status` (no auth needed for reading
your own status) shows:
- `conscription` / `conscriptions` — who's helping *you* (singular =
  first/primary, plural = the full list; read the plural for anything
  new, the singular exists for backward compatibility)
- `donor_contract` / `donor_contracts` — who *you're* currently helping

**Note on timestamps**: `assigned_at`/`expires_at` are the Federator's
own internal clock values — they have no meaningful relationship to
wall-clock time or any other machine's clock. Don't try to compute
"minutes remaining" from them; just treat presence/absence as the
signal.

### 4.6 Manually ending a contract early

You don't have to wait for natural expiry or restart the Federator
(which would clear *every* rank's contracts, not just the one you
care about):

```bash
# Revoke ALL donors currently helping "chat"
curl -X POST https://your-federator.example/api/federate/contracts/revoke \
  -H "Content-Type: application/json" \
  -d '{"rank": "chat"}'

# Revoke just ONE specific donor, leaving any other donor for the
# same rank untouched
curl -X POST https://your-federator.example/api/federate/contracts/revoke \
  -H "Content-Type: application/json" \
  -d '{"rank": "chat", "donor_url": "https://vision-box.example"}'
```

If you've set a `[Federation] token`, add `-H "X-Federation-Token:
your-secret"` — this admin endpoint is gated the same way as everything
else once a token is configured (§3.6).

### 4.7 Reporting more than vision/imagine (advanced)

By default, only `vision` and `imagine` get reported in
`capability_avg_s` — both are backed by the Provider/Chain pattern with
a real Echo-floor safeguard (an idle floor never masquerades as a fast
real peer). You *can* extend this:

```ini
[Federation]
report_capabilities = vision,imagine,weather
```

**Understand the tradeoff before adding anything else to this list**:
non-chain capabilities (weather, music, service, roundup, or any future
intent) get a **weaker** signal — reported only once they've actually
been served at least once this session, with **no** floor-vs-real
distinction available (there's no Echo-floor concept for a plain
function call like weather). A weather query that fails fast due to a
missing API key would look deceptively "fast" under this weaker
signal. This is why the default list only contains the two capabilities
that have the real safeguard.

---

## 5. Proof-of-work anti-abuse gate

### 5.1 What it is

RENT-A-HAL's public surface (`/api/ask`, `/api/speak`, and federation
check-ins) is protected by a tiered proof-of-work challenge — a small,
deliberately-expensive-to-compute puzzle a caller must solve before a
request is served, once they've made enough calls recently. It's
**enabled by default** and, unlike everything else in this manual, it
isn't something you opt into — it's protecting your realm from day one.

The puzzle uses **Argon2id**, a memory-hard function, not plain
SHA-256. RENT-A-HAL's own user base tends to have serious GPUs — a
compute-bound puzzle would be nearly free for exactly the people most
likely to abuse the system. Memory-hardness closes that gap: a GPU's
huge core count doesn't help much when every attempt needs its own
dedicated block of RAM.

### 5.2 The tier ladder

| Calls in a 10-minute window | Public label | Cost |
|---|---|---|
| 1–10 | `free` | None — no puzzle at all |
| 11–50 | `pi-100` | ~1-3 seconds |
| 51–200 | `pi-1000` | ~15-25 seconds |
| 200+ | `pi-10000` (and climbing) | minutes, escalating |

The `pi-N` labels are deliberately playful — the tier names show up in
API responses, but the puzzle underneath is real Argon2id, not
literally computing digits of pi. Casual, normal use never crosses the
free threshold and never sees a puzzle at all.

### 5.3 Configuration

```ini
[AbuseGate]
enabled = true
secret =                     # blank = auto-generate at boot (fine unless
                              # you're running multiple processes that need
                              # to verify each other's issued challenges)
free_calls_window_s = 600.0
challenge_ttl_s = 60.0
```

The difficulty ladder itself (thresholds and bit counts) isn't a config
option — it's a "ship, then tune" decision (see `realm/pow_gate.py`'s
`DEFAULT_TIERS`), deliberately kept as code rather than exposed too
early, before real traffic data exists to tune it against. The setup
wizard shows the current ladder as a read-only reference table.

### 5.4 Checking real-world timing on your own hardware

```cmd
python pow_benchmark.py --tier pi-100
python pow_benchmark.py --tier pi-1000
python pow_benchmark.py --skip-slow
```

Numbers vary by machine — what matters is the *shape*: each tier should
be meaningfully pricier than the last, and `pi-100` should stay under a
couple seconds so the first paid tier doesn't feel broken to someone
who innocently crossed the free threshold.

---

## 6. The ledger

### 6.1 What it is

An append-only, hash-chained record of every credit and debit —
consumer top-ups, per-submit charges, donor payout credits. It's the
foundation both billing and payout are built on. **Requires a real
Postgres instance** — not because of throughput, but tamper-evidence: a
SQLite file is just bytes anyone with disk access can silently edit; a
hash chain makes tampering detectable regardless of how it happened.

```ini
[Ledger]
dsn =    # e.g. postgresql://user:pass@127.0.0.1:5432/dbname
```

Empty (the default) means the entire economic layer — billing, payout,
public proof — is off. Nothing else in your realm needs this to run
normally.

### 6.2 Independent verification

Anyone can audit the ledger's integrity without trusting this realm's
operator at all:

```cmd
python ledger_verify.py --dsn postgresql://... --account some-account-id
```

Recomputes every hash from scratch and reports the first discrepancy,
if any — the exact same check a tampered row would fail.

### 6.3 Public proof (Bitcoin anchoring)

Run daily (cron / Task Scheduler):

```cmd
python ots_daily_job.py --public-dir ./public_proofs
```

Anchors the current ledger state to Bitcoin via
[OpenTimestamps](https://opentimestamps.org) — free, no wallet, no
token, borrowing Bitcoin's own existing security. Publish the resulting
`public_proofs/ledger.ots` however you publish anything else (a repo, a
page on your site). Anyone can verify it independently:

```cmd
pip install opentimestamps-client
ots verify public_proofs/ledger.ots
```

Once connected, your realm also serves this over HTTP:

- `GET /api/ledger/proof` — downloads the current proof file
- `GET /api/ledger/proof/info` — human-readable status + verification instructions

---

## 7. Consumer billing

### 7.1 What it is

A prepaid balance, topped up via Stripe Checkout, spent down at a flat
rate per submit — **$0.0001 (100 micros) by default**. Not metered by
compute time or tokens; deliberately flat and predictable, the same
reasoning Claude/OpenAI/AWS all land on for consumer-facing pricing. A
$5 top-up buys 50,000 submits at the default rate.

Requires `[Ledger] dsn` **and** both Stripe keys below — three
separate opt-ins, all required together.

```ini
[Billing]
stripe_secret_key =              # sk_test_... or sk_live_...
stripe_webhook_secret =          # whsec_... from your Stripe dashboard
price_per_submit_micros = 100
low_balance_threshold_micros = 10000     # $0.01 — triggers the cockpit banner
checkout_success_url =
checkout_cancel_url =
```

### 7.2 The flow

1. User taps **Top up $5** in the cockpit (or hits the low-balance
   banner's own button) → `POST /api/billing/checkout` creates a real
   Stripe Checkout Session and redirects them to Stripe's hosted page.
2. Stripe sends a `checkout.session.completed` webhook to
   `POST /api/billing/webhook` once payment succeeds.
3. The webhook is **signature-verified** (real cryptography, not
   trust) before anything is credited, and **idempotent** — Stripe
   *will* redeliver webhooks, and a redelivery correctly does nothing
   the second time rather than double-crediting.
4. Every processed query debits the flat rate. Once the balance drops
   below `low_balance_threshold_micros`, a `low_balance` event fires
   and the cockpit shows a dismissable top-up banner.

**Balance is never hard-blocking.** A negative balance doesn't stop
service — Section 5's PoW gate is the anti-abuse backstop; billing's
job is honest bookkeeping and a gentle nudge, not a second rate
limiter. Worth revisiting once you have a feel for real usage.

### 7.3 Checking a balance directly

```
GET /api/billing/balance?account_id=<user_guid>
```

Same identity the cockpit's own balance indicator already polls, using
the browser's own `userGuid` — no separate login system.

---

## 8. Donor payout

### 8.1 What it is

If your realm moonlights as a conscription donor (Section 4), you can
get paid for confirmed work via Stripe Connect. This is genuinely the
most involved piece of the economic layer, because of one deliberate
safeguard: **bilateral confirmation**.

Federation's ordinary self-reported health numbers (`llm_avg_s` etc.)
are fine to trust unilaterally — lying about them only costs you your
own routing quality. A donor claiming "I served this request, pay me"
is a different risk class entirely, since lying is directly profitable.
So **both sides** — the struggling realm that received an answer, and
the donor that gave it — independently submit a claim about the same
piece of work to the Federator. A payout only ever happens when both
claims match. A donor claiming work nobody confirms gets paid **zero**,
no matter how many times they ask.

### 8.2 Configuration (Federator-role only)

```ini
[Payout]
stripe_secret_key =                    # a SEPARATE key from [Billing]'s own
conscription_payout_rate_micros = 80   # $0.00008 per confirmed request
minimum_payout_micros = 5000000        # $5.00 — below this, credits just accumulate
claim_match_tolerance_s = 60.0
unmatched_claim_max_age_s = 3600.0
onboarding_refresh_url =
onboarding_return_url =
```

Only meaningful for a realm acting as the Federator — that's where
claims actually get reconciled. A donor realm doesn't need this section
at all; it just needs to *link* a payout account (next).

### 8.3 Linking a payout account

```
POST /api/federate/payout/link
{"donor_url": "https://your-realm.example"}
```

Creates (or reuses) a Stripe Connect Express account and returns a
one-time onboarding URL — redirect the donor operator there to verify
identity and link a bank account. Nothing gets paid until onboarding
actually completes.

### 8.4 Watching your own earnings

The cockpit shows a `🌙 Donor earnings: $X.XX` indicator automatically
once your realm has a linked account — it polls the Federator's own
status endpoint using your realm's `self_url`:

```
GET /api/federate/payout/status?donor_url=<your self_url>
```

Shows whether you're linked, whether onboarding is actually complete,
and your current confirmed (bilaterally-matched) balance.

### 8.5 Getting paid

Payouts are **batched**, not real-time — Stripe's own transfer fee
makes paying out every single confirmed request wasteful. Run weekly
or monthly:

```cmd
python payout_batch_job.py                 # real payouts
python payout_batch_job.py --dry-run       # preview without calling Stripe
```

Re-verifies each account's onboarding status with Stripe directly
before attempting a transfer (your own cached flag can go stale — an
account that was onboarded once but later restricted is correctly
skipped, not blindly attempted).

### 8.6 Reviewing unconfirmed claims

```
GET /api/federate/conscription-claims/unmatched
```

Shows every claim still waiting for its pair — including any donor
claim that's been sitting unconfirmed past `unmatched_claim_max_age_s`,
which is worth a manual look, not an automatic payout.

---

## 9. Config cheat sheet

**`config.ini`** — capabilities

| Section | Key | Default | Purpose |
|---|---|---|---|
| `[VisionChain]` | `vision_order` | `llava,echo` | Provider fall-through order |
| `[LLaVA]` | `host` / `port` / `model` / `timeout` | `localhost` / `11434` / `llava` / `60` | Ollama connection |
| `[ImagineChain]` | `imagine_order` | `automatic1111,echo` | Provider fall-through order |
| `[Automatic1111]` | `host` / `port` / `steps` / `width` / `height` / `sampler` / `timeout` | `localhost` / `7860` / `20` / `512` / `512` / `Euler a` / `120` | AUTOMATIC1111 connection |

**`federation.ini`** — federation & conscription

| Section | Key | Default | Purpose |
|---|---|---|---|
| `[Federation]` | `desire` | `off` | Opt in as a member |
| | `master_url` | `https://rentahal.com/api/federate` | Who to check in with |
| | `self_url` | (blank) | Your reachable URL; blank = consumer-only |
| | `token` | (blank) | Shared secret; blank = fully open |
| | `node_type` | `chat` | Declared primary role: `chat`/`vision`/`imagine` |
| | `report_capabilities` | `vision,imagine` | What beyond llm/tts to report |
| | `prefer_federation_for_llm_avg_s` | `31.0` | Overflow threshold (seconds) |
| `[Federator]` | `enabled` | `false` | Is THIS realm the coordinator? |
| | `conscription_enabled` | `true` | Federator's own conscription master switch |
| | `conscription_trigger_avg_s` | `10.0` | Shortage threshold |
| | `conscription_idle_avg_s` | `2.0` | Idleness threshold |
| | `max_donors_per_rank` | `2` | Simultaneous donors cap |
| `[FederationConscription]` | `allow_federation_conscription` | `on` | Donor master switch |
| | `permitted_conscription_ranks` | (blank = opt-in required) | Ranks you'll lend capacity for |
| | `max_conscription_minutes` | `15` | Your preferred contract ceiling |
| `[AbuseGate]` | `enabled` | `true` | Proof-of-work anti-abuse gate — on by default |
| | `free_calls_window_s` | `600.0` | Rolling window for the free-call allowance |
| `[Ledger]` | `dsn` | (blank = economic layer off) | Postgres connection string |
| `[Billing]` | `stripe_secret_key` / `stripe_webhook_secret` | (blank) | Both required together for consumer top-ups |
| | `price_per_submit_micros` | `100` | $0.0001 per submit, flat |
| | `low_balance_threshold_micros` | `10000` | Triggers the cockpit top-up banner |
| `[Payout]` | `stripe_secret_key` | (blank) | Separate key from `[Billing]`'s own; Federator-role only |
| | `conscription_payout_rate_micros` | `80` | Per bilaterally-confirmed request |
| | `minimum_payout_micros` | `5000000` | $5.00 — below this, credits just accumulate |

**HTTP endpoints** (all under `/api/`)

| Endpoint | Method | Notes |
|---|---|---|
| `/ask`, `/speak` | POST | Text-only shortcut / TTS; open to direct callers always, token-gated for federated forwards |
| `/federate/checkin` | POST | Member → Federator |
| `/federate/matrix` | GET | Phonebook dump |
| `/federate/contracts` | GET | Active conscription contracts |
| `/federate/contracts/revoke` | POST | `{"rank": "..."}` or `{"rank": "...", "donor_url": "..."}` |
| `/federation/status` | GET | This realm's own federation/conscription state |
| `/ledger/proof`, `/ledger/proof/info` | GET | Public Bitcoin-anchored proof + verification instructions |
| `/billing/checkout` | POST | Create a real Stripe Checkout Session |
| `/billing/webhook` | POST | Stripe's own callback — signature-verified, idempotent |
| `/billing/balance` | GET | `?account_id=...` |
| `/federate/conscription-claim` | POST | Bilateral confirmation — either side submits a claim |
| `/federate/conscription-claims/unmatched` | GET | Claims still waiting for their pair |
| `/federate/payout/link` | POST | Start/resume Stripe Connect onboarding for a donor |
| `/federate/payout/status` | GET | `?donor_url=...` — onboarding + confirmed balance |

---

## 10. Troubleshooting

**"Vision/Imagine always answers with the Magoo clip / rickroll."**
The floor is firing, meaning the realm can't reach LLaVA/AUTOMATIC1111.
Check the host/port in `config.ini` match where Ollama/AUTOMATIC1111 is
actually listening, and confirm they're running (`ollama list`, or
visit AUTOMATIC1111's own webui in a browser).

**"The wizard's GO button is grey and I don't have GPT4All installed."**
Set `[Federation] node_type = vision` (or `imagine`) in
`federation.ini` if that's genuinely your primary mode — the wizard
will gate on your actual backend instead.

**"I set `permitted_conscription_ranks` but nothing ever gets
conscripted into my box."**
Confirm you actually have a real (non-Echo) provider configured for
that rank — consent alone isn't enough. Also confirm your OWN
native-duty average is genuinely below `conscription_idle_avg_s`
(2.0s by default) — an "idle" vision box that's actually still slow at
vision won't qualify as a donor.

**"A contract won't go away."**
Contracts expire naturally, but if you need it gone now: `POST
/api/federate/contracts/revoke` (§4.6). A Federator restart also clears
all contracts, but that's a bigger hammer than most situations need.

**"Federation seems totally open, is that a bug?"**
No — empty `token` (the default) means fully open by design, matching
how federation has always behaved. Set a token (§3.6) if you want it
locked down.

**"I'm suddenly getting a 402 instead of an answer."**
Working as designed (§5) — you've crossed the free-call threshold
(10 calls per 10-minute window by default). The response includes a
real Argon2id challenge; solve it and resubmit with `pow_solution`
attached. Casual/normal use should never see this at all.

**"Billing/Payout endpoints return 404."**
They only exist when fully configured — `/billing/*` needs
`[Ledger] dsn` **and both** `[Billing]` Stripe keys; `/federate/payout/*`
needs `[Ledger] dsn` **and** `[Payout] stripe_secret_key`, and only on a
realm running as Federator. A 404 here almost always means one piece
of that trio is still blank, not a real error.

**"A consumer says they paid but their balance didn't update."**
Check Stripe's own dashboard first — has the webhook actually been
delivered to `/api/billing/webhook`? A wrong `stripe_webhook_secret`
causes every delivery to fail signature verification (a 400, logged,
not silently dropped). Stripe will keep retrying on its own; once the
secret is corrected, the next retry credits normally.

**"A donor says they should have been paid but weren't."**
Check `/api/federate/conscription-claims/unmatched` (§8.6) first —
if their claim is sitting there alone, the requester side's claim
never arrived (a network hiccup on the requester's end, most likely).
This is the bilateral-confirmation design working exactly as intended,
not a bug: a claim with no matching pair is never auto-paid, on
purpose. If both claims genuinely exist and matched, confirm their
Stripe Connect account has actually finished onboarding
(`payouts_enabled` — see §8.4) and their confirmed balance has crossed
`minimum_payout_micros`.
