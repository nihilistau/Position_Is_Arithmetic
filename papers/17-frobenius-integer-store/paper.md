---
type: paper-bite
title: "The Frobenius integer episode store, and the boundary of the algebra"
description: "Shannon-Prime release series, paper 17."
tags: [paper-bite, frobenius, frob]
timestamp: 2026-06-17T21:43:50Z
resource: ./papers/17-frobenius-integer-store/paper.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# The Frobenius integer episode store, and the boundary of the algebra

*Shannon-Prime release series, paper 17. Discipline: [METHODOLOGY.md](../../METHODOLOGY.md).
Every number below is a row in [LEDGER.md](../../LEDGER.md) with a command behind it.*

> **Front-door receipt (measured + gated 2026-06-18, ledger X-OK-FROB).** Paper 16
> carried the Ring-3 *bind* onto the exact-integer `O_K` substrate. This paper carries
> the Ring-2 *episode store* onto it too — and then spends most of its length mapping the
> **boundary** of where the algebra helps. The store is `G-R2-FROB`: a rank-2 `O_K`
> lattice codec `x = a·s_a + b·s_b` (real scales, not literal complex `ω`) that
> reconstructs episodic K/V tensors to **sub-ULP at 24 bits** (`a16b8`: relative L2
> **1.2e-7**, 18% of coefficients byte-exact), with the Frobenius `π^k` scale-cancellation
> (paper 03's validated lever) replaying clean. Lossless is established by
> **reconstruction fidelity, not a fake `+0.000%`** — and the honest scope is stated
> bluntly: the `n=42` single-chunk perplexity gate is **blind below ~1%**, so it cannot
> certify the codec, and we do not pretend it does. Then the cluster of negatives that
> draws the line: entropy-coding the codes (**1.02×**, residual incompressible), Möbius
> over the superposition (**sheds memories**, recall 1.000→0.969), and the proposed `T2`
> transform on real model weights (recon cosine **0.032 ≈ random 0.039** — `T2` was a
> *design proposal, never validated*, unlike the `T4` lever that was). The boundary
> thesis: **`O_K` wins on exact arithmetic — the container — never on structuring the
> high-entropy content.**

## 1. The container, made into a codec

Ring-2 is the verbatim hippocampus: a stored episode is the model's own K/V cache, and
its value is that it replays *exactly*. Paper 16 proved the Ring-3 superposition could
live on the integer ring; the natural next question is whether the Ring-2 episode itself
can be stored in the project's algebra rather than as a raw `f32` dump — a codec that is
auditable and, ideally, smaller, while preserving the bytes the replay seam (paper 13)
depends on.

`G-R2-FROB` (`tools/curator/frob_episode.py`) is that codec. Each coefficient of the
episode tensor is written as a **rank-2 `O_K` lattice element** `x = a·s_a + b·s_b`,
where `s_a` and `s_b` are the two basis scales of the integer ring (these are *real*
scales — the implementation uses the rank-2 real lattice, not a literal complex `ω`
multiply, and the paper says so to keep the claim honest). The `a` term is a coarse
quantization; the `b` term is a refinement, and the `T4` Frobenius `π^k` machinery
(paper 03 — the *validated* calibration-free lever) makes the scale free: `π^k`
cancellation means the codec's scale factor drops out of the reconstruction, and the
decoded episode replays clean.

## 2. The fidelity ladder: sub-ULP at 24 bits

The codec is a knob, and the receipts walk it (`G-R2-FROB-PARITY`, `G-R2-FROB-AB`):

| variant | bit budget | reconstruction relative L2 | byte-exact coeffs | store size vs f32 |
|---|---|---|---|---|
| `a16` | 16 bit | 3e-5 | — | 2.0× (larger) |
| `a8b4` | 12 bit | 6e-4 | — | 2.86× (larger) |
| **`a16b8`** | **24 bit** | **1.2e-7 (sub-ULP)** | **18%** | **0.76× (smaller)** |
| `a16b16` | 32 bit | 8e-11 | 98.9% | larger |

The headline is `a16b8`: a **24-bit** rank-2 lattice code reconstructs the episode to
**relative L2 1.2e-7 — below the unit-in-the-last-place of the f32 it encodes** — with
**18% of coefficients reproduced byte-for-byte**, and it is **smaller than the raw f32
store (0.76×)**. The `T4` `π^k` scale is free and the decoded episode replays through
the paper-13 seam clean. At 32 bits (`a16b16`) the codec is **98.9% byte-exact** —
essentially the original tensor — at the cost of size. The codec is a real fidelity/size
ladder on the integer ring.

## 3. The honest scoping: the perplexity gate is blind here

This is the load-bearing methodology of the paper, and it is a *refusal* to overclaim.

The natural instinct is to gate the codec the way every prior memory result was gated:
replay the encoded episode and report the perplexity deflection. We ran it. On the 12B
wiki.tiny fixture, `n_scored = 42`:

- the **float-exact** episode replays at the baseline **4.6665 (`+0.000%`)** — as
  paper 11 already established for a matched-context verbatim replay;
- the **Frobenius variants** jitter **−2.27% … +3.37%**, and — the tell —
  **non-monotonically in fidelity**: a *more* faithful codec sometimes deflects *more*
  than a less faithful one.

A metric that moves non-monotonically with the quantity it is supposed to measure is
**not measuring that quantity**. The `n=42` single-chunk gate is **blind below ~1%**:
the deflections are tie-flip noise (paper 10's small-N illusion, paper 11's single-chunk
caveat), not a fidelity signal. So we **do not claim `+0.000%` for the codec.** The
codec's losslessness is established the only honest way — by **reconstruction fidelity**
(the relative-L2 and byte-exact-fraction numbers of §2, which are sub-ULP and
direct) — and the perplexity gate is reported as *blind at this resolution*, not as a
passing grade. A fake `+0.000%` from a blind gate would be exactly the kind of number
this series exists to refuse. Receipts: `G-R2-FROB-PARITY.log`, `G-R2-FROB-AB.log`.

## 4. The boundary: three measured negatives

The codec works because it is the integer container doing what it is good at — exact
arithmetic on a tensor. The temptation, again, is to push the algebra into the
*content*: to make the memory's structure itself number-theoretic. Three attempts, three
negatives, each kept on the record because each maps the boundary.

**(a) Entropy-coding the codes — 1.02×** (`G-R2-FROB-ENTROPY`). If the `a16b8` code has
number-theoretic structure, it should compress. It does not: `a16b8 + lzma` is **1.02×**
— essentially incompressible. The `b8` refinement residual is **incompressible by
construction** (it is the high-entropy tail of the tensor), and transpose/delta
reorderings do not help. The code is dense and near-random because the *content* it
encodes is. Receipt: `G-R2-FROB-ENTROPY.log`.

**(b) Möbius over the superposition — sheds memories** (`G-R3-MOBIUS`,
`tools/ring3/g_r3_mobius_probe.py`). The Ring-3 store `M` is dense — **99.6% nonzero** —
and the square-free density of its index is **60.94%**, which is *exactly* `6/π²`, the
real number-theoretic density of square-free integers. The structure is genuinely there.
But exploiting it via a Möbius/divisor reconstruction gives a divisor-recon error
**1.35× the signal** (worse than the signal it is reconstructing), and *masking* the
non-square-free part to compress the store **sheds memories**: recall **1.000 → 0.969 at
N=32** (multi-seed mean 0.988). The `6/π²` is real; using it costs recall. Receipt:
`G-R3-MOBIUS.log`.

**(c) `T2` on real model weights — recon ≈ random** (`G-T2-WEIGHTS`,
`tools/ring3/g_t2_weights_probe.py`). The most ambitious content-side idea was a `T2`
multiplicative-index transform: if a model's embedding rows are indexed by token id, and
token ids carry BPE-merge structure, maybe the weight matrix has a multiplicative
(Möbius-amenable) structure to exploit. Measured on the real **gemma-4-12B
`embed_tokens`** (V=262144, E=3840, bf16): the Möbius transform leaves **43.6% of the
energy non-square-free** (the proposal predicted ~0%), and a composite-row reconstruction
hits cosine **0.032 — against a random baseline of 0.039**. The reconstruction is
**indistinguishable from random**. Trained embeddings simply *do not* carry multiplicative
index structure; the BPE merge ranks are not a number-theoretic factorization. The
crucial honesty here: **`T2` was a design proposal, never validated** — unlike `T4`
(paper 03 / the `π^k` Frobenius lever), which *was* validated to 6 significant figures on
Gemma3-1B. This paper does not retroactively dignify a proposal by burying its
falsification; it states the falsification. Receipt: `G-T2-WEIGHTS.log`.

## 5. The boundary thesis, stated plainly

Put the four results side by side — the working codec of §2 and the three negatives of
§4 — and the line is sharp:

> **`O_K` wins on exact arithmetic (the container). It never wins on structuring the
> high-entropy content.**

The integer ring is the right home for *operations that must be exact and auditable*: the
bind (paper 16, 256/256 bit-identical, order-immune), the episode codec (this paper,
sub-ULP at 24 bits, smaller than f32). The moment the algebra is asked to find structure
*in the trained content itself* — to compress the codes, to sieve the superposition, to
factor the weights — it measures inert or worse, because the content is high-entropy and
has no number-theoretic structure to find. The structure that *is* there (`6/π²` in the
square-free density, lower coherence for `χ_d` carriers in paper 16) is real but
unexploitable: it is structure of the *carrier*, not of the *information*. The container
is the contribution; the content is, and stays, entropy.

## 6. Honest scope

- **Losslessness is reconstruction fidelity, not a perplexity pass.** §3 is explicit: the
  `n=42` gate is blind below ~1% and jitters non-monotonically; the codec is certified by
  relative-L2 / byte-exact-fraction, and *no* `+0.000%` is claimed from the blind gate.
- **The negatives are negatives.** Entropy-coding (1.02×), Möbius-on-`M` (sheds
  memories), and `T2`-on-weights (recon ≈ random) are falsified content-side ideas, kept
  on the record. `T2` in particular was a design proposal that never passed a gate, and is
  labelled as such — only `T4` (paper 03) was validated.
- **The `T2`-weights probe is on one tensor of one model.** gemma-4-12B `embed_tokens`;
  the claim is "trained embeddings lack multiplicative index structure," scoped to that
  evidence, not a theorem about all weight matrices.
- **One model, one host.** Gemma-4-12B (the B1 / OK_Q4B artifact of paper 06), RTX 2060
  12 GB; the codec parity is CPU. Proof-of-mechanism, not a scaling study, not
  multi-model, not independently reproduced.

## 7. Reproduction

Every number above is a row in [`LEDGER.md`](../../LEDGER.md) with model, fixture, flags,
gate, and commit attached. Gates run from the engine repo
([shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)),
`tools/curator/frob_episode.py` + `tools/ring3/{g_r3_mobius_probe,g_t2_weights_probe}.py`;
`gemma4_decode_cuda` is left byte-untouched.

| Gate | Driver | Expected | Receipt log |
|---|---|---|---|
| G-R2-FROB (codec) | `tools/curator/frob_episode.py` | `a16b8` relL2 1.2e-7 sub-ULP, 18% byte-exact, 0.76× store; `a16b16` 98.9% byte-exact; `T4` `π^k` free, replays clean | `tests/fixtures/xbar_r3/G-R2-FROB-PARITY.log`, `…/G-R2-FROB-AB.log` |
| G-R2-FROB (PPL is blind) | (same, `SP_REPLAY` + `SP_G4_SCORE`) | float-exact == baseline 4.6665 (+0.000%); frob variants jitter −2.27%…+3.37% **non-monotonically** → gate blind below ~1%, **no `+0.000%` claimed for the codec** | `tests/fixtures/xbar_r3/G-R2-FROB-AB.log` |
| G-R2-FROB-ENTROPY (neg) | (same + lzma) | `a16b8`+lzma 1.02×; `b8` residual incompressible; transpose/delta no help | `tests/fixtures/xbar_r3/G-R2-FROB-ENTROPY.log` |
| G-R3-MOBIUS (neg) | `tools/ring3/g_r3_mobius_probe.py` | dense `M` 99.6% nonzero; square-free density 60.94% (=6/π²); divisor-recon err 1.35× signal; masking sheds memories recall 1.000→0.969 @N=32 | `tests/fixtures/xbar_r3/G-R3-MOBIUS.log` |
| G-T2-WEIGHTS (neg) | `tools/ring3/g_t2_weights_probe.py` | gemma-4-12B `embed_tokens` (V=262144 E=3840 bf16): Möbius 43.6% energy non-square-free; composite-row recon cos 0.032 ≈ random 0.039 | `tests/fixtures/xbar_r3/G-T2-WEIGHTS.log` |

**Commit hashes.** Engine: `dbe4103` / `d076797` (G-R2-FROB codec — rank-2 `O_K` lattice
`a·s_a + b·s_b`, the `a16b8` sub-ULP point, `T4` `π^k` scale-cancellation), `e6d17bb`
(G-R2-FROB-ENTROPY — 1.02×, the incompressible residual), `1e70763` (G-R3-MOBIUS — the
`6/π²` density and the recall it costs), `ac76c8e` (G-T2-WEIGHTS — `T2` falsified on real
weights). The `T4` `π^k` Frobenius lever is paper 03's validated result; the `Q(√-163)` /
class-number-1 / `O_K = Z[ω]` (`ω² = ω − 41`) math is the production substrate.
Architecture: lattice `papers/CONTRACT-XBAR-R3-consolidation.md` + the C2 curator contract.

## Receipts

| Row | Receipt |
|---|---|
| X-OK-FROB | The Ring-2 episode store carried onto the integer `O_K` substrate, and the boundary the algebra draws. **Codec (`G-R2-FROB`):** rank-2 `O_K` lattice `x = a·s_a + b·s_b` (real scales) — `a16` (16b, relL2 3e-5, 2.0× store) / `a8b4` (12b, 6e-4, 2.86×) / **`a16b8` (24b, relL2 1.2e-7 SUB-ULP, 18% byte-exact, 0.76× store)** / `a16b16` (32b, 8e-11, 98.9% byte-exact); `T4` `π^k` scale free, replays clean. **Honest scoping:** the `n=42` single-chunk PPL gate is **blind below ~1%** — float-exact == baseline 4.6665, but frob variants jitter −2.27%…+3.37% **non-monotonically** in fidelity = tie-flip noise; losslessness is established by **reconstruction fidelity, NOT a fake `+0.000%`**. **Boundary negatives:** entropy-coding the codes **1.02×** (`b8` residual incompressible) — `G-R2-FROB-ENTROPY`; Möbius over the superposition **sheds memories** (dense `M` 99.6% nonzero; square-free density 60.94% = `6/π²` real but divisor-recon err 1.35× signal; masking recall 1.000→0.969 @N=32) — `G-R3-MOBIUS`; `T2` on real gemma-4-12B `embed_tokens` (V=262144 E=3840 bf16) recon cos **0.032 ≈ random 0.039** (Möbius 43.6% energy non-square-free vs claimed ~0%; `T2` was a *design proposal, never validated* — unlike `T4`) — `G-T2-WEIGHTS`. **Boundary thesis: `O_K` wins on exact arithmetic (the container), never on structuring high-entropy content.** 12B-b1, RTX 2060 12 GB, codec parity CPU. Open: the `T4` `π^k` codec on the 9.4 GB model weights (the one validated content-side lever, untouched) |

Companions: paper 03 / Frobenius quant (the validated `T4` `π^k` lever this codec reuses,
and the contrast that makes the `T2` falsification honest), paper 16 / X-OK-BIND (the
integer bind, and the Leg-B `χ_d` carrier negative this paper's boundary thesis
generalizes), paper 13 / X-222 (the replay seam the decoded episode lands through), paper
11 / X-R3 (the single-chunk deflection caveat that makes the `n=42` gate blind here),
paper 10 (the no-fake-zero, honest-negative discipline that is the spine of §3–§4).
