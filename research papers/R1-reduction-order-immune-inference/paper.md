---
type: research-paper
title: "Reduction-Order-Immune Inference: an exact-integer, deterministic Gemma-4-12B forward pass"
description: A full-length preprint making the entire Gemma-4-12B forward pass exact-integer so its output is reduction-order-immune (cross-hardware deterministic) by construction, vs order-pinned float determinism.
resource: ./provenance.md
tags: [research-paper, determinism, exact-integer, byte-exact, gemma4, inference]
timestamp: 2026-06-18T00:00:00Z
sp_status: DRAFT
sp_gate: G-BYTEEXACT-FORWARD-12B
sp_commit: 69c0588, d9d96f3
sp_repro: ninja -C build-cuda test_gemma4_ppl_cuda (see Appendix: Reproduction)
---

# Reduction-Order-Immune Inference: an exact-integer, deterministic Gemma-4-12B forward pass

**Authors:** [Shannon-Prime — author list TBD]

> **DRAFT / preprint — not yet submitted.** Numbers below are gated on a single dev host
> (RTX 2060, 12 GB) at small N; every figure carries its scope. See §5 for the honest
> negatives, including the one external check that remains open.

---

## Abstract

Large-language-model inference is, in practice, non-deterministic: the same prompt at
temperature 0 can yield different token streams across runs, batch sizes, or hardware, because
floating-point reductions are not associative and their order is not pinned. The current
state of the art removes the *run-to-run* and *batch-size* variance by making the floating-point
kernels **batch-invariant** — pinning the reduction order so a given engine reproduces itself on
the same hardware (He et al., 2025). That guarantee is, by construction, *engine- and
hardware-local*: it pins one order; it does not make the result independent of order.

We take the complementary route. We make the entire Gemma-4-12B forward pass **exact-integer**,
so that its output is **reduction-order-immune by construction** rather than order-pinned: any
reordering of any reduction is bit-identical because every reduction is an exact integer sum, and
every transcendental is a deterministic, `libm`-free integer function. The four nonlinear "fp32
islands" — RMSNorm, softmax, GELU-tanh, and RoPE — become exact-integer fixed-point kernels
(RMSNorm via an int64 sum-of-squares and an integer `isqrt`; softmax/GELU via an integer
`2^x` polynomial; RoPE via a deterministic fixed-point CORDIC, with **no** `sin`/`cos`/`exp`
from `libm`). Attention's Q·K and p·V dot products move to an exact-integer dual-prime negacyclic
convolution (two frozen Proth primes whose product fits a `u64`, so no 128-bit arithmetic is
required on the device). The whole exact-integer path sits behind a default-off flag
(`SP_BYTEEXACT`); with the flag off the forward is **byte-identical** to the bf16-gold baseline.

On the real Gemma-4-12B (a 4-bit OK_Q4B artifact) on a single RTX 2060, the gate
**G-BYTEEXACT-FORWARD-12B** reports: flag **off** → perplexity 4.6665, *byte-identical* to the
baseline (the null floor); flag **on** → 4.6569 (parity; −0.21% at n = 42 scored positions,
within small-N noise); and the flag-on run is **run-to-run bit-identical**. A universal Rust
daemon drives the 12B end to end over a C ABI — prefill and token-by-token decode — with a flat,
O(1) resident KV cache. We position this as a step toward *portable bit-identical inference*
(cross-hardware reproducibility by construction) as distinct from *same-engine reproducibility*
(order-pinned floats). We are explicit about what is not yet shown: the cross-hardware claim
awaits a true two-physical-GPU logit check; PPL parity is at n = 42; and the per-token speed cost
of the exact-integer path is not yet measured.

---

## 1 Introduction

A trained model is a deterministic function on paper. In deployment it is not. At temperature 0
— greedy decoding, no sampling — practitioners routinely observe that the same prompt produces
different completions across runs, across batch sizes, and across hardware. The cause is not the
sampler; it is the arithmetic. Floating-point addition is not associative: `(a + b) + c` and
`a + (b + c)` can differ in the last bits. Modern inference kernels reduce over thousands of
terms (the hidden dimension, the context length, the vocabulary) and the order in which those
terms are summed depends on the launch configuration — the number of thread blocks, the split-K
strategy, the batch size, the GPU's SM count, the libm implementation of `exp`/`sin`/`cos`. Two
machines, or one machine under two batch sizes, take different reduction orders and therefore
produce different logits, and a single differing bit at an argmax tie flips a token and, from
there, the whole continuation.

