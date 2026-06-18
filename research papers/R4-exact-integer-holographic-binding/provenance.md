---
type: paper-provenance
title: R4 provenance — Exact-Integer Holographic Reduced Representations
description: Genuine-wins assessment, literature positioning, defensibility tier, and honest open items / pre-publication checklist for the R4 exact-integer NTT holographic-binding paper.
resource: ./paper.md
tags: [provenance, hrr, vsa, ntt, exact-integer, holographic-binding]
timestamp: 2026-06-18T00:00:00Z
sp_status: DRAFT
sp_gate: G-R3-BIND-on-OK
sp_commit: 0019b86, 1f0f6be
sp_repro: SP_R3_LIB=... python3 tools/ring3/g_r3_bind_ok.py (see paper.md Appendix)
---

# R4 provenance — Exact-Integer Holographic Reduced Representations

Provenance, literature positioning, and honest status for [the R4 paper](./paper.md)
(*Exact-Integer Holographic Reduced Representations via the Dual-Prime Negacyclic Number-Theoretic
Transform*).

## Genuine-wins assessment

**Verdict: REAL, small and precise.** HRR / VSA binding is instantiated as an **exact-integer
negacyclic convolution** in `R_q = Z_q[x]/(x^N+1)` over a dual-prime CRT-NTT (frozen Proth primes
`q1=1073738753`, `q2=1073732609`, product `M ≈ 2^60` fitting one 64-bit word, so no 128-bit
arithmetic) with Garner CRT reconstruction. The win is exactness/reproducibility, not capacity:
bind / unbind / inner product / encode-and-score are **256/256 bit-identical** to the native ring
primitives; the integer ±1 carrier recalls exactly as the float carrier did; and — the property
floats cannot have — the superposition `M` is **byte-identical across all 8 summation-order
permutations**, where the float bind drifts by 4.44e-15 between orders.

## Literature positioning

Positioned against the float-FFT and binary/XOR-spatter VSA families (ACM Computing Surveys
**10.1145/3538531**; "Attention as Binding" arXiv **2512.14709**). The float route's defining
defect for an *auditable* memory is exactly the order-dependence this paper removes (two systems
consolidating the same memories in different orders produce different stores and cannot prove they
agree); the binary route is order-free but discards magnitude. The integer-NTT instantiation keeps
magnitude *and* is order-immune.

## Defensibility tier

**Tier 2.** A clean, bit-exact, reproducibility-focused contribution with a property the
incumbent approaches structurally lack. Honestly scoped as *not* a capacity win.

## Honest OPEN items / pre-publication checklist

- [ ] **Capacity is small: N ≈ 32** (recall@5 ≥ 0.90 only to ~64 at degree 512). The paper must keep
      this scope on every recall figure and not let "exactness" be read as "more capacity."
- [ ] **Crosstalk is not eliminated, it is verify-gated.** Clean-up after unbind relies on the C2
      256-bit signature / O(1) Hamming verify; the bind itself still superposes with crosstalk. State
      this plainly.
- [ ] **A prior-art sweep specifically on exact-integer / NTT-based VSA binding** is needed before
      submission — the novelty claim is "exact-integer NTT bind," so the closest integer/modular VSA
      work must be found and positioned against.
- [ ] Author list / affiliation (`[Shannon-Prime — author list TBD]`).

## Anchors

- Primary gate: **G-R3-BIND-on-OK** (C-PARITY 256/256 bit-identical; order-immune; engine `0019b86`).
- Supporting: G-R3-ORGANISM-NATIVE (`1f0f6be`), G-R3-DUALROUTE, G-R3-NIGHTSHIFT;
  negative companion G-R3-BIND-on-OK-legB (Dirichlet carriers inert).
- Receipts: `tests/fixtures/xbar_r3/G-R3-BIND-on-OK.log`, `.../G-R3-ORGANISM-NATIVE.log`,
  `.../G-R3-BIND-on-OK-legB.log`.
- Sibling: [paper.md](./paper.md).
