---
type: paper-bite
title: "Byte-exact, not compression: the boundary thesis, the honest negatives, and a re-derivation kept on the record"
description: "Shannon-Prime release series, paper 21."
tags: [paper-bite, byte-exact, compression]
timestamp: 2026-06-18T05:40:57Z
resource: ./papers/21-byte-exact-not-compression/paper.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# Byte-exact, not compression: the boundary thesis, the honest negatives, and a re-derivation kept on the record

*Shannon-Prime release series, paper 21. Discipline: [METHODOLOGY.md](../../METHODOLOGY.md).
Every number below is a row in [LEDGER.md](../../LEDGER.md) with a command behind it.*

> **Front-door receipt (the reflective record, 2026-06-18, ledger X-BX-BOUNDARY).** Papers
> 19–20 made a 12B forward exact-integer and drove it through the daemon. This paper says what
> that did and — at equal length — what it did **not** do, because the de-conflation is the
> contribution. **Byte-exact buys *auditability*: exact arithmetic, reduction-order immunity,
> cross-machine determinism — not speed, and not size.** The compression levers that look
> adjacent were *convicted*: incoherence-rotation (`~1.37×` @ int4) and column-reordering
> (`~1.05×`) are both **redundant against the existing per-32-block `OK_Q4B`**, which already
> sits at gold PPL. And the same **boundary thesis** the memory papers found holds for the
> forward: `O_K` wins as the exact-arithmetic **container**; every attempt to make *content*
> number-theoretic is measured-inert — split-prime Dirichlet carriers, Möbius-on-`M`,
> entropy-on-the-Frobenius-codes, and `T2` on the real 12B embedding (recon cosine **0.032 ≈
> random**). Finally, the honest negative about our own process: the byte-exact **linear
> algebra was already in the bounded crate, bit-exact-gated**; re-deriving it offline was the
> campaign's one wasted motion, and it is kept on the record as the lesson it is.

## 1. The de-conflation

Two things wear similar clothes and were, until this set, easy to conflate:

- **Compression** — making the model *smaller*: fewer bytes per weight, fewer bytes on disk.
- **Byte-exactness** — making the forward *exact and reproducible*: bit-identical logits across
  reduction order and across machines.

They are different missions with different deliverables, and the byte-exact campaign (papers
19–20) is **only the second one**. It does not shrink the model. It does not speed it up.
Saying so loudly is the point of this paper, because the temptation — once you are doing
number theory on a neural network — is to assume the algebra must also be buying compression.
It is not. It is buying **auditability**: the property that you can hash a forward's logits and
have a second party, on different silicon, reproduce the same hash. That is what exact integer
arithmetic, reduction-order immunity, and cross-machine determinism add up to, and it is the
whole of what they add up to.

## 2. The compression levers were convicted

To keep the de-conflation honest we ran the obvious compression ideas and let the gates rule on
them. Both were **convicted as redundant** — not because they do nothing in the abstract, but
because the production artifact already captures the win they would offer:

| lever | measured | verdict |
|---|---|---|
| incoherence rotation @ int4 | `~1.37×` | **redundant** vs `OK_Q4B` (no 3-bit unlock on this axis) |
| column re-ordering | `~1.05×` | **redundant** vs `OK_Q4B` |

The reason both are redundant is the same: the existing **per-32-block `OK_Q4B`** quantization
(paper 06) already sits at gold PPL (`4.6665 ≈ 4.68`), so a transform that buys a little more
coding efficiency on top of it buys nothing the artifact does not already have. The genuine
3-bit unlock — if it exists — is a *different axis* (QAT / codebook / mixed-precision), not a
transcode trick, and is explicitly **out of scope** here (it is the operator's separate future
study). The point for *this* set: the compression levers adjacent to the byte-exact work were
tested and convicted, so the byte-exact result is not quietly smuggling a size claim. Receipts:
`tests/fixtures/xbar_r3/G-WEIGHT-{TRANSFORMS,FOLD-ORACLE}.log`.

## 3. The boundary thesis, now on the forward too

Papers 16–17 found a sharp line on the *memory* tier: `O_K` is an unmatched **container** for
operations that must be exact, but every attempt to make the memory's *content* itself
number-theoretic measured inert or worse. The byte-exact forward confirms the same line on the
*weights and activations* side. Put the negatives side by side:

- **Split-prime `O_K` Dirichlet carriers** (paper 16, Leg B). Number-theoretic `χ_d` *carriers*
  lower vector coherence in exactly the predicted Heegner order — and do not improve recall.
  Operationally inert.
