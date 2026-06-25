---
type: paper-bite
title: "Tiered memory: short, mid, and long on one content-addressed store"
description: "Shannon-Prime release series, paper 28."
tags: [paper-bite, memory, tiered, mem-okf]
timestamp: 2026-06-25T00:00:00Z
resource: ./papers/28-tiered-memory/paper.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# Tiered memory: short, mid, and long on one content-addressed store

*Shannon-Prime release series, paper 28. Discipline: [METHODOLOGY.md](../../METHODOLOGY.md).
Every number below is a row in [LEDGER.md](../../LEDGER.md) with a command behind it.*

> **Front-door receipt (2026-06-25, ledger X-CONVMEM).** A served chat needs three kinds of
> memory, not one. **SHORT** is the live conversation, carried by re-prefill — the daemon already
> holds the full thread (a name planted in turn 1 survives to turn 20). **MID** is the durable
> *facts* extracted from that thread into the recall registry (the librarian of paper 24 reads
> them). **LONG** is the *whole conversation* stored both **complete** (`full/`) and **summarized**
> (`sum/`), bound by one sha256 address: recall the gist by default (`recall_conversations`), dig
> into the verbatim transcript on demand (`read_conversation`). All three ride one
> content-addressed MEM-OKF store with **three disclosure tiers — LUT (index) → `sum/` → `full/`** —
> and the organism is primed about *itself* at init: a system prompt, a recallable capabilities
> corpus ("how do I use myself"), and diverse non-parametric seed facts. Gates
> **`G-HARNESS-CONVMEM-E2E`**, **`G-HARNESS-CONSOLIDATE`**, **`G-HARNESS-HOOK-E2E`** (harness
> `tests/`), all default-off = null floor.

## 1. Three kinds of memory, not one

Paper 24 shipped a learned librarian that recalls the *right stored fact* for a chat turn. But a
fact store is only one tier of what a conversational organism needs. There is the thread you are
*in* right now — the last twenty turns, the name you just gave, the topic you are on. There are the
durable facts worth keeping past this thread — "my favorite animal is the octopus," "the vault code
is 8-FALCON-7729." And there is the *record*: the whole conversation, kept so it can be re-read
months later, but summarized so the model can scan a hundred of them without drowning. These are
**short**, **mid**, and **long** term memory, and conflating them is how chat assistants end up
either goldfish (forget everything) or hoarders (re-read everything).

KEYSTONE separates them cleanly, on one substrate:

| Tier | What | Where | How it fills |
|---|---|---|---|
| **SHORT** | the live conversation | prefilled `messages` each turn; `_current_conversation.json` | the daemon carries full history (re-prefill); a system prompt makes the model *faithful* to it |
| **MID** | durable facts | `registry.jsonl` (+ `_nightshift_live/ep.k`) | NIGHTSHIFT live capture; harness `consolidate_conversation` extraction; `remember()` (idempotent) |
| **LONG** | whole conversations + capabilities | `memory-okf-conv/` (full + summary), `memory-okf-caps/` | `store_conversation` (sha-linked `full`/`sum`); `seed_capabilities` |

## 2. SHORT: the daemon already carries the thread

The first finding is a *negative that mattered*: the served chat **felt** like it restarted each
turn, and the instinct was a cache bug. It was not. The daemon re-prefills the **full** message
list every turn — system + every user + every assistant turn, templated with the gemma4 control
tokens — so the conversation is genuinely present. We proved it the only honest way: plant a name
("Zog," "jazz") early and ask for it twenty turns later. **It survives**, with autonomous recall
both **on and off**. Short-term memory was never missing.

What *was* wrong was a faithfulness failure (the subject of paper 29) — the model leaning on
parametric priors over the thread it was holding. The cache was correct; the grounding was not.
Naming that correctly is what let us build the *right* fix (the higher tiers and a system prompt)
instead of chasing a phantom in the KV cache. The honest caveat travels with the tier: short-term
memory is **O(n) re-prefill**, correct but not yet O(1) — the persistent stateful KV decode verb
(L1 §6b) is the path to a true "continue the cache," and it is the headline open edge of KEYSTONE.

## 3. MID: facts extracted out of the thread

Mid-term memory is the bridge: facts pulled *out* of the perishable conversation into the durable
registry, so they survive the window scrolling away or the daemon restarting. Three roads fill it,
and they are deliberately redundant:

- **NIGHTSHIFT live capture** — a statement turn (not a question, not a request, not a forget) is
  admitted into the registry as an episode (`ep.k`/`ep.v`/`ep.mf`), the same store the learned
  librarian of paper 24 recalls from.
