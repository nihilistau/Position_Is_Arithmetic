---
type: research-paper
title: "The Boundary Thesis: algebra rules the container, statistics rule the payload"
description: A negative-results preprint reporting a sustained falsification of usable number-theoretic structure in trained Gemma-4-12B content, vs the algebra winning decisively on the exact-arithmetic container.
resource: ./provenance.md
tags: [research-paper, boundary-thesis, negative-results, mobius, falsification, gemma4]
timestamp: 2026-06-18T00:00:00Z
sp_status: DRAFT
sp_gate: G-T2-WEIGHTS
sp_commit: ac76c8e, d7d96fe, 1e70763, e6d17bb
sp_repro: SP_R3_LIB=... python3 tools/ring3/g_t2_weights_probe.py (see Appendix: Reproduction)
---

# The Boundary Thesis: algebra rules the container, statistics rule the payload — a falsification register for number-theoretic structure in trained transformers

**Authors:** [Shannon-Prime — author list TBD]

> **DRAFT / preprint — not yet submitted.** This is a *negative-results* paper. Every
> conviction below is gated on a single model family (Gemma-4-12B) at the project's scales on a
> single dev host (RTX 2060, 12 GB); each figure carries its scope. The boundary we report is an
> *empirical principle*, not a theorem. See §5.

---

## Abstract

There is an active line of work asking whether trained transformer weights hide deep
mathematical, symmetry, or number-theoretic structure — structure that, if found, could be used
to compress, factor, or interpret the model. We report a sustained, multi-datapoint attempt to
*use* such structure on a real 12-billion-parameter model, and a clean falsification of it. The
organizing finding is a sharp boundary, which we call the **Boundary Thesis**: exact
number-theoretic arithmetic is a near-perfect **container** for LLM inference — the substrate wins
decisively when it supplies *exact, order-independent arithmetic* (the bit-identical forward of
our companion R1, the exact-integer holographic bind of our companion R4) — but imposing
number-theoretic *structure on the trained, high-entropy content* (the weight matrices, the
embedding table, the superposed memory store) is **measured inert**. We document the falsification
register in full. The lead case: a multiplicative-index (Möbius / `T2`) transform on the real
Gemma-4-12B embedding table reconstructs at cosine **0.032** against a random baseline of
**0.039** — *indistinguishable from random*. The mechanism is simple and, in hindsight,
predictable: byte-pair encoding assigns token IDs by *frequency rank*, not by algebra, so token
6 is not a multiplicative function of tokens 2 and 3, and any multiplicative structure imposed on
the ID axis aliases pure statistical noise. Four further levers are convicted with their
receipts: split-prime `O_K` Dirichlet-character carriers (operationally inert), Möbius over the
memory superposition (sheds memories, recall 1.000 → 0.969 at N = 32), entropy-coding the
Frobenius residual codes (1.02× — dead weight), and two weight-transcode tricks (incoherence
rotation ~1.37× @ int4, column reordering ~1.05×, both redundant against the existing per-32-block
4-bit quantization at gold perplexity 4.6665). We contrast each negative with the *same algebra
winning on the container*, and distill a reusable design boundary: **use the algebra for the
arithmetic, never for the meaning.** We are explicit that these are negatives on one model family
at our scales; the boundary is an empirical principle whose value is precisely that it is falsified
cleanly and kept on the record.

---

## 1 Introduction

A trained large language model is, to a number theorist, an irresistible object: nine billion
floating-point numbers arranged in matrices, indexed by integer token IDs, transformed by
operations that look — superficially — like the convolutions, rotations, and inner products that
number theory has exact, beautiful machinery for. It is natural to ask whether that machinery
*buys* anything: whether the weights factor, whether the embedding table has multiplicative
structure, whether a memory store of superposed vectors can be sparsified along a square-free or
Möbius axis, whether a number-theoretic *carrier* binds more cleanly than a random one. A growing
literature pursues variants of this question — hidden symmetry, algebraic structure, spectral or
arithmetic regularity in trained networks.

This paper reports what happened when a project whose entire substrate is exact number theory —
a dual-prime negacyclic number-theoretic transform, `O_K = Z[(1+√-163)/2]` arithmetic with class
number 1, the Frobenius lift — turned that machinery on the *content* of a real Gemma-4-12B and
asked it to pay. It did not pay. Across five distinct levers, structure imposed on trained content
measured inert or worse, while the *same algebra* was, in parallel, winning decisively wherever
it was used as an *exact-arithmetic container* rather than as a lens on meaning.

