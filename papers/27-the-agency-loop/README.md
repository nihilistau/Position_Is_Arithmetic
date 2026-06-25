---
type: paper-bite
title: "27 — The agency loop: a model that tidies its own memory between turns, on a heartbeat *(written, citable — X-AGENCY-LOOP)*"
description: "An agency round shows the model its memory + the curation tools and lets it forget/consolidate on its own; a KAIROS heartbeat fires it idle-gated, so the auto rounds become where the organism acts."
tags: [paper-bite, agency, kairos, heartbeat, memory, harness]
timestamp: 2026-06-25T00:00:00Z
resource: ./papers/27-the-agency-loop/README.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# 27 — The agency loop: a model that tidies its own memory between turns, on a heartbeat *(written, citable — X-AGENCY-LOOP)*

> **STATUS: written — front-door complete, LIVE on the served 12B.** The closing layer of KEYSTONE (ledger
> **X-AGENCY-LOOP**): the model does memory work *between* turns — not just stop — and a heartbeat fires that
> work on a tick, idle-gated so it never starves a live turn.

> **Front-door (2026-06-25):** Papers 25 and 26 gave the model authority over its memory and the tools to act
> through. This paper closes the loop: an agency round + a KAIROS heartbeat turn the quiet between turns into
> where the organism *acts*.

## The claim this paper makes

On the served 12B, in the harness ([shannon-prime-harness](https://github.com/nihilistau/the-clockwork-dark)):

- **Memory as tools** — `skills/memory.py`: `list_memories` / `remember` (idempotent) / `forget` over
  `SP_RECALL_REGISTRY`. **G-HARNESS-MEMTOOLS-E2E (H3):** the model calls `list_memories` and recites the
  **real** facts (Knack; teal) — after a verbatim-use rule killed an initial confabulation.
- **The agency round** — `agency_round` shows the model its memory + the curation tools (the H2 tool loop
  pointed inward) and lets it decide. **G-HARNESS-AGENCY-E2E (H4):** "has a dog" + "has a dog named Rex" →
  the model **forgets the vague subsumed fact**, keeps the specific (3 → 2, "memory is healthy").
- **The heartbeat** — `run_agency_scheduler` fires the round on a KAIROS tick, **idle-gated** (it backs off
  while the daemon is generating, never starving a live turn). The consolidation hook (`SP_CURRENT_CONVO`
  daemon-write → idle-tick consolidate) closes the lifecycle with zero manual steps.

The thesis: **agency is what happens between turns** — the auto rounds become where the organism acts.

## What's in it (the map)

1. **Memory as tools** — the model reaches its own store; the confabulation + verbatim-use fix; idempotent `remember`.
2. **The agency round** — the model proactively curates (3 → 2 redundant pair); the tool loop pointed inward.
3. **The heartbeat** — KAIROS fires the round idle-gated, so it never starves a live turn; the consolidation hook.
4. **What the heartbeat completes** — the full autonomous lifecycle; the engine-tick stub still to wire.
5. **The thesis** — agency is what happens between turns; idle-gated, idempotent, the model holds the verdict.

## Honest scope

Proof-of-mechanism: one model (12B-b1), one host (RTX 2060), small-registry E2E gates. The engine `kairos.rs`
tick is still a deterministic stub — the model-driven round is fired by the *harness* scheduler (the agency
substance is proven; the Rust-heartbeat wiring is the remaining step). Grounding needs a verbatim-use prompt
patch. Idle-gating is a cadence + idle heuristic, not a hard real-time scheduler. Host-side; no frozen-ABI /
`.sp-model` change.

## Status

**Front-door written/complete — LIVE** — citable via ledger **X-AGENCY-LOOP**. Receipts harness
`tests/g_memory_tools_e2e.py` (H3) / `tests/g_agency_loop_e2e.py` (H4); commits `8e855ca` (memory-as-tools) /
`71873bb` (the agency round). Lives in `harness/skills/memory.py` + `harness/control/agency.py`; engine-side
tick stub `kairos.rs`; GUI lever fix engine `d1e4bba`. Lattice `papers/PPT-LAT-KEYSTONE.md` §4/§6 + memory
`project_harness_toolcalling`. Companions: **25** (the forget/decide/merge this fires proactively), **26** (the
text-protocol tool loop it runs inside), 24 (the recall it consolidates), 09 (KAIROS + rewind), 14 (the memory tier).
