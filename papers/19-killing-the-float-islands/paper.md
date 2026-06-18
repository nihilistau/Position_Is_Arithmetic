# Killing the float islands: an exact-integer forward pass on a 12B

*Shannon-Prime release series, paper 19. Discipline: [METHODOLOGY.md](../../METHODOLOGY.md).
Every number below is a row in [LEDGER.md](../../LEDGER.md) with a command behind it.*

> **Front-door receipt (measured + gated 2026-06-18, ledger X-BX-ISLANDS).** Papers 16–18
> carried the *memory* tier onto the exact-integer `O_K` substrate. This paper carries the
> *forward pass itself*. The engine already ran its **linear algebra** exactly — the
> dual-prime dp4a accumulate is order-immune (paper 06) — but four nonlinear operations
> were still computed in floating point: **RMSNorm, softmax, GELU, and RoPE**. They were
> the only places a bit-identical forward could still drift. This paper kills all four. Each
> becomes a deterministic fixed-point integer function — RoPE via a **device CORDIC** with
> no `libm`, the norm's reciprocal-square-root via a **64-bit integer split**, exp via an
> integer `2^x` polynomial — and the whole forward runs behind a default-off flag
> `SP_BYTEEXACT` (the one-shot decode stays byte-untouched = the null floor). The headline
> is `G-BYTEEXACT-FORWARD-12B`: **OFF reproduces the bf16-gold baseline byte-identically
> (PPL 4.6665, the null floor); ON scores 4.6569 (parity, −0.21% at `n=42`); and the ON run
> is run-to-run bit-identical** — the on-machine proxy for the cross-machine determinism the
> exactness is *for*. Measured on `gemma4-12b-b1.sp-model`, one RTX 2060 (12 GB, sm_75).

## 1. The islands were the only thing still drifting

By paper 06 the engine computes the transformer's heavy arithmetic — the matmuls — in
exact integers: each weight is a packed `OK_Q4B` code, each GEMV is an `int4 × int8 →
int32` dp4a accumulate, and an integer accumulate is **reduction-order-immune** by
construction (the answer does not depend on the order the partial products are summed). That
is the property the whole project is named for. But a transformer forward is not only
matmuls. Between the linear layers sit four nonlinear operations, and every one of them was
still being evaluated in `f32`:

- **RMSNorm** — a reciprocal square root over a sum of squares;
- **softmax** — an `exp` and a normalizing divide over the attention logits;
- **GELU** — the MLP nonlinearity (gemma's `k_gelu_mul`);
- **RoPE** — the rotary position embedding, a `sin`/`cos` table applied per head dimension.

These are the "fp32 islands": small float lagoons in an otherwise integer pipeline. They are
where a forward that is supposed to be exact can still disagree with itself across machines,
because float `1/√x`, float `exp`, and a libm `sin` are *not* guaranteed bit-identical from
one GPU, compiler, or math library to the next. The earlier 1B validation found this
directly: the *only* nonzero logit deltas it ever saw came from exactly these islands. The
weights were not the problem. **Byte-exactness was blocked at the islands.**

This paper drains the lagoons.

## 2. Four integer functions, no `libm`

The replacements share one design rule: every island becomes a **deterministic fixed-point
integer function** whose every reduction is order-immune, and *no* libm call survives in the
exact path. `sp_islands_q_ref.rs` is the scalar bit-exact reference
(`rmsnorm` / `softmax` / `gelu` / `rope_q_ref`); the host gate `G-ISLANDS-Q-REF` measures
each against float (`cargo run --bin sp_islands_q_ref_test`, x86, **no GPU**).

| island | exact-integer replacement | fidelity vs float (host) |
|---|---|---|
| **RMSNorm** | `Σx²` accumulated in exact `int64`; the reciprocal square root via a **64-bit integer `isqrt` split** (no float `1/√`) | relative **5.8e-6** |
| **softmax** | exact-integer logits → fixed-point `exp` (an integer `2^x` polynomial, coeffs `(ln2)^k/k!`) → exact-integer `Σ` → fixed-point divide | **1.3e-6** |
| **GELU** | `0.5·x·(1+tanh(…))`, `tanh` built from the same `exp` primitive | **2.8e-6** |
| **RoPE** | a deterministic fixed-point **CORDIC** rotation — the angle is produced by integer shift-add iterations, **no `sin`/`cos` libm call** | **9.2e-6** |

Two of the techniques are the load-bearing ones, because they are where float would
normally sneak back in:

- **The reciprocal square root with no float.** RMSNorm needs `1/√(Σx²/n)`. Rather than a
  float `rsqrtf` (whose last bits are hardware-dependent), the sum of squares is held exact
  in `int64` and the root is taken by an **integer `isqrt`** computed on a 64-bit split —
  a deterministic bit-shift refinement. The same `Σx²` is order-immune because it is an
  integer sum.
- **RoPE by CORDIC, not by a sine table.** The rotary embedding is the last place a `sin`/
  `cos` would live. Instead the rotation is done by **CORDIC** — the classic shift-and-add
  vector-rotation iteration — in fixed point. CORDIC needs only integer adds and shifts and a
  small fixed table of `arctan` constants, so it is bit-identical everywhere and needs no
  math library at all.

`G-ISLANDS-Q-REF` confirms every one of the four matches float to `~1e-6` and is
**deterministic / reduction-order-immune** — lossless for inference, and now exact.
Receipt: `tests/fixtures/xbar_r3/G-ISLANDS-Q-REF.log`.

## 3. No `__int128` — the cross-hardware mandate

The wide arithmetic underneath the islands carries its own constraint, and it is a
deliberate one: **no `__int128`**. The frozen dual primes are
`q1 = 1073738753`, `q2 = 1073732609`, with CRT modulus `M = q1·q2 = 1152908312643096577`
and Garner inverse `894602413`. `M` is `≈ 2^60` — it **fits in a `u64`**. That is not an
accident; it is the whole point. A 128-bit integer type is a compiler/ABI luxury that is not
uniformly available or uniformly fast across the targets this engine must run on, so the
arithmetic is engineered to stay inside 64 bits everywhere. Where a product would overflow,
the device uses `__umul64hi` to take the high half of a wide multiply directly; the RMS split
and the CORDIC fixed-point both live inside 64 bits by design. The exactness is therefore
**portable** — it does not depend on a 128-bit type the target might lack.

## 4. On the 12B: islands integer, then the whole forward

The host reference is one thing; the same arithmetic on real model activations is the gate
that matters. `G-BYTEEXACT-ISLANDS-CUDA` runs the device island kernels against the integer
references on **real 12B activations (layer 24)**: RMS **3.8e-5**, GELU **8.2e-7**, RoPE
**9.6e-6** — the on-model island fidelity, in line with the host numbers. Receipt:
`tests/fixtures/xbar_r3/G-BYTEEXACT-ISLANDS-CUDA.log`.

Then the headline, `G-BYTEEXACT-FORWARD-12B` — the four islands and the attention dot (paper
20) all converted to exact-integer device kernels behind the default-off flag `SP_BYTEEXACT`,
scored on the 12B:

| run | PPL | meaning |
|---|---|---|
| `SP_BYTEEXACT` **OFF** | **4.6665** | **== bf16-gold baseline, byte-identical — the null floor** |
| `SP_BYTEEXACT` **ON** | **4.6569** | parity (**−0.21% at `n=42`**) |
| `SP_BYTEEXACT` ON, re-run | **bit-identical** | run-to-run, the determinism proxy |

Three things are load-bearing here, in order:

1. **The null floor holds.** With the flag off, the forward is byte-identical to the bf16
   gold baseline at PPL **4.6665** — the same null floor papers 11–18 cite. The exact-integer
   path is genuinely default-off and inert; nothing in the stock forward moved.
2. **Parity, honestly scoped.** With the flag on, PPL is **4.6569**, a **−0.21%** move at
   `n = 42` scored positions. That is parity — the integer islands cost nothing measurable —
   and it is reported with its `n=42` caveat, not as a clean win (papers 10–11: `n=42` is a
   small single-chunk window; a sub-1% move is at the edge of what it can resolve).
3. **The ON run is run-to-run bit-identical.** This is the closest *on-machine* proxy for the
   property the exactness exists to deliver — that two runs (and, the external step, two
   *machines*) produce the same logits to the bit. On one card we can only show run-to-run
   identity; the two-physical-GPU check is the open external step (§5).

`gemma4_decode_cuda`, the one-shot decode, is left byte-untouched throughout — it is the null
floor every gate above is measured against. Receipt:
`tests/fixtures/xbar_r3/G-BYTEEXACT-FORWARD-12B.log`.

## 5. Honest scope

- **The only remaining gap is external, and it is the headline property.** The exactness is
  *for* cross-machine bit-identity. On this single host we prove run-to-run bit-identity and
  reduction-order immunity; a **literal bit-identical logit comparison across two physical
  GPUs needs a second machine** and is not done here. That is the one open step, stated as
  open.
- **PPL parity is `n=42`.** The OFF==4.6665 / ON==4.6569 numbers are a single 42-token chunk.
  The byte-identical OFF result and the run-to-run-identical ON result are exact; the −0.21%
  ON *deflection* carries the small-N caveat (papers 10/11) and is not a quality claim.
- **Byte-exact buys auditability, not speed or size.** This is the de-conflation paper 21
  makes at length: exactness is the deliverable, not compression. The integer islands are
  `~1e-6`-faithful to float, so they do not change the model's quality; they change whether
  the forward is *bit-reproducible*.
- **One model, one host.** Gemma-4-12B (the B1 / `OK_Q4B` artifact of paper 06), RTX 2060
  12 GB, sm_75. Proof-of-mechanism, not a scaling study, not multi-model, not independently
  reproduced.

## 6. Reproduction

Every number above is a row in [`LEDGER.md`](../../LEDGER.md) with model, fixture, flags,
gate, and commit attached. The host island reference runs from the universal Rust crate
([shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine),
`tools/sp_dsp_smoke`); the on-model gates run from the engine's CUDA forward;
`gemma4_decode_cuda` is left byte-untouched.

| Gate | Driver | Expected | Receipt log |
|---|---|---|---|
| G-ISLANDS-Q-REF | `cargo run --bin sp_islands_q_ref_test` (host x86, no GPU) | `rmsnorm`/`softmax`/`gelu`/`rope_q_ref` vs float: RMS 5.8e-6 / softmax 1.3e-6 / GELU 2.8e-6 / RoPE 9.2e-6; all reduction-order-immune / deterministic; RoPE via CORDIC, no libm | `tests/fixtures/xbar_r3/G-ISLANDS-Q-REF.log` |
| G-BYTEEXACT-ISLANDS-CUDA | engine CUDA forward, `SP_BYTEEXACT` island kernels vs integer refs (12B activations, layer 24) | RMS 3.8e-5 / GELU 8.2e-7 / RoPE 9.6e-6 on-model | `tests/fixtures/xbar_r3/G-BYTEEXACT-ISLANDS-CUDA.log` |
| G-BYTEEXACT-FORWARD-12B | `SP_BYTEEXACT` on/off PPL on `gemma4-12b-b1.sp-model` | OFF == 4.6665 (byte-identical to bf16 gold, null floor); ON == 4.6569 (parity, −0.21% @ n=42); ON run-to-run **bit-identical** | `tests/fixtures/xbar_r3/G-BYTEEXACT-FORWARD-12B.log` |

**Commit hashes.** Engine: `69c0588` (the four integer islands + attention exact-integer
behind `SP_BYTEEXACT`; `G-BYTEEXACT-FORWARD-12B` GREEN — OFF 4.6665 null floor / ON 4.6569
parity / run-to-run bit-identical), math-core submodule `d9d96f3`. The frozen dual primes
(`q1=1073738753`, `q2=1073732609`, `M=1152908312643096577`, Garner inverse `894602413`,
`M < 2^60` ⇒ no `__int128`) and the dp4a `OK_Q4B` linear algebra are paper 06's production
substrate. Architecture and pre-registered gates: lattice
`papers/CONTRACT-BYTEEXACT-forward.md` §3–§5.

## Receipts

| Row | Receipt |
|---|---|
| X-BX-ISLANDS | The four nonlinear fp32 "islands" of the gemma-4-12B forward — RMSNorm, softmax, GELU, RoPE — converted to deterministic exact-integer fixed-point functions, with no `libm` and no `__int128` (the `M = q1·q2 ≈ 2^60` CRT modulus fits a `u64`; device `__umul64hi` for wide products, a 64-bit `isqrt` split for the RMS reciprocal-root, a device **CORDIC** for RoPE). **`G-ISLANDS-Q-REF` (host x86, `sp_islands_q_ref.rs`, no GPU):** RMS **5.8e-6** / softmax **1.3e-6** / GELU **2.8e-6** / RoPE **9.2e-6** vs float, all reduction-order-immune / deterministic. **`G-BYTEEXACT-ISLANDS-CUDA` (real 12B activations, layer 24):** RMS **3.8e-5** / GELU **8.2e-7** / RoPE **9.6e-6** vs the integer refs. **`G-BYTEEXACT-FORWARD-12B`:** the four islands + attention as exact-integer device kernels behind a default-off `SP_BYTEEXACT` (the one-shot `gemma4_decode_cuda` left byte-untouched = null floor) — **OFF = PPL 4.6665 == bf16-gold baseline, byte-identical (null floor); ON = 4.6569 (parity, −0.21% at n=42); the ON run is run-to-run bit-identical** (the on-machine cross-machine-determinism proxy). 12B-b1, RTX 2060 12 GB (sm_75); host reference on x86. **Open (external):** a literal bit-identical logit comparison across two *physical* GPUs (needs a second machine); the n=42 PPL parity carries the small-N caveat. Byte-exact buys **auditability**, not speed or size |

Companions: paper 06 / 06-R10 (the `OK_Q4B` dp4a linear algebra that was already exact —
this paper completes the forward by converting the four nonlinear islands too), paper 20 /
X-BX-WIRE (the universal-crate architecture and the dual-prime CRT-NTT attention this forward
plugs into, and the daemon that drives it), paper 21 / X-BX-BOUNDARY (the de-conflation —
why this buys auditability and not compression — and the honest negatives), paper 16 /
X-OK-BIND (the same exact-integer `O_K` substrate, on the memory tier), paper 10 (the small-N
discipline that keeps the n=42 parity honest).