We call the resulting principle the **Boundary Thesis**:

> **Use the algebra for the arithmetic, never for the meaning.** Exact number-theoretic arithmetic
> is the right home for *operations that must be exact and auditable* — the forward pass, the
> holographic bind, the episode codec. The moment the same algebra is asked to find structure *in
> the trained content itself* — the weights, the embeddings, the superposed memories — it measures
> inert, because a neural network's high-entropy content has no number-theoretic structure to find.

This is not a defeatist claim. It is a *boundary*, and a useful one: it tells a practitioner
exactly where to spend the algebra (the container — see R1 and R4) and exactly where not to (the
content). The contribution of this paper is the falsification register itself — five clean,
receipted negatives — plus the design boundary they delineate. Our contributions:

1. **A multi-datapoint falsification** of number-theoretic *structure-on-content* in a trained
   12B transformer, each datapoint with a gate name and a reproducing command (§4).
2. **The lead case made mechanistic:** why a multiplicative-index transform on a BPE embedding
   table reconstructs at chance — token IDs are frequency-sorted, not algebraically related (§3.1,
   §4.1).
3. **The contrast that makes the boundary sharp:** the same algebra, used as an *exact-arithmetic
   container*, is decisive (the bit-identical forward; the exact-integer bind), so the inertness
   is specific to content, not a weakness of the algebra (§3.4, §4.6).
4. **A reusable design boundary** for anyone tempted to impose arithmetic structure on
   frequency-sorted or trained content (§6).

We state the load-bearing caveat up front: these are negatives measured on **one model family**
(Gemma) at the project's scales, on one host. The Boundary Thesis is an *empirical principle*, not
a proven theorem; its strength is that it is falsifiable and that we report the falsification
rather than the lone lucky positive.

## 2 Background & Related Work

**Structure in trained weights.** A substantial line of work probes trained networks for latent
mathematical regularity: symmetry and equivariance in learned representations, spectral structure
in weight matrices, algebraic or group-theoretic interpretations of learned features, and the
broad interpretability program of finding *exploitable* structure in what gradient descent
produced. The implicit hope across much of this work is that the structure, once found, is
*usable* — for compression, for editing, for understanding. Our contribution sits squarely against
the strong form of that hope on the *number-theoretic* axis specifically: we tried to use
multiplicative-index, Dirichlet-character, Möbius, and Frobenius-residual structure on real 12B
content, and report a clean falsification.

**Tokenization is frequency-sorted, not algebraic.** Byte-pair encoding (Sennrich et al., 2016;
the GPT-2/SentencePiece lineage) builds a vocabulary by greedily merging the most frequent
adjacent pairs; the resulting token IDs are, to first order, a *frequency rank*. There is no sense
in which token 6 is "token 2 times token 3." This is folklore among practitioners but is exactly
the mechanism that dooms a multiplicative-index transform on the embedding axis, and we make it
explicit and measure its consequence (§4.1).

**Quantization and transform coding.** Incoherence processing (rotating weights by a random
orthogonal / Hadamard transform so that outliers spread out, as in QuIP and the incoherence-based
quantization line) and activation-order / column-reordering (the act-order heuristic popularized
by GPTQ) are real, published levers that *do* help when applied to a naive quantizer. Our finding
is not that they do nothing in the abstract — it is that they are **redundant against a strong
baseline**: the project's per-32-block 4-bit quantization (`OK_Q4B`) already sits at gold
perplexity, so the marginal coding efficiency these transforms buy is already captured. This is a
scoped, baseline-relative negative, and we state it as such.

**Vector-symbolic / holographic memory.** The HDC/VSA literature (Kanerva; Plate's Holographic
Reduced Representations; the ACM Computing Surveys survey, doi 10.1145/3538531) supplies the
binding and superposition operations our memory tier uses. One tempting "structure-on-content"
move there is to sparsify or reweight the superposed store along a number-theoretic axis (a Möbius
/ square-free filter). We tried it and it sheds memories (§4.3). The *container* contribution —
exact-integer binding with reduction-order immunity — is the subject of our companion R4 and is a
*win*; it is the contrast that sharpens this paper's negatives.

