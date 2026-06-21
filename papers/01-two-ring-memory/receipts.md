---
type: gate-receipt
title: Paper 01 — receipts (ledger slice)
description: "Extract of the [master ledger](../../LEDGER.md) rows tagged 01."
tags: [gate-receipt, memo, two-ring, memory]
timestamp: 2026-06-06T11:57:11Z
resource: ./papers/01-two-ring-memory/receipts.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# Paper 01 — receipts (ledger slice)

Extract of the [master ledger](../../LEDGER.md) rows tagged `01`. Every row is reproducible per [`../../METHODOLOGY.md`](../../METHODOLOGY.md).

| # | Claim | Number | Gate | Caveat |
|---|---|---|---|---|
| R1 | Quality at 8× KV sparsification | +0.69% PPL (2× −0.71, 4× −0.92) | <2% deflection | 0.6B, 2k, one corpus |
| R2 | Needle retrieval, no recency bias | HIT at depth 10/50/90, to 8× @2k | NIAH HIT | one model, one needle type |
| R3 | Two-ring on physical Optane | HIT off NVMe | poison-gated | 512 proven; 32k = R9 |
| R4 | Random-read latency | 7.57 µs/read | timed, no page cache | Optane-specific |
| R5 | KV-RAM footprint | 910× cache (1.8 GB live) | measured | net ~8×, router-index-dominated |
| R6 | KV codec | ~3.5×/f32, lossy | 29/31 argmax, KL .023 | not bit-exact |
| R7 | O(N) recall selection | set-equivalent | parity + HIT | time win not benchmarked |
| R8 | Bit-exact when disabled | bit-identical | argmax parity | methodology |
| R9 | 32k needle off NVMe @ ~1.8 GB | **MISS** (run completed 16.3 h, zero errors; 67% cache absorption; 19.6 µs/read at QD) | NIAH HIT (poison) — **not met** | B=512 @ 32k = 64× selection (gated regime was 2×–8×); router-config regression (f32 r=16, not bits-r64/KVSEL); no full-attention 32k control — **measured honest negative, not a claim** |

**Honest negatives (in the paper):** CPU decode ~1.34× behind llama.cpp-Q8 — the value is the memory envelope, not throughput; a magnitude-histogram recall signature was falsified and dropped; the composed 32k retrieval (R9) MISSed at the 64× selection budget — diagnosis open, the paper's retrieval claims are the 512-position-proven ones.

Commit chain: `67f4997` → `f8ea920` (+ `a5e9b86`).
