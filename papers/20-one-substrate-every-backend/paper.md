# One substrate, every backend: the universal crate, the CRT-NTT attention, and an O(1) 12B decode through the daemon

*Shannon-Prime release series, paper 20. Discipline: [METHODOLOGY.md](../../METHODOLOGY.md).
Every number below is a row in [LEDGER.md](../../LEDGER.md) with a command behind it.*

> **Front-door receipt (measured + gated 2026-06-18, ledger X-BX-WIRE).** Paper 19 made the
> four nonlinear islands exact-integer. This paper is the *architecture* that lets that
> exactness mean the same thing on every backend, and the bridge that drives a real 12B
> through it. Three pieces. **(1) One reference, many backends.** A universal Rust crate
> (`tools/sp_dsp_smoke`) is both the L2 orchestrator *and* the scalar bit-exact reference for
> the whole linear algebra — dual-prime Barrett reduction, mod-q matmul, Garner CRT, the NTT
> ladder — each bit-exact-gated (`T_GARNER_BIT_EXACT` and siblings). The C / CUDA / HVX
> backends are correct precisely when they gate to it. **(2) Attention as exact convolution.**
> The float `⟨q,k⟩` and `p·V` of attention are computed as an **exact-integer dual-prime
> negacyclic-convolution dot** — a single convolution coefficient *is* the plain dot, done
> mod `q1`/`q2` and reassembled by Garner; gates `G-BYTEEXACT-ATTN-{NTT,FULL}` GREEN, and the
> `p·V` accumulator stays `~2^46 ≪ M` even at window 16384, so **two primes suffice — no third
> prime**. **(3) The daemon drives the 12B.** The universal daemon runs the resident 12B over
> the L1 C ABI: prefill via `sp_session_register_forward_backend` (`G-WIRE-CUDA-GEMMA4`), and
> token-by-token decode via a new L1 verb `sp_session_register_kvdecode_backend` +
> `gemma4_kv_decode_logits` — `G-WIRE-CUDA-DECODE-GEMMA4` GREEN: **32/32 tokens bit-identical
> to the null-floor oracle, with VRAM flat (O(1) resident cache)**. One model, one RTX 2060.

## 1. The problem a universal substrate solves

Paper 19 proved a forward pass *can* be exact integer. But "exact" is only worth something if
it is the *same* exact on the CPU reference, the CUDA kernel, and any other backend — a number
that is exact on one device and merely "close" on another has bought nothing. The risk in a
multi-backend engine is precisely this: each backend re-implements the arithmetic, and the
re-implementations quietly disagree in the last bits.

The architecture that removes that risk is **one canonical reference everything else gates
to**. That is what the universal crate is.

## 2. One reference, many backends

`tools/sp_dsp_smoke` is a Rust crate that plays two roles at once:

- **The L2 orchestrator** — the layer that drives the engine and schedules the work.
- **The scalar bit-exact reference** — a plain, slow, obviously-correct implementation of the
  entire linear-algebra substrate, against which every fast backend is checked.

And — a banked lesson stated plainly, because the discipline of this series is that the
unflattering facts stay attached — the crate *already owned* the byte-exact linear algebra
before paper 19's campaign began. The dual-prime **Barrett reduction**, the **mod-q matmul**,
the **Garner CRT** reconstruction, and the **NTT ladder** were all already implemented here
and already **bit-exact-gated** (`T_GARNER_BIT_EXACT` and its siblings). The session's offline
prototypes that re-derived this arithmetic were the one wasted motion of the campaign — kept on
the record as the lesson it is (verify against the substrate before rebuilding it; paper 21
draws it out). The contribution of this paper is *not* re-deriving the linear algebra. It is:
the architecture exists, the reference is the crate, and the backends are correct exactly when
they gate to it.

## 3. Attention as an exact-integer convolution

The one part of the forward not covered by "matmul + the four islands" is attention's two
inner products: `⟨q,k⟩` (the scores) and `p·V` (the weighted value sum). Both were float. Both
become exact integer through one identity:

> a single coefficient of a **negacyclic polynomial convolution** *is* a dot product.

Concretely, `⟨q, k⟩ = coeff_{N-1}( Q(x) · K(x̂) ) / Δ²` — the engine forms the polynomial
product `Q(x)·K(x̂)` in the ring, and the `(N−1)`-th coefficient of that product is exactly the
dot of the two vectors (for a single coefficient this reduces to the plain dot). The product is
computed mod `q1` and mod `q2` and reassembled by Garner CRT — the same dual-prime machinery as
the rest of the substrate. On the 12B this is the `k_attn_decode_win_bx` kernel. Gates
`G-BYTEEXACT-ATTN-NTT` and `G-BYTEEXACT-ATTN-FULL` are GREEN: **the dot equals the exact
integer at every scale `Δ`.**

