---
type: paper-bite
title: "The Unification: re-carrying the latent crossbar onto the exact-integer O_K substrate"
description: "Shannon-Prime release series, paper 16."
tags: [paper-bite]
timestamp: 2026-06-17T21:43:50Z
resource: ./papers/16-the-unification/paper.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# The Unification: re-carrying the latent crossbar onto the exact-integer O_K substrate

*Shannon-Prime release series, paper 16. Discipline: [METHODOLOGY.md](../../METHODOLOGY.md).
Every number below is a row in [LEDGER.md](../../LEDGER.md) with a command behind it.*

> **Front-door receipt (measured + gated 2026-06-18, ledger X-OK-BIND).** The
> crossbar's memory math had a seam in it that nobody had paid for: the holographic
> superposition that holds the consolidated Ring-3 memories (paper 14) was computed in
> **host floating-point**, decoupled from the project's own proven exact-integer engine.
> This paper closes the seam. The VSA/HRR bind/unbind is re-carried onto the
> engine-native **dual-prime negacyclic CRT-NTT over `Z_q`** (the same algebra paper 06
> ships in production), and the result is **256/256 bit-identical** to the native
> `sp_pr_mul` / `ntt_forward∘pointwise∘inverse` / `sp_pr_inner` path — and
> **reduction-order-immune** (the integer answer is byte-identical across all 8
> summation-order permutations, where the float answer drifts at 4.44e-15). The live
> Ring-3 loop is then rewired through `ok_bind` (native `sp_pr_mul` via ctypes, D=1024
> tiled as a direct sum of two 512-blocks); `recall@1 = 1.0` capacity is **not
> regressed** (CAP=32), and dual-route + nightshift run **GREEN on the native path**.
> And the first honest negative of the set: making the *carrier* itself number-theoretic
> (split-prime O_K characters) **lowers coherence but is operationally inert** — the
> integer container is the win, not the integer carrier.

## 1. The seam nobody had paid for

The series has, by paper 14, a complete latent-memory hierarchy: a verbatim Ring-2
hippocampus, an O(1) bit-exact rewind, a parameter-free Ring-3 neocortex that superposes
many episodes into one bounded store and recalls them by content address. And it has,
since paper 06, a *different* crown jewel: a sovereign discrete arithmetic engine — the
dual-prime negacyclic CRT-NTT over `Z_q`, the Frobenius lift, `Q(√-163)` with class
number 1 — that computes the transformer forward pass exactly, bit-faithful when off,
gated when on.

These two things had never been the *same* thing. The `gemma4_kv_*` cache the crossbar
reads and writes is pure `f32`. The Ring-3 bind in paper 14 was, by its own honest
scope, "host-numpy": proven in the real domain via FFT circular convolution, with the
`Z_q`/NTT engine port named as the deferred follow-on. The crossbar's *memory math* was
running on generic floating-point carriers, structurally decoupled from the very
substrate that gives the project its name. That decoupling is a debt: it means the one
operation the architecture most wants to be exact and auditable — superposing memories
into a single content-addressable store — was, in fact, drifting in floating point like
everything the project set out to replace.

This paper pays the debt. It is the **unification**: the crossbar's memory carried onto
the exact-integer container it was always supposed to live in.

## 2. The seam survey

Before re-carrying anything, the seam was surveyed honestly. The relevant surface is
small and concrete:

- The **bind** `M = Σ_i (addr_i ⊛ id_i)` (paper 14, §3) — circular convolution `⊛` plus
  superposition `Σ`. In numpy this is an FFT, a pointwise multiply, an inverse FFT, and a
  float accumulate.
- The **unbind** `id_est = M ⊛ addr_j†` — the same convolution against the conjugate
  (negacyclic: the inverse carrier), followed by a cleanup argmax over the id codebook.
- The **score** that the curator's resolver and the Ring-3 cleanup both reduce to — an
  inner product in the projection space.