- **Möbius over the superposition** (paper 17). The Ring-3 store's square-free density is
  genuinely `6/π²`, but exploiting it sheds memories (recall `1.000 → 0.969` at N=32). The
  structure is real; using it costs.
- **Entropy-coding the Frobenius codes** (paper 17). `a16b8 + lzma` is `1.02×` — the
  quantization residual is incompressible noise; there is nothing to compress.
- **`T2` on the real 12B embedding** (paper 17). The most ambitious content-side idea — a
  multiplicative-index transform on `embed_tokens` — reconstructs at cosine **0.032 against a
  random baseline of 0.039**: **indistinguishable from random.** Trained embeddings carry no
  multiplicative index structure. And the crucial honesty: `T2` was a **design proposal that
  never passed a gate**, unlike `T4` (paper 03 / the validated `π^k` Frobenius lever) — so the
  falsification is *stated*, not buried.

The thesis, stated once for the whole project:

> **Use the algebra for the arithmetic, never for the meaning.** `O_K` is the right home for
> *operations that must be exact and auditable* — the bind (paper 16), the episode codec
> (paper 17), and now the forward pass (papers 19–20). The moment the algebra is asked to find
> structure *in the trained content itself*, it measures inert, because a neural network's
> high-entropy content has no number-theoretic structure to find. Intelligence lives at the
> edge of chaos: unstructured content bound inside rigid algebraic order. The container is the
> contribution; the content is, and stays, entropy.

These negatives are not failures of the byte-exact campaign — they are its boundary, mapped, so
that the one thing the algebra *is* good for (exact arithmetic) is not over-sold into the one
thing it is *not* good for (structuring meaning).

## 4. The re-derivation: our own honest negative

The integrity of a receipts-first record includes the receipts about the *process*. So: the
byte-exact **linear algebra was already in the bounded Rust crate** (paper 20 §2). The dual-prime
Barrett reduction, the mod-q matmul, the Garner CRT reconstruction, and the NTT ladder were all
implemented and **bit-exact-gated** (`T_GARNER_BIT_EXACT` and siblings) before the byte-exact
campaign opened. The campaign's offline prototypes **re-derived that arithmetic from scratch** —
the one wasted motion of the session. The lesson is a standing one in this project and it is
worth stating as a result: *verify against the substrate before rebuilding it.* The genuinely
new substrate work of papers 19–20 was narrow and real — the four exact-integer **islands**
(RMSNorm, softmax, GELU, the CORDIC RoPE) and the **attention convolution** + the **kvdecode
verb** — and it sits *on top of* a linear-algebra reference that already existed. Keeping the
re-derivation on the record is the same discipline that kept the 32k MISS on paper 01's front
page and retired paper 06's first speed headline by its own PPL rule (paper 10): the
self-corrections are the evidence that the gates discriminate.

## 5. What discreteness does and does not buy — the ledger of it

| claim | byte-exact buys it? |
|---|---|
| reduction-order immunity (sum in any order → same bits) | **yes** — the integer accumulate, by construction |
| cross-machine determinism (same logits on different silicon) | **yes** in principle; the **two-physical-GPU check is the open external step** (papers 19–20) |
| run-to-run bit-identity on one host | **yes** — measured (`G-BYTEEXACT-FORWARD-12B`) |
| an auditable, hashable forward | **yes** — this is the deliverable |
| smaller model / fewer bytes | **no** — compression is a different mission; the levers were convicted (§2) |
| faster decode | **no** — exactness is the cost-neutral-to-slightly-costly deliverable, not a speedup |
| number-theoretic structure in the *content* | **no** — measured inert across four attempts (§3) |

## 6. Honest scope

- **This paper claims no new performance number.** It is the reflective record: the
  de-conflation, the convicted compression levers (§2, `~1.37×` / `~1.05×`, redundant vs
  `OK_Q4B`), the boundary thesis (§3, four inert content-side attempts), and the re-derivation
  lesson (§4). The forward's measured results are papers 19–20.
- **The negatives are negatives, kept attached.** Split-prime carriers, Möbius-on-`M`,
  entropy-on-codes, `T2`-on-weights — each measured-inert, each on the record. `T2` in
  particular was a *design proposal that never passed a gate* and is labeled as such.
- **The compression conviction is scoped to this artifact.** `~1.37×` / `~1.05×` are redundant
  *because* `OK_Q4B` already sits at gold PPL; the separate 3-bit-unlock axis (QAT / codebook /
  mixed-precision) is not addressed here.
- **One model, one host.** The forward and the boundary probes are on Gemma-4-12B (the B1 /
  `OK_Q4B` artifact of paper 06), RTX 2060 12 GB. Proof-of-mechanism, not a scaling study, not
  multi-model, not independently reproduced.

