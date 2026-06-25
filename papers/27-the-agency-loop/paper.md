---
type: paper-bite
title: "The agency loop: a model that tidies its own memory between turns, on a heartbeat"
description: "Shannon-Prime release series, paper 27."
tags: [paper-bite, agency, kairos, heartbeat, memory, harness]
timestamp: 2026-06-25T00:00:00Z
resource: ./papers/27-the-agency-loop/paper.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# The agency loop: a model that tidies its own memory between turns, on a heartbeat

*Shannon-Prime release series, paper 27. Discipline: [METHODOLOGY.md](../../METHODOLOGY.md).
Every number below is a row in [LEDGER.md](../../LEDGER.md) with a command behind it.*

> **Front-door receipt (2026-06-25, ledger X-AGENCY-LOOP).** Papers 25 and 26 gave the model authority over
> its memory and the tools to act through. This paper closes the loop: the model does memory work **between
> turns**, not just *stop*. An **agency round** shows the model its own memory *and* the curation tools (the
> memory-as-tools of §1) and lets it decide what to forget or consolidate — and a **heartbeat scheduler**
> (KAIROS) fires that round on a tick, **idle-gated** so it backs off while the daemon is generating and
> never starves a live turn. **G-HARNESS-MEMTOOLS-E2E** (H3): the model calls `list_memories` and recites
> the *real* facts (after a verbatim-use rule killed a confabulation). **G-HARNESS-AGENCY-E2E** (H4): shown
> a redundant pair — "has a dog" + "has a dog named Rex" — the model **forgot the vague subsumed fact** and
> kept the specific one (3 → 2 memories, "memory is healthy"). The "auto rounds" become where the organism
> *acts*.

## 1. Memory as tools — so the model can reach its own store

The agency loop needs one thing the recall head (paper 24) and the daemon-side agency (paper 25) did not
give the model: the ability to *operate on its memory through the tool protocol* — to list it, add to it,
and remove from it, the same way it calls `calculate` or `run_python` (paper 26).

`harness/skills/memory.py` exposes exactly that, over the daemon's persistent registry
(`SP_RECALL_REGISTRY`), as three ephemeral tools:

- **`list_memories()`** — return the current facts.
- **`remember(text)`** — mint a recallable episode (via the daemon's `POST /v1/capture` when reachable, else
  a registry line) — and **idempotent** (dedup on text), so the model cannot duplicate a fact it already has.