**Honest-negative methodology.** Reporting falsifications as first-class results, with the same
receipt discipline as positives, is the stance of our companion R5 (receipts-first methodology).
This paper is, in a sense, the strongest instance of that stance: its entire contribution is a
register of things that did not work, kept because the boundary they map is more valuable than any
one of them would have been as a positive.

## 3 Method

### 3.1 The lead case: a multiplicative-index transform on the embedding table

The most ambitious content-side idea was a multiplicative-index transform (internally `T2`,
Möbius-family) on `embed_tokens`: treat the token-ID axis as a multiplicative structure and try to
express the embedding of a composite index as a function of the embeddings at its factors, then
reconstruct. The hypothesis is that if token IDs carried multiplicative meaning, this transform
would reconstruct the table at high cosine similarity from a compressed multiplicative basis.

The mechanism that determines the outcome is the tokenizer. BPE assigns IDs by *frequency of
merge*, so the integer 6 has no algebraic relationship to 2 and 3 — token 6 is simply the sixth
merge the BPE trainer happened to make. A multiplicative-index transform therefore correlates the
embedding axis against a structure the data does not possess; it aliases statistical noise. The
gate measures reconstruction cosine against a *random* baseline so that "indistinguishable from
random" is a measured statement, not an assertion.

### 3.2 The carrier and the superposition: Dirichlet characters and Möbius

Two memory-tier levers test whether making the *carrier* or the *store* number-theoretic helps.

**Split-prime `O_K` Dirichlet-character carriers (Leg B).** The holographic bind (R4) uses a
random ±1 (Rademacher) carrier. A number-theoretic alternative builds the carrier from Kronecker
characters `χ_d` walked along the Heegner ladder (`d = -67`, `d = -163`). Such carriers *are* more
nearly orthogonal — lower mutual coherence, in exactly the Weil-bound order — so the hypothesis is
better recall. We measure recall and the curator's actual address space.

**Möbius over the superposition.** The Ring-3 store superposes many episodes into one bounded
vector; its index density is genuinely square-free (`6/π²`). The hypothesis: filter or reweight
the store along a Möbius / square-free axis to shed redundancy without losing recall. We measure
recall at fixed N before and after.

### 3.3 The residual codes and the weight transcodes