## 7. Reproduction

Every number above is a row in [`LEDGER.md`](../../LEDGER.md) with model, fixture, flags, gate,
and commit attached. The compression-conviction gates and the boundary probes run from the
engine repo ([shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine));
`gemma4_decode_cuda` is left byte-untouched.

| Gate | Driver | Expected | Receipt log |
|---|---|---|---|
| G-WEIGHT-TRANSFORMS (compression convicted) | engine weight-transform probe | incoherence rotation `~1.37×` @ int4 / column reorder `~1.05×` — **both redundant vs `OK_Q4B`** (gold PPL); no 3-bit unlock on this axis | `tests/fixtures/xbar_r3/G-WEIGHT-TRANSFORMS.log` |
| G-WEIGHT-FOLD-ORACLE | (same, oracle fold check) | the transforms add nothing the per-32-block `OK_Q4B` artifact does not already have | `tests/fixtures/xbar_r3/G-WEIGHT-FOLD-ORACLE.log` |
| G-T2-WEIGHTS (boundary, paper 17) | `tools/ring3/g_t2_weights_probe.py` | gemma-4-12B `embed_tokens`: recon cos **0.032 ≈ random 0.039** — `T2` (a design proposal, never validated) falsified on real weights | `tests/fixtures/xbar_r3/G-T2-WEIGHTS.log` |
| (boundary set, papers 16–17) | `g_r3_bind_ok_leg_b` / `g_r3_mobius_probe` / frob-entropy | `χ_d` carriers inert; Möbius sheds memories (1.000→0.969); entropy 1.02× | `tests/fixtures/xbar_r3/{G-R3-BIND-on-OK-legB,G-R3-MOBIUS,G-R2-FROB-ENTROPY}.log` |

**Commit hashes.** The byte-exact forward this paper reflects on is engine `69c0588` (math-core
submodule `d9d96f3`); the compression-conviction receipts are the `G-WEIGHT-*` logs; the four
content-side negatives are papers 16–17's (engine `d7d96fe` / `1e70763` / `e6d17bb` / `ac76c8e`).
The `OK_Q4B` per-32-block quantization at gold PPL is paper 06's `06-R10`. Architecture: lattice
`papers/CONTRACT-BYTEEXACT-forward.md` §0–§1 (the de-conflation) + the `CONTRACT-XBAR-R3` boundary
probes.

## Receipts

| Row | Receipt |
|---|---|
| X-BX-BOUNDARY | The reflective record of the byte-exact campaign — what discreteness buys and what it does not. **De-conflation:** byte-exact buys **auditability** (exact arithmetic, reduction-order immunity, cross-machine determinism), explicitly **not** speed or size. **Compression convicted:** incoherence rotation **`~1.37×`** @ int4 / column reorder **`~1.05×`**, **both redundant vs the per-32-block `OK_Q4B`** (already gold PPL 4.6665 ≈ 4.68); the 3-bit unlock is a separate axis (QAT/codebook/mixed-precision), out of scope — `G-WEIGHT-{TRANSFORMS,FOLD-ORACLE}`. **Boundary thesis (`O_K` is the container, never the content):** four measured-inert content-side levers — split-prime `O_K` Dirichlet carriers (paper 16 Leg B, coherence drops in Heegner order, recall unchanged), Möbius-on-`M` (paper 17, sheds memories 1.000→0.969 @N=32), entropy-on-Frobenius-codes (paper 17, 1.02×), and `T2` on the real gemma-4-12B `embed_tokens` (recon cos **0.032 ≈ random 0.039**; `T2` was a *design proposal, never validated*, unlike `T4`). **The re-derivation, kept on the record:** the byte-exact *linear algebra* (dual-prime Barrett / mod-q matmul / Garner / NTT) was **already in the bounded crate, bit-exact-gated** (`T_GARNER_BIT_EXACT` &c.) — re-deriving it offline was the campaign's one wasted motion; the genuinely new work was paper 19's four islands + paper 20's attention conv + kvdecode verb. 12B-b1, RTX 2060 12 GB. No new performance number claimed here — this is the honest-record paper |

Companions: paper 19 / X-BX-ISLANDS + paper 20 / X-BX-WIRE (the measured byte-exact forward this
paper de-conflates and bounds), paper 06 / 06-R10 (the `OK_Q4B` artifact that makes the
compression levers redundant), paper 16 / X-OK-BIND + paper 17 / X-OK-FROB (the four content-side
negatives this generalizes into the boundary thesis), paper 03 (the validated `T4` `π^k` lever
that makes the `T2` falsification honest), paper 10 (the receipts-or-it-didn't-happen discipline
this paper is, in the end, an instance of).
