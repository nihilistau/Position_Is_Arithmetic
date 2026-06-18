---
type: paper-provenance
title: R2 provenance — The Boundary Thesis
description: Genuine-wins assessment, literature positioning, defensibility tier, and honest open items / pre-publication checklist for the R2 boundary-thesis negative-results paper.
resource: ./paper.md
tags: [provenance, boundary-thesis, negative-results, mobius, falsification, gemma4]
timestamp: 2026-06-18T00:00:00Z
sp_status: DRAFT
sp_gate: G-T2-WEIGHTS
sp_commit: ac76c8e, d7d96fe, 1e70763, e6d17bb
sp_repro: SP_R3_LIB=... python3 tools/ring3/g_t2_weights_probe.py (see paper.md Appendix)
---

# R2 provenance — The Boundary Thesis

Provenance, literature positioning, and honest status for [the R2 paper](./paper.md)
(*The Boundary Thesis: algebra rules the container, statistics rule the payload — a
falsification register for number-theoretic structure in trained transformers*).

## Genuine-wins assessment

**Verdict: STRONGEST honest paper in the set.** This is a *negative-results* paper, and its value
is precisely that it convicts the project's own attractive ideas with their receipts rather than
spinning them. The organizing finding — the **Boundary Thesis**: exact number-theoretic arithmetic
is a near-perfect *container* for inference, while imposing number-theoretic *structure on
high-entropy trained content* is **measured inert** — is supported by multiple independent
datapoints, not one. The lead case is decisive and mechanistically explained: a multiplicative-index
(Möbius / `T2`) transform on the real Gemma-4-12B embedding reconstructs at cosine **0.032** vs a
random baseline of **0.039** — indistinguishable from random — because BPE assigns token IDs by
frequency rank, not algebra.

## Literature positioning

Engages the active line asking whether trained transformer weights hide deep mathematical /
symmetry / number-theoretic structure usable for compression, factoring, or interpretability. The
paper's posture is a clean falsification *of a usable-structure claim on a real model*, with four
further convicted levers: split-prime `O_K` Dirichlet carriers (operationally inert), Möbius over
the superposition (sheds memories 1.000→0.969 @ N=32), entropy-coding the Frobenius codes (1.02×
dead weight), and weight transcodes (redundant vs the per-32-block `OK_Q4B` baseline). The
contrast — where the algebra *does* win (the R1 container, the R4 exact bind) — is cited to its
companion gates.

## Defensibility tier

**Tier 1 (clean negative, multiple data points).** The Möbius cos 0.032-vs-0.039 result plus four
independently convicted levers make this hard to wave away; negative-results papers with this much
receipt density are rare and citable.

## Honest OPEN items / pre-publication checklist

- [ ] **All negatives are measured on ONE model family (Gemma-4-12B) at this project's scales** on a
      single dev host. The Boundary Thesis is stated as an *empirical principle, not a theorem* — the
      paper must keep that scope explicit and ideally add at least one other model family before
      claiming generality.
- [ ] **Exhaustive prior-art pass on the "deep structure in trained weights" literature** before
      submission, so the falsification is positioned against the specific claims it rebuts (not a
      strawman). This is the most important pre-pub item for a negative-results paper.
- [ ] Author list / affiliation (`[Shannon-Prime — author list TBD]`).
- [ ] Confirm each convicted-lever receipt is still reproducible at the cited commit.

## Anchors

- Primary gates: **G-T2-WEIGHTS** (engine `ac76c8e`); plus G-R3-BIND-on-OK-legB (`d7d96fe`),
  G-R3-MOBIUS (`1e70763`), G-R2-FROB-ENTROPY (`e6d17bb`), G-WEIGHT-TRANSFORMS / G-WEIGHT-FOLD-ORACLE.
- Container contrast (companions): G-BYTEEXACT-FORWARD-12B (R1), G-R3-BIND-on-OK (R4).
- Receipts: `tests/fixtures/xbar_r3/G-T2-WEIGHTS.log`, `.../G-R3-MOBIUS.log`,
  `.../G-R2-FROB-ENTROPY.log`, `.../G-WEIGHT-*.log`.
- Sibling: [paper.md](./paper.md).
