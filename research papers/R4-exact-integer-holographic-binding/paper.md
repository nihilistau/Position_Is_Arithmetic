---
type: research-paper
title: "Exact-Integer Holographic Reduced Representations via the Dual-Prime Negacyclic Number-Theoretic Transform"
description: A preprint instantiating HRR/VSA binding as an exact-integer negacyclic convolution over a dual-prime CRT-NTT — bit-identical to native ring primitives and reduction-order-immune, vs order-dependent float-FFT VSA.
resource: ./provenance.md
tags: [research-paper, hrr, vsa, ntt, exact-integer, holographic-binding]
timestamp: 2026-06-18T00:00:00Z
sp_status: DRAFT
sp_gate: G-R3-BIND-on-OK
sp_commit: 0019b86, 1f0f6be
sp_repro: SP_R3_LIB=... python3 tools/ring3/g_r3_bind_ok.py (see Appendix: Reproduction)
---

# Exact-Integer Holographic Reduced Representations via the Dual-Prime Negacyclic Number-Theoretic Transform

**Authors:** [Shannon-Prime — author list TBD]

> **DRAFT / preprint — not yet submitted.** Numbers below are gated on a single dev host (RTX
> 2060, 12 GB, for the recall/nightshift runs; a CPU `libsp.so` build for the bit-parity gate) at
> the project's capacity scales. This is an *exactness / reproducibility* contribution, **not** a
> capacity win; every figure carries its scope. See §5.

---

## Abstract

Holographic Reduced Representations (HRR) and the broader family of vector-symbolic architectures
(VSA) bind a *filler* to a *role* by circular convolution and superpose many such bindings into a
single fixed-width vector that can be queried by content address. In practice the bind is
implemented either as a **floating-point FFT** circular convolution or as a **binary/XOR** spatter
code. The float route inherits floating-point's defining defect for an auditable memory: the
superposition is a sum, and a float sum *depends on the order the terms are added*, so two systems
that consolidate the same memories in different orders produce *different* stores, bit-for-bit, and
cannot prove they agree. The binary route is order-free but discards magnitude. We instantiate HRR
binding as an **exact-integer negacyclic convolution** in the ring `R_q = Z_q[x]/(x^N + 1)`,
computed over a **dual-prime CRT number-theoretic transform** with two frozen Proth primes
(`q1 = 1073738753`, `q2 = 1073732609`, product `M ≈ 2^60` fitting a single 64-bit word, so no
128-bit arithmetic is required) and Garner CRT reconstruction. The result (gate G-R3-BIND-on-OK):
the bind, unbind, inner product, and encode-and-score are each **256/256 bit-identical** to the
project's native ring primitives; the integer ±1 carrier recalls **exactly as the float carrier
did** (recall@1 = 1.0 to N = 16, recall@5 = 1.0 to N = 32 at degree 512); and — the property
floats cannot have — the superposition `M` is **byte-identical across all 8 summation-order
permutations**, where the float bind drifts by **4.44e-15** between orders. Clean-up after unbind
uses a 256-bit content signature with an O(1) integer Hamming check. The live consolidation loop
(dual-route retrieval + idle nightshift garbage collection) runs on the native integer multiply
without regression (CAP = 32 at D = 1024, tiled as a direct sum of two 512-blocks). We are explicit
that this is an exactness and reproducibility result, not a capacity result: capacity is small
(recall@5 ≥ 0.90 only to N ≈ 64), and crosstalk is not eliminated — it is *verify-gated* by the
Hamming clean-up.

---

## 1 Introduction

A vector-symbolic memory stores structured knowledge in a single high-dimensional vector. To
remember the pair (role = `address_i`, filler = `id_i`), it **binds** them with an invertible,
similarity-preserving operation — Plate's Holographic Reduced Representations use circular
convolution `⊛` — and to remember many pairs it **superposes** the bindings by vector addition:

```
M = Σ_i ( address_i ⊛ id_i ).
```

Recall is the inverse: convolve `M` against the conjugate of a query address `address_j`, recover
a noisy estimate of `id_j`, and clean it up against a codebook. The appeal is that one bounded
vector holds many associations and is queried associatively, by content, with graceful degradation.