**Entropy-coding the Frobenius codes.** The Frobenius integer episode store (companion R4 / the
project's `core/frobenius`) emits rank-2 `O_K` lattice codes (a coarse term plus a residual). The
hypothesis: the residual codes have exploitable redundancy, so a general-purpose entropy coder
(lzma over the `a16b8` codes) shrinks them. We measure the compression ratio.

**Incoherence rotation and column reordering on weights.** Two published quantization-assist
transforms — a random-orthogonal incoherence rotation before 4-bit quantization, and an
activation-order column permutation — applied *on top of* the production per-32-block `OK_Q4B`
artifact. The hypothesis: extra coding efficiency, possibly a 3-bit unlock. We measure the ratio
relative to the `OK_Q4B` baseline, which already sits at gold perplexity.

### 3.4 The contrast: where the algebra *does* win (the container)

The negatives are only interpretable against the positives. The *same* dual-prime negacyclic
CRT-NTT, the *same* `O_K` arithmetic, and the *same* exact-integer discipline are, in companion
work, decisive:

- **The exact-integer forward (R1).** Making the Gemma-4-12B forward exact-integer yields a
  reduction-order-immune, run-to-run bit-identical forward (PPL 4.6665 byte-identical with the
  flag off; 4.6569 parity with it on). The algebra wins because it is supplying *exact arithmetic*
  — the container.
- **The exact-integer holographic bind (R4).** The VSA bind re-carried onto the integer NTT is
  256/256 bit-identical to the native ring multiply and byte-identical across summation-order
  permutations (where the float bind drifts 4.44e-15). Again the win is *exact arithmetic*.

The contrast is the whole point: the identical algebra that is inert on content (this paper) is
decisive on the container (R1, R4). The boundary runs between *arithmetic* and *meaning*, not
between "good math" and "bad math."

## 4 Results

All probes are on Gemma-4-12B (the B1 / `OK_Q4B` artifact of the project's paper-06 lineage), RTX
2060 (12 GB, sm_75), except the memory-tier gates which also use a CPU `libsp.so` build of the
NTT/poly-ring core. Receipts-first: every number names its gate, its driver, and its commit. Logs
live under `tests/fixtures/xbar_r3/`.

### 4.1 The lead case — `T2` on the real embedding is indistinguishable from random (gate G-T2-WEIGHTS)

| probe | reconstruction cosine | random baseline | verdict |
|---|---|---|---|
| `T2` multiplicative-index on `embed_tokens` | **0.032** | **0.039** | **FALSIFIED** (≈ random) |

The reconstruction cosine (0.032) is *below* the random baseline (0.039): the trained embedding
carries no multiplicative-index structure to recover. The honest framing is part of the result —
`T2` was a **design proposal that never passed a gate** (unlike the validated `T4` Frobenius `π^k`
weight lever), so this is a stated falsification, not a buried one. Driver:
`tools/ring3/g_t2_weights_probe.py`. Receipt: `tests/fixtures/xbar_r3/G-T2-WEIGHTS.log`. Engine
commit `ac76c8e`.

### 4.2 Split-prime `O_K` Dirichlet carriers — lower coherence, operationally inert (Leg B)

The `χ_d` carriers are measurably more orthogonal, in the predicted Heegner order:

| carrier | mean coherence @ N = 64 (random pairs) |
|---|---|
| random ±1 | 0.0355 |
| `χ_d`, d = -67 | 0.0153 |
| `χ_d`, d = -163 | 0.0086 (Weil-bound territory) |

And yet recall is *worse*, not better. Two reasons, both measured: the periodic character carrier
has a spiky spectrum that hurts the unbind; and the curator's actual address space is a ~128-bit
SimHash that is **unchanged** by the carrier swap — the resolver lives in the projection-bit
space, not the carrier's correlation space, so it cannot even *see* the lower coherence. The
structure is real; the system has no mechanism to exploit it. Driver:
`tools/ring3/g_r3_bind_ok_leg_b.py`. Receipt: `tests/fixtures/xbar_r3/G-R3-BIND-on-OK-legB.log`.
Engine commit `d7d96fe`.

### 4.3 Möbius over the superposition — sheds memories (gate G-R3-MOBIUS)

The store's square-free density is genuinely `6/π²`, but exploiting it costs recall:

| store | recall @ N = 32 |
|---|---|
| baseline superposition | **1.000** |
| Möbius / square-free filtered | **0.969** |

Using the real structure *sheds* memories (1.000 → 0.969 at N = 32). The structure exists; reading
the store through it loses content. Driver: the `g_r3_mobius_probe`. Receipt:
`tests/fixtures/xbar_r3/G-R3-MOBIUS.log`. Engine commit `1e70763`.

### 4.4 Entropy-coding the Frobenius codes — dead weight (gate G-R2-FROB-ENTROPY)

| codec | ratio | verdict |
|---|---|---|
| `a16b8` Frobenius codes + lzma | **1.02×** | **dead weight** |

The quantization residual is incompressible noise: a general entropy coder gains 1.02×, i.e.
nothing. There is no redundancy left in the residual codes to exploit. Receipt:
`tests/fixtures/xbar_r3/G-R2-FROB-ENTROPY.log`. Engine commit `e6d17bb`.

### 4.5 Weight transcodes — redundant vs the per-block 4-bit baseline (gate G-WEIGHT-TRANSFORMS)

| lever | measured ratio | verdict |
|---|---|---|
| incoherence rotation @ int4 | **~1.37×** | **redundant** vs `OK_Q4B` (no 3-bit unlock on this axis) |
| column re-ordering (act-order) | **~1.05×** | **redundant** vs `OK_Q4B` |

Both are real transforms that help a *naive* quantizer; both are redundant against the production
per-32-block `OK_Q4B`, which already sits at **gold PPL 4.6665** (≈ 4.68). A transform that buys a
little extra coding efficiency on top of a baseline that is already at gold PPL buys nothing the
artifact does not have. The genuine 3-bit unlock — if it exists — is a *different axis* (QAT,
codebook, mixed-precision), explicitly out of scope here. This is a *baseline-relative* negative,
scoped to this artifact. Receipts: `tests/fixtures/xbar_r3/G-WEIGHT-{TRANSFORMS,FOLD-ORACLE}.log`.

### 4.6 The contrast — the same algebra winning on the container

For completeness, the positives that bound the negatives (full treatment in R1 and R4):

| use of the algebra | result | win/inert |
|---|---|---|
| exact-integer forward (container) | PPL off 4.6665 byte-identical / on 4.6569 parity, run-to-run bit-identical | **WIN** |
| exact-integer holographic bind (container) | 256/256 bit-identical to native ring multiply; byte-identical across 8 summation orders (float drifts 4.44e-15) | **WIN** |
| multiplicative-index on embedding (content) | recon cos 0.032 ≈ random 0.039 | inert |
| `χ_d` Dirichlet carriers (content) | coherence drops, recall worse | inert |
| Möbius on superposition (content) | recall 1.000 → 0.969 | inert (costs) |
| entropy-code Frobenius residual (content) | 1.02× | inert |
| weight transcodes (content) | ~1.37× / ~1.05× redundant vs `OK_Q4B` | inert |

The five content-side rows are this paper's falsification register; the two container rows are why
the register is interesting. Same algebra, opposite verdicts, divided exactly along the
arithmetic/meaning line.

## 5 Limitations & Honest Negatives

This is a negative-results paper, so "limitations" and "results" overlap by design; what follows
is about the *scope* of the falsification, not additional negatives.

- **One model family, the project's scales, one host.** Every probe is on Gemma-4-12B (4-bit
  `OK_Q4B`), on an RTX 2060 (and a CPU `libsp.so` for the memory gates). We have **not** tested
  other tokenizers, other model families, other scales. It is entirely possible that some model
  with a *deliberately algebraic* vocabulary, or a different training regime, would show
  exploitable content structure. Our claim is bounded: on a standard BPE-tokenized, gradient-
  trained transformer at these scales, number-theoretic structure-on-content measured inert.

- **The Boundary Thesis is an empirical principle, not a theorem.** We have a mechanism for the
  lead case (frequency-sorted token IDs) and a plausible mechanism for each other negative, but we
  do not *prove* that trained content can carry no number-theoretic structure. We report a clean,
  multi-datapoint falsification and a useful design boundary; we do not claim impossibility.

- **The weight-transcode negatives are baseline-relative.** Incoherence rotation and column
  reordering are *redundant against `OK_Q4B`*, not useless in general — they help a naive
  quantizer. Read against a weaker baseline the verdict would differ. The scope ("redundant vs the
  per-32-block 4-bit artifact at gold PPL") travels with the number.

- **Some structure is real but unexploitable, which is a subtler negative than "no structure."**
  The `χ_d` carriers genuinely lower coherence; the superposition store is genuinely square-free.
  The negative is that the *system has no mechanism to convert that structure into a win* (the
  curator's address space cannot see the carrier coherence; reading the store through Möbius sheds
  content). "Real but inert" is the honest characterization, and we keep it.

- **Recall figures are at small N.** The memory-tier recalls (N = 32, N = 64) are at the project's
  capacity scales; they are proof-of-mechanism, not capacity studies. The companion R4 states the
  capacity scope of the bind in full.

- **Not independently reproduced.** All gates are internal. The receipts (gate names, drivers,
  commit hashes, log paths) are provided precisely so that a third party *can* reproduce them; none
  has yet.

## 6 Conclusion

We set out to use number theory on the *content* of a real 12B transformer — its embedding table,
its weights, its memory store — and we report a clean, multi-datapoint falsification. The lead
case is the sharpest: a multiplicative-index transform on the embedding reconstructs at cosine
0.032 against a random 0.039, because byte-pair encoding sorts token IDs by frequency, not algebra,
so there is no multiplicative structure to find. Four further levers join it on the register —
Dirichlet-character carriers (inert), Möbius over the superposition (sheds memories 1.000 →
0.969), entropy-coding the Frobenius residual (1.02×), and two weight transcodes (~1.37× / ~1.05×,
redundant vs the 4-bit baseline at gold PPL).

The value of the register is the boundary it draws. The *same* algebra that is inert on content is
decisive on the container: the exact-integer forward (R1) is bit-identical and reduction-order
immune; the exact-integer bind (R4) is 256/256 bit-identical and order-immune. The line runs
between *arithmetic* and *meaning*. The reusable principle for anyone tempted to put number theory
inside a neural network: **use the algebra for the arithmetic, never for the meaning** — spend it
on the exact-arithmetic container, where it pays in auditability and determinism, and do not
expect it to find structure in frequency-sorted or gradient-trained content, where it aliases
noise. Intelligence, on this evidence, lives at the edge of chaos: high-entropy, unstructured
content held inside rigid algebraic order. The container is the contribution; the content is, and
stays, entropy.

---

## Appendix: Reproduction

**Commits.** The four content-side negatives: engine `ac76c8e` (`T2` on weights), `d7d96fe`
(split-prime `χ_d` carriers, Leg B), `1e70763` (Möbius-on-`M`), `e6d17bb` (entropy-on-Frobenius-
codes). The weight-transcode conviction: the `G-WEIGHT-*` receipts. The container contrast: engine
`69c0588` (byte-exact forward, R1) and `0019b86` (exact-integer bind, R4). The `OK_Q4B` per-32-
block artifact at gold PPL is the project's paper-06 `06-R10` lineage. Math-core submodule
`d9d96f3`.

**Gates and drivers.**

| Gate | Driver | Expected | Receipt log |
|---|---|---|---|
| G-T2-WEIGHTS | `python3 tools/ring3/g_t2_weights_probe.py` | `embed_tokens` recon cos **0.032 ≈ random 0.039** — `T2` falsified (design proposal, never validated) | `tests/fixtures/xbar_r3/G-T2-WEIGHTS.log` |
| G-R3-BIND-on-OK-legB | `SP_R3_LIB=… python3 tools/ring3/g_r3_bind_ok_leg_b.py` | `χ_d` coherence 0.0153 (d=-67) / 0.0086 (d=-163) < random 0.0355; recall worse, SimHash ~128 bits unchanged — INERT | `tests/fixtures/xbar_r3/G-R3-BIND-on-OK-legB.log` |
| G-R3-MOBIUS | `g_r3_mobius_probe` | recall sheds 1.000 → 0.969 @ N = 32 | `tests/fixtures/xbar_r3/G-R3-MOBIUS.log` |
| G-R2-FROB-ENTROPY | frob-entropy probe (`a16b8` codes + lzma) | 1.02× — incompressible residual, dead weight | `tests/fixtures/xbar_r3/G-R2-FROB-ENTROPY.log` |
| G-WEIGHT-TRANSFORMS | engine weight-transform probe | incoherence rotation ~1.37× @ int4 / column reorder ~1.05× — both redundant vs `OK_Q4B` (gold PPL 4.6665) | `tests/fixtures/xbar_r3/G-WEIGHT-TRANSFORMS.log` |
| G-WEIGHT-FOLD-ORACLE | (same, oracle fold check) | transforms add nothing the per-32-block `OK_Q4B` does not already have | `tests/fixtures/xbar_r3/G-WEIGHT-FOLD-ORACLE.log` |

**The container contrast (companion gates, full treatment in R1 / R4).** G-BYTEEXACT-FORWARD-12B
(off 4.6665 byte-identical / on 4.6569 parity / run-to-run bit-identical); G-R3-BIND-on-OK
(256/256 bit-identical to `sp_pr_mul`/NTT, byte-identical across 8 summation orders vs float drift
4.44e-15).

**Frozen constants** (for an independent re-implementation of the substrate): dual-prime Proth
moduli `q1 = 1073738753`, `q2 = 1073732609`, `M = q1·q2 = 1152908312643096577` (≈ 2^60, fits u64);
the ring `R_q = Z_q[x]/(x^N + 1)`, negacyclic, `N ∈ {128, 256, 512}`; `O_K = Z[(1+√-163)/2]`,
class number 1.

**Related work referenced.** R. Sennrich, B. Haddow, A. Birch, *Neural Machine Translation of Rare
Words with Subword Units* (BPE), ACL 2016. K. Schlegel, P. Neubert, P. Protzel, *A comparison of
vector symbolic architectures* / the HDC/VSA survey, ACM Computing Surveys (doi 10.1145/3538531).
T. Plate, *Holographic Reduced Representations*, IEEE TNN, 1995. The incoherence-processing
(QuIP-family) and activation-order (GPTQ) quantization lines for the weight-transcode baseline.
(Full citation keys TBD at submission.)
