# Computing on the Zip File: the dp4a bandwidth ladder

*Shannon-Prime release series, paper 06. Discipline: [METHODOLOGY.md](../../METHODOLOGY.md).
Every number below is a row in [LEDGER.md](../../LEDGER.md) with a command behind it.*

## 1. The physics: the bus is the speed of light

A consumer GPU decoding a large dense transformer is not compute-bound. On an
RTX 2060 (Turing, 336 GB/s GDDR6), an f32 SGEMV saturates at ~290 GB/s — 87%
of theoretical peak — and stays there, flat, from N=3K to N=16K (06-R1). Every
generated token must stream essentially every weight byte through that bus.
The weights' byte count is therefore the decode speed limit, and the only
lever that moves it is *reading fewer bytes per weight*.

The trap is that the obvious implementation throws the lever away. Dequantizing
packed weights to an f32 scratch buffer before the GEMM moves ~9 bytes per
weight — the packed read PLUS the f32 write PLUS the f32 re-read — and runs 3×
slower than just keeping the weights in f32 (06-R4). The zip file is only
worth having if you compute on it zipped.

## 2. The ladder

Computing directly on the packed integer codes — `__dp4a` int8 dot products,
in-ALU nibble unpack for 4-bit, exact integer accumulation, one scale at the
end — recovers the byte ratio almost entirely (clocks pinned, isolated GEMV
sweep, 06-R2/R3):

| rung | bytes/weight | measured speedup | note |
|---|---|---|---|
| f32 | 4 | 1× (~290 GB/s) | the bus-saturated baseline |
| int8 dp4a | 1 | ~3.8× | 4:1 byte ratio, warp-per-row, 128-bit loads |
| Q4 dp4a | 0.5 | ~7.06× | 8:1 minus ~7% in-ALU nibble-unpack tax |

The Q4 kernel reads a 128-bit `int4` (16 bytes = 32 packed weights) per thread
per iteration, sign-extends nibbles with `(n^8)-8` in registers, and feeds
`__dp4a`. Against a host f32 reference the kernel's max relative error is
1.34e-7; in production decode it is top-1 lossless (06-R3).

Two findings from making this production-grade became standing equipment:

- **Per-tensor precision dispatch** (06-R5): K-quant-mix artifacts keep some
  tensors at higher precision; a global-precision shortcut read Q4 nibbles as
  int8 and scored 0/256 before `DevTensor.prec` routing fixed it.
- **Per-block activation scales** (06-R7): per-vector int8 activation
  quantization collapses on outlier-heavy models — Gemma-4-12B's layer 11
  (trained `out_scale` 0.005, the model flagging its own outliers) drove the
  decode to oracle-rank 205596 before per-16-block scales restored rank 2.
  The blocks align exactly with the GEMV's 128-bit loads: zero extra bus
  traffic.

## 3. OK_Q4B: block scales inside the chunk loop

The per-row-scale Q4 format that powered the early ladder has a measured
limit: one scale per 3840-weight row at 15 levels destroys Gemma-4-12B
distributionally (the per-row artifact scored wikitext PPL in the tens of
thousands; 06-R9 supersedes it). The fix is the **OK_Q4B** format: identical
nibble codes, but one f16 scale per 32-element block, stored as a `.bscale`
sibling stream.

The kernel change is the whole point of the design. One 32-code chunk — one
128-bit load — is exactly one Q4B weight block, and exactly two of the per-16
activation blocks. The dp4a chunk loop is unchanged except that the trailing
per-row scale becomes a per-chunk fused multiply:

```
facc += wbsc[c] * ((float)acc0 * sxb[2c] + (float)acc1 * sxb[2c+1]);
```

Two extra FMAs per 32 weights; the bscale stream adds 1/16th of the code
bytes, sequential and cached. Quantization uses store-then-derive discipline:
the scale is rounded through f16 *first*, codes are quantized against the
stored scale — so dequantization is exact by construction, and 4-bit-code ×
f16-scale products are exactly representable in f32 (the prefill dequant
carries no extra rounding).

## 4. The recipe: gemma4 is PTQ-hostile, so simulate before you build

Gemma-4 ships a QAT release for a reason. Naive post-training Q4 on the 12B,
simulated through the reference forward of paper 04 (six recipes, minutes
each, identical fixture and protocol, vs the bf16 gold 4.6776):

| recipe | wikitext PPL | Δ vs gold |
|---|---|---|
| all tensors, symmetric per-32 | 6.79 | +45% |
| + Q8 down-proj/embed | 6.29 | +34% |
| per-16 blocks | 6.13 | +31% |
| asymmetric per-32 | 5.86 | +25% |
| **B1: Q4B on FFN gate/up ONLY, Q8 rest** | **5.13** | **+9.6%** |
| B2: asymmetric gate/up, Q8 rest | 5.01 | +7.0% |

