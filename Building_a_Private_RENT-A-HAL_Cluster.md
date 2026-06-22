# Building a Private RENT-A-HAL Cluster for Your Business
## A Deployment Guide for Small Business and Professional Offices

**Version 1.0** | June 2026 | N2NHU Labs

---

## Executive summary

This paper describes how to deploy a private RENT-A-HAL federation as the voice AI substrate for a small business or professional office. It is written for decision-makers and IT operators who have evaluated the alternatives (cloud subscriptions, single-instance self-hosting) and are considering a small private cluster.

The intended audience runs an organization with **2 to 30 staff members** who would benefit from on-premises voice AI for tasks such as document drafting, client communications, scheduling support, knowledge base queries, and internal Q&A. The paper addresses three deployment scales — the **small office** (2 realms), the **multi-location professional firm** (4-6 realms), and the **regional small enterprise** (8+ realms) — with concrete hardware specifications, capacity math operators can validate, and honest scoping of what the architecture does and does not provide at each scale.

A working RENT-A-HAL cluster for a typical professional office can be deployed in one afternoon by a competent IT operator using off-the-shelf consumer hardware, with a total hardware cost in the $2,000–$8,000 range and a total ongoing cost approaching the marginal cost of electricity. The federation provides redundancy, burst capacity sharing, self-healing recovery from engine failures, and an audit-friendly local-first architecture suitable for regulated workloads.

The paper does **not** describe department-scale or enterprise deployments (50+ users, multi-region operations, formal identity management, audit trail compliance). Section 12 honestly scopes where the current architecture would require additional work for those use cases.

---

## 1. The cluster pattern

A RENT-A-HAL cluster is **a small number of cooperating realms**, each running on its own hardware, sharing capacity through the MTOR Federation. Every realm in the cluster has the same software, the same configuration model, and the same federation protocol. There is no leader-follower replication, no shared state outside the federation matrix, and no central component whose failure takes down the cluster.

A cluster is distinguished from a single realm by three properties:

**Capacity pooling.** When one realm is busy serving local users, other realms handle overflow transparently. The user experience does not change. Latency typically stays within normal ranges because the federation routes to a less-loaded peer.

**Redundancy.** When one realm's local engine fails (model crash, GPU thermal throttle, power loss), other realms rescue the affected queries automatically. The watchdog ensures the failed realm's operator is notified within five minutes if the failure persists.

**Bounded silent dependency.** No realm can become silently dependent on its peers. The watchdog forces honest signaling: a realm whose local engine has been dead for five minutes stops federating and falls through to its visibly-degraded floor. This protects peer capacity from being unilaterally consumed and protects the operator from running blind.

These three properties hold for clusters of any size from two realms upward. The federation protocol does not change with cluster scale; what changes is the typical operating pattern and the capacity envelope.

---

## 2. Reference cluster topologies

Three topologies cover the range this paper addresses. Each topology specifies the realm count, the typical concurrent-user envelope, and the federation roles. All three use the same software; the differences are in hardware, networking, and operational practice.

### 2.1 Small office (2 realms)

```
            ┌──────────────────────────────┐
            │         Office LAN           │
            │                              │
            │   ┌────────────┐             │
            │   │  Realm A   │  ◄─────┐    │
            │   │  Primary   │        │    │
            │   │ Federator  │  Federation │
            │   └─────┬──────┘    LAN-only │
            │         │                │   │
            │         │ federation     │   │
            │         ▼                │   │
            │   ┌────────────┐         │   │
            │   │  Realm B   │  ◄──────┘   │
            │   │  Peer      │             │
            │   └────────────┘             │
            │                              │
            │   Staff browsers connect to  │
            │   either realm over WiFi/LAN │
            └──────────────────────────────┘
```

**Realm count:** 2
**Concurrent active users:** 4-15
**Hardware investment:** $2,000-$3,500
**Best for:** Small professional office, single location, primary cluster pattern for first-time deployers.

Realm A acts as both a member and the cluster's Federator (running the public Federator endpoint). Realm B is a pure member. Federation is LAN-only — neither realm needs an ngrok tunnel because the office uses them on the local network. This is the simplest possible cluster and the strongest privacy position.