This matters beyond reproducibility hygiene. Auditability — being able to say "this model, on
this input, produces *exactly* this output, and you can check it" — requires that the output be a
deterministic function of (weights, input), not of the accelerator that happened to run it.
Regression testing, debugging, safety evaluation, and any setting where a third party must verify
a claim all degrade when "the model's output" is really "the model's output on this engine, this
GPU, this batch size."

There are two ways to remove the variance.

**Order-pinning (the current SOTA).** Fix the reduction order so that, for a given engine on a
given class of hardware, the kernels always sum in the same sequence regardless of batch size.
This is the approach of Thinking Machines' *Defeating Nondeterminism in LLM Inference*
(He et al., 2025), which makes the matmul, attention, and normalization kernels
**batch-invariant**. It is real and it is shipping (the technique is now available in SGLang and
vLLM). But it is, by design, *local*: it pins **one** order, the engine's. It does not make the
result independent of order, so it does not by itself give bit-identical logits **across
hardware** or across engines that pin a different order, and the batch-invariant kernels carry a
reported throughput cost (on the order of tens of percent).

**Order-immunity (this paper).** Make the arithmetic *exact*, so there is no order to pin: an
exact integer sum is associative, so *any* reduction order yields the *same* bits. If, in
addition, every transcendental is a deterministic integer function — not a call into a
platform's `libm` — then the entire forward is a deterministic function of (weights, input) and
nothing else. This is reduction-order-immunity by construction, and it is the precondition for
*portable* bit-identical inference: the same logits on any ALU that implements the same integer
operations, independent of FMA contraction, accumulation width, or transcendental
implementation.

This paper reports the second route carried end to end on a real 12-billion-parameter model. Our
contributions:

1. **The four nonlinear "fp32 islands" made exact-integer and `libm`-free.** RMSNorm, softmax,
   GELU-tanh, and RoPE — the points where a quantized-integer inference engine otherwise drops
   back to float — are replaced by exact-integer fixed-point kernels with deterministic integer
   transcendentals (integer `isqrt`; a `2^x` integer polynomial for `exp`/`tanh`; a fixed-point
   CORDIC for `cos`/`sin`). These are the genuinely new piece (§3.2).
2. **Attention as an exact-integer dual-prime negacyclic dot product**, using two frozen Proth
   primes whose product fits a 64-bit word, so the device never needs 128-bit integers (§3.3).
3. **End-to-end realization on the real Gemma-4-12B**, behind a default-off flag whose off-path
   is byte-identical to the bf16-gold baseline, with a universal daemon driving prefill and
   token-by-token decode over a C ABI at flat O(1) KV (§3.4, §4).
4. **A clean framing of the contribution relative to the SOTA:** portable, cross-hardware
   bit-identicality *by construction* versus same-engine reproducibility *by order-pinning*
   (§2, §6), together with an honest statement of the one external check still open (§5).

We are deliberately precise about a de-conflation that organizes the whole effort: **byte-exact
here means exact arithmetic and determinism, not compression.** Separate work in this project
convicted the structure-on-content compression levers as redundant against the existing per-block
4-bit quantization; this paper is about the *container's* exactness, not about making the model
smaller. The distinction is load-bearing and we restate it where it matters.

## 2 Background & Related Work

**Non-determinism in LLM inference.** The defining recent treatment is He, Murthy, et al.,
*Defeating Nondeterminism in LLM Inference* (Thinking Machines, 2025). It identifies the primary
culprit not as concurrency races but as **batch-size-dependent reduction order**: the kernels a
server uses are not invariant to how requests are batched, so the same request reduces in a
different order depending on what else is in the batch, and floating-point non-associativity turns
that into different logits. Their fix is **batch-invariant kernels** for matmul, attention, and
RMSNorm that fix a single reduction order independent of batch size; combined with deterministic
launch, this yields run-to-run and batch-independent reproducibility on a given engine and
hardware class. The reported cost is a throughput regression (roughly on the order of tens of
percent in their setting). Follow-on work studies the same axis from the verification side
(e.g., DiFR, *Detecting Inference Forgery / numerical-divergence checks*, arXiv:2511.20621),
treating numerical divergence as a signal.

