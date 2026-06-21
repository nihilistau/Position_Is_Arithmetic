---
type: gate-receipt
title: "EXPECTED — what success looks like (paper 08, ledger X-R2)"
description: pre-registered < 2.0% bar = GREEN.
tags: [gate-receipt, kv]
timestamp: 2026-06-14T04:01:35Z
resource: ./papers/08-o1-kv-learned-router/repro/EXPECTED.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# EXPECTED — what success looks like (paper 08, ledger X-R2)

> **Status (series rule 4):** the front-door receipt is **measured + gated**
> (X-R2) from the cited commits against the cited receipt logs. These are the
> expected gate lines a reproduction is scored against — not a claim of a fresh
> re-run here. The standalone one-command repro + re-gate is the pre-release step.
>
> All runs: Gemma-4-12B **B1** artifact (`gemma4-12b-b1.sp-model` + `.sp-tokenizer`,
> PPL 4.6665 == gold — NOT the plain `gemma4-12b.sp-model`, which is the coarse
> 7.4M-PPL QAT variant), RTX 2060 12 GB, clocks pinned, `gemma4_decode_cuda`
> backend-direct. Fixtures: `tests/fixtures/ppl/wiki.valid.g4tokens.txt` (PPL/NIAH
> haystack), `tests/fixtures/lsh/lsh_M_r32.bin` + `lsh_R_r32_raw.bin` (the router).

## (a) The router win — `_run_g2_lsh.bat` (commit `222463a`)

```
===== FULL baseline =====
... SP PPL = 5.1551 ...
===== LSH 8x (B=256) M=...lsh_M_r32.bin =====
... SP PPL = 5.1791 ...
```

- FULL **5.1551** vs LSH r=32 **5.1791** = **+0.47%** deflection — under the
  pre-registered **< 2.0%** bar = **GREEN**. (Frozen ±1 = +4.17% RED; oracle
  ceiling = −0.08%; same per-step cost as frozen — M = R·Rᵀ reuses `k_qk_scores`.)
- N=2048 × 3 windows = **3072 scored positions** (the full corpus — the small-N
  42-position read that showed a fake −3.21% was the noise illusion).

## (b) The O(1) VRAM ladder — `_run_g2_cb2_vram.bat <N> 4400 1 <tag>` (slab `725058c`/`33ac632`)

```
===== C-b.2 VRAM gate NCTX=8192  BSLAB=4400 ... =====  SP PPL = 5.0549  union=2058 clip=0  VRAM ~11440-11476 MiB  VRAM_EXIT=0
===== C-b.2 VRAM gate NCTX=16384 BSLAB=4400 ... =====  SP PPL = 5.1371  union=2287 clip=0  VRAM ~11477-11524 MiB  VRAM_EXIT=0
```

- `nvidia-smi` **flat within ~50 MiB across a 2× context jump** = the **O(1)
  cache** receipt. A full O(N) cache would have added **~5.4 GiB** over 8k→16k.
- `union` grew only 2058→2287 (GQA-overlap ceiling far below nh·B=4096); `clip=0`
  (no valid key dropped by a too-small slab).
- **Scope:** the ~11.4 GiB absolute floor is the **resident 9.4 GB model** in a
  backend-direct harness — a harness artifact. The KV term (ring W=1024 + slab
  Bslab=4400 ≈ 0.8 GiB) is what is O(1) and what we claim. NOT "12B @ 16k on 12GB".

## (c) NIAH retention — `_run_niah_cc.bat <A|B|C> <depth> <N>` (commit `8e35877`/`3218d73`)

```
[g4-niah] N=16384 depth=10% n_prompt=... needle@[...,...) W=1024 swa_gap=14729
[g4-niah] HIT  depth=10% LSH=on SLAB=on PAGE=... SWA_RING=on gen_ids=[... 236828 236800 236832 236812 236819 236778 ...]
===== NIAH_EXIT=0 (0=HIT 3=MISS 2=err) =====
```

| condition | depth | N | expect | meaning |
|---|---|---|---|---|
| A (baseline: globals full + SWA ring) | 50 | 16384 | **HIT** | the model *can* retrieve at this depth |
| C (gate: slab + LSH r=32, 8×) | 10 | 16384 | **HIT** (837492) | needle survives the O(1) compaction (deepest edge) |
| C | 50 | 8192 | **HIT** (837492) | middle |
| C | 90 | 16384 | **HIT** (837492) | SWA boundary |
| B (neg control: slab + FROZEN ±1) | 50 | 8192 | **MISS** | 5/6 digits → corrupts `258882` → loops |

- The HIT is the **6 secret-digit tokens `837492`** as a contiguous subsequence
  in the free-decoded tail (token-space match — no tokenizer linkage).
- **SWA-isolation** is asserted in the harness (`needle_end ≤ n_prompt − W`); it
  ABORTS (exit 2) rather than score if the needle is inside the window — so a HIT
  can ONLY have traversed the global crossbar.
- The global K/V is **`0xFF` NaN-poisoned every step**, so a HIT proves the
  router *selected* the needle's key AND served it off Ring-2 (a poisoned,
  un-paged slot would NaN-corrupt the output).
- **The B MISS is the point:** the frozen ±1 router gets 5/6 digits then corrupts
  the sixth — coarse geometry pulls the region but can't land the key. So the HIT
  is the **learned router**, not leakage.

## What a FAILURE looks like

- `[g4-niah] MISS` in condition C, or the secret absent from `gen_ids` → the
  router lost the needle (budget/weights/slab changed, or the model/fixture
  differ).
- `[g4-niah] ABORT: needle NOT SWA-isolated` (exit 2) → raise N or lower depth;
  the needle fell inside the window and the test refuses to score a non-isolated
  HIT.
- PPL deflection ≥ 2.0% in (a), or `clip > 0` / VRAM growth in (b) → a regression,
  not a model problem.

## Honest scope

One model (Gemma-4-12B B1), one host (RTX 2060 12 GB), one needle type. The
≤8× / N≤16k band is the gated regime; 32×–64× budgets are exactly where paper
01's composed 32k run MISSed (01-R9) and are not claimed. Proof-of-mechanism, not
a scaling study, not independently reproduced.
