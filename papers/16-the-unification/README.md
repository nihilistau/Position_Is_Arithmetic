---
type: paper-bite
title: "16 — The Unification: re-carrying the latent crossbar onto the exact-integer O_K substrate *(written, citable — X-OK-BIND)*"
description: "The crossbar's most auditability-critical operation — superposing memories into one"
tags: [paper-bite]
timestamp: 2026-06-17T21:43:50Z
resource: ./papers/16-the-unification/README.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# 16 — The Unification: re-carrying the latent crossbar onto the exact-integer O_K substrate *(written, citable — X-OK-BIND)*

> **STATUS: written — [`paper.md`](paper.md) complete.** Front-door receipts measured
> + gated (ledger **X-OK-BIND**).

> **Front-door receipt (measured + gated 2026-06-18, ledger X-OK-BIND):** the crossbar's
> memory math had a seam — the Ring-3 holographic superposition (paper 14) was computed in
> **host floating-point**, decoupled from the project's own exact-integer engine. This
> paper closes it: the VSA/HRR bind is re-carried onto the engine-native **dual-prime
> negacyclic CRT-NTT over `Z_q`** and comes out **256/256 bit-identical** to the native
> `sp_pr_mul` path, and **reduction-order-immune** (integer `M` byte-identical across 8
> summation permutations; float drifts 4.44e-15). The live loop is rewired through
> `ok_bind` (native `sp_pr_mul`, D=1024 as a direct sum of two 512-blocks); CAP=32 not
> regressed; dualroute + nightshift GREEN native. And the first honest negative: a
> number-theoretic *carrier* (split-prime `χ_d` O_K characters) lowers coherence but is
> **operationally inert** — the integer container is the win, not the integer carrier.

## The claim this paper makes

The crossbar's most auditability-critical operation — superposing memories into one
content-addressable store — was drifting in floating point, structurally decoupled from
the substrate that names the project. Paper 16 pays that debt: the bind/unbind/score are
carried onto the production CRT-NTT algebra (frozen primes `q1`/`q2`, `M`;
`R_q=Z_q[x]/(x^N+1)`; `Q(√-163)`, class number 1), proven **bit-identical** and
**order-immune**, and the live Ring-3 loop is wired to the native multiply. The boundary
thesis opens here: `O_K` wins as the exact-arithmetic **container**, not as a
number-theoretic **carrier**.

## What's in it (the map)

1. **The seam nobody had paid for** — the `f32` Ring-3 bind decoupled from the exact engine.
2. **The seam survey** — bind/unbind/score map onto `ntt_forward`/`sp_pr_mul`/`sp_pr_inner`,
   primitives the engine already ships exact.
3. **Leg A** — C-PARITY 256/256 bit-identical; margin parity (recall@1=1.0 to N=16);
   reduction-order immunity (integer byte-identical vs float 4.44e-15).
4. **Wiring** — `ok_bind` native `sp_pr_mul`, D=1024 as 2×512 direct sum; CAP=32 not
   regressed; dualroute + nightshift GREEN native.
5. **Leg B (honest negative)** — `χ_d` Heegner-ladder carriers: lower coherence
   (0.0153 / 0.0086 < random 0.0355) but inert (recall worse, SimHash ~128 unchanged).

## Honest scope

Proof-of-mechanism, **one model (12B-b1), one host (RTX 2060)**; bit-identical is scoped
to the bind algebra (the cleanup glue is still host code); `D=1024` is a direct sum of two
`N=512` blocks (a native `N=1024` ring is a separate build); Leg B is a negative kept
because the structure is real and the inertness is the point.

## Status

**Paper written/complete** ([`paper.md`](paper.md)) — citable via ledger **X-OK-BIND**.
Front-door receipts measured + gated in
[shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)
(`tools/ring3/{g_r3_bind_ok,g_r3_bind_ok_leg_b,ok_bind}.py`, `libsp.so` from
`core/ntt_crt`+`core/poly_ring`; receipts `tests/fixtures/xbar_r3/`); architecture in
lattice `papers/CONTRACT-XBAR-R3-consolidation.md`. Companions: 14 (the parameter-free
Ring-3 bind this carries onto integers — its named engine-port follow-on, now closed), 06
(the CRT-NTT engine + `Q(√-163)` math reused), 17 (the integer Frobenius store + the
boundary this Leg-B negative opens), 18 (the full organism loop on this native bind), 10
(the honest-negative discipline).
