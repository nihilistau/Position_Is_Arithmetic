---
type: index
title: "Research papers (full-length preprints) — folder guide"
description: Orientation for the research papers bundle — what it is, how it differs from the papers/ bite series, the per-paper template, and the planned-drafts table. The machine-readable bundle map is index.md.
resource: ./index.md
tags: [index, research-paper, preprints, guide]
timestamp: 2026-06-18T00:00:00Z
sp_status: ACTIVE
sp_gate: none
sp_commit: a6858ce
sp_repro: none
---

# Research papers (full-length preprints)

> **Bundle map:** the SP-OKF progressive-disclosure map for this bundle is [index.md](./index.md);
> chronological history is [log.md](./log.md). This README is the human folder guide.

This folder holds **full-length, arXiv-style research preprints** — real papers, written for
external review and (eventually) submission. It is deliberately separate from the `papers/`
folder one level up.

## `research papers/` vs `papers/`

- **`papers/` (the "Papers series")** — short, digestible, receipts-first *bites*. Each is a
  self-contained module (`README.md` + `paper.md` + `receipts.md` + `repro/`) sized to be read
  in a few minutes and released on a staggered schedule. They share one ledger
  (`../LEDGER.md`) and one discipline (`../METHODOLOGY.md`). See `../SERIES.md` for the manifest.
- **`research papers/` (this folder)** — *full preprints*: longer-form, conventional academic
  structure (Abstract → Introduction → Background & Related Work → Method → Results →
  Limitations → Conclusion → Appendix: Reproduction), with related work cited against the real
  literature. One paper may consolidate the material of several "Papers series" bites into a
  single, citable, self-contained document suitable for arXiv.

Both folders obey the same non-negotiables: **receipts-first** (no number without a gate name +
a reproducing command), **scope travels with every figure** (n, hardware, model), honest
negatives stay attached, no spin.

## Template (subsequent drafts MUST match)

Each paper lives in its own subfolder as a single `paper.md`:

```
research papers/
  R1-reduction-order-immune-inference/
    paper.md
```

`paper.md` sections, in order:

1. **Title**
2. **Authors** — `[Shannon-Prime — author list TBD]`
3. A `> DRAFT / preprint — not yet submitted` banner
4. **Abstract**
5. **1 Introduction**
6. **2 Background & Related Work** — cite real prior art
7. **3 Method**
8. **4 Results** — receipts-first; every number maps to a gate name + a reproducing command
9. **5 Limitations & Honest Negatives**
10. **6 Conclusion**
11. **Appendix: Reproduction** — commands, commit hashes

## Planned drafts

| ID | Title (working) | Source bites (`papers/`) | Status |
|----|-----------------|--------------------------|--------|
| **R1** | Reduction-Order-Immune Inference: an exact-integer, deterministic Gemma-4-12B forward pass | 19, 20, 21 | **first draft — this folder** |
| **R2** | The Boundary Thesis: algebra rules the container, statistics rule the payload — a falsification register for number-theoretic structure in trained transformers | 16, 17, 21 | **first draft — this folder** |
| **R3** | O(1) Episodic Memory by KV-Tensor Replay: bypassing token re-computation in agentic recall | 07, 13, 15 | **first draft — this folder** |
| **R4** | Exact-Integer Holographic Reduced Representations via the Dual-Prime Negacyclic Number-Theoretic Transform | 14, 16, 18 | **first draft — this folder** |
| **R5** | The KV-Cache Compression Mirage: extreme quantization ratios collapse beyond perplexity, and the engineered 3–4.5× standard that holds | 06, 08 | **first draft — this folder** |

(R2–R5 are scoped here so later agents can pick one up and match the R1 template. The "Source
bites" column points at the short `papers/` modules the full draft consolidates and expands;
the full draft must re-verify every number against the repo, not copy prose.)
