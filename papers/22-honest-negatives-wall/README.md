---
type: paper-bite
title: "22 — The honest-negatives wall: why hand-designed recall fails the open world *(written, citable — X-B3-NEGATIVES)*"
description: "A hand-designed relevance signal cannot separate \"the episode this query depends on\" from \"an episode"
tags: [paper-bite]
timestamp: 2026-06-20T02:27:28Z
resource: ./papers/22-honest-negatives-wall/README.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# 22 — The honest-negatives wall: why hand-designed recall fails the open world *(written, citable — X-B3-NEGATIVES)*

> **STATUS: written — front-door complete.** The honest-record paper that opens the autonomous-recall
> set (ledger **X-B3-NEGATIVES**). It carries no winning number — it is the map of nine measured
> negatives that bound the win in papers 23–24.

> **Front-door (2026-06-19):** The served Gemma-4-12B should recall the *right* stored episode for a
> chat turn, or refuse. We tried to build that selector by hand — **nine** relevance signals — and
> **every one failed open-world.** This paper keeps the failures on the record, because they are the
> reason the eventual win (a *learned* head on a *diverse* corpus, paper 24) is the honest answer and
> not the first thing we reached for.

## The claim this paper makes

A hand-designed relevance signal cannot separate "the episode this query depends on" from "an episode
that merely shares a fluent attractor," at small corpus size, on open-world queries. We prove it by
exhausting the design space: **6 verifier prompts + 4 post-inject "Disposer" signals** (a Yes/No
reasoning bridge; a first-token Δ-continuation; a multi-token ΣΔLL over the model's own greedy
continuation; a consensus of q·K ∧ ΔLL) **+ cosine-normalized q·K + a ΔLL-polarity flip.** The best
hand-design (raw q·K + argmax multi-token-ΔLL) reaches only **2/3 rank, 1/3 consensus** at N=3, and a
**diagnosed** failure mode kills the rest: per-episode bias and a high-energy "super-attractor" episode
that wins q·K on *every* query (it measures magnitude, not direction). The two most *principled* fixes —
cosine-normalizing the score, flipping the ΔLL sign — each made it **worse**, for reasons we name.

## What's in it (the map)

1. **The six verifiers and the four Disposer signals** — what each measured, why each lost.
2. **The N-sweep** — adding more/novel memory *amplified* the confound (a super-attractor), it did not help.
3. **The two pristine fixes that backfired** — cosine-q·K collapses the angle (every episode ~0.14);
   argmin-ΔLL picks the *least-disruptive* = most-irrelevant episode.
4. **The lesson** — the binding constraint is not normalization and not more memory; it is something the
   next paper names.

## Honest scope

No winning number — this is the negatives paper. All signals were *measured then discarded*, not shipped
(receipts-first: nothing reached deployment). One model (12B-b1), one host (RTX 2060), small-N corpora.

## Status

**Front-door written/complete** — citable via ledger **X-B3-NEGATIVES**. Receipts in
[shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)
`tests/fixtures/chat_fullstack/G-CHAT-B3-DISPOSER-{yesno,dcont,multitok,consensus,nsweep,dualfix}.log`;
commits `4dba6c8` / `2b623ab` / `acd7b3a`. Companions: **23** (the oracle that broke this wall), **24**
(the learned head that the negatives justify), 16–17 + 21 (the boundary thesis these extend to recall).
