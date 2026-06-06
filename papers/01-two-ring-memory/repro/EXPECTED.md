# R9 — what success looks like

> **Status (2026-06-06):** the reference composed 32k run completed and **MISSed** at the B=512 budget (= 64× selection at 32k; the gated regime was 2×–8×, and the run carried a router-config regression — see the [ledger](../../../../LEDGER.md) row 01-R9). This file describes what a HIT looks like so a reproduction can be scored; the mechanism itself (poison-gated retrieval off the drive) is proven at 512 positions (R3). Until R9 is diagnosed and re-gated, treat the 32k HIT below as the *target output*, not a reproduced result.

Two lines print at startup (config), then — after the I/O-bound prefill — the result.

## At startup (confirms the memory + storage setup)

```
    [ring1] f32 cache SHRUNK to window: 36 slots/layer (sink 4 + W 32) = 8.3 MB vs full 7521.7 MB (911x)
    [ring2] PHYSICAL Optane spill ON (W=32, sinks pinned in Ring-1, ... old reads MUST come off disk; v1 per-layer dedupe staging)
    [ring2-disk] Optane store @ F:\ (NO_BUFFERING + IOCP, 4096 B/block, 3.76 GB/file)
```

- `911x` is the **memory-wall receipt (R5)**: the resident KV cache is 8.3 MB instead of the dense 7.5 GB. (Net process RAM is ~1.8 GB, router-index-dominated — both numbers are true; quote both.)
- `3.76 GB/file` × 2 (K+V) = the full history living **on the drive**, not in RAM.

## At the end (the headline — R9 / R3)

```
    [ring2-disk] <N> blocking reads, <T> s total, <X> us/read avg
[niah] HIT  N=32768(actual=32768) depth=50% inj_tok=16384  B=512 W=32 R=32 RING2=1  answer=" 837492. ..."
```

- **`HIT` + `837492` in the answer = the proof.** The needle injected at depth 50% (token ~16384) was retrieved after the model attended to keys fetched off the drive. Ring-1 is a 36-slot window, so that token is **not in RAM** — a correct answer is only possible if the block came off the drive. (The engine NaN-poisons evicted Ring-1 slots, so a stale/fake read can't pass — that's the poison gate.)
- `<X> us/read` is the **latency receipt (R4)**. On Optane this is single-digit µs (~7.6 on the dev host). **On a generic NVMe it will be higher** (tens of µs) — that's expected; the *correctness* is identical, only the latency is media-dependent. Do not quote 7.6 µs unless you ran it on Optane.

## What a FAILURE looks like

- `[niah] MISS ... answer="..."` without `837492` → the needle was lost. At B=512 (4×) on the 0.6B reference this should be a HIT; a MISS means the budget/sinks were changed, the drive path failed silently, or the model/corpus differ.
- A crash before the `[ring2-disk] ... reads` summary line → an I/O or build problem, not a model problem (the summary prints in cleanup).

## Honest scope

- One model (Qwen3-0.6B), one needle type, one depth in this script. The sweep (depths 10/50/90, budgets 2×/4×/8×, N=512…32k) is in the paper; this script reproduces the single headline point.
- Runtime is long (~1–2 h+) because recall runs during the *whole* prefill in this build — an I/O artifact, not the production decode pattern. The `SP_RECALL_DECODE_ONLY=1` mode (dense prefill, sparse decode) is faster but trades the always-low-RAM property; see the paper's §3.7.