The honest design question is whether two primes are enough — whether the `p·V` accumulator can
overflow the CRT modulus `M = q1·q2 ≈ 2^60`. It does not. The `p·V` accumulator stays
**`~2^46`**, which is **`≪ M`** even at a sliding window of **`W = 16384`**. So the dual-prime
container holds the full attention accumulate without a **third prime** — a real economy, not an
assumption: it is measured in `G-BYTEEXACT-ATTN-FULL`. Receipts:
`tests/fixtures/xbar_r3/G-BYTEEXACT-ATTN-NTT.log`, `…/G-BYTEEXACT-ATTN-FULL.log`.

## 4. The daemon drives the 12B: prefill, then an O(1) decode

A reference and a set of kernels are not yet a *running model*. The bridge is the universal
daemon (the resident L1-ABI process of paper 09) driving the real Gemma-4-12B over the L1 C
ABI, in two halves:

- **Prefill.** The daemon registers the 12B's forward through
  `sp_session_register_forward_backend` — the existing forward-backend seam — and the prefill
  runs on the CUDA forward. Gate `G-WIRE-CUDA-GEMMA4`.
- **Decode.** Token-by-token generation needs a *decode* seam the L1 ABI did not have, so this
  paper adds one: a **new L1 verb** `sp_session_register_kvdecode_backend`, plus an *additive*
  `gemma4_kv_decode_logits` entry point in the engine. "Additive" is the discipline — the new
  verb is a strict addition; the one-shot decode is not touched, so the null floor is preserved.

The decode gate, `G-WIRE-CUDA-DECODE-GEMMA4`, is GREEN with two properties:

| property | result | meaning |
|---|---|---|
| correctness | **32/32 tokens bit-identical to the null-floor oracle** | the daemon-driven decode == the byte-untouched reference decode, to the bit |
| memory | **VRAM flat across the 32-token decode** | the resident KV cache is **O(1)** — the decode does not grow the footprint per token |

The bit-identity is the load-bearing claim: routing the 12B's decode through the daemon and the
new kvdecode verb produces *exactly* the tokens the untouched oracle produces — the wiring adds
the resident-daemon machinery without perturbing a single output bit. And the flat VRAM is the
O(1) resident-cache property (the KV term of paper 08), now exercised through the production
daemon path rather than the backend-direct harness. Receipt:
`tests/fixtures/xbar_r3/G-WIRE-CUDA-DECODE-GEMMA4.log`.

## 5. Honest scope

- **The bit-identity is the strong claim; it is on one host.** `G-WIRE-CUDA-DECODE-GEMMA4` is
  32/32 tokens bit-identical to the oracle on this RTX 2060. It proves the daemon path is
  output-faithful, not that the result is identical on a *second* GPU — that cross-machine check
  is the open external step paper 19 names.
- **"O(1) VRAM" is the KV-cache term.** The flat footprint is the resident KV cache not growing
  per token; as in paper 08, the absolute footprint still carries the resident model in this
  harness. The O(1) claim is scoped to the cache term it names.
- **Two primes suffice — measured, at `W ≤ 16384`.** The "no third prime" result is the
  measured `~2^46 ≪ M` accumulator bound at windows up to 16384; it is not a claim about
  arbitrarily large windows or other models.
- **The re-derivation was the wasted motion.** The byte-exact linear algebra already lived in
  the crate, bit-exact-gated; re-deriving it offline was the campaign's one redundant step,
  kept on the record (paper 21 §). The *new* substrate work in this set is paper 19's four
  islands and §3's attention convolution + §4's decode verb.
- **One model, one host.** Gemma-4-12B (the B1 / `OK_Q4B` artifact of paper 06), RTX 2060
  12 GB. Proof-of-mechanism, not a scaling study, not multi-model, not independently reproduced.

## 6. Reproduction

Every number above is a row in [`LEDGER.md`](../../LEDGER.md) with model, fixture, flags, gate,
and commit attached. The reference and its bit-exact gates are in the universal crate
([shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine),
`tools/sp_dsp_smoke`); the attention and wire gates run from the engine's CUDA forward and the
daemon; `gemma4_decode_cuda` is left byte-untouched.

