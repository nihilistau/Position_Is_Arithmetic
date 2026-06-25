---
type: paper-bite
title: "30 — KEYSTONE: the night the arches locked into one organism *(written, citable — X-KEYSTONE)*"
description: "The capstone. For months the pieces were proven in isolation; KEYSTONE is the integration — the night they"
tags: [paper-bite, keystone, integration, capstone, organism]
timestamp: 2026-06-25T00:00:00Z
resource: ./papers/30-keystone-integration/README.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# 30 — KEYSTONE: the night the arches locked into one organism *(written, citable — X-KEYSTONE)*

> **STATUS: written — front-door complete. THE CAPSTONE of the series so far.** The integration
> paper (ledger **X-KEYSTONE**, milestone **keystone-1**): the night the isolated proofs locked into
> one self-supporting organism. No single new performance number — the contribution is that the
> pieces *compose*, on one substrate, in one loop, default-off-is-null-floor, all receipted.

> **Front-door (2026-06-25):** A keystone is the apex stone that makes an arch stand on its own. For
> months the subsystems were stones held up by scaffolding — a byte-exact forward, a two-ring
> memory, a learned librarian, a diffusion judge, each proven *alone*. KEYSTONE is the night the
> integration stone dropped in: a served Gemma-4-12B that holds a conversation faithfully, owns its
> memory (learn / forget / decide / merge), calls tools and runs Python, beats on an agency
> heartbeat that consolidates between turns, keeps conversations in tiers, and knows what it is —
> all on the byte-exact `O_K` substrate, all default-off = null floor, all receipted, with the loop
> closing in zero manual steps.

## The claim this paper makes

**The integration is the result.** The isolated proofs of the series — byte-exact forward (papers
19–21), two-ring / integer memory (papers 13–18), the learned librarian (paper 24), the diffusion
judge — locked into **one self-supporting organism** at milestone **keystone-1**. The served 12B now
composes: **faithful conversation** (paper 29) + **memory agency** (store / forget / decide / merge,
paper 27, `G-FORGET` / `G-DECIDE` / `G-MERGE`) + **tool calling and Python** (harness,
`G-HARNESS-TOOLCALL-E2E` / `-MEMTOOLS-E2E`) + an **agency heartbeat** that consolidates between turns
(`G-HARNESS-AGENCY-E2E` / `-KAIROS-TICK`) + **tiered conversation memory** (paper 28,
`G-HARNESS-CONVMEM-E2E` / `-CONSOLIDATE` / `-HOOK-E2E`) + **self-priming** — **all on the byte-exact
`O_K` substrate** (`G-BYTEEXACT-FORWARD-12B`), **all default-off = null floor**. The loop closes with
**zero manual steps** (daemon writes the turn → scheduler consolidates on its tick). It is ~**90%**
of the envisioned organism, with the open edges named in the front door. The boundary thesis holds
across the whole arch: the **container is exact**, the **structure is learned**.

## What's in it (the map)

1. **The keystone** — the apex stone metaphor; the series until now was isolated proofs held up by scaffolding.
2. **What locked together** — the six stones (faithful chat, memory agency, tool calling, the heartbeat, tiered memory, the byte-exact substrate) and how each presses into its neighbors.
3. **The loop closes with zero manual steps** — write-on-turn, consolidate-on-tick; the wedge that makes it an organism, not a toolbox.
4. **The thread through every stone** — default-off = null floor; no number without a command; the container is exact, the structure is learned.
5. **Done vs open (honest)** — ~90% built; the four open edges (O(1) conversation KV, the 2-GPU check, deeper faithfulness, native-C XBAR + T4 weights).
6. **Why this is the capstone** — the series, locked under one stone; from here we build up.

## Honest scope

Integration paper: the headline is that the pieces run **together**, default-off-is-null-floor — not
a single new performance number (each subsystem's measured result is its own paper). Proof-of-
mechanism still: one model (12B-b1), one host (RTX 2060), one machine; not multi-model, not
multi-user, not a scaling study, not independently reproduced. ~90% built; the four open edges of §5
are named, not buried. Host-side memory/agency (no frozen-ABI change) + the additive L1 §6b verb;
the byte-exact forward touches `core/exact_islands` but renumbers no frozen surface and changes no
`.sp-model` format.

## Status

**Front-door written/complete — THE CAPSTONE** — citable via ledger **X-KEYSTONE** (milestone
**keystone-1**, 2026-06-25). The canonical, current, complete description of the integrated system
is lattice `papers/PPT-LAT-KEYSTONE.md`; the proof map is §8 of [`paper.md`](paper.md); run-it-from-
clean is `PPT-LAT-KEYSTONE.md` §10. Key commits: byte-exact engine `69c0588` / submodule `d9d96f3`;
faithfulness `88d924e` / `9e4b40f`; recall deploy `edc8079`; memory agency `0fd52e4`; harness
end-to-end in [shannon-prime-harness](https://github.com/nihilistau/shannon-prime-harness)
`tests/`. Companions: the **whole series** locks under this stone — 01–06 (the container), 07–15
(the crossbar + orchestration), 16–21 (the exact-integer substrate + boundary thesis), 22–24 (the
autonomous librarian), 27 (memory agency), 28 (tiered memory), 29 (faithfulness). **This is the
foundation — build forward from here.**
