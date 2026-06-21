---
type: paper-bite
title: "05 — The Probe Suite *(staged — mapped, not yet written)*"
description: Correct numbers about computing systems are not read off; they are
tags: [paper-bite]
timestamp: 2026-06-06T10:30:18Z
resource: ./papers/05-probe-suite/README.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# 05 — The Probe Suite *(staged — mapped, not yet written)*

> **Front-door receipt (already gated in the engine repo):** one measurement
> suite — used **together, as a single set** — caught a 12.65× phantom speedup
> (three stacked artifacts), a wrong-arithmetic 2.8e-3 divergence, a
> mixed-precision 0/256 correctness bug the isolated bench could not see, and a
> ~25× norm-amplification that would have failed every naive gate — and then
> landed a 35-layer GPU port **first-try**. The suite is the reason the
> monolith never needed a debugger.

## The claim this paper will make

Correct numbers about computing systems are not read off; they are
**engineered**. This paper ships the suite of testing methodologies we run as
one set — boundary detection, bisection, isolation, and benchmark hygiene —
with the receipts of what each component caught.

## The suite (the map — each tool with its kill)

1. **The truncated-parity bisection harness** (boundary detection): a CPU
   mirror built from the oracle's own primitives, truncated at staged
   boundaries (embed / norm / projection / attention / pre-norm / residual),
   diffed against the port at the same boundary. *Kill: localized a 2.8e-3
   divergence to the matmul arithmetic in two probe runs; proved the L15
   shared-KV cross-layer VRAM addressing exact at 1.1e-5.*
2. **Telemetry-then-pin gating**: first run measures the floor, gates pin at
   ~3× measured — never invented tolerances, never silent revisions. *Kill:
   the ×25 norm-amplification was characterized (rms≈0.04 denominator) instead
   of papered over; ABS error became the gate currency at norm boundaries
   because rel inflates on near-zeros.*
3. **The isolated crossover sweep** (`bench_gemv_int8.cu`): one variable (the
   kernel) against one axis (matrix size), everything else stripped. *Kill:
   located the overhead→bandwidth-bound crossover at N≈2K; proved the byte-diet
   ladder (paper 06) without paying a 12B integration tax.*
4. **Benchmark hygiene** (the GPU rules, now binding in CONVENTIONS): warm-up
   (cold-start ≈13× phantom), long windows (sub-second jitter swung one number
   32→88→92), **lock BOTH clocks** (`-lgc` pins SM only; a weight-GEMV tracks
   the free-running GDDR6 clock), Amdahl regime-check (a faster kernel on a
   non-binding bottleneck measures as a tie), within-run ratios over absolutes.
   *Kill: the 12.65× CUDA-graph "win" dissolved into ~1.06× — and the honest
   number held.*
5. **Isolated bench ≠ production gate** (the pairing rule): the bench validates
   kernel *math*; only the production gate validates the *data-structure
   handoff*. *Kill: a uniform-synthetic Q4 bench passed at 1.3e-7 while the
   real K-quant-mix arena (Q8 head / Q4 body) returned 0/256 — caught only in
   the production loop, fixed with per-tensor precision dispatch.*
6. **Structural ingest probes**: weight-set upload gates that print the
   resolved geometry (layer types, owner/sharer split, elastic widths,
   per-tensor precision) before any forward runs. *Kill: the artifact's real
   period=5 / kvfs=15 vs the documentation's 6 / 20-15.*

## Status

Staged. Every component exists and is exercised in
[shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)
(`tests/test_gemma4_cuda.c` — the harness; `tests/bench_gemv_int8.cu` — the
sweep; `CONVENTIONS.md` in the system repo — the benchmark rules); ledger rows
in [`LEDGER.md`](../../LEDGER.md) §Paper 05. Companions: 04 (the oracle the
probes grade against), 06 (the result the suite certified).
