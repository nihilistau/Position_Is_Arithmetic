# 08 — O(1) KV: a context-decoupled cache via a learned router *(written — front-door gated, X-R2)*

> **STATUS: written, citable via X-R2** — the full paper is
> [`paper.md`](paper.md); the gate lines + commands are
> [`repro/EXPECTED.md`](repro/EXPECTED.md). The front-door receipt is measured +
> gated (ledger **X-R2**) from the cited commits against the cited receipt logs.
> Per series rule 4, the standalone one-command re-gate is the pre-release step
> (this module reproduces from `<commit>` via `<command>` against `<log>`; it
> does not claim a fresh re-run).

> **Front-door receipt (measured + gated, ledger X-R2):** the KV cache of a
> frozen **Gemma-4-12B** is decoupled **O(1) from context length**, with the
> needle retained. A learned **512×32 LSH projection router** selects the
> global top-B keys at **+0.47% PPL at 8× compression** (oracle ceiling
> **−0.08%**; the frozen ±1 geometric router was **+4.17%** — RED). A compact
> slab realizes **O(1) VRAM**: at context **8k vs 16k** `nvidia-smi` is flat
> within **~50 MiB** (a full O(N) cache would add ~5.4 GiB across that
> doubling). And the **NIAH needle survives the compaction at depths 10 / 50 /
> 90%** (exact, learned-router-only) — the **frozen-router negative control
> MISSES**, isolating the learned projection as the cause, not leakage.

## The claim this paper makes

Mainstream inference treats the KV cache as an opaque, ever-growing scratchpad —
its VRAM footprint is O(context). It does not have to be. Move the dominant
sliding-window layers onto a **W-slot ring** (O(1) by construction), keep the
full-attention "global" layers' K/V resident in host RAM, and per step page in
only the small union of keys a **learned router** selects into a fixed-size
device slab. The cache term then stops growing with context. The hard part is
*which* keys to keep — and that is a learned-projection problem, measured
against an oracle ceiling before a single training step is spent.

## What's in it (the map)

1. **The ring and the slab** — SWA layers (the dominant 40 of 48) on a W=1024
   ring (write slot = position mod W); the 8 global layers on a compact slab
   capped at the GQA union `nh·B`=4096, full K/V resident in a host-RAM Ring-2,
   ranked by a resident r=32 `RᵀK` sidecar.
2. **The router progression, measured in order** — frozen ±1 geometric router
   **+4.17%** (RED) → **oracle** (exact top-B by true attention) **−0.08%**,
   proving 8× is *information-achievable* → a **learned 512×32 LSH** router
   distilling the true attention distribution lands **+0.47%** (GREEN) at the
   *same per-step cost* (a one-time projection matrix, no new hot-path kernel).
3. **Why measure the oracle ceiling first** — the mass-captured proxy said
   "concede 4×"; the on-engine oracle PPL flipped it to "8× is learnable, train
   it." Measuring the best-possible selection on the real metric *before*
   training is what made the training cycle worth running (methodology, paper
   10).
4. **O(1) VRAM, the ladder** — `nvidia-smi` at 8k vs 16k flat within ~50 MiB;
   the honest scope caveat (the absolute ~11.4 GiB floor is the resident 9.4 GiB
   model in a backend-direct harness — the **KV term** is what's O(1) and what
   we claim; we deliberately do **not** publish "12B @ 16k on 12GB").
5. **NIAH retention under poison** — plant a secret outside the sliding window
   so it can *only* be retrieved through the global crossbar; the learned router
   recovers it at 10 / 50 / 90% depth; the **frozen-router control MISSES** at
   the same depth (the HIT is the router, not a live-buffer artifact); the
   full-attention 16k baseline is *physically impossible* on the 2060, which is
   the motivation.
6. **Honest boundaries** — when a stage crosses from exact to lossy, bit-exact
   is impossible by definition: the +0.47% bar was pre-registered (<2%) before
   the code; a small-N "improvement" was caught as a noise illusion and only
   the full-corpus number is reported.

## Honest scope

Proof-of-mechanism: **one model (Gemma-4-12B), one host (RTX 2060 12 GB)**. The
**KV-cache term** is O(1) and retentive; the **absolute footprint** in this
backend-direct harness still carries the resident model — arena-streamed weights
are a separate gate. Not scale-validated, not independently reproduced.

## Module

[`paper.md`](paper.md) — the full paper (8 sections + Reproduction + Receipts).
[`repro/EXPECTED.md`](repro/EXPECTED.md) — the expected gate lines for the three
reproductions (`_run_g2_lsh.bat`, `_run_g2_cb2_vram.bat`, `_run_niah_cc.bat`).

## Status

Written; citable via X-R2. Front-door receipt measured + gated in
[shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)
(`tests/test_gemma4_cuda.c` `SP_G4_NIAH` + `SP_ARM_*` knobs in
`cuda_forward.cu`; trainer `tools/xbar_lsh/train_lsh.py`); architecture in
lattice `papers/CONTRACT-XBAR-P3-ring-on-exec.md` (run-records
G-P3-R2.b-2b-* / -NIAH). Ledger row in [`LEDGER.md`](../../LEDGER.md) §XBAR
(**X-R2**). Companions: 07 (the crossbar that writes into this cache), 09 (the
resident daemon that runs this machinery underneath it), 10 (the
oracle-ceiling-before-training discipline).
