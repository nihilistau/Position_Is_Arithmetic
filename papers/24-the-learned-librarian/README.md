---
type: paper-bite
title: "24 — The learned librarian: diversity, logsumexp-mean, and int16-exact autonomous recall on a 12B *(written, citable — X-B3-WC)*"
description: "A learned W_c head (HD=512 → r=32; relevance = logsumexp over positions, then mean over heads;"
tags: [paper-bite, librarian]
timestamp: 2026-06-20T02:27:28Z
resource: ./papers/24-the-learned-librarian/README.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# 24 — The learned librarian: diversity, logsumexp-mean, and int16-exact autonomous recall on a 12B *(written, citable — X-B3-WC)*

> **STATUS: written — front-door complete, DEPLOYED LIVE.** The win of the autonomous-recall set (ledger
> **X-B3-WC**): a learned head that does live, instance-level episodic recall on the served Gemma-4-12B,
> with clean foreign-reject — int16-exact.

> **Front-door (2026-06-20):** With paper 23's oracle removing the corpus constraint, a small learned head
> learns what nine hand-designed signals could not. The binding constraint turned out to be **corpus
> diversity**, not the machinery — and the right scoring reduction makes the int16 head **bit-for-bit
> identical** to float. It is deployed and verified on the metal.

## The claim this paper makes

A learned **W_c** head (HD=512 → r=32; relevance = **logsumexp over positions, then mean over heads**;
InfoNCE over [episodes + a NULL/s0 slot] + a reject-margin hinge) does autonomous instance-level recall:
**360/361 recall + 50/50 foreign-reject, int16 == f32 lossless, s0 = +0.102** (gate `G-CHAT-B3-WC-DIV2`).
Two findings carry it: (1) **diversity** — a templated corpus gave only **34%** instance top-1 (query
vectors collide on shared carrier boilerplate); distinct subjects + varied phrasing per needle took it to
**100%** (float). (2) **the reduction** — under `max` the diagonal is 12/361, under top-8-mean 16/361, under
**logsumexp-mean 361/361**, and **int16 equals f32 for all three**; the earlier "quantization hurts" result
was a wrong-reduction bug, not quantization. The reject is the **NULL slot of an (E+1)-way argmax**, not an
absolute threshold (no fixed line exists at small N). **Deployed live** (`G-CHAT-B3-WC-DEPLOY`): a matched
query recalls its needle (score 9.858, clear argmax, replayed at a bounded M=42 mass); "what is the capital
of France?" drives the whole population negative (best −0.026 < s0) → NULL → clean "Paris."

## What's in it (the map)

1. **Diversity was the wall** — 34% → 100% instance top-1 by de-duplicating subjects/phrasings.
2. **logsumexp-mean** — the only reduction that discriminates *and* quantizes losslessly (int16 == f32).
3. **The NULL slot** — reject as the (E+1)-th argmax coordinate, not a threshold.
4. **The deploy** — `recall.rs` head + `routes.rs` (E+1)-argmax + M=42 bounded replay; default-off = null floor.
5. **The boundary thesis, on recall** — the win is a *learned* selector on a *diverse* corpus, never a
   hand-designed number-theoretic/geometric signal (paper 22's negatives are the proof of that boundary).

## Honest scope

Proof-of-mechanism: 90-needle curated registry, one model (12B-b1), one host (RTX 2060). The reject boundary
is relative (NULL-argmax), not an absolute calibrated threshold. Between-turn consolidation (the memory that
*grows* as you talk) is scoped but **not yet built** (B4 NIGHTSHIFT).

## Status

**Front-door written/complete — DEPLOYED LIVE** — citable via ledger **X-B3-WC**. Receipts
`tests/fixtures/chat_fullstack/G-CHAT-B3-WC-DIV2.log` / `G-CHAT-B3-WC-DEPLOY.log`; head + deploy commits
`87044d8` (head finished, 360/361 + 50/50) / `f62e6ef` (diversity 34%→100%) / `edc8079` (live deploy);
blob `_b3_wc/wc_deploy.bin` via `tools/xbar_lsh/export_wc_deploy.py`. Lattice `papers/CONTRACT-CHAT-FULLSTACK.md`
+ `SESSION-HANDOFF.md §0d`. Companions: **22** (the negatives), **23** (the oracle/labeler), 14 (the memory tier).