- **`forget(text)`** — remove a fact (the host-side mirror of paper 25's LAYER-2 forget).

**G-HARNESS-MEMTOOLS-E2E (H3)** proves the cycle. The direct path is clean —
list → remember → list → forget → list round-trips correctly. The *model* path is where the recurring
lesson bit: asked to recall via the tool, the model first **confabulated** — it substituted a generic
"User / blue / pizza" for the real tool result instead of reading it. The fix is the same family as paper
25's detection-not-decision and paper 26's grounding patch: a **verbatim-use preamble** — "base your answer
ONLY on the tool result, quote the EXACT values, never invent or substitute." With that rule, the model
calls `list_memories` and recites the **real** facts (Knack; teal). The idempotent `remember` is load-bearing
here too — without it the model duplicates a fact on a curation round (the agency must not pollute the store
it is curating, the same theme as paper 25's admission gate).

## 2. The agency round — the organism acts, instead of stopping

`harness/control/agency.py` composes the two prior layers into a single round. `agency_round` shows the
model **its own memory** (via `list_memories`) **and** the curation tools (`remember` / `forget`), inside the
`run_with_tools` loop (paper 26), and lets it **decide for itself** what to forget or consolidate. It is the
tool-calling loop pointed inward — the tools operate on the agent's own state.

**G-HARNESS-AGENCY-E2E (H4)**, on the served 12B: the registry holds a redundant pair — "has a dog" and "has
a dog named Rex" — plus an unrelated fact. The model, shown its memory and the tools, **forgot the vague
subsumed fact** ("has a dog") and **kept the specific one** ("has a dog named Rex") *and* the unrelated fact
— 3 memories → 2, and it reports "memory is healthy." The consolidation is the model's: it judged that the
specific fact subsumes the vague one and removed the redundancy *on its own*, through the same tool protocol
it uses for arithmetic.

This is the structural payoff of papers 25 and 26 together. Paper 25 gave the daemon-side agency (forget /
decide / merge fired *reactively*, on a capturing turn). Paper 26 gave the text-protocol tools. The agency
*round* is the model **proactively** curating — not in response to a conflicting statement, but as a
deliberate maintenance pass over its whole store. The same `forget` the user triggers in paper 25, the model
now triggers in itself, between turns.

## 3. The heartbeat — KAIROS fires the round, idle-gated

A maintenance round the model can run is not yet an organism that *maintains itself*; something has to fire
the round on its own. That is **KAIROS** — the heartbeat / agency tick.

The control plane lives on both sides of the seam. On the engine side, `kairos.rs` is the resident daemon's
tick control plane (currently a deterministic stub — no model call). The **model-driven realization** is the
harness scheduler, `run_agency_scheduler`: on each tick it calls `agency_round` — but **idle-gated.**

> The scheduler backs off while the daemon is generating, so the agency round **never starves a live turn.**

This is the whole discipline of the heartbeat. A naïve timer would fire `agency_round` mid-generation, queue
behind the resident-cache mutex, and slow the user's live turn (or worse, contend with it). The idle gate
makes the maintenance work happen *in the gaps* — the auto rounds fire when the organism is *not* answering,
which is exactly when it should be tidying up. The cadence is `SP_AGENCY_INTERVAL`; the conversation to
consolidate is handed in through `SP_CURRENT_CONVO` — the daemon writes each turn's conversation to disk (the
consolidation hook, KEYSTONE §6), and the scheduler's tick picks it up. The loop closes with **zero manual
steps**: the daemon writes, the heartbeat consolidates.

So the "auto rounds" — the ticks between user turns — stop being dead air and become **where the organism
acts.** It is the difference between a model that *stops* after answering and one that, in the quiet between
answers, reads its own memory and tidies it.

## 4. What the heartbeat completes (and what it doesn't, yet)

With the heartbeat wired, the full memory lifecycle of KEYSTONE closes autonomously: a turn is captured
(STORE, paper 25 §2), the daemon writes the conversation to disk, and on an idle tick the scheduler
consolidates it — facts into the mid tier, the transcript into the long MEM-OKF tier (KEYSTONE §5) — then
runs a **maintenance round** where the model curates its own memory (forget / consolidate, §2). No operator
in the loop.

Honest about the seam: the **substance** is proven (H3 memory-as-tools, H4 the agency round) and the
**scheduler** is the harness realization that fires it idle-gated. The engine-side `kairos.rs` tick remains a
deterministic stub — the remaining wiring is to call `agency_round` from the Rust heartbeat itself (rather
than the harness scheduler) so the daemon's own tick drives the model-call. The agency *substance* does not
wait on that; it is the harness scheduler that makes the rounds fire on a schedule today.

## 5. The thesis: agency is what happens between turns

The whole organism, read as one claim, is that a language model can be more than a turn-taking responder. It
can *own* a memory (paper 25), *act* through tools (paper 26), and — this paper — **do work on its own state
in the quiet between turns**, on a heartbeat, without being asked. The auto rounds are not overhead; they are
where the agency lives.

And the discipline that makes it safe is the same throughout: the heartbeat is **idle-gated** (it yields to
the user), the curation tools are **idempotent** and **admission-gated** (the agency does not pollute what it
curates), and the model's curation verdict is *its own* (the trigger schedules, the model decides). The
recurring lesson holds one more time: the model leans on its parametric prior over grounding — it confabulated
its own memory until a verbatim-use rule pointed it at the tool result (§1). Point the model at the
grounding, schedule the work for the gaps, and let it hold the verdict.

## 6. Honest scope

- **Proof-of-mechanism.** Single host (RTX 2060), single model (Gemma-4-12B B1 / OK_Q4B, paper 06). H3/H4
  are end-to-end gates on small registries, not a long-horizon autonomy study.
- **The KAIROS engine tick is a stub.** The model-driven round is fired by the *harness* scheduler
  (`run_agency_scheduler`, idle-gated); the engine `kairos.rs` tick is still a deterministic stub. Calling
  `agency_round` from the Rust heartbeat itself is the remaining wiring (§4), not yet built.
- **Grounding needs a prompt patch.** The model confabulates its own memory without the verbatim-use rule
  (§1) — a patch, not a structural guarantee.
- **Idle-gating is the safety property, and it is a heuristic.** The scheduler backs off while generating; it
  is a cadence + idle check, not a hard real-time scheduler.
- **Host-side, no frozen change.** The memory tools, the round, and the scheduler are all harness (Python)
  over the daemon's `POST /v1/chat` + `/v1/capture`; **no frozen-ABI change, no `.sp-model` change.**

## 7. Reproduction

Every number above is a row in [`LEDGER.md`](../../LEDGER.md) (`X-AGENCY-LOOP`: H3 / H4) with model, fixture,
and commit attached. The harness is
[shannon-prime-harness](https://github.com/nihilistau/the-clockwork-dark); the tests run on the Windows host
(reaching the daemon at :3000), launched detached and polled from a log.

| Gate | Driver | Expected | Receipt log |
|---|---|---|---|
| G-HARNESS-MEMTOOLS-E2E (H3) | `tests/g_memory_tools_e2e.py` (`skills/memory.py` over `SP_RECALL_REGISTRY`) | direct cycle clean (list → remember → list → forget → list); the **model** calls `list_memories` and recites the **real** facts (Knack; teal) — after a verbatim-use preamble killed the initial confabulation (generic User/blue/pizza); `remember` idempotent | (harness `8e855ca`) |
| G-HARNESS-AGENCY-E2E (H4) | `tests/g_agency_loop_e2e.py` (`control/agency.py` `agency_round` = H2 tools + H3 memory) | shown "has a dog" + "has a dog named Rex" + an unrelated fact, the model **forgets the vague subsumed fact**, keeps the specific + unrelated (3 → 2, "memory is healthy"); idempotent `remember` prevents self-duplication | (harness `71873bb`) |

**Commit hashes.** Memory-as-tools (H3) is harness `8e855ca`; the agency round (H4) is `71873bb`. The
memory tools are `harness/skills/memory.py`; the round is `harness/control/agency.py`
(`agency_round` / `run_agency_scheduler` / `consolidate_current`); the engine-side tick stub is
`kairos.rs`; the consolidation hook is `SP_CURRENT_CONVO` (daemon writes the turn) + the harness scheduler's
idle-gated tick (`SP_AGENCY_INTERVAL`). The served console is `frontend_mockups/index.html` (the GUI lever
fix, engine `d1e4bba`). No frozen-ABI / `.sp-model` change. Architecture: lattice
`papers/PPT-LAT-KEYSTONE.md` §4/§6 + memory `project_harness_toolcalling`.

## Receipts

| Row | Receipt |
|---|---|
| X-AGENCY-MEMTOOLS | Memory as tools — the model reaches its own store through the text protocol. `skills/memory.py`: `list_memories` / `remember` (idempotent, via `/v1/capture` or a registry line) / `forget`, over `SP_RECALL_REGISTRY`. **G-HARNESS-MEMTOOLS-E2E (H3):** direct cycle clean; the model calls `list_memories` and recites the **real** facts (Knack; teal) — after a **verbatim-use** preamble ("answer ONLY from the tool result, quote EXACT values, never substitute") killed an initial confabulation (generic User/blue/pizza). Idempotent `remember` prevents self-duplication. Gemma-4-12B B1, RTX 2060; host-side, no frozen-ABI / `.sp-model` change. **Measured + gated — LIVE.** |
| X-AGENCY-LOOP | The model does memory work **between turns**, on a heartbeat. `agency_round` (`control/agency.py`) shows the model its memory + the curation tools and lets it decide what to forget/consolidate (the H2 tool loop pointed inward); `run_agency_scheduler` fires it on a tick, **idle-gated** so it backs off while the daemon is generating and never starves a live turn. **G-HARNESS-AGENCY-E2E (H4):** "has a dog" + "has a dog named Rex" → the model **forgets the vague subsumed fact**, keeps the specific + unrelated (3 → 2, "memory is healthy"). The consolidation hook (`SP_CURRENT_CONVO` daemon-write → idle-tick consolidate) closes the lifecycle with zero manual steps. The "auto rounds" become where the organism acts. Honest: the engine `kairos.rs` tick is still a deterministic stub — the model-driven round is fired by the harness scheduler (the agency *substance* is proven; calling it from the Rust heartbeat itself is the remaining wiring). **Measured + gated — LIVE.** |

Companions: paper 25 / X-AGENCY (the daemon-side forget/decide/merge this loop fires *proactively*, between
turns), paper 26 / X-HARNESS-TOOLS (the text-protocol tool loop the round runs inside), paper 24 / X-B3-WC
(the recall the curated memory feeds), paper 09 / KAIROS (the resident daemon + rewind the heartbeat sits on),
paper 14 / X-R3VSA (the memory tier the rounds consolidate into). The boundary it draws: **agency is what
happens between turns** — a model that owns its memory (25), acts through tools (26), and tidies its own state
on an idle heartbeat (here), default-off, byte-exact when off.