Our work is **complementary, not competing**. Order-pinning fixes *which* order; we remove the
*dependence on order*. The practical difference is the scope of the guarantee: order-pinning
gives same-engine, same-hardware reproducibility (and is already deployed); exact-integer
arithmetic aims at cross-hardware bit-identicality by construction, at the cost of building
exact-integer replacements for the float operations (and at a per-token speed cost we have not
yet measured — see §5). We see the two as points on a spectrum: pin the float order when you
control the engine; go exact-integer when you need the result to be portable and auditable
independent of the engine.

**Integer-only inference.** Integer/quantized inference has a long line (e.g., Jacobin et al.'s
integer-arithmetic-only quantization for efficient inference; the broad int8/int4 quantization
literature). Our use of integers is for a *different end*: not (only) efficiency, but
**exactness and determinism**. Critically, prior integer-inference work typically still computes
the nonlinearities (normalization, softmax, activations, positional rotation) in float, or in a
quantized form that is not bit-reproducible across libraries. Making those four nonlinearities
exact-integer and `libm`-free is the part that is, to our knowledge, not standard.

**Exact / verifiable arithmetic substrates.** Number-theoretic transforms over prime moduli and
CRT reconstruction (Garner's algorithm) are classical tools for exact integer convolution; we use
a dual-prime negacyclic NTT for the attention dot products. CORDIC (Volder, 1959) is the classical
shift-and-add method for computing trigonometric functions in integer hardware without a table of
products; we use it to make RoPE's rotation deterministic and `libm`-free. These are old, robust
building blocks; the contribution is wiring them into a complete modern transformer forward and
gating the result on a real 12B model.

**A cautionary note that motivated this work.** During this effort we found that a widely used
open-source inference engine produced a Gemma forward roughly **100× off** in perplexity (PPL on
the order of 397–505 versus our bf16-gold reference of ≈4.68 on the same evaluation), traced to a
corruption in a GGUF weight conversion rather than to the engine's arithmetic. The episode is a
direct argument for *exact, auditable reference forwards*: when the reference itself can be
silently broken by a format conversion, "matches the reference" is only as trustworthy as the
reference, and a bit-exact, deterministic forward is the floor you check everything else against.
This is anecdotal and specific to one artifact; we report it as motivation, not as a benchmark.

## 3 Method

### 3.1 Setup and the default-off discipline

The substrate is a 4-bit, per-32-block quantized Gemma-4-12B artifact (`gemma4-12b-b1.sp-model`,
the project's OK_Q4B container, ≈9.4 GB, which fits the 12 GB RTX 2060). The baseline forward
runs the **linear algebra** already in exact integer form — the 4-bit × 8-bit → int32 dot-product
accumulate (dp4a) is an integer reduction and is order-immune — but performs four nonlinear
operations in float: RMSNorm, softmax, GELU-tanh, and RoPE, plus the attention Q·K/p·V dot
products and the logit softcap. These are the "fp32 islands."

All exact-integer work sits behind a single environment flag, `SP_BYTEEXACT`. A device constant
`d_bx_flag` is set **once** at the decode entry (copied from the environment *before* CUDA-graph
capture, so the captured graph bakes in the chosen path). Each float island kernel gains a guard
of the form `if (d_bx_flag) { …integer path…; return; }` ahead of its unchanged float body.
**With the flag off, the float path runs untouched** — this is the *null floor*, and a hard gate
requires it to be byte-identical to the pre-existing baseline (§4, Leg A). Nothing about the
default-off behavior changes.

### 3.2 The four nonlinear islands, exact-integer and `libm`-free

The four islands are defined as host-runnable scalar references in the project's universal Rust
crate (`tools/sp_dsp_smoke/src/sp_islands_q_ref.rs`); the CUDA kernels reproduce them bit-for-bit
in their integer arithmetic. The fixed-point layout is frozen: fractional bits FB = 30 for the
`exp`/`tanh` primitive; RMSNorm uses Q = 16 input / IB = 20 internal / Qw = 16 weight scaling.

**RMSNorm.** `y[i] = x[i] · √(n / Σx²) · (w[i] ? w[i] : 1)`. The sum of squares `Σx²` is computed
as an **exact int64/int128 reduction** (hence reduction-order-immune), and `1/√` is an **integer
inverse-square-root**: `inv = isqrt( (n << 2(Q+IB)) / Σx² )`, with `isqrt` the classical exact
integer square root. On the device this avoids 128-bit integers via a 64-bit isqrt split
(`num = (n << 50)/Σx²; val = num << 22; inv = bx_isqrt_u64(val)`). No `sqrtf`, no `rsqrtf`.

**softmax.** `p = exp(z − max) / Σ exp(z − max)`. Inputs are encoded fixed-point (Z = 2^14); the
exponentials use the shared integer `exp` primitive; the denominator is summed as an **exact
int128 integer** (order-immune); the divide is fixed-point. No `expf`.

**GELU-tanh** (the gemma activation, `0.5·x·(1 + tanh(√(2/π)·(x + 0.044715·x³)))`). The cubic and
the `tanh` are evaluated in FB = 30 fixed-point; `tanh` is built from the same `exp` primitive
(`tanh(t) = sign · (1 − 2e^{−2|t|}/(1 + e^{−2|t|}))`). On the device the wide products `X·X` and
`X·X·X` use `__umul64hi`-based `(a·b) >> FB` so that no 128-bit integer type is needed. It is a
deterministic per-element integer function.

**RoPE** via **CORDIC** (the one that most directly removes `libm` from the rotation). The fp32
RoPE bridge calls `sinf`/`cosf`, which are machine-dependent; we replace them with a rotation-mode
CORDIC — an integer shift-and-add iteration over a fixed `atan` table (`CORDIC_N = 30` stages, the
`atan(2^{−k})` table and the gain constant K stored as FB = 30 constants). The per-pair frequency
table `base^{−2i/d}` is a **model constant**, baked once as fixed-point and *stored, not
recomputed*, so the rotation is fully integer and deterministic. `θ` is reduced mod 2π into
`(−π/2, π/2]` (with a sign fold for the far quadrants) and rotated. No `sinf`/`cosf`.

The shared `exp` primitive is itself integer: `e^d` for `d ≤ 0` is computed via `2^x` with a
degree-6 polynomial whose coefficients are `round((ln2)^k/k! · 2^30)`, after splitting the
exponent into an integer part (a bit-shift) and a fractional part (the polynomial). Everything is
shifts, integer multiplies, and exact integer reductions.

The **logit softcap** (`k_softcap` at the LM head) likewise uses the integer `tanh`.

### 3.3 Attention as an exact-integer dual-prime negacyclic dot

The attention Q·K and p·V inner products move off float onto an **exact-integer negacyclic
convolution**: with values CKKS-style encoded to fixed-point integers, `⟨q, k⟩` is recovered
exactly as a coefficient of the negacyclic product `Q(x)·K(x̂)`. The arithmetic is carried over
**two frozen Proth primes** `q1 = 1073738753`, `q2 = 1073732609`; their product
`M = q1·q2 ≈ 2^60` fits a `u64`, and Garner CRT reconstruction (`q1^{-1} mod q2 = 894602413`)
recombines the two residue channels. Because `M ≈ 2^60` fits a 64-bit word, the device needs **no
128-bit integers**; wide products use `__umul64hi`. The p·V accumulator stays around `~2^46`,
comfortably below `M`, even at context length 16384, so the dual-prime modulus is sufficient
without a third prime. The CUDA decode uses an exact-integer windowed-attention kernel
(`k_attn_decode_win_bx`) on this substrate.

This linear-algebra layer was **not invented for this paper**: the dual-prime Barrett reduction,
the mod-q matmul, the Garner CRT, and the NTT ladder already existed and were bit-exact-gated in
the project's universal Rust crate (`tools/sp_dsp_smoke`). We re-use it; the new arithmetic here
is the nonlinear islands of §3.2 and the on-12B end-to-end realization.

### 3.4 Driving the 12B end to end: the universal daemon and the L1 ABI

A universal resident daemon (Rust, `tools/sp_daemon`) drives the real 12B through a C ABI ("L1"),
with CUDA registered as a backend. **Prefill** routes through a forward-backend registration hook
(`sp_session_register_forward_backend`); the gate **G-WIRE-CUDA-GEMMA4** confirms the daemon's
registered backend dispatches into the gemma4 CUDA forward on the real 12B (the forward-count
counter increments 0 → 1 on a `/v1/chat` call).

Token-by-token **decode** uses a new, additive L1 verb,
`sp_session_register_kvdecode_backend` — a *stateful, session-resident KV* decode hook (open /
prefill / decode_step / rewind / position / close) that the single-token decode call routes to.
The engine's CUDA decode (`gemma4_kv_decode_logits`) registers here. The gate
**G-WIRE-CUDA-DECODE-GEMMA4** drives 32 decode steps through the verb and checks the token stream
against the direct one-shot oracle: **32/32 tokens identical**, with **VRAM flat** between the two
paths (delta 0 MiB ⇒ an O(1) resident cache, not a growing one). The ABI growth is append-only —
no frozen surface was renumbered.

## 4 Results

All results are on a single dev host: **RTX 2060 (12 GB, sm_75)**, CUDA 13.2, `build-cuda-vs22`
(VS18 BuildTools), model **`gemma4-12b-b1.sp-model`** (OK_Q4B, ≈9.4 GB). Receipts-first: every
number below names its gate and its reproducing command. PPL is measured with NCTX = 84,
CHUNKS = 1, **n_scored = 42**.

### 4.1 On-model island fidelity — gate G-BYTEEXACT-ISLANDS-CUDA

Before wiring the integer islands into the forward, we verify that the exact-integer references
match the engine's actual float island outputs *on real 12B per-layer activations* (dumped from a
mid layer, layer 24, 16 tokens) and re-run through the crate's exact-integer references. Relative
error (`‖cuda − ref‖₂ / ‖cuda‖₂`), threshold `< 1e-4`:

| island | shape | relerr | verdict |
|---|---|---|---|
| RMSNorm | rows = 16, E = 3840 | **3.843e-5** | GREEN |
| GELU-tanh | rows = 16, ff = 15360 | **8.181e-7** | GREEN |
| RoPE (NEOX) | rows = 256, hd = 256 | **9.618e-6** | GREEN |
| softmax | (gated offline) | max\|Δp\| **1.3e-6** (< 1e-5) | GREEN |

The companion **host** gate G-ISLANDS-Q-REF (the crate's scalar references against float, on
synthetic inputs) reports RMS 5.8e-6 / softmax 1.3e-6 / GELU 2.8e-6 / RoPE 9.2e-6, all
**order-immune**. Receipt: `tests/fixtures/xbar_r3/G-BYTEEXACT-ISLANDS-CUDA.log`; host gate via
`cargo run --bin sp_islands_q_ref_test` (crate `tools/sp_dsp_smoke`).

### 4.2 The full integer forward — gate G-BYTEEXACT-FORWARD-12B

With the islands (and integer attention and softcap) wired into the gemma4 CUDA decode behind
`SP_BYTEEXACT`:

| leg | env | PPL | meaning |
|---|---|---|---|
| **A** | `SP_BYTEEXACT` unset | **4.6665** | == baseline, **byte-identical null floor** |
| **B** | `SP_BYTEEXACT=1` | **4.6569** | full integer islands, parity (−0.21% at n = 42) |
| **determinism** | `SP_BYTEEXACT=1`, run twice | 4.6569 == 4.6569 | **run-to-run bit-identical** |

Leg A is the hard constraint: default-off must be **exactly** the baseline (4.6665), and it is.
Leg B is a parity band; the −0.21% deflection is within the ±~1.5% small-N noise at n = 42 (and is
*tighter* than the attention-only datapoint of −1.28% / 4.6069, consistent with the islands'
~1e-5…1e-7 fidelity). The determinism leg is the key claim of this paper *on this machine*: the
flag-on run reproduces itself bit-for-bit, because the integer reductions are order-immune. This
run-to-run bit-identicality plus the reduction-order immunity is our **proxy** for cross-machine
bit-identicality; the true cross-machine check is §5. Receipt:
`tests/fixtures/xbar_r3/G-BYTEEXACT-FORWARD-12B.log`.

### 4.3 Driving the 12B over the C ABI

- **G-WIRE-CUDA-GEMMA4** (prefill): the universal daemon's registered §6 forward backend
  dispatches into `gemma4_forward_cuda` on the real 12B (`cuda_forward_count` 0 → 1 on a chat
  call). Receipt: `tests/fixtures/xbar_r3/G-WIRE-CUDA-GEMMA4.log`.
- **G-WIRE-CUDA-DECODE-GEMMA4** (token-by-token decode via the new persistent-KV verb): 32 decode
  steps through `sp_decode_step` → the registered kvdecode backend, **32/32 tokens identical** to
  the one-shot oracle; VRAM delta between the two paths **0 MiB** (flat ⇒ O(1) resident cache).
  Receipt: `tests/fixtures/xbar_r3/G-WIRE-CUDA-DECODE-GEMMA4.log`.

## 5 Limitations & Honest Negatives

We state these plainly because the framing of the paper (portable bit-identicality) is stronger
than what we have yet *externally* proven.

- **The cross-hardware claim is a proxy, not yet a measurement.** What we have shown on-machine is
  **run-to-run bit-identicality** plus **reduction-order immunity by construction**. The actual
  target — bit-identical logits across two **physically different** GPUs (or CPU vs GPU) — is
  **not yet measured**; it requires a second machine, which we do not currently have in the loop.
  The order-immunity argument is sound (exact integer reductions are associative; the
  transcendentals are deterministic integer functions with no `libm` dependence), but until a
  two-GPU logit-diff is run, "portable bit-identical" is a *construction-level* claim, not an
  *empirical cross-hardware* one. This is the single most important caveat.

- **PPL parity is at n = 42 (small N).** The −0.21% (Leg B) sits inside the ±~1.5% deflection band
  at this N; it is **not** evidence that the integer path is *better*, only that it is not
  measurably worse. A larger-N run is needed to tighten the parity band to a real number. The
  byte-identical null floor (Leg A) is N-independent and exact.

- **The per-token SPEED cost of `SP_BYTEEXACT` is unmeasured.** The order-pinning SOTA reports a
  throughput regression on the order of tens of percent; our exact-integer path's per-token cost
  is **TBD** and could be larger or smaller. We make no speed claim. (The default-off path carries
  zero cost by construction, since it is byte-identical to the unmodified float forward.)

- **The byte-exact LINEAR algebra pre-existed.** The dual-prime Barrett / mod-q matmul / Garner
  CRT / NTT ladder were already built and bit-exact-gated in the project's Rust crate
  (`tools/sp_dsp_smoke`). The genuinely new contributions of this paper are (a) the four nonlinear
  islands as exact-integer, `libm`-free kernels and (b) the on-12B, end-to-end realization and
  gating. We flag this so the reader does not over-credit the arithmetic substrate to this work.

- **Scope.** A single model (Gemma-4-12B, 4-bit OK_Q4B), a single GPU (RTX 2060, 12 GB, sm_75),
  one evaluation harness. Not scale-validated, not multi-model, not independently reproduced.

- **Exactness is not compression.** This paper is explicitly about the *exactness of the
  container*, not about making the model smaller. Separate work in the project measured the
  structure-on-content compression levers (incoherence rotation, column reordering, Möbius/entropy
  coding of the codes) as **inert** against the existing per-32-block 4-bit quantization, and kept
  them as honest negatives. We restate the boundary so the contribution is not misread as a
  quantization result.

## 6 Conclusion

Determinism in LLM inference can be achieved two ways: pin the floating-point reduction order
(same-engine, same-hardware reproducibility, deployed today, with a throughput cost), or remove
the dependence on order by making the arithmetic exact (reduction-order immunity by construction,
the precondition for portable, cross-hardware bit-identicality). We carried the second route
through a complete Gemma-4-12B forward: the four nonlinear fp32 islands become exact-integer,
`libm`-free kernels (integer `isqrt`, an integer `2^x`/`tanh` primitive, a fixed-point CORDIC for
RoPE); attention's dot products become an exact-integer dual-prime negacyclic convolution that
fits a 64-bit word; and the whole exact-integer path sits behind a default-off flag whose off-path
is byte-identical to the bf16-gold baseline. On the real 12B on a single RTX 2060, the flag-off
forward is byte-identical (PPL 4.6665), the flag-on forward is PPL-parity (4.6569 at n = 42) and
**run-to-run bit-identical**, and a universal daemon drives prefill and O(1) token-by-token decode
over a C ABI. The one external check that would upgrade "reduction-order-immune by construction"
to "empirically cross-hardware bit-identical" — a two-physical-GPU logit diff — remains open and
is the clear next step.

---

## Appendix: Reproduction

**Commits.** Engine `69c0588`; math-core submodule `d9d96f3`.
Build host: `build-cuda-vs22` (VS18 BuildTools + CUDA 13.2, sm_75, RTX 2060). Model:
`gemma4-12b-b1.sp-model` (+ `.sp-tokenizer`).

**Environment (forward gates):**
```
set SP_GEMMA4_SPMODEL=...\models\gemma4-12b-b1.sp-model
set SP_GEMMA4_SPTOK=...\models\gemma4-12b-b1.sp-tokenizer
set SP_PPL_TOKENS=tests\fixtures\ppl\wiki.tiny.g4tokens.txt
:: NCTX=84  CHUNKS=1  -> n_scored = 42
```

**G-BYTEEXACT-FORWARD-12B** (target `test_gemma4_ppl_cuda`):
```
build:  _bx_islands_build.bat        :: cmake --build build-cuda-vs22 --target test_gemma4_ppl_cuda
Leg A:  _bx_islands_legA.bat         :: SP_BYTEEXACT unset  -> PPL 4.6665 (byte-identical null floor)
Leg B:  _bx_islands_legB.bat         :: SP_BYTEEXACT=1, run twice -> 4.6569 == 4.6569 (bit-identical)
```
Receipt: `tests/fixtures/xbar_r3/G-BYTEEXACT-FORWARD-12B.log`.

**G-BYTEEXACT-ISLANDS-CUDA** (dump real 12B islands, then compare vs crate refs):
```
:: 1. dump (mid layer, 16 tokens)
set SP_G4_BX_DUMP=1
set SP_BYTEEXACT_DUMP=tests\fixtures\xbar_r3\bx_islands_12b.bin
build-cuda-vs22\tests\test_gemma4_cuda.exe
:: 2. gate vs the exact-integer references (host cargo, no CUDA)
cd tools\sp_dsp_smoke
cargo run --release --bin bx_islands_compare -- ..\..\tests\fixtures\xbar_r3\bx_islands_12b.bin
```
Receipt: `tests/fixtures/xbar_r3/G-BYTEEXACT-ISLANDS-CUDA.log`.

**Host island reference gate (G-ISLANDS-Q-REF):**
```
cd tools\sp_dsp_smoke
cargo run --bin sp_islands_q_ref_test
```
Reference source: `tools/sp_dsp_smoke/src/sp_islands_q_ref.rs`.

**G-WIRE-CUDA-GEMMA4** (daemon prefill) and **G-WIRE-CUDA-DECODE-GEMMA4** (daemon decode):
```
:: daemon, CUDA backend
set SP_DAEMON_BACKEND=cuda
sp_daemon.exe start --model gemma4-12b-b1.sp-model --tokenizer gemma4-12b-b1.sp-tokenizer --port 8092
:: decode gate binary
sp_wire_cuda_decode_gate
```
Receipts: `tests/fixtures/xbar_r3/G-WIRE-CUDA-GEMMA4.log`,
`tests/fixtures/xbar_r3/G-WIRE-CUDA-DECODE-GEMMA4.log`.

**Frozen constants** (for an independent re-implementation of the exact-integer path):
dual-prime Proth moduli `q1 = 1073738753`, `q2 = 1073732609`, `M = q1·q2 = 1152908312643096577`
(`≈ 2^60`, fits u64); Garner `q1^{-1} mod q2 = 894602413`. Fixed-point: FB = 30
(`exp`/`tanh`); RMSNorm Q = 16 / IB = 20 / Qw = 16; softmax Z = 2^14; GELU Z = 2^16. CORDIC: 30
stages, FB = 30 `atan(2^{-k})` table, gain K = 652032874.

**Related work referenced.** H. He, J. Murthy, et al., *Defeating Nondeterminism in LLM
Inference*, Thinking Machines, 2025 (batch-invariant kernels; now in SGLang/vLLM). DiFR /
inference-divergence detection, arXiv:2511.20621. B. Jacob et al., *Quantization and Training of
Neural Networks for Efficient Integer-Arithmetic-Only Inference*, CVPR 2018. J. Volder, *The
CORDIC Trigonometric Computing Technique*, IRE Trans. Electronic Computers, 1959. (Full citation
keys TBD at submission.)