For a memory that is meant to be *auditable* — where two systems, or one system at two times, must
be able to *prove* they hold the same store — the standard implementation has a defect that has
nothing to do with the algorithm and everything to do with the arithmetic. The bind is conventionally
a floating-point FFT, and the superposition is a floating-point sum. **Floating-point addition is
not associative.** The consolidation loop that builds `M` adds its terms in *some* order — whatever
order episodes happened to arrive, or threads happened to finish — and a different order yields a
different `M` in the last bits. A store you cannot hash and compare byte-for-byte regardless of
write order is a store you cannot *prove* two systems agree on. The binary/XOR spatter variant is
order-free but throws away magnitude, changing the operator's algebra and its capacity profile.

This paper carries HRR binding onto an **exact-integer container** that keeps the magnitude-bearing
convolution algebra *and* is order-immune by construction. The bind becomes a negacyclic
convolution in `R_q = Z_q[x]/(x^N + 1)`, computed via a dual-prime CRT-NTT over two frozen Proth
primes whose product fits a 64-bit word. Because the arithmetic is exact integer, the superposition
sum is associative: *any* order of writes produces the *same* `M`, to the bit. Our contributions:

1. **HRR bind/unbind/score as an exact-integer negacyclic NTT convolution** in `R_q`, dual-prime,
   with the modulus product fitting a `u64` so the device never needs 128-bit integers (§3).
2. **Bit-identity to a native ring implementation** — 256/256 coefficients on every primitive —
   establishing that the holographic algebra *is* the engine's exact algebra, not a float
   approximation of it (§4.1).
3. **Reduction-order immunity, measured** — the integer `M` is byte-identical across all
   summation-order permutations, where the float bind drifts 4.44e-15 — which is the auditability
   guarantee floats cannot offer (§4.2).
4. **An O(1) content-signature clean-up** (a 256-bit signature, integer Hamming check) and a live
   consolidation loop running on the native integer multiply without recall regression (§3.4, §4.3).

We are equally explicit about what this is *not*: it is not a capacity improvement (§5). The
crosstalk inherent to superposition is unchanged; we *gate* it with an exact verify step rather
than reduce it. The contribution is exactness and reproducibility — the same property our companion
R1 brings to the forward pass — brought to the memory tier.

## 2 Background & Related Work

**HRR and vector-symbolic architectures.** Plate's Holographic Reduced Representations (Plate,
1995) introduced circular-convolution binding with superposition and clean-up, the model we
instantiate. The broader VSA / hyperdimensional-computing family — Kanerva's spatter codes, the
Multiply-Add-Permute (MAP) model, binary spatter codes — is surveyed comprehensively in *A
comparison of vector symbolic architectures* (ACM Computing Surveys, doi 10.1145/3538531). Across
this literature the bind is realized either as a **float FFT** circular convolution (HRR / FHRR)
or as a **binary** operation (XOR / majority). Recent work reframes transformer attention itself
through this lens — *Attention as Binding: A Vector-Symbolic Perspective* (arXiv:2512.14709) — which
underlines that the bind operation is a first-class primitive worth getting *exactly* right. To our
knowledge, an **exact-integer NTT** instantiation of HRR binding, with measured reduction-order
immunity, is the gap we fill: the literature has float-exactness-free convolution and order-free
binary binding, but not an exact, magnitude-bearing, order-immune integer convolution.

