# Research papers (full-length preprints)

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
| R2 | The Auditable Latent Crossbar: token-free, receipted KV memory on an exact-integer substrate | 07, 12 | planned |
| R3 | O(1) KV at Long Context: a learned router over a compact slab, gated by needle-in-a-haystack | 06, 08 | planned |
| R4 | One Substrate, Every Backend: a universal exact-integer reference and the discrete-O_K memory rings | 14, 15, 16, 17, 18 | planned |
| R5 | Receipts or It Didn't Happen: a falsification-first methodology for systems-ML claims | 04, 05, 10 | planned |

(R2–R5 are scoped here so later agents can pick one up and match the R1 template. The "Source
bites" column points at the short `papers/` modules the full draft consolidates and expands;
the full draft must re-verify every number against the repo, not copy prose.)
