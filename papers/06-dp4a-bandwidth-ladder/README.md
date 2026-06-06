# 06 — Computing on the Zip File: the dp4a bandwidth ladder *(staged — mapped, not yet written)*

> **Front-door receipt (already gated in the engine repo):** on a consumer
> RTX 2060, an isolated single-token GEMV sweep with clocks pinned shows the
> packed-weight ladder **f32 1× (~290 GB/s, the bus saturated at 87% of peak) →
> int8 dp4a ~3.8× → Q4 dp4a ~7.06×** at 12B-scale matrix sizes — each halving
> of bytes-per-weight ~doubling throughput, hugging the 4:1 / 8:1 byte ratios —
> **top-1 lossless** (256/256 argmax agreement in the production decode; Q4
> kernel vs host reference: max rel err 1.34e-7).

## The claim this paper will make

When inference is memory-bound, the weights' *byte count* is the speed of
light. Dequantizing packed weights before the GEMM destroys the advantage
(measured: the dequant-to-f32-scratch path moves ~9 B/weight and runs 3× slower
than plain f32). Computing **directly on the packed integer codes** —
`__dp4a` INT8 dot-products with an in-ALU nibble unpack for Q4, one Frobenius
lift at the end — recovers the full byte ratio, with zero top-1 loss.

## What goes in it (the map)

1. **The physics** — the GDDR6 bus as the wall: f32 SGEMV pinned at ~290 GB/s
   (87% of the 2060's 336 GB/s peak) across all large sizes; the crossover from
   overhead-bound to bus-bound at N≈2K; why a 0.6B model can't show the win
   (Amdahl) and a 12B sits squarely in the ~7× regime.
2. **The kernels** — warp-per-row dp4a GEMV, 128-bit `int4` loads (16 codes per
   thread per iteration), `__shfl_down_sync` register reduction; the Q4 variant
   unpacking 2 nibbles/byte in the ALU (measured tax: ~7% — idle ALU cycles
   traded for bus bytes, landing 7× of the theoretical 8×).
3. **The arithmetic** — the inline Frobenius lift (exact integer accumulation,
   ONE scale at the end) as the *correct* arithmetic, matching the discrete
   math-core reference; dynamic per-vector int8 activation quantization,
   top-1 lossless on real decode.
4. **The dispatcher** — per-tensor precision routing for K-quant mixes
   (`Q4_K_M` keeps embeddings/head at higher precision; the global-precision
   shortcut measured 0/256 before the fix — the industrial-grade lesson).
5. **Honest boundaries** — what dp4a does NOT do: it ties (not beats) f32 when
   the workload is overhead-bound; activation quant is top-1-lossless, not
   byte-exact; the naive GEMV ≈ cuBLAS-f32 absolute at small scale.

## Status

Staged. Kernels + sweep + gates live in
[shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)
(`src/backends/cuda/cuda_forward.cu`, `tests/bench_gemv_int8.cu`,
`tests/test_qwen3_decode_cuda.c` 28/28); ledger rows in
[`LEDGER.md`](../../LEDGER.md) §Paper 06. The 12B end-to-end tok/s number
(Stage Eta ETA.5b, vs llama.cpp) is the intended headline figure before
release. Companions: 05 (the suite that certified these numbers), 02 (the
reducing loader that produces the packed artifacts).