**Number-theoretic transforms and exact convolution.** Computing convolution exactly over a prime
modulus via the NTT, and reconstructing across coprime moduli via the CRT (Garner's algorithm), is
classical (the FHE / lattice-cryptography community uses negacyclic NTTs over `Z_q[x]/(x^N+1)`
routinely). We borrow that machinery wholesale: the dual-prime negacyclic CRT-NTT here is the same
substrate the project's exact-integer transformer forward runs on (companion R1), with frozen Proth
primes chosen so the CRT modulus `M = q1·q2 ≈ 2^60` fits a single 64-bit word — which removes the
need for 128-bit arithmetic on the device. The novelty is not the NTT; it is wiring HRR binding
onto it and *measuring* the order-immunity it buys.

**Determinism and reduction order.** The motivation for exactness is the same one our companion R1
develops for the forward pass: floating-point reductions are order-dependent, and pinning the order
(the batch-invariant-kernel SOTA, He et al., 2025) is engine-local, whereas making the arithmetic
exact removes the dependence on order entirely. This paper applies that argument to the *memory*
rather than the forward: a consolidation loop that superposes episodes is a reduction, and an exact
integer reduction is order-immune by construction.

## 3 Method

### 3.1 The ring and the dual-prime CRT-NTT

The carrier ring is `R_q = Z_q[x]/(x^N + 1)` — negacyclic, degree `N ∈ {128, 256, 512}`.
Convolution in this ring is multiplication of polynomials modulo `x^N + 1`, computed by a
**negacyclic NTT**: forward-transform both operands, multiply pointwise, inverse-transform. To keep
the dynamic range exact, the arithmetic is carried over **two frozen Proth primes**:

```
q1 = 1073738753 ,  q2 = 1073732609 ,  M = q1·q2 = 1152908312643096577  (≈ 2^60, fits u64).
```

Each operation is performed independently in `Z_{q1}` and `Z_{q2}`, and the two residue channels
are recombined by **Garner CRT reconstruction** (`q1^{-1} mod q2 = 894602413`). Because `M ≈ 2^60`
fits a single 64-bit word, the recombination and all intermediate products stay within `u64` /
`__umul64hi` reach — **no 128-bit integer type is needed**, which is what makes the same substrate
deployable as device kernels (the forward of R1 uses exactly this). The ring, primes, and CRT
constant are *production constants*, shared with the engine's forward pass, not a toy parallel
implementation.

### 3.2 Bind, unbind, score on the integer ring

The three HRR operations map directly onto native ring primitives:

- **Bind** `M = Σ_i (address_i ⊛ id_i)` — the convolution `⊛` is `ntt_forward ∘ pointwise ∘
  ntt_inverse` (equivalently the native ring multiply `sp_pr_mul`); the superposition `Σ` is an
  **exact integer accumulate**, which is where order-immunity comes from.
- **Unbind** `id_est = M ⊛ address_j†` — convolution against the inverse (negacyclic conjugate)
  carrier, followed by clean-up.
- **Score** — the inner product the resolver and the clean-up reduce to is the native `sp_pr_inner`
  / `sp_pr_score_kstore` (encode-and-score).

The carrier is a random ±1 (Rademacher) address; the filler is the clean label code. Each of these
maps onto an operation the engine already implements in exact integers for the forward pass, so the
memory layer and the forward share one arithmetic substrate.

### 3.3 The content-signature clean-up (C2): O(1) verify

Unbind returns a *noisy* estimate; superposition crosstalk means the raw estimate is not by itself
trustworthy. Rather than attempt to *reduce* the crosstalk in the algebra, we *gate* it with an
exact verify. Each stored item carries a **256-bit content signature** (the project's "C2"
signature, content-hashed at the model's global-layer cadence). Clean-up is: take the unbind's
shortlist, and accept only the candidate whose 256-bit signature matches the query's within an
integer **Hamming** threshold. The Hamming check is an XOR plus a popcount — **O(1)** per
candidate, exact, and order-free. This is the retrieve-and-verify pattern: the lossy holographic
unbind proposes a shortlist; the exact signature disposes. Crosstalk is therefore *bounded by the
verify*, not by the dimension.

### 3.4 The live loop: D = 1024 as a direct sum, and the nightshift

The production Ring-3 dimension is `D = 1024`, larger than the largest ring degree `N = 512`. The
store is therefore tiled as a **direct sum of two 512-blocks**: each block binds independently in
`R_q`, and the clean-up runs over the concatenation. This is the honest way to carry a `D > N` store
onto a fixed-degree ring without inventing a new modulus (a single native `N = 1024` ring is a
separate engine build, not claimed here). The live consolidation loop — `ok_bind.py` routing
bind/unbind through native `sp_pr_mul` via ctypes — runs the full pipeline: a dual-route retrieval
(content cue → holographic shortlist → signature verify → land) and an idle **nightshift** garbage
collector that seals the store at its capacity (CAP = 32) and demotes the resident working set.

## 4 Results

The bit-parity gate runs on a CPU `libsp.so` built from `core/ntt_crt` + `core/poly_ring` (gcc);
the recall-capacity and nightshift runs are on Gemma-4-12B (the B1 / `OK_Q4B` artifact) on an RTX
2060 (12 GB). Receipts-first: every number names its gate and driver; logs under
`tests/fixtures/xbar_r3/`.

### 4.1 Bit-identity to the native ring — gate G-R3-BIND-on-OK (C-PARITY)

The integer-reference bind and the native engine path agree **bit-for-bit on all 256 coefficients**,
on every primitive:

| primitive | reference vs native | result |
|---|---|---|
| ring multiply | `sp_pr_mul` | **256/256 bit-identical** |
| circular convolution | `ntt_forward ∘ pointwise ∘ ntt_inverse` | **256/256 bit-identical** |
| inner product | `sp_pr_inner` | **256/256 bit-identical** |
| encode-and-score | `sp_pr_score_kstore` | **256/256 bit-identical** |

The holographic superposition is no longer a numerical approximation of the engine's algebra — it
*is* the engine's algebra, to the bit. Receipt: `tests/fixtures/xbar_r3/G-R3-BIND-on-OK.log`.

### 4.2 Reduction-order immunity — the property floats cannot have

Superposition is a sum; a float sum depends on the order of the terms. Building the store over **8
different summation-order permutations**:

| carrier | store `M` across 8 summation orders |
|---|---|
| integer (this work) | **byte-identical** (all 8 hash equal) |
| float FFT bind | drifts **4.44e-15** between orders |

This is the auditability guarantee, measured. A store you can hash and compare byte-for-byte
regardless of how the consolidation loop ordered its writes is a store two systems can *prove* they
agree on. Floating point cannot offer it; the integer ring offers it for free. Receipt:
`tests/fixtures/xbar_r3/G-R3-BIND-on-OK.log`.

### 4.3 Recall parity and the live loop — gate G-R3-ORGANISM-NATIVE

The integer ±1 carrier reproduces the float-carrier capacity curve, and the live loop runs on the
native multiply without regression:

| run | result |
|---|---|
| margin parity (degree 512) | recall@1 = 1.0 to **N = 16**, recall@5 = 1.0 to **N = 32** (== the float-carrier curve) |
| capacity (D = 1024, two 512-blocks) | recall@1 = 1.0, **CAP = 32 not regressed** |
| G-R3-DUALROUTE (native) | cue → shortlist → verify → land **GREEN** on the integer path |
| G-R3-NIGHTSHIFT (native) | idle consolidation seals at CAP = 32 @ D = 1024, **349.8 MB resident demoted / 16.3 KB index** — GREEN |

The whole pipe — bind, capacity, the decoy-scan dual-route, the idle garbage collector — runs on
the engine-native integer multiply with the same numbers the float prototype reported. Receipt:
`tests/fixtures/xbar_r3/G-R3-ORGANISM-NATIVE.log`.

## 5 Limitations & Honest Negatives

The framing of this paper is *exactness and reproducibility*, and we are careful not to let it read
as a capacity or quality claim, which it is not.

- **This is not a capacity win.** Capacity is small: recall@1 = 1.0 only to N ≈ 16, recall@5 ≥ 0.90
  only to N ≈ 64, at degree 512; the production store caps at CAP = 32. Exact-integer arithmetic
  does not increase how many memories the superposition holds — it makes the holding *exact and
  order-immune*. A reader looking for more capacity should look elsewhere; the contribution is
  auditability.

- **Crosstalk is not eliminated — it is verify-gated.** Superposition crosstalk ("ghosting") is
  inherent to packing many bindings into one vector and is unchanged by moving to integers. We do
  not reduce it; we *bound* it with the exact 256-bit Hamming clean-up (§3.3). Recall therefore
  depends on the verify step, not on the algebra alone. If the signature collides, the verify can
  still admit the wrong item; the Hamming threshold is the safety margin, not a proof.

- **Bit-identity is on the bind algebra, not the whole pipe.** C-PARITY proves the bind / unbind /
  score *primitives* are 256/256 bit-identical to the native engine, and the live loop routes
  through the native multiply. The clean-up argmax and the glue around it are still host code; the
  bit-identity claim is scoped to the ring algebra it names.

- **D = 1024 is a direct sum of two N = 512 blocks**, not a single native `N = 1024` ring (which is
  a separate engine build). The tiling is the honest way to carry a store wider than the ring
  degree; we do not claim a 1024-degree NTT here.

- **The number-theoretic *carrier* is inert (an attached negative).** Replacing the random ±1
  carrier with a number-theoretic one (Kronecker `χ_d` characters on the Heegner ladder) *lowers*
  vector coherence in the predicted order but does **not** improve recall — the curator's ~128-bit
  SimHash address space cannot see the lower coherence. This is the Boundary Thesis of our companion
  R2 in miniature: the integer *container* is the win, not a number-theoretic *carrier*. We keep the
  negative attached.

- **One host, the project's scales, not independently reproduced.** The parity gate is a CPU
  `libsp.so`; the recall/nightshift runs are on Gemma-4-12B on a single RTX 2060. Proof-of-
  mechanism, not a scaling study, not multi-model.

## 6 Conclusion

Holographic memory is conventionally bound by a floating-point FFT (order-dependent, so a store you
cannot prove two systems agree on) or by a binary spatter code (order-free but magnitude-blind). We
instantiated HRR binding as an exact-integer negacyclic convolution in `R_q = Z_q[x]/(x^N + 1)`,
computed over a dual-prime CRT-NTT whose modulus product fits a 64-bit word. The bind, unbind,
inner product, and encode-and-score are 256/256 bit-identical to the native ring primitives; the
integer ±1 carrier reproduces the float recall curve; and — the load-bearing result — the
superposition is byte-identical across all summation-order permutations, where the float bind drifts
4.44e-15. Crosstalk is bounded by an O(1) 256-bit Hamming verify rather than reduced, and the live
consolidation loop runs on the native integer multiply without recall regression. This is an
exactness and reproducibility contribution — the memory-tier counterpart to the bit-identical
forward of R1 — not a capacity win: capacity is small and crosstalk is verify-gated, both stated
plainly. The auditable property it buys — a memory store you can hash and compare byte-for-byte
independent of write order — is precisely what floating-point holographic memory cannot offer, and
it comes for free from carrying the algebra onto the exact-integer ring.

---

## Appendix: Reproduction

**Commits.** Engine `0019b86` (Leg A — exact-integer dual-prime negacyclic CRT-NTT bind, C-PARITY
256/256, reduction-order immunity), `1f0f6be` (`ok_bind` native-`sp_pr_mul` wiring, D = 1024
direct-sum, dual-route + nightshift GREEN native), `d7d96fe` (the inert `χ_d`-carrier negative).
Math-core submodule `d9d96f3`. The dual-prime CRT-NTT, the ring `R_q = Z_q[x]/(x^N+1)`, and the
`Q(√-163)` / class-number-1 math are the production constants of the engine's forward pass (R1).

**Gates and drivers.**

| Gate | Driver | Expected | Receipt log |
|---|---|---|---|
| G-R3-BIND-on-OK (Leg A) | `SP_R3_LIB=… python3 tools/ring3/g_r3_bind_ok.py` | C-PARITY 256/256 bit-identical (mul / conv / inner / score); margin parity recall@1 = 1.0 to N = 16, recall@5 = 1.0 to N = 32; order-immune (int byte-identical / float 4.44e-15) | `tests/fixtures/xbar_r3/G-R3-BIND-on-OK.log` |
| G-R3-ORGANISM-NATIVE (wiring) | `tools/ring3/ok_bind.py` (native `sp_pr_mul`, D = 1024 as 2×512) | CAP = 32 not regressed; dual-route + nightshift GREEN native (349.8 MB → 16.3 KB) | `tests/fixtures/xbar_r3/G-R3-ORGANISM-NATIVE.log` |
| G-R3-BIND-on-OK-legB (negative) | `tools/ring3/g_r3_bind_ok_leg_b.py` | `χ_d` coherence 0.0153 (d=-67) / 0.0086 (d=-163) < random 0.0355; recall worse, SimHash ~128 unchanged — INERT | `tests/fixtures/xbar_r3/G-R3-BIND-on-OK-legB.log` |

**Build.** Build `libsp.so` from `core/ntt_crt` + `core/poly_ring` (gcc), then point `SP_R3_LIB` at
it; `gemma4_decode_cuda` is left byte-untouched. Recall/nightshift gates run from the engine repo on
Gemma-4-12B (B1 / `OK_Q4B`), RTX 2060 12 GB.

**Frozen constants** (for an independent re-implementation): dual-prime Proth moduli
`q1 = 1073738753`, `q2 = 1073732609`, `M = q1·q2 = 1152908312643096577` (≈ 2^60, fits u64); Garner
`q1^{-1} mod q2 = 894602413`; the ring `R_q = Z_q[x]/(x^N + 1)`, negacyclic, `N ∈ {128, 256, 512}`;
clean-up signature width 256 bits with an integer Hamming threshold; production store `D = 1024` as
a direct sum of two 512-blocks, CAP = 32.

**Related work referenced.** T. Plate, *Holographic Reduced Representations*, IEEE Trans. Neural
Networks, 1995. K. Schlegel, P. Neubert, P. Protzel, *A comparison of vector symbolic
architectures*, ACM Computing Surveys (doi 10.1145/3538531). P. Kanerva, *Hyperdimensional
Computing*, Cognitive Computation, 2009. *Attention as Binding: A Vector-Symbolic Perspective*,
arXiv:2512.14709. (Full citation keys TBD at submission.)