If Realm A fails, Realm B continues to serve its own connected users normally, but no new federation advice is generated (the Federator is offline). When Realm A returns, the cluster heals automatically — Realm B's next check-in succeeds and federation resumes. For maximum availability, see Section 2.4 on dual-Federator topologies.

### 2.2 Multi-location professional firm (4-6 realms)

```
   ┌──────────────────┐        ┌──────────────────┐
   │   Office 1 LAN   │        │   Office 2 LAN   │
   │                  │        │                  │
   │   Realm A (Fed)  │        │   Realm C        │
   │   Realm B        │        │   Realm D        │
   │                  │        │                  │
   └────────┬─────────┘        └────────┬─────────┘
            │                           │
            │  Site-to-site VPN         │
            │     OR                    │
            │  Reserved ngrok tunnels   │
            │                           │
            └──────────┬────────────────┘
                       │
                       ▼
              Federation matrix
              spans both offices
```

**Realm count:** 4-6
**Concurrent active users:** 15-50
**Hardware investment:** $4,000-$8,000
**Best for:** Professional firm with 2-3 office locations, regional small business, multi-branch operations.

Each office has its own realms. The federation matrix spans both offices via either site-to-site VPN (preferred for privacy) or reserved ngrok tunnels. A realm in Office 1 can rescue a query in Office 2 and vice versa. Each office continues operating independently if the inter-office link fails — federation falls back to local-only at each site.

This is the natural growth path from the small-office topology. Operators who outgrow the small office add realms in the same office (vertical scale) until LAN topology becomes complex, then add a second office (horizontal scale).

### 2.3 Regional small enterprise (8+ realms)

**Realm count:** 8-20
**Concurrent active users:** 50-200
**Hardware investment:** $10,000-$30,000
**Best for:** Larger regional business, small enterprise with 3+ locations, organizations approaching the upper bound of what this architecture currently supports.

The architecture continues to work at this scale, but operational practice becomes more demanding. Operators at this scale should plan for: dedicated IT staff (one part-time administrator for every 4-6 realms), automated monitoring (operators should not rely on individual cockpit checks), formal change management for software updates, and **dual-Federator topology** (Section 2.4).

Section 12 honestly addresses where this scale starts pushing the architecture's current limits.

### 2.4 Dual-Federator topology (recommended for 4+ realms)

```
    Realm A (Federator 1, primary)
       │
       ├─── Realm C
       ├─── Realm D
       │
    Realm B (Federator 2, hot standby)
       │
       ├─── Realm E
       ├─── Realm F
```

For clusters of 4+ realms, two realms run the Federator role. Member realms check in with both. If Federator 1 is unreachable, members continue with the most recent peer advice from Federator 2. The federation continues to operate degraded but functional during a Federator failure.

This is the recommended topology for any production cluster of 4+ realms. The dual-Federator pattern is currently a configuration choice (two realms with `[Federator] enabled = true`); future versions may add a formal consensus protocol between Federators.

---

## 3. Hardware specifications

Hardware costs reflect realistic mid-2026 consumer market pricing in the US. Prices age — treat these as order-of-magnitude guidance.

### 3.1 Realm hardware tiers

| Tier | Use Case | CPU | RAM | GPU | Storage | Approx. Cost |
|---|---|---|---|---|---|---|
| **Starter** | 2-4 concurrent users | 6-core x64 | 16 GB DDR4 | NVIDIA RTX 4060 8GB | 500 GB NVMe | $900-$1,200 |
| **Standard** | 5-10 concurrent users | 8-core x64 | 32 GB DDR4 | NVIDIA RTX 4070 12GB | 1 TB NVMe | $1,500-$2,000 |
| **Heavy** | 10-20 concurrent users | 12-core x64 | 64 GB DDR5 | NVIDIA RTX 4080 16GB or RTX 5080 | 2 TB NVMe | $2,500-$3,500 |
| **Enterprise** | 20+ concurrent users / larger models | 16-core x64 | 128 GB DDR5 | NVIDIA RTX 4090 / 5090 24GB or workstation GPU | 4 TB NVMe | $5,000-$8,000 |

