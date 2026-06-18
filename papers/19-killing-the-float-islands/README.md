# 19 — Killing the float islands: an exact-integer forward pass on a 12B *(written, citable — X-BX-ISLANDS)*

> **STATUS: written — [`paper.md`](paper.md) complete.** Front-door receipts measured
> + gated (ledger **X-BX-ISLANDS**).

> **Front-door receipt (measured + gated 2026-06-18, ledger X-BX-ISLANDS):** papers 16–18
> carried the *memory* tier onto the exact-integer `O_K` substrate; this paper carries the
> *forward pass*. The engine's linear algebra was already exact (the dp4a accumulate is
> order-immune, paper 06), but four nonlinear ops — **RMSNorm, softmax, GELU, RoPE** — were
> still floating-point "islands," the only places a forward could still drift. All four are
> now deterministic fixed-point integer functions: RoPE by a **device CORDIC** (no `libm`),
> the norm's reciprocal-root by a **64-bit `isqrt` split**, `exp` by an integer `2^x`
> polynomial — and the whole forward runs behind a default-off `SP_BYTEEXACT` (the one-shot
> decode stays byte-untouched = null floor). `G-BYTEEXACT-FORWARD-12B`: **OFF = PPL 4.6665
> == bf16-gold baseline byte-identical (null floor); ON = 4.6569 (parity, −0.21% at n=42);
> the ON run is run-to-run bit-identical.** No `__int128` anywhere (`M = q1·q2 ≈ 2^60` fits a
> `u64`). Gemma-4-12B-b1, one RTX 2060 (12 GB, sm_75).

## The claim this paper makes

The transformer forward pass can be computed in exact integers end to end — not only the
matmuls (already exact since paper 06) but the four nonlinear operations that were still
float. The result is a forward that is **bit-reproducible**: byte-identical to the bf16 gold
when the exact path is off, run-to-run bit-identical when it is on, with the four islands
matching float to `~1e-6` so quality is unchanged. The CORDIC RoPE and the integer
reciprocal-square-root (no `libm`), and the no-`__int128` 64-bit arithmetic (cross-hardware
portability), are the load-bearing techniques.

## What's in it (the map)

1. **The islands were the only thing still drifting** — why RMSNorm / softmax / GELU / RoPE
   were the last float in an integer pipeline.
2. **Four integer functions, no `libm`** — the replacements + host fidelity (RMS 5.8e-6 /
   softmax 1.3e-6 / GELU 2.8e-6 / RoPE 9.2e-6), the integer `isqrt` and the CORDIC RoPE.
3. **No `__int128`** — the `M ≈ 2^60` `u64` mandate; `__umul64hi` for wide products.
4. **On the 12B** — on-model island fidelity (RMS 3.8e-5 / GELU 8.2e-7 / RoPE 9.6e-6), then
   `G-BYTEEXACT-FORWARD-12B` (OFF 4.6665 null floor / ON 4.6569 parity / run-to-run identical).

## Honest scope

Proof-of-mechanism, **one model (12B-b1), one host (RTX 2060, sm_75)**. The exactness is
*for* cross-machine bit-identity; on a single host only **run-to-run** identity and
reduction-order immunity are shown — the **two-physical-GPU logit comparison is the open
external step**. The PPL parity is `n=42` (a single chunk; the OFF byte-identity and the ON
run-to-run identity are exact, the −0.21% ON deflection carries the small-N caveat). Byte-exact
buys **auditability, not speed or size**.

## Status

**Paper written/complete** ([`paper.md`](paper.md)) — citable via ledger **X-BX-ISLANDS**.
Front-door receipts measured + gated in
[shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)
(host reference `tools/sp_dsp_smoke` / `sp_islands_q_ref.rs`; on-model gates in the CUDA
forward behind `SP_BYTEEXACT`; receipts `tests/fixtures/xbar_r3/`); commits engine `69c0588`,
math-core submodule `d9d96f3`; architecture in lattice
`papers/CONTRACT-BYTEEXACT-forward.md` §3–§5. Companions: 06 (the dp4a linear algebra already
exact), 20 (the universal-crate architecture + the CRT-NTT attention + the daemon decode), 21
(the de-conflation and the honest negatives), 16 (the same `O_K` substrate on the memory
tier), 10 (the small-N discipline).
