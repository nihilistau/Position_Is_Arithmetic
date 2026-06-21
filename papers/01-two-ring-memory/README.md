---
type: paper-bite
title: Paper 01 — Two-ring memory
description: "A needle retrieved with the cold KV cache served off an NVMe drive (poison-gated, 7.57 µs/read), a 910× resident KV-cache shrink at 32k context, and 8× KV sparsification at +0.69% perplexity (2× and 4"
tags: [paper-bite, memo, two-ring, memory]
timestamp: 2026-06-06T11:56:47Z
resource: ./papers/01-two-ring-memory/README.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# Paper 01 — Two-ring memory

**A needle retrieved with the cold KV cache served off an NVMe drive (poison-gated, 7.57 µs/read), a 910× resident KV-cache shrink at 32k context, and 8× KV sparsification at +0.69% perplexity (2× and 4× go negative).**

> **Status note (2026-06-06):** the composed 32k retrieval run (R9) completed and **MISSed** — B=512 at 32k is a 64× selection budget, far beyond the gated 2×–8× regime, and the run carried a router-config regression (details in the [ledger](../../LEDGER.md)). The infrastructure half of that run (16.3 h saturated dual-store I/O, 67% temporal-cache absorption, queue-depth latency measured) is real. The retrieval claims this paper makes are the **512-position-proven** ones; the 32k needle is an open diagnostic, not a claim.

- Read it: [`paper.md`](paper.md)
- Run the storage-retrieval receipt: [`repro/run_r9_32k_needle.ps1`](repro/) — expected output in [`repro/EXPECTED.md`](repro/EXPECTED.md) (see the status note above re: 32k)
- Receipts (this paper's ledger slice): [`receipts.md`](receipts.md) · full master ledger: [`../../LEDGER.md`](../../LEDGER.md)
- Discipline: [`../../METHODOLOGY.md`](../../METHODOLOGY.md)

A memory architecture that attaches to a frozen pretrained transformer and preserves its outputs, knocking down the three walls of long-context inference — memory (a two-ring offload to byte-addressable storage), compute (a ±1 projection router + O(N) selection), and quality (attention-sink pinning). Every mechanism is bit-exact when disabled.

Proof-of-mechanism on Qwen3-0.6B; scope and honest negatives are in the paper.
