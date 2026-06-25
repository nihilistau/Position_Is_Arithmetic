---
type: paper-bite
title: "28 — Tiered memory: short, mid, and long on one content-addressed store *(written, citable — X-CONVMEM)*"
description: "Three kinds of memory on one MEM-OKF store: SHORT (the live conversation, re-prefilled), MID (durable facts"
tags: [paper-bite, memory, tiered, mem-okf]
timestamp: 2026-06-25T00:00:00Z
resource: ./papers/28-tiered-memory/README.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# 28 — Tiered memory: short, mid, and long on one content-addressed store *(written, citable — X-CONVMEM)*

> **STATUS: written — front-door complete.** The memory-model paper of the KEYSTONE set (ledger
> **X-CONVMEM**): the three tiers a conversational organism needs, all on the content-addressed
> MEM-OKF store, all default-off = null floor.

> **Front-door (2026-06-25):** A served chat needs three kinds of memory, not one. **SHORT** is the
> live conversation (the daemon already carries it — a planted name survives 20 turns). **MID** is
> the durable facts extracted into the recall registry (the librarian of paper 24 reads them).
> **LONG** is the whole conversation stored **complete** *and* **summarized** under one sha256
> address: recall the gist by default, dig into the verbatim transcript on demand. Plus the init
> priming that teaches the organism what it is.

## The claim this paper makes

Three memory tiers on **one** content-addressed store, linked by **one** signature scheme.
**SHORT** = the live conversation, carried by re-prefill (correct, O(n); the felt "restart" was a
faithfulness bug — paper 29 — not a cache miss; a planted name survives, recall on and off).
**MID** = durable facts lifted out of the thread into `registry.jsonl` (NIGHTSHIFT capture /
`consolidate_conversation` / idempotent `remember()`) — the tier paper 24's librarian recalls and
paper 27's agency curates. **LONG** = each conversation stored **complete** (`full/`) **and**
**summarized** (`sum/`) under one **sha256** address; `recall_conversations` returns the gist,
`read_conversation` dereferences the same address into the verbatim transcript. The MEM-OKF
**three-disclosure-tier** discipline (**LUT → `sum/` → `full/`**) makes the gist cheap and the full
fidelity one dereference away. At init the organism is **primed about itself**: a default system
prompt + a recallable **capabilities corpus** ("how do I use myself") + diverse **non-parametric
seed facts** (seed what the model *can't* parametrically know, so recall is clean proof). Gates
`G-HARNESS-CONVMEM-E2E`, `G-HARNESS-CONSOLIDATE`, `G-HARNESS-HOOK-E2E`.

## What's in it (the map)

1. **Three kinds of memory, not one** — short / mid / long, and why conflating them makes goldfish or hoarders.
2. **SHORT** — the daemon already carries the thread (the "restart" was a faithfulness bug, paper 29); O(n) re-prefill is the open edge.
3. **MID** — facts extracted out of the perishable thread into the durable registry; three redundant roads; the tier the librarian reads.
4. **LONG** — `full/` + `sum/` under one sha256; gist by default, verbatim on demand; the LUT → `sum/` → `full/` disclosure ladder.
5. **Priming** — system prompt + capabilities corpus + non-parametric seed facts; the organism recalls its own manual.
6. **Why content-addressing** — idempotence, de-dup, and auditability all fall out of "the address is the content."

## Honest scope

Proof-of-mechanism: one model (12B-b1), one host (RTX 2060), the harness end-to-end gates. **SHORT
is O(n) re-prefill** — true O(1) "continue the cache" awaits the persistent kvdecode verb (L1 §6b),
the headline open edge. Extraction is model-graded; summaries are lossy by design (fidelity lives
in `full/`). Host-side (`skills/conversation_memory.py`), no frozen-ABI / `.sp-model` change;
default-off = null floor.

## Status

**Front-door written/complete** — citable via ledger **X-CONVMEM**. Receipts in
[shannon-prime-harness](https://github.com/nihilistau/shannon-prime-harness)
`tests/G-HARNESS-{CONVMEM-E2E,CONSOLIDATE,HOOK-E2E}.log`; the served system prompt is engine
`88d924e` (`index.html`); store + priming in `skills/conversation_memory.py`, `control/agency.py`,
`_seed_capabilities.py`, `_seed_mint.py`. Lattice `papers/PPT-LAT-KEYSTONE.md` §5–§6 +
`MEMORY-OKF-PROFILE.md`. Companions: **29** (the faithfulness lesson), **27** (the agency that
curates the mid tier), **24** (the librarian that recalls it), 14 (the memory tier it rides), **30**
(the integration this is the heart of).
