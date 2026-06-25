---
type: paper-bite
title: "25 — The memory agency: a model that forgets, supersedes, and merges its own facts *(written, citable — X-AGENCY)*"
description: "Three layers — FORGET, DECIDE (supersede), MERGE (consolidate) — that give the served Gemma-4-12B authority over its own memory; the verdict is the model's, not a dedup rule."
tags: [paper-bite, agency, memory, forget, decide, merge]
timestamp: 2026-06-25T00:00:00Z
resource: ./papers/25-the-memory-agency/README.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# 25 — The memory agency: a model that forgets, supersedes, and merges its own facts *(written, citable — X-AGENCY)*

> **STATUS: written — front-door complete, LIVE on the served 12B.** The agency layer of KEYSTONE (ledger
> **X-AGENCY**): the model *owns* its memory — it forgets a fact on request, retires a stale one, and merges
> two complementary facts into one synthesized truth, all on its own verdict.

> **Front-door (2026-06-25):** Paper 24 deployed a librarian that *recalls*. This paper gives the model
> authority over the store. Not a dedup rule — **emergent self-curation**: the trigger is a cheap overlap
> gate, but the verdict (forget? supersede? merge?) is the model's own.

## The claim this paper makes

Three default-off layers on the served Gemma-4-12B, each a byte-identical null floor when its flag is unset:

- **FORGET** (`SP_FORGET`) — "forget X" → `token_overlap` match (the trusted 0.6 verifier, fire ≥0.25) →
  drop *all* live copies + rewrite the persisted registry (survives restart) → text-in-context confirm.
  **G-FORGET:** "vault code 7-RAVEN-3300" → recall → "forget" → recall **"12345"** (gone); registry 8→9→**8**.
- **DECIDE / supersede** (`SP_DECIDE`) — on a capturing turn overlapping an existing memory, a side
  model-call asks the model **which is out of date** → `CHANGED=n` → silent forget. **G-DECIDE:** "color blue"
  → "color green" → model **`CHANGED=1`** → recall **"Green."**
- **MERGE / consolidate** (`SP_DECIDE`, stage-2) — the model returns **`MERGE:: <combined>`**; the daemon
  drops both originals and captures the synthesis. **G-MERGE:** "sister is a doctor" + "sister lives in
  Boston" → **`MERGE:: …Boston and is a doctor.`** → the consolidation is recalled.

The thesis: a memory is *owned* when the **model holds the verdict.** The trigger is deterministic
(overlap-gated, conflict-only); forget / supersede / merge are the model's own judgement.

## What's in it (the map)

1. **From a database to an agency** — the operator's reframe: not a clean dedup index, but a memory the model owns.
2. **FORGET** — remove from RAM *and* disk; the bug where the forget command captured itself.
3. **DECIDE** — the model retires its own stale fact; *frame as DETECTION not DECISION, force the answer prefix.*
4. **MERGE** — two complementary facts → one synthesized truth; the "cannot both be true at once" criterion.
5. **The admission gate** — the quiet spine: the agency must not capture its own forget/recall/request utterances.
6. **Emergent, not deterministic** — why the model holding the verdict (not a rule) is the whole point.

## Honest scope

Proof-of-mechanism: one model (12B-b1), one host (RTX 2060), smoke gates (not a corpus-scale curation study).
FORGET is fully in-session for learned facts; seeds are removed from disk but recallable until restart. The
conflict *trigger* is a string-op heuristic; the *verdict* is the model. Default-off = null floor; host-side,
no frozen-ABI / `.sp-model` change.

## Status

**Front-door written/complete — LIVE** — citable via ledger **X-AGENCY**. Receipts
`tests/fixtures/chat_fullstack/G-FORGET.log` / `G-DECIDE.log` / `G-MERGE.log`; commits `78e4acf` (FORGET) /
`be9a426` (DECIDE supersede) / `0fd52e4` (MERGE consolidate). Lattice `papers/PPT-LAT-KEYSTONE.md` §4 + memory
`project_memory_agency_forget`. Companions: **24** (the librarian that recalls), **26** (memory-as-tools),
**27** (the between-turn loop + heartbeat that fire this on a schedule), 14 (the memory tier), 13 (the replay seam).