- **harness `consolidate_conversation`** — between turns, an extraction pass reads the written
  conversation and lifts its durable facts into `registry.jsonl` (gate `G-HARNESS-CONSOLIDATE`).
- **`remember()`** — an explicit, *idempotent* memory tool: writing the same fact twice does not
  duplicate it (sha-addressed), so re-consolidation is safe.

This is the tier the recall librarian reads, the tier the memory agency (paper 27's forget /
decide / merge) curates, and the tier that makes the *structural* answer to faithfulness real:
reliable recall of a stated fact beats a prompt that merely asks the model to remember it.

## 4. LONG: the whole conversation, complete *and* summarized, one address

The long tier is the record. `store_conversation` writes each conversation **twice** under **one
sha256 address**: the verbatim transcript into `full/`, and a model-written summary into `sum/`.
That single-address-two-bodies design is the whole trick. The model recalls the **gist** by
default — `recall_conversations(query)` scans the cheap summaries — and only pays for the verbatim
transcript when it actually needs it — `read_conversation(addr)` resolves the same address into
`full/`. You get the recall surface of a hundred summaries at the storage-scan cost of summaries,
with the full fidelity one dereference away.

This is exactly the MEM-OKF **three-disclosure-tier** discipline the project already runs for its
own knowledge docs, now pointed at conversations:

```
  LUT  (the index: addresses + one-line keys)        cheapest — "what conversations exist"
   │
   ▼
  sum/ (the model-written summary per conversation)  the gist — recall_conversations scans here
   │
   ▼
  full/ (the verbatim transcript)                    on demand — read_conversation dereferences here
```

`G-HARNESS-CONVMEM-E2E` exercises the round trip end to end: summarize → store (full + sum under
one sha) → `recall_conversations` returns the gist by query → `read_conversation` returns the exact
verbatim transcript at that address. Content-addressing is what makes it auditable: the address
*is* the content hash, so a recalled summary and its full transcript are provably the same
conversation, and a re-store of an unchanged conversation is a no-op.

## 5. Priming: teaching the organism what it is

A memory that the model does not know it has is dead weight. So init **primes the organism about
itself**, in three layers, each recallable:

1. **A default system prompt** (served console `index.html`) — identity, capabilities, and the
   faithfulness rule ("use what the user said; never substitute a stated fact"). This is the seed
   of paper 29.
2. **A capabilities corpus** — recallable self-knowledge facts (`_seed_capabilities.py` →
   `memory-okf-caps/` / the served registry): *how do I use myself* — that I can remember, forget,
   recall conversations, run tools and Python. The model can **recall its own manual** through the
   very recall path of paper 24.
3. **Diverse non-parametric seed facts** (`_seed_mint.py`) — facts the model *cannot* parametrically
   know (self / hardware / operator), so recall is clean proof and any self-model is genuine, not a
   parametric echo.

The principle is the boundary thesis again, on priming: seed facts the model **can't** already
know, so that a recall is a real retrieval and not the weights answering. `init_primer` wires the
three together; `G-HARNESS-HOOK-E2E` confirms the priming-plus-consolidation loop closes with zero
manual steps — the daemon writes the turn, the scheduler consolidates it on its tick.

## 6. Why content-addressing, not a database

The choice to put all three tiers on the sha256 / C2-signature MEM-OKF store (rather than a SQL
table or a vector index) is the same choice the whole project keeps making: **the address is the
content.** Idempotence falls out for free (re-storing a fact is a no-op, so consolidation and
re-consolidation are safe). De-duplication falls out for free (the same fact from two roads collapses
to one address). Auditability falls out for free (a recalled summary and its full transcript share an
address, so they are *provably* the same conversation — no dangling pointer, no stale join). And the
anti-rebuild pre-flight the project lives by — *look it up before you build it* — is the same
`okf_mem lookup` over the same store. One store, three tiers, one signature scheme; the model gets
the gist and digs deeper only when it needs to.

## 7. Honest scope

- **Proof-of-mechanism.** One model (Gemma-4-12B B1 / `OK_Q4B`, paper 06), one host (RTX 2060 12 GB),
  the harness end-to-end gates. Not a scaling study, not multi-user, not independently reproduced.
- **SHORT is O(n), not O(1).** The daemon re-prefills the whole conversation each turn — correct
  but linear. True O(1) "continue the cache" needs the persistent stateful kvdecode verb (L1 §6b);
  that is built as an ABI hook but not yet wired as the served path. This is the headline open edge.
