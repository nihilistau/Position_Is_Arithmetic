---
type: paper-bite
title: "07 — The Auditable Latent Crossbar: steering a frozen 12B through its KV cache *(complete — gated, citable)*"
description: "Multi-agent systems today communicate by detokenizing model A's state into text"
tags: [paper-bite]
timestamp: 2026-06-14T04:02:05Z
resource: ./papers/07-auditable-latent-crossbar/README.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# 07 — The Auditable Latent Crossbar: steering a frozen 12B through its KV cache *(complete — gated, citable)*

> **STATUS: written, complete — citable via ledger X-R1.** The full paper is
> [`paper.md`](paper.md); the front-door receipt is measured + gated (ledger
> **X-R1**). Per series rule 4, two items remain before public release: a
> one-command standalone repro (`EXPECTED.md` capture) and the closing commit
> hash pinned from the engine `git log`. See `paper.md` §7.

> **Front-door receipt (measured + gated 2026-06-08, ledger X-R1):** a frozen
> **Gemma-4-12B**'s generation is steered by **direct KV-cache transplant — no
> tokens involved**. Across a 5-prompt × 3-concept matrix: **15/15 lexical
> incorporation** and **15/15 selectivity** (a 2×2 double dissociation,
> own-family logit-rank geomean 11×–880× and always above cross-family), with a
> max single-token rank pull of **3.69 orders of magnitude** (`' violin'`
> 4910→1). The load-bearing control: a **self-transplant null** (write the
> cache's own contents back onto itself) came out **7/7 byte-identical** — the
> instrument provably changes nothing, so the measured effect is the payload,
> not the splice machinery. Coherence held under the gold instrument
> (steered-text PPL 1.70–4.10 vs the model's true 4.68).

## The claim this paper makes

Multi-agent systems today communicate by detokenizing model A's state into text
and retokenizing it for model B — a boundary that is lossy, slow, and discards
everything the residual stream knew that the argmax threw away. **XBAR bypasses
the boundary:** a frozen transformer's behaviour can be steered by writing donor
KV directly into its running cache, model-to-model communication through *latent
state* rather than text — and **every such write is well-formed, receipted,
gated, and reversible**. "Auditable" is the one word no floating-point,
text-bus agent stack can claim, and it is the entire reason this lane exists.

## What's in it (the map)

1. **The crossbar premise** — why latent state, not tokens: the detokenize /
   retokenize boundary as the lossy bottleneck of every multi-agent stack, and
   what a *gated, receipted, rewindable* latent write buys that a text bus
   cannot.
2. **RoPE-phase-exact donor minting** — donor KV minted at identical absolute
   positions (phase-exact), spliced into a live 12B's cache; geometry is the
   law (per-layer, per-head, position-exact coordinates — nothing else enters).
3. **The null floor that makes it measurable** — the self-transplant null (7/7
   byte-identical): the instrumentation is a strict no-op, so every downstream
   number is a controlled delta against a byte-identical baseline, not a
   comparison between two moving targets.
4. **Incorporation and selectivity** — the 15/15 / 15/15 double dissociation,
   the rank-pull telemetry every step, and the dose-response curve (one row
   ≈4% attention mass bends ranks ≤22×; six contiguous rows breach the lexical
   surface).
5. **Coherence, certified not asserted** — the gold-instrument coherence gate
   (steered-text PPL 1.70–4.10 in the healthy band) and why PPL alone can't
   certify coherence (the distinct-token diagnostic flags 3/15 payloads as
   repetition-degenerate — low PPL *because* repetitive).
6. **The blunt-instrument honesty** — raw KV splice is a deliberately blunt
   tool; the learned-adapter phase (P2) exists to refine exactly what the raw
   splice over-steers. Stated up front, not buried.

## Honest scope

Proof-of-mechanism: **one model (Gemma-4-12B), one host (RTX 2060 12 GB)**, not
scale-validated, not independently reproduced. The direct latent write requires
runtime ownership of the cache — a deployment-isolation property, recorded as
motivation (a verifiable, gated latent substrate is a defense direction the
field lacks), not a project pivot.

## Module

[`paper.md`](paper.md) — the full paper (abstract, the six-section argument,
Reproduction, limitations). Front-door receipt measured + gated in
[shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)
(`tests/test_xbar_p1_cuda.c`, `SP_XBAR_*` harness in
`src/backends/cuda/cuda_forward.cu`, XBP1 payloads); architecture ground truth
in lattice `papers/RFC-XBAR-auditable-latent-crossbar.md` and
`papers/CONTRACT-XBAR-P1-inception-probe.md` (§7–9 run records). Ledger row in
[`LEDGER.md`](../../LEDGER.md) §XBAR (**X-R1**). Companions: 06 (the B1 12B
artifact every XBAR run rides on — paper 07 is the first thing built on it),
04 (the gold instrument that grades the coherence numbers), 08 (the O(1) KV +
learned router the crossbar later pages over).