A cluster typically uses **the same tier** across all realms to keep capacity predictable. Mixed tiers work — the federation does not require uniform hardware — but capacity planning becomes more complex.

### 3.2 Recommended starter cluster (2-realm small office)

For a typical professional office:

- **2 × Standard-tier realms** at approximately $1,800 each = $3,600
- **1 × small UPS** (uninterruptible power supply) for each realm, approximately $150 each = $300
- **Existing office network** (gigabit switch, WiFi) — no additional cost in most cases
- **Existing office router/firewall** — no additional cost

**Total: approximately $3,900 for a 2-realm starter cluster.**

This is the realistic entry point. Operators reusing older office hardware can sometimes start at half that cost; operators requiring more headroom can comfortably spend twice that.

### 3.3 What the hardware actually buys

A Standard-tier realm running Llama 3.2 3B Instruct on an RTX 4070 typically delivers:

- **65-90 tokens/second** sustained single-stream generation
- **Voice query response time:** 5-10 seconds (model inference + TTS synthesis)
- **Single-threaded throughput:** 6-12 voice queries per minute
- **With TTS overlap and federation:** 15-25 queries per minute
- **Cold-start to wizard-ready:** under 60 seconds from power-on

A Heavy-tier realm running Llama 3.1 8B Instruct on an RTX 4080 delivers roughly:

- **40-55 tokens/second** sustained (larger model, more parameters per token)
- **Voice query response time:** 8-15 seconds
- **Quality improvement** over 3B-class models is noticeable on complex reasoning tasks

The trade-off between model size and throughput is the central capacity-planning decision. Section 7 develops this in detail.

---

## 4. Network architecture

The federation is **transport-agnostic** at the protocol level — it operates over any IP network. Three deployment patterns cover the realistic options.

### 4.1 LAN-only federation (recommended for single-site)

All realms reside on the same local network. Federation traffic never leaves the office. No ngrok tunnel is required. Browsers connect to realm cockpits via LAN IP addresses or DNS names resolved internally.

**Setup:** Set `[Federation] self_url` to the realm's LAN address (e.g., `http://192.168.1.50:9999`) for each realm. Configure both realms with the same `master_url` pointing at the Federator-role realm.

**Privacy posture:** Strongest. No federation traffic crosses any internet boundary. Voice queries and responses remain entirely within the office network.

**Limitations:** Remote staff (working from home, traveling) cannot reach the cluster without a VPN. The cluster cannot rescue another cluster's queries (no inter-organization federation).

### 4.2 LAN federation with remote staff access

The federation operates LAN-only. A separate ngrok tunnel (or reverse proxy) exposes one or more realm cockpits to remote staff. Remote users authenticate to the tunnel; federation between realms stays internal.

**Setup:** Same as 4.1 for federation. Additionally, run `ngrok http --url=officename.ngrok.app 9999` (or equivalent reverse proxy) on the realm that should be remotely accessible.

**Privacy posture:** Strong. Federation stays local. Only the remote-facing cockpit endpoints are exposed externally.

**Recommended for:** Most professional offices with occasional remote workers.

### 4.3 Multi-site federation

Two or more office LANs are connected via site-to-site VPN, and the federation matrix spans all sites. Each office's realms can rescue queries from other offices' realms.

**Setup:** Configure each realm's `self_url` to its VPN-routable address. All realms point at the same Federator-role realm. The site-to-site VPN handles encryption and routing.

**Privacy posture:** Strong, assuming the VPN is properly configured. Federation traffic is encrypted in transit.

**Limitations:** Inter-site bandwidth and latency now matter — federation rescue calls add the inter-site round-trip to the user's perceived latency. Plan for at least 25 Mbps symmetric between sites and round-trip latencies under 50 ms.

---

## 5. Deployment procedure

The following procedure stands up a 2-realm small-office cluster from scratch. It is intended for an IT operator who has read the Quick Start Guide. Total time: approximately 90 minutes for an experienced operator, half a day for first-time deployers.

### Step 1 — Procure and prepare hardware

Order or assemble two Standard-tier machines. Install Windows 11 on each. Apply current updates. Verify each has an active wired Ethernet connection (avoid WiFi for realm hardware — federation traffic deserves wire-speed latency).