Every one of these maps onto an operation the engine *already implements in exact
integers* for the forward pass: `ntt_forward` / pointwise / `ntt_inverse` is the
convolution; `sp_pr_mul` is the ring multiply; `sp_pr_inner` is the inner product;
`sp_pr_score_kstore` is the encode-and-score. The substrate was never missing the
primitives — the memory layer simply hadn't been wired to them. The frozen primes are
`q1 = 1073738753`, `q2 = 1073732609`, with CRT modulus
`M = 1152908312643096577`; the ring is `R_q = Z_q[x]/(x^N + 1)`, negacyclic, `N ∈ {128,
256, 512}`. These are the production constants — not a parallel toy.

## 3. Leg A: the bind is bit-identical to the native integer path

**G-R3-BIND-on-OK** (`tools/ring3/g_r3_bind_ok.py`, `SP_R3_LIB` pointing at a `libsp.so`
built from `core/ntt_crt` + `core/poly_ring` with gcc). The re-carried bind is checked
against the native engine on three axes.

**C-PARITY — bit-identical, 256/256.** The numpy-integer reference bind and the native
engine path agree **bit-for-bit on all 256 coefficients**, on every primitive:

| primitive | numpy-int vs native | result |
|---|---|---|
| ring multiply | `sp_pr_mul` | **256/256 bit-identical** |
| circular convolution | `ntt_forward ∘ pointwise ∘ ntt_inverse` | **256/256 bit-identical** |
| inner product | `sp_pr_inner` | **256/256 bit-identical** |
| encode-and-score | `sp_pr_score_kstore` | **256/256 bit-identical** |

This is the load-bearing line: the holographic superposition is no longer a numerical
approximation of the engine's algebra — it *is* the engine's algebra, to the bit.

**MARGIN PARITY — the integer carrier recalls exactly as the float carrier did.** The
concern when moving off floats is always that the discrete carrier pays a quality tax.
It does not. The `±1` integer carrier reproduces the float-carrier recall: `recall@1 =
1.0` to **N=16**, `recall@5 = 1.0` to **N=32** at degree-512 — the same capacity curve
paper 14 measured, now on exact integers.

**REDUCTION-ORDER IMMUNITY — the property floats cannot have.** Superposition is a sum,
and a float sum depends on the order you add the terms. We bound the store over **8
different summation-order permutations**: the integer `M` is **byte-identical across all
8**; the float `M` drifts by **4.44e-15** between permutations. This is not a performance
number — it is the auditability guarantee. A memory store you can hash and compare
byte-for-byte regardless of how the consolidation loop happened to order its writes is a
memory store you can *prove* two systems agree on. Floating point can never offer that;
the integer ring offers it for free.

Receipt: `tests/fixtures/xbar_r3/G-R3-BIND-on-OK.log`.

## 4. Wiring the live loop onto native `sp_pr_mul`

A parity gate proves the math is equal; it does not prove the *live loop* runs on it. So
the Ring-3 loop itself was rewired. `ok_bind.py` routes bind and unbind through the
native `sp_pr_mul` via ctypes — the same shared library the parity gate validated. The
production Ring-3 dimension is `D=1024`, larger than the `N=512` ring degree, so it is
tiled as a **direct sum of two 512-blocks**: each block binds independently in `R_q`, and
the cleanup runs over the concatenation. The direct-sum tiling is the honest way to carry
a `D > N` store onto a fixed-degree ring without inventing a new modulus.

The check is that nothing regressed when the loop moved off numpy:

| run | result |
|---|---|
| capacity | `recall@1 = 1.0`, **CAP=32 not regressed** (D=1024, two 512-blocks) |
| G-R3-DUALROUTE (native) | cue→shortlist→verify→land **GREEN** on the integer path |
| G-R3-NIGHTSHIFT (native) | idle consolidation seals at CAP=32 @ D=1024, **349.8 MB resident demoted / 16.3 KB index** — GREEN |