B1 ships: single-digit PPL, 9.4 GB (fits a 12 GB card with ~3 GB headroom),
and a ~30-line kernel delta. The built artifact then matched the simulation
**to four decimal places** (5.1259 simulated, 5.1259 measured on the
container), and the GPU kernel landed at 5.1160 — the triple-instrument
agreement that papers 04 and 05 describe (06-R9). B2 is the documented
upgrade path (it needs per-block activation sums — the "bsums" pattern).

## 5. The supply chain: why no GGUF bytes touch the artifact

The artifact is transcoded **directly from the official safetensors
checkpoint** (`sp_transcode --st`), with GGUF used only for verified-clean
metadata and tokenizer tables. This is not preference; it is the conviction
of 06-R8: every gemma4 GGUF measurable in June 2026 — including the
post-fix "rebuilt" wave — carries broken text-tower weights (PPL 192–506
through two independent engines that agree per-artifact). The full forensic
record (the hand-written reference forward at 4.6776, the tensor-class
bisection, the period-6 damage anatomy) is in papers 04 and 05, the
community tutorial in [GEMMA4-QUANT-FIX.md](../../GEMMA4-QUANT-FIX.md), and
the instruments in lattice `tests/gemma4_gold/`.

The consequence for this paper: the artifact's mapped-but-missing rule
(`--st` hard-errors rather than falling back to GGUF bytes) is part of the
speed claim's integrity. A fast kernel over poisoned weights is a fast lie.

## 6. The headline, decomposed honestly

**SHOOTOUT-2 (06-R10), RTX 2060 12GB, tg256, SM pinned 2100:**

| | SP engine (B1, 9.4 GB) | llama.cpp-CUDA (Q4_K_M, 6.6 GB) |
|---|---|---|
| decode | **26.1 tok/s** | 31.29 ± 0.20 tok/s |
| wikitext PPL (same fixture/protocol) | **5.12** | **192–506** |
| effective decode bandwidth | **245 GB/s** | 207 GB/s |
| correctness gates | graph EXACT 256/256, dp4a top-1 256/256, 24/24 | n/a (artifact quality-failed) |

Read the decomposition before the row: the SP engine moves **18% more bytes
per second** than llama.cpp on the same silicon — the kernel stack is
faster. The SP artifact is 42% heavier — because it is the only
mathematically intact 4-bit Gemma-4-12B in existence. Dividing one by the
other gives llama.cpp a tok/s number it cannot cash: its output distribution
is broken at PPL 192+. There is no like-for-like speed race on this model.
The citable point is the pair: **26.1 tok/s at PPL 5.12 on a 12 GB card** —
a point no other stack can occupy at any speed.

An earlier headline from this series (06-R6: 34.2 tok/s, +9.3% over
llama.cpp) is formally **retired**: it was measured on the 5.56 GB per-row
artifact whose weights failed the PPL gate. The series' own rule — no tok/s
without a quality anchor on the same artifact — is what caught it.

## 7. Honest boundaries

- dp4a ties, not beats, f32 when the workload is overhead-bound (small N,
  small models); the naive GEMV ≈ cuBLAS-f32 absolute at small scale.
- Activation quantization is top-1-lossless, not byte-exact; the graph path
  IS byte-exact vs per-step.
- The +9.6% PPL cost of B1 is the price of fitting 12 GB today; the speed
  lever from here is shrinking the artifact at a quality budget (B2 asym,
  importance-weighted scaling), not kernel tricks — the kernels already sit
  on the bus limit.
- All numbers are one card (RTX 2060 12GB, sm_75), one model family;
  proof-of-mechanism, not a survey.

## Receipts

Ledger rows this paper rests on: 06-R1 (f32 bus saturation), 06-R2 (int8
rung), 06-R3 (Q4 rung), 06-R4 (dequant anti-pattern), 06-R5 (precision
dispatch), 06-R6 (retired headline, kept as the honest negative), 06-R7
(activation-quant collapse), 06-R8 (the GGUF conviction), 06-R9 (sovereign
pipeline artifact gates), 06-R10 (the citable speed/quality point).
Engine provenance: `src/backends/cuda/cuda_forward.cu` (k_gemv_q8/q4/q4b
dp4a, k_dequant_arena*, graph capture), `tools/sp_transcode` (`--st`,
`--q4b-ffn`), `tests/bench_gemv_int8.cu`, `tests/test_gemma4_cuda.c`,
`tests/test_gemma4_ppl_cuda.c`. Gold instruments + receipts: lattice
`tests/gemma4_gold/`.
