---
type: paper-bite
title: "04 — The Oracle & the Teacher *(staged — mapped, not yet written)*"
description: Porting a complex architecture to new silicon does not have to end in a
tags: [paper-bite, oracle]
timestamp: 2026-06-06T10:29:49Z
resource: ./papers/04-oracle-teacher/README.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# 04 — The Oracle & the Teacher *(staged — mapped, not yet written)*

> **Front-door receipt (already gated in the engine repo):** a 35-layer
> variable-geometry MatFormer (per-layer attention widths, shared-KV,
> proportional RoPE, AltUp, softcap) ported to a consumer GPU and matched to its
> CPU oracle at **max KL = 2.663e-10** (argmax 12/12) — and an autoregressive
> decode whose every generated token the oracle **teacher-forced-predicts
> exactly**. Both live runs lit green on the **first attempt**, with zero
> debugging sessions on the composed system.

## The claim this paper will make

Porting a complex architecture to new silicon does not have to end in a
weeks-long divergence hunt. If you (1) extract a **bit-faithful CPU oracle**
from the reference implementation first, (2) grade every backend against the
oracle — never against your own prior port — and (3) use **teacher-forcing** as
the decode gate (the oracle re-predicts the port's own generated stream), then
correctness becomes a checklist, not an investigation.

## What goes in it (the map)

1. **The oracle discipline** — what an oracle is here: a scalar, readable,
   reference-precision (f64-accumulate) CPU forward, validated against the
   upstream implementation (llama.cpp) once, then frozen as the single source
   of arithmetic truth. Comments are aspirations; the oracle and the artifact
   config are physics (case: the E2B's real period/kvfs vs the doc comments).
2. **Gate currency** — why cross-backend correctness is graded in
   **argmax + KL** (distribution identity) and **teacher-forced decode**, not
   raw activation error (which norm layers amplify ~25× — measured, mechanism
   in paper 05).
3. **Oracle arithmetic, enforced** — the inline Frobenius lift: integer codes
   accumulated exactly, ONE scale at the end. Dequantize-per-weight injects an
   extra f32 rounding per term (measured 2.8e-3 divergence); the GPU must
   compute what the oracle computes, not what is algebraically equivalent.
4. **The case study** — the Gemma4 CUDA campaign: five gates, two first-try
   live runs, 38/38. The full receipt trail.

## Status

Staged. All receipts already gated in
[shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)
(`tests/test_gemma4_cuda.c`, tag `stage-eta-phase1-closed-2026-06-06`); ledger
rows in [`LEDGER.md`](../../LEDGER.md) §Paper 04. Per series rule 4: re-gate +
one-command repro before release. Companion: paper 05 (the probe suite this
methodology rides on).
