---
type: paper-provenance
title: R5 provenance — The KV-Cache Compression Mirage
description: Genuine-wins assessment, literature positioning, defensibility tier, and honest open items / pre-publication checklist for the R5 KV-cache extreme-quantization rebuttal + engineered-standard paper.
resource: ./paper.md
tags: [provenance, kv-cache, quantization, niah, vht2, rebuttal]
timestamp: 2026-06-18T00:00:00Z
sp_status: DRAFT
sp_gate: G-P3-R2.b-2c-NIAH
sp_commit: 8e35877, 3218d73, 222463a, 33ac632, 587c8d7
sp_repro: see paper.md Appendix (engine NIAH + VHT2 receipts)
---

# R5 provenance — The KV-Cache Compression Mirage

Provenance, literature positioning, and honest status for [the R5 paper](./paper.md)
(*The KV-Cache Compression Mirage: extreme quantization ratios collapse beyond perplexity, and the
engineered 3–4.5× standard that holds*).

## Genuine-wins assessment

**Verdict: a reframed paper (originally the project's #2), now a respectful rebuttal plus an
engineered standard.** The narrow, falsifiable claim is sound: extreme-ratio KV-cache quantization
is validated almost entirely on perplexity and short contexts, and its fidelity falls off when
evaluated **beyond perplexity** — retrieval and long context in particular. The paper includes
itself in the indictment (the project's own VHT2 / Spinor / half-Möbius codec reaches extreme
single-cache ratios only *lossily*) and tests beyond PPL on a NIAH harness, where a frozen
extreme-sparsity router loses the needle while the learned router holds it. The "no broad
large-lab production adoption" observation is correctly flagged as *suggestive, not dispositive*.

## Literature positioning

Engages **TurboQuant** (Zandieh et al., arXiv 2504.19874, ICLR 2026; 3-bit / 6×), **PolarQuant**,
**IsoQuant** (arXiv 2603.28430), and **Coupled Quantization** — explicitly as good work whose PPL
numbers are real. The claim is not that they are wrong, but that their *validation surface* is too
narrow.

## Defensibility tier

**Position paper UNTIL the open items close.** This is the weakest-grounded paper of the five at
the moment and must not be over-claimed; its tier is gated on closing the items below.

## Honest OPEN items / pre-publication checklist (IMPORTANT — this paper is not yet defensible)

- [ ] **The "8× @ relL2 0.0998" figure was NOT found in the repo receipts.** The paper therefore
      grounds on the *verified* VHT2 numbers — ~3.4–3.8× combined at +0.6–1.24% PPL; single-cache
      max ~4.3–4.7×. Any residual reference to the unverified 8×/0.0998 figure must be removed or
      explicitly marked operator-reported-and-unlocated. This is the top pre-pub item.
- [ ] **The drift-triggered cache-refresh is DESIGN, not yet gated.** The "engineered standard"
      (telemetry-refresh / two-tier adaptive) is presented at its exact gate status; the
      drift-trigger mechanism is design-not-yet-gated and must be labelled as such.
- [ ] **The beyond-PPL collapse is shown on OUR NIAH at OUR scales, not a universal proof.** The
      frozen-router needle loss is a real datapoint on this harness; it is not a general theorem
      about all extreme-ratio schemes. Keep scope explicit.
- [ ] **The "no production adoption" claim stays suggestive.** Do not let it drift toward the
      unfalsifiable "a big lab would deploy it if it worked."
- [ ] Exhaustive prior-art pass on the (fast-moving) extreme-ratio KV-quant literature, current to
      submission date.
- [ ] Author list / affiliation (`[Shannon-Prime — author list TBD]`).

## Anchors

- Primary gates: **G-P3-R2.b-2c-NIAH** (engine `8e35877` / `3218d73`), G-P3-R2.b-2b-LSH (`222463a`,
  frozen-vs-learned router), G-P3-R2.b-2b-N (`587c8d7`, larger-N PPL: 4× +1.65% / 8× +4.17%),
  and the VHT2 / Spinor codec receipts.
- Receipts: engine NIAH logs + the VHT2 ratio/PPL receipts (see paper.md Appendix).
- Sibling: [paper.md](./paper.md).
