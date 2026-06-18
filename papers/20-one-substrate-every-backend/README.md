# 20 — One substrate, every backend: the universal crate, the CRT-NTT attention, and an O(1) 12B decode through the daemon *(written, citable — X-BX-WIRE)*

> **STATUS: written — [`paper.md`](paper.md) complete.** Front-door receipts measured
> + gated (ledger **X-BX-WIRE**).

> **Front-door receipt (measured + gated 2026-06-18, ledger X-BX-WIRE):** paper 19 made the
> four nonlinear islands exact-integer; this paper is the architecture that makes that
> exactness mean the same thing on every backend, and the bridge that drives a real 12B
> through it. **(1)** A universal Rust crate (`tools/sp_dsp_smoke`) is both the L2 orchestrator
> *and* the scalar bit-exact reference for the whole linear algebra (dual-prime Barrett, mod-q
> matmul, Garner CRT, NTT ladder — each bit-exact-gated); C / CUDA / HVX backends are correct
> iff they gate to it. **(2)** Attention's `⟨q,k⟩` / `p·V` become an exact-integer dual-prime
> **negacyclic-convolution dot** (`⟨q,k⟩ = coeff_{N-1}(Q·K̂)/Δ²`; on the 12B = `k_attn_decode_win_bx`);
> `G-BYTEEXACT-ATTN-{NTT,FULL}` GREEN, and the `p·V` accumulator stays **`~2^46 ≪ M`** at W up to
> 16384 ⇒ **no third prime**. **(3)** The daemon drives the 12B over the L1 C ABI — prefill via
> `sp_session_register_forward_backend` (`G-WIRE-CUDA-GEMMA4`), decode via the new L1 verb
> `sp_session_register_kvdecode_backend` + `gemma4_kv_decode_logits`: `G-WIRE-CUDA-DECODE-GEMMA4`
> GREEN — **32/32 tokens bit-identical to the null-floor oracle, VRAM flat (O(1) resident cache)**.
> 12B-b1, one RTX 2060.

## The claim this paper makes

Exactness is only worth something if it is the *same* exactness on every backend — so the
architecture is one canonical bit-exact reference (the universal crate) that the C / CUDA / HVX
backends gate to. Attention's two inner products join the exact-integer substrate through a
negacyclic-convolution identity (a single convolution coefficient *is* the dot), and the
dual-prime container holds the `p·V` accumulate without a third prime. And the resident daemon
drives the whole 12B — prefill and a new token-by-token decode verb — producing tokens
bit-identical to the untouched oracle with a flat (O(1)) KV cache.

## What's in it (the map)

1. **The problem a universal substrate solves** — why one reference, not per-backend re-impls.
2. **One reference, many backends** — the crate as L2 orchestrator + bit-exact reference (and
   the honest lesson: the linear algebra already lived here, bit-exact-gated — the offline
   re-derivation was the wasted motion).
3. **Attention as an exact-integer convolution** — `⟨q,k⟩ = coeff_{N-1}(Q·K̂)/Δ²`; `p·V`
   `~2^46 ≪ M` at W≤16384 ⇒ no third prime (`G-BYTEEXACT-ATTN-{NTT,FULL}`).
4. **The daemon drives the 12B** — prefill (`G-WIRE-CUDA-GEMMA4`) + the new kvdecode verb
   (`G-WIRE-CUDA-DECODE-GEMMA4`: 32/32 bit-identical, O(1) VRAM).

## Honest scope

Proof-of-mechanism, **one model (12B-b1), one host (RTX 2060)**. The decode bit-identity is
32/32 tokens vs the oracle on *this* host — the **two-physical-GPU** check is the open external
step (paper 19). "O(1) VRAM" is the **KV-cache term** (the harness still carries the resident
model, as in paper 08). "No third prime" is measured at **W ≤ 16384**. The byte-exact linear
algebra already existed in the crate; the offline re-derivation is kept on the record as the
campaign's one redundant step.

## Status

**Paper written/complete** ([`paper.md`](paper.md)) — citable via ledger **X-BX-WIRE**.
Front-door receipts measured + gated in
[shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)
(reference `tools/sp_dsp_smoke`; attention + wire gates in the CUDA forward and the daemon;
receipts `tests/fixtures/xbar_r3/`); commits engine `69c0588`, math-core submodule `d9d96f3`;
architecture in lattice `papers/CONTRACT-BYTEEXACT-forward.md` §5.1–§5.2 + the L1-ABI / daemon
contract. Companions: 19 (the four exact-integer islands this carries across backends), 06 (the
CRT-NTT engine + `OK_Q4B` the crate references), 09 (the resident daemon this decode verb
extends), 08 (the O(1) KV term, here through the daemon path), 21 (the re-derivation lesson).
