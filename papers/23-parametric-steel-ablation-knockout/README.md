---
type: paper-bite
title: "23 — Parametric steel and the teacher-forced ablation knockout: making episodic dependency measurable *(written, citable — X-B3-ABLATION)*"
description: "You cannot detect episodic dependency on knowledge the model already has (\"parametric steel\")."
tags: [paper-bite, ablation]
timestamp: 2026-06-20T02:27:28Z
resource: ./papers/23-parametric-steel-ablation-knockout/README.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# 23 — Parametric steel and the teacher-forced ablation knockout: making episodic dependency measurable *(written, citable — X-B3-ABLATION)*

> **STATUS: written — front-door complete.** The keystone of the autonomous-recall set (ledger
> **X-B3-ABLATION**): the result that turned a year of hand-designed negatives (paper 22) into a clean,
> shippable relevance gate.

> **Front-door (2026-06-19):** Why was recall unmeasurable? Because the test facts were **parametric** —
> the 12B regenerates them from its own weights, so deleting the stored copy strands nothing. The corpus
> was the wall. The unlock is a **novel needle** the model cannot know, plus a **teacher-forced ablation
> knockout** that measures the secret's *causal* dependence on the stored memory.

## The claim this paper makes

You cannot detect episodic dependency on knowledge the model already has ("parametric steel"). Replace
the corpus with **novel needles** (secrets stated once) and the dependency becomes a clean, large signal:
teacher-force the secret's tokens, `cudaMemset`-ablate **exactly** their source KV rows, and score the
collapse in summed log-likelihood. **Novel-needle collapse = −33.56 nats; a parametric fact = −0.15** — a
**~220× separation.** The full **3-archetype matrix** (high-entropy code **−33.56** / parametric-contradiction
**−18.58** / relational **−16.10**) sits clear of the parametric control band **[−0.15, +1.45]**; **TAU pinned
at −8.0** gives ~8 nats of margin each side. The gate nine hand-designed signals could not build is one
exact-integer causal probe — and it is **both** a shippable admission oracle **and** a perfect labeler
(a perfectly-diagonal, fully-separable cross-matrix) for the learned head in paper 24.

## What's in it (the map)

1. **Parametric steel** — the causal-ablation diagnosis: collapse ≈ 0 on facts the model knows.
2. **The novel needle** — a curator that mints secrets the model cannot have memorized.
3. **The teacher-forced knockout** — force the secret, ablate its source rows, measure ΣΔLL; `O(1)` rewind.
4. **The matrix + the pin** — 3 archetypes vs a parametric control, TAU = −8.0, ~16-nat gap.
5. **Oracle = labeler** — the same probe that *admits* an episode *labels* it for the learned selector.

## Honest scope

The gate needs the answer key (the secret), so it is an **offline** oracle/labeler, not the live selector —
that is paper 24. Proof-of-mechanism on a curated novel-needle corpus; one model (12B-b1), one host.

## Status

**Front-door written/complete** — citable via ledger **X-B3-ABLATION**. Receipts
`tests/fixtures/chat_fullstack/G-CHAT-B3-NEEDLE-v12.log` / `G-CHAT-B3-NEEDLE-v13-MATRIX.log` /
`G-CHAT-B3-LABELER.log` / `G-CHAT-B3-ADMISSION-200.log`; commits `15738c1` (v12 knockout) / `b6470cc`
(v13 matrix, TAU pinned) / `7556d04` (labeler) / `f4166c7` (200/200 admission). Companions: **22** (the
negatives this breaks), **24** (the head it labels), 14 (the parameter-free memory it rides on).
