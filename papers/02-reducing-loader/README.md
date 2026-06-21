---
type: paper-bite
title: "Paper 02 — The reducing loader *(staged)*"
description: A model transcoded into a smaller artifact that loads zero-copy and runs bit-faithfully — same top-1 output as the original.
tags: [paper-bite]
timestamp: 2026-06-03T00:14:50Z
resource: ./papers/02-reducing-loader/README.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# Paper 02 — The reducing loader *(staged)*

**A model transcoded into a *smaller* artifact that loads zero-copy and runs bit-faithfully — same top-1 output as the original. On a 35B mixture-of-experts model: 16.3 GB vs the source's 19.7 GB, top-1 identical.**

- Read it: [`paper.md`](paper.md)
- Receipts (ledger slice): [`receipts.md`](receipts.md) · master: [`../../LEDGER.md`](../../LEDGER.md)
- Reproduce: [`repro/`](repro/) — **harness TODO before release** (see below)

The *bolt-on* half of the project: keep a model's exact behavior, get a smaller artifact and a load path that never inflates a quantized weight to fp16 in RAM (avoiding the customary ~4× bandwidth/footprint tax). Codec-by-source means the transcode repacks the source's quantization rather than re-quantizing it — lossless relative to the model you already had.

**Status:** staged. Its receipts (L1–L4) come from prior measured work; per the series' release rules this paper does not go public until its one-command repro is built and the gates are re-run. See [`../../SERIES.md`](../../SERIES.md).