Assign each realm a static IP address (e.g., 192.168.1.50 for Realm A, 192.168.1.51 for Realm B). The realms must have stable, predictable addresses; DHCP-assigned addresses are not appropriate for federation members.

### Step 2 — Install dependencies on both realms

On each realm in turn:

1. Install NVIDIA drivers; verify with `nvidia-smi`
2. Install GPT4All from gpt4all.io
3. Download a model in GPT4All (recommended: Llama 3.2 3B Instruct for Standard tier; Llama 3.1 8B Instruct for Heavy/Enterprise tier)
4. Enable the GPT4All Local Server (Settings → Application → Enable Local Server)
5. Install the **KOKORO RENT-A-HAL VOICE Microservice**
6. Install **RENT-A-HAL SOHO Multi-User '26**

### Step 3 — Configure Realm A (Federator + member)

Launch the wizard on Realm A. In the wizard form:

- **Realm name:** Choose a descriptive name (e.g., "Office-Realm-1")
- **Tagline:** Your office or department name
- **Federation: participate** — On
- **Federator URL:** `http://192.168.1.50:9999/api/federate`
- **Your public realm URL:** `http://192.168.1.50:9999`
- **All other fields:** Defaults

Edit `federation.ini` on Realm A to enable the Federator role:

```ini
[Federator]
enabled = true
```

Save and click GO in the wizard. Verify the cockpit comes up at `http://192.168.1.50:9999`.

### Step 4 — Configure Realm B (member only)

Launch the wizard on Realm B. In the wizard form:

- **Realm name:** "Office-Realm-2"
- **Federation: participate** — On
- **Federator URL:** `http://192.168.1.50:9999/api/federate` (Realm A's Federator)
- **Your public realm URL:** `http://192.168.1.51:9999`
- **All other fields:** Defaults

Click GO. Verify the cockpit at `http://192.168.1.51:9999`.

### Step 5 — Verify federation

After approximately 15 seconds, the cockpit of each realm should show:

```
Fed: ON · Master: 192.168.1.50 · State: HEALTHY · (LLM→<peer>, TTS→<peer>)
```

If both realms show HEALTHY and recommend each other as peers, the federation is operational.

### Step 6 — Validate end-to-end

From any browser on the office network, visit `http://192.168.1.50:9999` and ask a query. Verify a spoken answer is produced.

Repeat from `http://192.168.1.51:9999`. Both realms should serve queries independently.

For federation rescue verification, deliberately stop GPT4All on Realm A. Ask a query at Realm A's cockpit. After the pre-flight probe times out, the query should be rescued by Realm B and answered. Restart GPT4All on Realm A; the next query should return to local serving.

### Step 7 — Document the deployment

Record the following in your IT documentation:

- Realm IP addresses
- Realm hardware specifications
- Model selection per realm
- Federation configuration values
- Backup/restore procedure for `config.ini`, `federation.ini`, and any operator notes

---

## 6. Capacity planning

This section provides the math operators can use to size their cluster against their actual workload. The numbers are illustrative; substitute your own measurements for production planning.

### 6.1 Per-realm capacity baseline

A Standard-tier realm (RTX 4070, Llama 3.2 3B Instruct) sustains the following under typical voice workloads:

| Metric | Value | Notes |
|---|---|---|
| Tokens/second (generation) | 65-90 | Single-stream, post-prompt |
| Average response length | 200-500 tokens | Varies by query complexity |
| Average inference time | 4-8 seconds | Per query |
| Average TTS synthesis time | 2-4 seconds | Kokoro at 1.0 speed |
| Total per-query latency | 6-12 seconds | User speaks → user hears response |
| Sustained queries per minute (sequential) | 5-10 | Single user, back-to-back |
| Sustained queries per minute (with overlap) | 12-20 | TTS of query N while inferring query N+1 |

### 6.2 User-to-capacity ratio

In typical professional office workloads, a single active user does not generate sustained back-to-back queries. The empirical ratio is approximately:

- **A "concurrent active user"** generates roughly **1 query every 60-180 seconds** while actively using the realm
- **A "concurrent passive user"** (cockpit open, querying occasionally) generates roughly **1 query every 5-10 minutes**

This produces the following sizing rules of thumb:

| Use pattern | Queries/min per user | Users per Standard realm |
|---|---|---|
| Heavy active (research, drafting) | 0.5-1.0 | 8-15 |
| Typical office (Q&A, lookups) | 0.2-0.5 | 15-30 |
| Light/passive | 0.1-0.2 | 30-60 |

A typical professional office with 12 staff would size for ~15-30 typical-office concurrent users, suggesting **a single Standard realm could handle the load** under steady-state conditions. The reason to deploy 2 realms anyway is **redundancy and burst capacity**, not steady-state throughput.

### 6.3 The redundancy multiplier

A 2-realm cluster does not provide 2x capacity for burst loads — it provides 2x capacity **plus** the ability for either realm to absorb the other's load during a failure. The honest framing is:

- **Steady-state capacity:** 2x single realm (each realm serves its own users)
- **Burst capacity:** Up to 2x single realm (federation routes overflow)
- **Failure tolerance:** 1 realm can be down indefinitely while the other continues to serve all users (with watchdog signaling on the dead realm)
- **Operational confidence:** Major (one realm can be taken offline for maintenance without service interruption)

### 6.4 Capacity-planning worksheet

For your own organization:

1. **N_users** = peak concurrent active staff using the realm
2. **Q_user** = queries per minute per active user (estimate 0.3 for typical office)
3. **N_queries_per_min** = N_users × Q_user
4. **R_capacity** = realm capacity from Section 6.1 (typically 12-20 queries/min Standard tier)
5. **N_realms_min** = ceiling(N_queries_per_min / R_capacity) — the minimum cluster size for steady-state load
6. **N_realms_recommended** = N_realms_min + 1 — add one realm for redundancy

A 10-person law firm with 5 concurrent users at 0.4 queries/minute = 2 queries/min. Single Standard realm handles this comfortably. **Recommended: 2 realms** for redundancy.

A 25-person consulting firm with 15 concurrent users at 0.4 queries/minute = 6 queries/min. **Recommended: 2 realms** (still under capacity, but add one for redundancy).

A 60-person organization with 35 concurrent users at 0.3 queries/minute = 10.5 queries/min. **Recommended: 3 realms** (one realm could nominally handle the load, but federation overhead and headroom argue for 3).

A 150-person organization with 80 concurrent users at 0.3 queries/minute = 24 queries/min. **Recommended: 4-6 realms.** This is the upper bound of what this paper addresses confidently.

---

## 7. Concrete use case profiles

The following profiles describe realistic deployments. Each is plausible — operators with similar profiles have already deployed comparable architectures.

### 7.1 Small law firm (4-12 attorneys)

**Hardware:** 2 Standard-tier realms
**Use cases:** Document drafting, deposition summary, legal research Q&A, client communication drafts, internal knowledge base
**Why local matters:** Client confidentiality. Communications and documents cannot legally be transmitted to OpenAI, Anthropic, or Google for non-trivial workflows in many jurisdictions. The realm runs on the firm's own hardware, behind the firm's own firewall, and no client data leaves the office.
**Federation benefit:** Redundancy. Lawyers cannot afford "the AI is down today" during deposition prep.
**Realistic monthly cost:** Electricity only, approximately $30-$60.

### 7.2 Dental or medical office (5-15 staff)

**Hardware:** 2 Standard-tier realms
**Use cases:** Patient intake question Q&A, appointment scheduling assistance, billing query support, insurance verification scripts, internal protocol lookups
**Why local matters:** HIPAA. Protected Health Information cannot be transmitted to cloud AI services without a Business Associate Agreement, which most consumer-grade cloud AIs do not offer.
**Federation benefit:** Redundancy and capacity sharing during busy clinic hours.
**Realistic monthly cost:** $30-$60.

### 7.3 Accounting firm (4-20 staff)

**Hardware:** 2-3 Standard-tier realms
**Use cases:** Tax law Q&A, internal procedure lookup, client communication drafts, document summary, training Q&A for junior staff
**Why local matters:** Client financial data confidentiality. Many accounting workflows fall under SOX, GLBA, or state-level requirements that resist cloud AI by default.
**Federation benefit:** Tax season burst capacity. The firm scales from 5 to 25 active users in March-April; federation pools capacity across realms during the spike.
**Realistic monthly cost:** $50-$100.

### 7.4 Mental health practice (3-10 clinicians)

**Hardware:** 2 Standard-tier realms (or one Standard + one Starter)
**Use cases:** Session note assistance, treatment plan drafts, billing code lookup, internal training Q&A
**Why local matters:** Therapy notes are among the most sensitive data categories. HIPAA + state mental health confidentiality laws preclude any cloud transmission. **This is the strongest case for local-first voice AI.**
**Federation benefit:** Modest redundancy. Clinics typically have one or two clinicians using the realm at a time.
**Realistic monthly cost:** $30-$50.

### 7.5 Real estate agency (10-40 agents)

**Hardware:** 2-4 Standard-tier realms
**Use cases:** Listing description drafting, contract summary, MLS query support, client communication drafts, market analysis Q&A
**Why local matters:** Client purchase records, financial details, and negotiating positions are confidential. Federation enables remote-agent access via ngrok while keeping the underlying engines on-premises.
**Federation benefit:** Capacity sharing across agents who use the realm in bursts (typically before or after client meetings).
**Realistic monthly cost:** $60-$100.

### 7.6 Small consultancy (5-20 consultants)

**Hardware:** 2-3 Standard or Heavy-tier realms
**Use cases:** Proposal drafting, internal knowledge base, client deliverable review, market research Q&A
**Why local matters:** Client IP and pre-publication research. Consulting firms sign NDAs that often preclude transmitting client materials to third-party AI services.
**Federation benefit:** Burst capacity during proposal-writing crunches.
**Realistic monthly cost:** $60-$120.

### 7.7 School / library / community center (variable)

**Hardware:** 1-2 Starter or Standard-tier realms
**Use cases:** Student Q&A, homework help (with appropriate teacher oversight), reference Q&A, language practice, accessibility support
**Why local matters:** Student privacy. Schools serving minors face significant regulatory hurdles for cloud AI use (COPPA, FERPA, state-level student privacy laws).
**Federation benefit:** Modest. Many schools start with one realm and add a second only when load justifies it.
**Realistic monthly cost:** $20-$50.

---

## 8. Privacy and compliance posture

For organizations evaluating RENT-A-HAL specifically for privacy or compliance reasons, the following points summarize the architecture's actual properties (rather than aspirational claims).

### What the architecture provides

- **Conversations never leave the local network** when federation is LAN-only and ngrok is not used. Audio is processed browser-side (speech recognition via Chrome/Edge's local APIs); only text is transmitted to the realm. Responses (text + audio) are transmitted back to the browser over the local network.
- **No conversation logging by default.** The realm produces operational logs (queries served, federation events, errors) but does not record conversation content. Operators may enable conversation logging deliberately if their workflow requires it.
- **No training on user data.** The realm uses pre-trained models from upstream providers (GPT4All bundled models, Kokoro voices). User queries and responses are not transmitted back to those providers and do not contribute to any training corpus.
- **Operator controls all data retention.** Logs are local files. The operator decides retention period, backup policy, and deletion timing.

### What the architecture does not provide

- **No formal compliance certifications.** RENT-A-HAL is not HIPAA-certified, SOC 2-audited, or ISO 27001-certified. Organizations requiring those certifications need to either: build the compliance program around their RENT-A-HAL deployment themselves (entirely feasible — the architecture supports it but does not produce the documentation), or use a vendor whose offering is already certified.
- **No built-in audit trails.** The realm logs operational events but does not produce the structured audit records required by some compliance frameworks. This is a Section 12 limitation.
- **No identity management.** All users connecting to the realm cockpit are anonymous from the realm's perspective. Organizations requiring per-user accountability need to layer identity (SSO, VPN-gated access) externally.
- **No transport encryption by default.** LAN-only federation runs over HTTP. Operators requiring TLS for federation traffic must configure HTTPS termination at each realm (reverse proxy or stunnel) themselves.

### The honest summary

RENT-A-HAL provides a **strong privacy floor**: conversations stay local, no vendor sees the data, no training corpus accumulates. It does **not** provide a complete compliance framework. For organizations with serious compliance requirements, the architecture supports building that framework on top of it, but the organization will have to do the building.

---

## 9. Operational concerns

### 9.1 Monitoring

The realm cockpit is the primary operational dashboard. The federation strip displays HEALTHY/DEGRADED status in real time. The query log records every event with provider attribution. The watchdog (Section 5.3 of the white paper) ensures degraded states are surfaced to the operator within 5 minutes.

For multi-realm clusters, operators should establish a routine check of each cockpit (daily or weekly depending on workload). The cockpit's per-query badge attribution makes it immediately visible whether queries are being served locally or federated.

External monitoring (Nagios, Prometheus, etc.) can poll the realm's `/health` endpoint and the federation matrix endpoint. This is appropriate for clusters of 4+ realms.

### 9.2 Updates

Each realm runs independently and can be updated independently. A typical update procedure:

1. Choose one realm at a time (begin with the smallest-traffic realm)
2. HALT the realm via the wizard
3. Back up `config.ini`, `federation.ini`, and any operator notes
4. Run the new installer
5. Re-launch via the wizard
6. Verify the cockpit, federation health, and a test query
7. Wait 15-30 minutes; verify the cluster federation matrix shows the upgraded realm healthy
8. Proceed to the next realm

The federation is wire-compatible across recent revisions (the hot-patch deployment doc explicitly addresses this), so a partial cluster with mixed versions operates correctly during the update window.

### 9.3 Backup

The state that matters for backup:

- `config.ini` — realm configuration (small, change rarely)
- `federation.ini` — federation configuration (small, change rarely)
- `federation_state.json` — federation matrix snapshot (regenerates on Federator restart)
- Operator notes / runbooks — outside the realm software, organization-specific

The realm does not maintain a database. There is no per-user history file. The realm is genuinely stateless beyond configuration. **Daily backup of `config.ini` and `federation.ini` is sufficient.**

### 9.4 The watchdog as an operational feature

The wall-clock degraded watchdog (Section 5.3 of the white paper) is not just a self-healing mechanism — it is an operational feature for businesses. It guarantees that a dead local engine cannot silently consume peer capacity for hours or days; it forces the failure to surface within 5 minutes. For an IT operator managing the cluster, this is the equivalent of a "service is degraded" alert built into the architecture, not bolted on as external monitoring.

---

## 10. Scale up versus scale out

A practical decision operators face: when load increases, **upgrade existing realms** (scale up) or **add more realms** (scale out)?

### When to scale up

- Current realm count provides adequate redundancy (2+ realms) and growth is modest
- A single class of users needs heavier model capability (e.g., switching from 3B to 8B model)
- Per-realm latency is the bottleneck, not throughput
- IT operations are at capacity managing the current realm count
- Budget for a one-time hardware refresh is available

### When to scale out

- Current realms are at sustained 60%+ utilization
- Geographic distribution would benefit (a second office)
- Higher redundancy is needed (3+ realms means one can be down without urgency)
- Multiple workload types need separation (e.g., dedicated realm for one department)
- Federation capacity sharing would benefit from more peer options

**The general principle:** Scale up to handle qualitative changes (better model, more headroom); scale out to handle quantitative changes (more users, more locations, more redundancy).

---

## 11. The cost comparison

For a 20-person organization considering RENT-A-HAL versus cloud AI subscriptions:

| Option | Year 1 cost | Year 3 cost | Year 5 cost |
|---|---|---|---|
| **2-realm RENT-A-HAL cluster** | $3,900 hardware + ~$500 electricity = **$4,400** | + ~$1,000 electricity = **$5,400** | + ~$1,500 electricity = **$6,900** (+ possible $2,000 hardware refresh year 4 = $8,900) |
| **20 × ChatGPT Plus subscriptions** | 20 × $20 × 12 = **$4,800/year** | **$14,400** | **$24,000** |
| **20 × Alexa+ subscriptions** | 20 × $20 × 12 = **$4,800/year** (or free with Prime) | **$14,400** | **$24,000** |
| **Hybrid (mixed cloud + local)** | Variable | Variable | Variable |

**Year 1 break-even** is approximately equal between RENT-A-HAL and 20 cloud subscriptions. **By year 3**, RENT-A-HAL is roughly $9,000 cheaper. **By year 5**, RENT-A-HAL is approximately $15,000-$17,000 cheaper.

These numbers exclude:

- **Operator time** for maintaining RENT-A-HAL (variable; typically 4-12 hours/month for a small cluster)
- **Cloud subscription tier upgrades** that may occur over 3-5 years
- **Productivity gains** from either option (both options produce them; not a differentiator)
- **Compliance value** of local-first architecture (substantial for regulated industries, hard to monetize directly)

For organizations where cloud AI is workflow-blocked by compliance requirements, the cost comparison is not the deciding factor — local-first is the only viable path.

---

## 12. Where the architecture would need additional work

In keeping with the honest framing throughout the RENT-A-HAL documentation set, this paper names what the architecture does **not** currently provide at the upper end of the scales it addresses.

### For clusters approaching 8+ realms or 50+ concurrent users

- **No centralized identity management.** Operators must layer SSO, LDAP, or VPN-gated access externally.
- **No formal audit trail format.** Operational logs exist but are not structured for compliance audit consumption.
- **No automated alerting infrastructure.** The watchdog surfaces degraded states in the cockpit but does not page operators externally. Operators wanting paging must implement it via the cockpit's status API and external monitoring tools.
- **No formal consensus protocol between Federators.** Dual-Federator topology works but relies on configuration, not protocol-level consensus. A Federator split-brain scenario is theoretically possible but has not been observed in production.
- **No per-user quotas or rate limiting.** Any browser connecting to a realm can issue queries at the realm's full capacity. Quota enforcement at the cluster level is not currently implemented.
- **No model-aware routing.** Federation does not currently consider which model each peer has loaded when recommending peers. A cluster with mixed models (some 3B, some 8B) will federate queries to whichever peer is least loaded, not to whichever has the appropriate model.

### For department-scale or enterprise deployments (50+ users)

Beyond the issues above, the following become operational concerns:

- **Software lifecycle management** across many realms — manual update procedure scales poorly past ~8 realms
- **Configuration drift** between realms — no central configuration management
- **No realm-to-realm secret management** — federation tokens are configured per-realm
- **No native containerization or Kubernetes support** — realms are designed for Windows-installer deployment, not orchestrated infrastructure

Organizations needing any of the above should treat RENT-A-HAL as the **foundation** of their solution and plan to add the missing layers themselves, or evaluate whether a different architecture better fits their scale.

---

## 13. Summary recommendations

For decision-makers reading this paper:

**If your organization has 2-20 staff** and either privacy/compliance requirements or substantial AI workload (10+ queries per active user per week), a **2-realm small-office cluster** is the realistic starting point. Total investment under $4,000. Time to deploy: half a day. Ongoing cost: electricity.

**If your organization has 20-50 staff** distributed across 2-3 locations, a **4-realm multi-location cluster** is the next step. Total investment $6,000-$10,000. Time to deploy: 2-3 days. Ongoing cost: electricity plus modest IT operations time.

**If your organization has 50+ staff or formal compliance/audit requirements**, plan to deploy a starter cluster (Section 2.1) to validate the architecture against your actual workload, then plan a phased expansion with the architectural additions described in Section 12 implemented incrementally.

**If your organization does not require local-first** and cloud AI subscriptions fit your privacy posture, **the cost difference is not large enough to justify RENT-A-HAL on cost grounds alone.** The decision should be based on privacy, compliance, vendor independence, and operational philosophy — not on saving money.

---

## 14. References

| Document | Audience | Purpose |
|---|---|---|
| **RENT-A-HAL Quick Start Guide** | First-time operators | Single-realm installation procedure |
| **MTOR Federation White Paper** | Engineers | Technical architecture details |
| **What Makes RENT-A-HAL Different** | Evaluators | Comparison against alternatives |
| **RENT-A-HAL Operator's Manual** | Active operators | Day-to-day operations |
| **Source Code Repository** | Engineers | Full implementation |

---

*This paper reflects the v1.0 architecture and 2026 market conditions. Future revisions will update both the architecture-specific guidance and the cost comparisons as the landscape evolves.*

🖖 Live long and prosper.
