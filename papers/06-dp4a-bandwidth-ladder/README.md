---
type: paper-bite
title: "06 — Computing on the Zip File: the dp4a bandwidth ladder *(complete — gated, citable)*"
description: "When inference is memory-bound, the weights' byte count is the speed of"
tags: [paper-bite, dp4a]
timestamp: 2026-06-07T04:44:58Z
resource: ./papers/06-dp4a-bandwidth-ladder/README.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# 06 — Computing on the Zip File: the dp4a bandwidth ladder *(complete — gated, citable)*

> **Front-door receipt (measured + gated 2026-06-08, ledger 06-R10):**
> **Gemma-4-12B at 26.1 tok/s and wikitext PPL 5.12 on an RTX 2060 12GB** —
> graph-captured dp4a decode on packed integer codes, 256/256 top-1, graph
> path bit-EXACT, 24/24 gates, SM clock pinned. llama.cpp-CUDA on the same
> card decodes 31.29 tok/s — **at PPL 192–506**, because every GGUF artifact
> its ecosystem can produce for this model carries broken weights (06-R8).
> Effective decode bandwidth: **SP 245 GB/s vs llama.cpp 207 GB/s (+18%)**;
> the SP artifact is 42% heavier because it is the only mathematically
> intact 4-bit Gemma-4-12B in existence (06-R9). There is no like-for-like
> speed race: no other stack runs this model correctly at 4-bit, at any
> speed.
>
> Underneath it, the isolated single-token GEMV ladder (clocks pinned):
> **f32 1× (~290 GB/s, 87% of peak) → int8 dp4a ~3.8× → Q4 dp4a ~7.06×**,
> hugging the 4:1 / 8:1 byte ratios (06-R1..R3); the dequant-before-GEMM
> anti-pattern measured 3× SLOWER than f32 (06-R4); and the two honest
> findings that became standing equipment: per-tensor precision dispatch
> for K-quant mixes (06-R5) and per-block activation scales after the
> per-vector collapse at oracle-rank 205596 (06-R7).

## The claim this paper makes

When inference is memory-bound, the weights' *byte count* is the speed of
light — but only if the bytes are worth reading. Computing **directly on
the packed integer codes** (`__dp4a` dots, in-ALU nibble unpack, block-wise
scale application, one lift at the end) recovers the full byte ratio with
zero top-1 loss. And when the industry's interchange format silently
destroys the weights it carries, the same discipline extends one level up:
own the quantization pipeline from the checkpoint's bytes to the kernel's
registers, and gate every artifact against a reference forward you wrote
yourself. The result is a speed/quality point nobody else can occupy.

## What's in it

1. **The physics** — the GDDR6 bus as the wall; crossover at N≈2K; why the
   12B sits squarely in the packed-codes regime.
2. **The kernels** — warp-per-row dp4a, 128-bit loads, the Q4 nibble unpack
   (~7% ALU tax), and **OK_Q4B**: per-32-block f16 scales applied inside the
   chunk loop — one weight block per 128-bit load, two activation blocks per
   weight block, zero extra code-bus traffic.
3. **The recipe** — gemma4 is PTQ-hostile (all-tensor symmetric Q4 costs
   +45% PPL); the shipped **B1 recipe** (Q4B on the FFN gate/up pair, Q8
   everywhere else) lands at +9.6% in 9.4 GB — found by SIMULATION through
   the reference forward before any kernel was built, and confirmed by the
   built artifact to four decimal places (06-R9).
4. **The supply chain** — why the artifact comes from the official
   safetensors via `sp_transcode --st` and not from any GGUF (06-R8: the
   conviction, with the rebuilt-wave 192.9 receipt).
5. **Honest boundaries** — the ladder ties f32 when overhead-bound; the
   prior 34.2 tok/s headline (06-R6) is RETIRED with its quality-failed
   artifact; the speed lever from here is artifact-size reduction at a
   quality budget, not kernel tricks.

## Module

[`paper.md`](paper.md) — the full paper. Receipts: [`LEDGER.md`](../../LEDGER.md)
§Paper 06 (06-R1..R10). Repro instruments: engine
(`src/backends/cuda/cuda_forward.cu`, `tools/sp_transcode`), lattice
(`tests/gemma4_gold/`). Companions: 04 (the oracle that grades every number
here), 05 (the suite that manufactured them), 02 (the reducing loader),
[`GEMMA4-QUANT-FIX.md`](../../GEMMA4-QUANT-FIX.md) (the community tutorial).
