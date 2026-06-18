---
type: index
title: "Research papers bundle — progressive-disclosure map"
description: The SP-OKF index for the research papers/ bundle — the five full-length preprints (R1–R5), each with its paper and provenance concept, plus the cross-cutting pre-publication checklist.
resource: ./README.md
tags: [index, research-paper, preprints, provenance, sp-okf]
timestamp: 2026-06-18T00:00:00Z
sp_status: ACTIVE
sp_gate: G-OKF-CONFORM
sp_repro: python shannon-prime-lattice/tools/okf_validate.py "Position_Is_Arithmetic/research papers"
---

# Research papers — bundle map

This bundle holds Shannon-Prime's **full-length, arXiv-style preprints**. Each paper `Rn` lives in
its own subfolder as a `paper.md` (`type: research-paper`) with a sibling `provenance.md`
(`type: paper-provenance`) capturing the genuine-wins assessment, literature positioning,
defensibility tier, and honest open items. Folder guide: [README.md](./README.md). History:
[log.md](./log.md). Standard: [SP-OKF-PROFILE](../../../shannon-prime-lattice/papers/SP-OKF-PROFILE.md).

## The five papers

| ID | Paper | Provenance | Primary gate | `sp_status` | Defensibility |
|----|-------|-----------|--------------|-------------|---------------|
| R1 | [Reduction-Order-Immune Inference](./R1-reduction-order-immune-inference/paper.md) | [provenance](./R1-reduction-order-immune-inference/provenance.md) | G-BYTEEXACT-FORWARD-12B | DRAFT | Tier 2 (strong positive) |
| R2 | [The Boundary Thesis](./R2-boundary-thesis/paper.md) | [provenance](./R2-boundary-thesis/provenance.md) | G-T2-WEIGHTS (+ convicted levers) | DRAFT | Tier 1 (clean negative) |
| R3 | [O(1) Episodic Memory by KV-Tensor Replay](./R3-o1-episodic-kv-injection/paper.md) | [provenance](./R3-o1-episodic-kv-injection/provenance.md) | G-XBAR-ORGANISM-FULL | DRAFT | Tier 2 |
| R4 | [Exact-Integer Holographic Reduced Representations](./R4-exact-integer-holographic-binding/paper.md) | [provenance](./R4-exact-integer-holographic-binding/provenance.md) | G-R3-BIND-on-OK | DRAFT | Tier 2 |
| R5 | [The KV-Cache Compression Mirage](./R5-kv-cache-compression-mirage/paper.md) | [provenance](./R5-kv-cache-compression-mirage/provenance.md) | G-P3-R2.b-2c-NIAH | DRAFT | Position paper (until open items close) |

## Cross-cutting pre-publication checklist

The bank the operator asked for — the items that must close before *any* of these ships. Per-paper
detail lives in each `provenance.md`; this is the shared list.

1. **Exhaustive per-claim prior-art pass.** Every paper needs a literature sweep current to its
   submission date, positioning each claim against the specific work it engages (R2's
   "deep structure in weights" survey and R4's "exact-integer / NTT VSA" survey are the heaviest;
   R5's extreme-ratio KV-quant field is the fastest-moving).
2. **Author list / affiliation.** All five carry `[Shannon-Prime — author list TBD]` — must be set.
3. **Close R5's open items before it is more than a position paper.** In particular: the unverified
   "8× @ relL2 0.0998" figure was NOT found in the repo receipts and the paper grounds instead on the
   verified VHT2 numbers (~3.4–3.8× combined at +0.6–1.24% PPL; single-cache max ~4.3–4.7×); the
   drift-triggered cache-refresh is DESIGN-not-yet-gated; the beyond-PPL collapse is shown on our NIAH
   at our scales, not a universal proof.
4. **R1's external 2-physical-GPU bit-identical logit check.** The cross-hardware determinism claim is
   currently carried by a run-to-run + reduction-order-immunity proxy; the true two-GPU demonstration
   is EXTERNAL and remains open.
5. **Scope on every figure.** All quantitative results are single-model-family (Gemma-4-12B), single
   dev host (RTX 2060, 12 GB), at the project's scales (and small-N where noted: R1 PPL n=42; R3/R4
   N ≤ 64). This must travel with each number; no figure ships unscoped.
6. **Re-verify every cited gate / commit / receipt at submission time** (no stale `sp_commit`).