The whole paper-14 pipe — bind, capacity, the decoy-scan dual-route, the idle
garbage-collector — now runs on the engine-native integer multiply, with the same
numbers paper 14 reported in floating point. The neocortex breathes on the discrete
container. Receipt: `tests/fixtures/xbar_r3/G-R3-ORGANISM-NATIVE.log`.

## 5. Leg B: the first honest negative — the integer *carrier* is inert

Carrying the *container* onto integers is the win. The tempting next move — make the
*carrier* number-theoretic too — is the first measured negative of this set, and it is
kept on the record exactly because it is tempting.

**G-R3-BIND-on-OK-legB** (`tools/ring3/g_r3_bind_ok_leg_b.py`). Instead of a `±1`
Rademacher carrier, use a carrier built from **Kronecker characters `χ_d`** — a
genuinely number-theoretic address. We walked the Heegner ladder: `d = -67` (streak-16)
and `d = -163` (streak-40, the project's signature discriminant), at degree `N=512`.

The characters *do* have the deeper structure. Their mutual coherence is lower — closer
to orthogonal — exactly as the Weil bound predicts:

| carrier | mean coherence @ N=64 (random pairs) |
|---|---|
| random `±1` | 0.0355 |
| `χ_d`, d = -67 | 0.0153 |
| `χ_d`, d = -163 | 0.0086 (Weil-bound territory) |

And yet: **recall is *worse*, and the change is operationally inert.** The periodic
character carrier has a spiky spectrum (it is, after all, periodic), which hurts the
unbind; and the SimHash Hamming address the curator actually uses is **~128 bits
unchanged** — the curator cannot even *see* the lower coherence, because its resolver
lives in the projection-bit space, not the carrier's correlation space. Lower coherence
on paper, no benefit (a small loss, actually) in practice.

This is the boundary thesis in miniature, and the rest of papers 17–18 elaborate it:
**`O_K` wins as the exact-arithmetic container; it does not win by making the carrier's
content number-theoretic.** The structure is real (the coherence drops, measurably), but
it is structure the memory system has no mechanism to exploit. We keep the negative
attached. Receipt: `tests/fixtures/xbar_r3/G-R3-BIND-on-OK-legB.log`.

## 6. Honest scope

- **Bit-identical is on the bind algebra, not the whole pipe yet.** C-PARITY proves the
  bind/unbind/score primitives are 256/256 bit-identical to the native engine, and the
  live loop runs through `ok_bind`'s native `sp_pr_mul`. The cleanup argmax and the
  glue around it are still host code; the parity claim is scoped to the ring algebra it
  names.
- **`D=1024` is a direct sum of two `N=512` blocks.** That is the honest way to carry a
  store wider than the ring degree; a single native `N=1024` ring is a separate engine
  build, not claimed here.
- **Leg B is a negative, stated as one.** The `χ_d` carrier lowers coherence and does
  *not* help recall; it is kept because the structure is real and the inertness is the
  point, not because it is a win.
- **One model, one host.** The recall capacity and the nightshift demotion are on
  Gemma-4-12B (the B1 / OK_Q4B artifact of paper 06), RTX 2060 12 GB; the parity gate is
  a CPU `libsp.so` build. Proof-of-mechanism, not a scaling study, not multi-model, not
  independently reproduced.

## 7. Reproduction

Every number above is a row in [`LEDGER.md`](../../LEDGER.md) with model, fixture, flags,
gate, and commit attached. Gates run from the engine repo
([shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)).
Build `libsp.so` from `core/ntt_crt` + `core/poly_ring` (gcc), then point `SP_R3_LIB` at
it; `gemma4_decode_cuda` is left byte-untouched.

| Gate | Driver | Expected | Receipt log |
|---|---|---|---|
| G-R3-BIND-on-OK (Leg A) | `SP_R3_LIB=… python3 tools/ring3/g_r3_bind_ok.py` | C-PARITY 256/256 bit-identical (mul/conv/inner/score); margin parity recall@1=1.0 to N=16, recall@5=1.0 to N=32; order-immune (int byte-identical / float 4.44e-15) | `tests/fixtures/xbar_r3/G-R3-BIND-on-OK.log` |
| G-R3-ORGANISM-NATIVE (wiring) | `tools/ring3/ok_bind.py` (native `sp_pr_mul`, D=1024 as 2×512) | CAP=32 not regressed; dualroute + nightshift GREEN native (349.8 MB → 16.3 KB) | `tests/fixtures/xbar_r3/G-R3-ORGANISM-NATIVE.log` |
| G-R3-BIND-on-OK-legB (negative) | `tools/ring3/g_r3_bind_ok_leg_b.py` | `χ_d` coherence 0.0153 (d=-67) / 0.0086 (d=-163) < random 0.0355; recall worse, SimHash ~128 unchanged — INERT | `tests/fixtures/xbar_r3/G-R3-BIND-on-OK-legB.log` |

**Commit hashes.** Engine: `0019b86` (Leg A — exact-integer dual-prime negacyclic
CRT-NTT bind, C-PARITY 256/256, reduction-order immunity), `1f0f6be`
(`ok_bind` native-`sp_pr_mul` wiring, D=1024 direct-sum, dualroute + nightshift GREEN
native), `d7d96fe` (Leg B — `χ_d` Heegner-ladder carrier, the inert negative). The frozen
primes (`q1`/`q2`/`M`), the ring `R_q = Z_q[x]/(x^N+1)`, and the `Q(√-163)` /
class-number-1 math are the production constants of paper 06's engine. Architecture and
pre-registered gates: lattice `papers/CONTRACT-XBAR-R3-consolidation.md` (the Path A
`Z_q`/NTT engine-port follow-on this paper closes).

## Receipts

| Row | Receipt |
|---|---|
| X-OK-BIND | The Ring-3 VSA/HRR bind re-carried onto the engine-native dual-prime negacyclic CRT-NTT over `Z_q` (frozen primes `q1=1073738753`, `q2=1073732609`, `M=1152908312643096577`; `R_q=Z_q[x]/(x^N+1)`, `N∈{128,256,512}`; `Q(√-163)`, class number 1). **Leg A (`G-R3-BIND-on-OK`):** C-PARITY **256/256 bit-identical** (numpy-int == `sp_pr_mul` / `ntt_forward∘pointwise∘inverse` / `sp_pr_inner` / `sp_pr_score_kstore`); margin parity (`±1` integer carrier recall@1=1.0 to N=16, recall@5=1.0 to N=32 @ deg-512); **reduction-order immunity** (integer `M` byte-identical across 8 summation permutations vs float drift 4.44e-15). **Wiring (`G-R3-ORGANISM-NATIVE`):** `ok_bind` routes bind/unbind through native `sp_pr_mul` (D=1024 = direct sum of two 512-blocks); CAP=32 not regressed; dualroute + nightshift GREEN native (349.8 MB resident demoted / 16.3 KB index). **Leg B (`G-R3-BIND-on-OK-legB`, honest negative):** Kronecker `χ_d` carriers on the Heegner ladder lower coherence (random 0.0355 > d=-67 0.0153 > d=-163 0.0086, Weil bound) but are **operationally inert** — recall worse (spiky periodic spectrum), SimHash Hamming ~128 unchanged. The boundary thesis: `O_K` wins as the exact-arithmetic container, not as a number-theoretic carrier. 12B-b1 (recall/nightshift), CPU `libsp.so` (parity), RTX 2060 12 GB. Open: single native `N=1024` ring; the cleanup glue is still host code |

Companions: paper 14 / X-R3VSA (the parameter-free Ring-3 bind this carries onto the
integer substrate — its named `Z_q`/NTT engine-port follow-on, now closed), paper 06 /
06-R10 (the dual-prime CRT-NTT engine and the `Q(√-163)` math this reuses), paper 17 /
X-OK-FROB (the integer Frobenius episode store and the boundary this Leg-B negative opens),
paper 18 / X-OK-ORG (the full organism loop that runs on this native bind), paper 10 (the
honest-negative discipline that keeps Leg B on the record).