- **Extraction is model-graded.** `consolidate_conversation` lifts facts via a model call; what it
  keeps is as good as that call. The agency tier (forget / decide / merge, paper 27) is the
  corrective, not a guarantee of perfect extraction.
- **Summaries are lossy by design.** The `sum/` tier is a gist; fidelity lives in `full/`. The
  point is the *two-tier* disclosure, not that the summary is complete.
- **Host-side, no frozen change.** The whole tiered store is harness-side (`skills/
  conversation_memory.py`) over the engine daemon; **no frozen-ABI change, no `.sp-model` format
  change.** Default-off (the seed/consolidation flags unset) is the byte-identical null floor.

## 8. Reproduction

Every number above is a row in [`LEDGER.md`](../../LEDGER.md) (`X-CONVMEM`) with model, fixture,
flags, and commit attached. The tiered store lives in the harness
([shannon-prime-harness](https://github.com/nihilistau/shannon-prime-harness),
`skills/conversation_memory.py`) over the engine daemon; all tier flags are default-off (null floor).

| Gate | Driver | Expected | Receipt log |
|---|---|---|---|
| G-HARNESS-CONVMEM-E2E | `summarize_conversation` → `store_conversation` → `recall_conversations` → `read_conversation` | one sha256 address binds `full/` + `sum/`; recall returns the **gist** by query; read returns the **exact verbatim** transcript at that address | `tests/G-HARNESS-CONVMEM-E2E.log` |
| G-HARNESS-CONSOLIDATE | `consolidate_conversation` (extraction pass) | durable facts lifted from the written conversation into `registry.jsonl` (mid tier); `remember()` idempotent (re-store = no-op) | `tests/G-HARNESS-CONSOLIDATE.log` |
| G-HARNESS-HOOK-E2E | `init_primer` (system prompt + capabilities corpus + seed facts) + the consolidation hook | the organism recalls *its own capabilities*; the loop (daemon writes turn → scheduler consolidates) closes with zero manual steps | `tests/G-HARNESS-HOOK-E2E.log` |

**Commit hashes.** The tiered conversation memory + priming + the consolidation hook are in the
harness repo (`skills/conversation_memory.py`, `control/agency.py`, `_seed_capabilities.py`,
`_seed_mint.py`); the served system prompt is engine `88d924e` (`index.html`). No frozen-ABI or
`.sp-model` change. Architecture: lattice `papers/PPT-LAT-KEYSTONE.md` §5–§6 + `MEMORY-OKF-PROFILE.md`.

## Receipts

| Row | Receipt |
|---|---|
| X-CONVMEM | Three-tier conversation memory on one content-addressed MEM-OKF store. **SHORT** = the live conversation (daemon re-prefills the full thread; a planted name survives 20 turns, recall on and off — short-term memory was never missing, the felt "restart" was a faithfulness bug, paper 29). **MID** = durable facts extracted into `registry.jsonl` (NIGHTSHIFT capture / `consolidate_conversation` / idempotent `remember()`), the tier paper 24's librarian recalls and paper 27's agency curates. **LONG** = the whole conversation stored **complete** (`full/`) **and summarized** (`sum/`) under **one sha256 address** — `recall_conversations` returns the gist by default, `read_conversation` dereferences the same address into the verbatim transcript. Three disclosure tiers: **LUT → `sum/` → `full/`**. **Priming**: a default system prompt + a recallable capabilities corpus ("how do I use myself") + diverse non-parametric seed facts (`_seed_capabilities.py` / `_seed_mint.py` / `init_primer`) — seed what the model *can't* parametrically know, so recall is clean proof. Gates `G-HARNESS-CONVMEM-E2E` (full+sum round trip, one address), `G-HARNESS-CONSOLIDATE` (extraction → mid tier, idempotent), `G-HARNESS-HOOK-E2E` (priming + the zero-step consolidation loop). Gemma-4-12B B1, RTX 2060; host-side, no frozen-ABI / `.sp-model` change; default-off = null floor. **OPEN:** SHORT is O(n) re-prefill — true O(1) "continue the cache" awaits the persistent kvdecode verb (L1 §6b). **Measured + gated.** |

Companions: paper 29 / X-FAITHFUL (the faithfulness lesson — why "restart" was a misread and the
system prompt that patches it; this tiered memory is the *structural* answer), paper 27 / X-AGENCY
(forget / decide / merge — the agency that curates the mid tier), paper 24 / X-B3-WC (the learned
librarian that recalls from the mid tier), paper 14 / X-R3VSA (the parameter-free memory tier the
mid store rides), paper 30 / X-KEYSTONE (the integration this memory model is the heart of).
