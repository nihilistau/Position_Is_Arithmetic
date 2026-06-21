---
type: log
title: "A byte-exact 12B forward pass on exact-integer math (field note, 2026-06-18)"
description: "What we did, in one sentence: we made the entire Gemma-4-12B forward pass byte-exact — bit-identical logits across reduction order and (the open external step) across machines — by killing the last fo"
tags: [log, byteexact]
timestamp: 2026-06-18T05:43:49Z
resource: ./posts/hf-post-2026-06-18-byteexact.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# A byte-exact 12B forward pass on exact-integer math (field note, 2026-06-18)

**What we did, in one sentence:** we made the *entire* Gemma-4-12B forward pass **byte-exact** — bit-identical logits across reduction order and (the open external step) across machines — by killing the last four floating-point operations in the pipeline and replacing them with deterministic exact-integer math on our own dual-prime substrate. All on a single RTX 2060, 12GB.

This is the forward-pass counterpart to the memory-tier work in **Papers 16–18**. Papers 16–18 carried XBAR's *memory* onto the exact-integer ring of `Q(√-163)`; **Papers 19–21** carry the *forward pass itself*. Receipts live in the engine repo under `tests/fixtures/` (engine `69c0588`, math-core submodule `d9d96f3`, pushed).

## The one-sentence "why"

**Byte-exact = auditability, not compression.** It means you can hash a forward's logits and have a second party, on different silicon, reproduce the same hash. Exact integer arithmetic is *reduction-order-immune* (sum the partial products in any order, get the same bits) and machine-deterministic. That is the deliverable. It does **not** make the model smaller or faster — and saying so loudly is half the point (Paper 21).

## What shipped (GREEN)

- **The four float "islands" are dead.** Our matmuls were already exact integer (Paper 06's dp4a accumulate is order-immune). But four nonlinear ops were still floating-point — **RMSNorm, softmax, GELU, RoPE** — and they were the *only* places a forward could still drift. All four are now deterministic fixed-point integer functions, matching float to `~1e-6`:
  - **RoPE** by a device **CORDIC** (shift-and-add vector rotation) — **no `sin`/`cos`, no `libm`**.
  - **RMSNorm** with the reciprocal-square-root by a **64-bit integer `isqrt` split** — no float `1/√`.
  - **softmax / GELU** via an integer `2^x` exp polynomial.
- **No `__int128`, anywhere.** The frozen dual primes give a CRT modulus `M = q1·q2 ≈ 2^60` that **fits in a `u64`** — deliberately, so the exactness is portable to hardware that lacks (or slows on) a 128-bit type. Wide products use the device `__umul64hi`.
- **The null floor holds.** `G-BYTEEXACT-FORWARD-12B`: with the exact path **OFF**, the forward is **byte-identical to the bf16 gold baseline at PPL 4.6665** (the one-shot decode is left untouched). With it **ON**, PPL is **4.6569** (parity, −0.21% at n=42), and **the ON run is run-to-run bit-identical** — the on-machine proxy for cross-machine determinism.
- **One substrate, every backend.** A universal Rust crate is both the orchestrator *and* the scalar **bit-exact reference** the C/CUDA/HVX backends gate to. Attention's `⟨q,k⟩` and `p·V` become an exact-integer dual-prime **negacyclic-convolution dot** (a single convolution coefficient *is* the plain dot) — and the `p·V` accumulator stays `~2^46 ≪ M` even at a 16384-wide window, so **two primes suffice, no third prime**.
- **The daemon drives the 12B, O(1).** A new L1 verb (`sp_session_register_kvdecode_backend` + `gemma4_kv_decode_logits`) lets the resident daemon decode the 12B token-by-token: **32/32 tokens bit-identical to the untouched oracle, with VRAM flat (O(1) resident cache)**.

## What didn't (and why that's the result)

The disappointments are load-bearing — they draw the boundary.

- **Compression was convicted.** Incoherence rotation (`~1.37×` @ int4) and column reordering (`~1.05×`) are both **redundant against our existing per-32-block `OK_Q4B`**, which already sits at gold PPL. Byte-exact does not buy smaller; we measured it and said so.
- **Structure-on-content is inert** (the same four negatives as Papers 16–17, now generalized): split-prime Dirichlet *carriers* lower coherence but don't help recall; Möbius over the memory superposition sheds memories; entropy-coding the Frobenius codes is `1.02×`; and `T2`-on-the-real-12B-embedding reconstructs at cosine **0.032 ≈ random**. `T2` was a *design proposal that never passed a gate* — unlike the validated `T4` Frobenius lever — and we state the falsification rather than bury it.
- **The honest negative about our own process:** the byte-exact *linear algebra* (dual-prime Barrett, mod-q matmul, Garner CRT, the NTT ladder) was **already in the bounded crate, bit-exact-gated**. The campaign's offline prototypes re-derived it from scratch — the one wasted motion of the session, kept on the record as the lesson: *verify against the substrate before rebuilding it.*

## The honesty notes that matter

- **The PPL parity is `n=42`** — a single small chunk. The OFF byte-identity and the ON run-to-run identity are *exact*; the −0.21% ON deflection is at the edge of what 42 tokens can resolve, so it is **not** a quality claim.
- **The one remaining gap is external:** a literal bit-identical logit comparison across **two physical GPUs** needs a second machine. On one card we prove run-to-run identity and reduction-order immunity — the cross-machine check is named as open.

## The boundary thesis (the keystone)

The discrete algebra is an unmatched **container** — exactness, bit-reproducibility, reduction-order immunity — and it is now the home of both the memory tier *and* the forward pass. But a neural network's high-entropy *content* must be allowed to stay unstructured. **Use the algebra for the arithmetic, never for the meaning.** That is what the convicted compression levers and the four inert content-side experiments, taken together, actually prove.

## Next

The one *validated* content-side lever we have **not** yet pulled: **T4 Frobenius `π^k` quantization of the 9.4GB model weights themselves** — the theorem that *did* pass its gate (Paper 03), applied to the model rather than the memory. That is the test that matters next.

---

*Shannon-Prime is a receipts-first project: no number without a reproducing command. Negatives stay attached. See Papers 19–21 and the [`LEDGER.md`](../LEDGER.md).*