| Gate | Driver | Expected | Receipt log |
|---|---|---|---|
| (T_GARNER_BIT_EXACT &c.) | `tools/sp_dsp_smoke` crate tests | dual-prime Barrett / mod-q matmul / Garner CRT / NTT ladder bit-exact (the L2 reference the backends gate to) | crate test suite (`tools/sp_dsp_smoke`) |
| G-BYTEEXACT-ATTN-NTT | engine attention conv (`k_attn_decode_win_bx`) | `⟨q,k⟩ = coeff_{N-1}(Q·K̂)/Δ²` == exact integer at every Δ (mod q1/q2 + Garner) | `tests/fixtures/xbar_r3/G-BYTEEXACT-ATTN-NTT.log` |
| G-BYTEEXACT-ATTN-FULL | (same, full attention) | `p·V` accumulator `~2^46 ≪ M` at W up to 16384 ⇒ dual-prime sufficient, **no third prime** | `tests/fixtures/xbar_r3/G-BYTEEXACT-ATTN-FULL.log` |
| G-WIRE-CUDA-GEMMA4 | daemon, `sp_session_register_forward_backend` (12B prefill) | the resident 12B prefill driven over the L1 C ABI | `tests/fixtures/xbar_r3/G-WIRE-CUDA-GEMMA4.log` |
| G-WIRE-CUDA-DECODE-GEMMA4 | daemon, new L1 verb `sp_session_register_kvdecode_backend` + `gemma4_kv_decode_logits` | **32/32 tokens bit-identical to the null-floor oracle**; VRAM flat (O(1) resident cache) | `tests/fixtures/xbar_r3/G-WIRE-CUDA-DECODE-GEMMA4.log` |

**Commit hashes.** Engine: `69c0588` (the exact-integer attention convolution + the new
`sp_session_register_kvdecode_backend` L1 verb and additive `gemma4_kv_decode_logits`;
`G-BYTEEXACT-ATTN-{NTT,FULL}`, `G-WIRE-CUDA-GEMMA4`, `G-WIRE-CUDA-DECODE-GEMMA4` GREEN),
math-core submodule `d9d96f3`. The universal crate `tools/sp_dsp_smoke` (Barrett / mod-q matmul
/ Garner / NTT, `T_GARNER_BIT_EXACT` &c.) and the daemon are the production substrate (papers 06
and 09). Architecture and pre-registered gates: lattice `papers/CONTRACT-BYTEEXACT-forward.md`
§5.1–§5.2 + the L1-ABI / resident-daemon contract.

## Receipts

| Row | Receipt |
|---|---|
| X-BX-WIRE | The universal-crate architecture that makes the exact-integer forward (paper 19) mean the same thing on every backend, plus the bridge that drives a real 12B through it. **One reference:** `tools/sp_dsp_smoke` is both the L2 orchestrator *and* the scalar bit-exact reference for the whole linear algebra (dual-prime Barrett, mod-q matmul, Garner CRT, NTT ladder — each bit-exact-gated, `T_GARNER_BIT_EXACT` &c.); the C / CUDA / HVX backends are correct iff they gate to it (and — honest lesson — this already existed before the byte-exact campaign; the offline re-derivation was the campaign's one wasted motion). **Attention as exact convolution:** float `⟨q,k⟩` / `p·V` → dual-prime negacyclic-convolution dot (`⟨q,k⟩ = coeff_{N-1}(Q(x)·K(x̂))/Δ²`, a single coefficient = the plain dot, mod q1/q2 + Garner; on the 12B = `k_attn_decode_win_bx`); `G-BYTEEXACT-ATTN-NTT`/`-FULL` GREEN — dot == exact integer at every Δ, and the `p·V` accumulator stays **`~2^46 ≪ M`** at W up to 16384 ⇒ **dual-prime sufficient, no third prime**. **The daemon drives the 12B:** prefill via `sp_session_register_forward_backend` (`G-WIRE-CUDA-GEMMA4`); decode via the **new L1 verb** `sp_session_register_kvdecode_backend` + additive `gemma4_kv_decode_logits` — `G-WIRE-CUDA-DECODE-GEMMA4` GREEN: **32/32 tokens bit-identical to the null-floor oracle, VRAM flat (O(1) resident cache)**. 12B-b1, RTX 2060 12 GB; `gemma4_decode_cuda` byte-untouched. Open: the cross-machine (two-physical-GPU) bit-identity check; the O(1) claim is the KV-cache term (the harness still carries the resident model) |

Companions: paper 19 / X-BX-ISLANDS (the four exact-integer islands this architecture carries
across backends), paper 06 / 06-R10 (the dual-prime CRT-NTT engine and the `OK_Q4B` linear
algebra the crate references), paper 09 / KAIROS (the resident daemon this decode verb extends),
paper 08 / X-R2 (the O(1) KV-cache term, here exercised through the production daemon path),
paper 21 / X-BX-BOUNDARY (the re-derivation lesson, drawn out as part of the honest record).
