---
type: paper-bite
title: "O(1) KV: a context-decoupled cache with a learned sparse router"
description: "Shannon-Prime release series, paper 08."
tags: [paper-bite, kv]
timestamp: 2026-06-14T04:01:01Z
resource: ./papers/08-o1-kv-learned-router/paper.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# O(1) KV: a context-decoupled cache with a learned sparse router

*Shannon-Prime release series, paper 08. Discipline: [METHODOLOGY.md](../../METHODOLOGY.md).
Every number below is a row in [LEDGER.md](../../LEDGER.md) (**X-R2**) with a command behind it.*

*A. Knack. Draft. All quantitative results are proof-of-mechanism on one model
(Gemma-4-12B, the B1 artifact of paper 06) on one host (RTX 2060, 12 GB); see §1
for the honest scope and §7 for reproduction.*

---

## The claim this paper makes

Mainstream inference treats the KV cache as an opaque, ever-growing scratchpad:
its VRAM footprint is O(context). It does not have to be. This paper makes the
KV-cache **term** of a frozen Gemma-4-12B **O(1) in context length** — flat VRAM
from 8k to 16k tokens — and shows the needle still survives the compaction. The
load-bearing part is *which* keys to keep: a learned **512×32 LSH projection
router** selects the global top-B keys at **+0.47% perplexity** at 8×
compression, where the oracle ceiling is **−0.08%** and a frozen ±1 geometric
router is **+4.17%** (RED). The needle survives **only because the router is
learned** — a frozen-router negative control MISSES at the same depth.

This is paper 01's two-ring memory thesis carried from a 0.6B reference (where
the composed 32k run MISSed at a 64× selection budget, 01-R9) to a 12B with a
learned router that does not miss. It answers the question the series left open
— *does 8×-at-<2% hold past 0.6B?* — with: yes, **+0.47% on a 12B**.

---

## 1. Why the cache, not the weights, is the long-context wall — and the honest scope

Paper 06 established the other wall: on a memory-bound GPU, the weights' byte
count is the decode-speed limit, and computing on packed integer codes recovers
the byte ratio. That wall is about the **weights**, which are fixed in size. The
long-*context* wall is different: the **KV cache** grows linearly with the
number of tokens in context. A token's worth of K and V must be stored for every
past position, in every layer, for the lifetime of the generation. At 32k tokens
this is gigabytes; it grows without bound as context extends; and it is the term
that decides whether a model can hold a long document on a small card at all.

The naive fix — keep only the highest-scoring keys — degrades the output
distribution badly (paper 01 measured a +104% perplexity catastrophe at 8× with
a hard top-B truncation and no sink pinning). The fix has to *select* the right
keys and *realize* the saving without re-introducing an O(context) cost
somewhere else. This paper does both, and gates each separately.

**The honest scope, stated before it can be used against us.** The thing this
paper makes O(1) is the **KV-cache term**, not the absolute VRAM footprint. The
measurement harness (`test_gemma4_ppl_cuda`, `test_gemma4_cuda`) calls
`gemma4_decode_cuda` **directly** — a backend-direct path that keeps the entire
9.4 GB resident model in VRAM and bypasses the L1/session/daemon layer and the
arena's zero-copy weight streaming. So the *absolute* steady-state footprint
(~11.4 GiB at both 8k and 16k) is dominated by the resident model and is a
**harness artifact**, not the production memory model. We therefore deliberately
do **not** publish "12B @ 16k on 12 GB." The claim is narrower and exact: the
**KV term** — the SWA ring plus the global slab, ~0.8 GiB — is the part that
*would* grow with context in a stock cache, and it is the part we hold flat. The
arena-streamed weight footprint is a separate full-stack gate, not claimed here.

---

## 2. The two-source structure: a ring and a slab

Gemma-4 mixes two attention geometries across its 48 layers, and each gets its
own O(1) treatment.

**The 40 sliding-window (SWA) layers — a W-slot ring.** Gemma's SWA is a *pure*
sliding window: no attention sinks, the window of the last W=1024 tokens is
always live, and nothing outside it is ever attended. There is therefore nothing
to *page* on these layers — only a ring to allocate. A SWA owner allocates
`Wring = min(W, P)` slots and writes position `pos` to slot `pos mod Wring`,
which evicts the slot that has just left the window for free. The decode kernel
reads the window in *position order* `(s0 + j) mod Wring`, so the floating-point
reduction is **byte-identical** to a full-cache window of the same width — the
non-associativity of float addition is defeated by fixing the order, not just
the key set. These 40 layers carry the dominant KVD (2048), so capping them at a
constant W is what caps the big term: ~21 GB → ~0.67 GB at 32k with W=1024.
*(Run-record G-P3-R2.b-2a, bit-exact 40/48 layers, ring-of-4 == full-cache
window-4, `diffs[4..16)=0`.)*

**The 8 global (full-attention) layers — a compact slab.** These attend over all
positions, so a ring cannot bound them — a sparse router must. The full K/V for
the 8 globals lives **resident in a host-RAM Ring-2**; each decode step pages the
small union of router-selected keys into a fixed-size device **slab** `[0, m)`,
remapping the gather index list from absolute position to compact slot. The slab
is **capped at the GQA union `nh·B`**, not `B`. This correction was *measured*,
not assumed: with `n_kv=1, n_h=16`, the single global K is scored against 16
query heads; gemma's global attention is diffuse, so each head's top-B is
near-orthogonal and the per-step union asymptotes to `nh·B = 16·256 = 4096`, not
`B + sink`. The compact-slab mechanics are output-invariant — SP PPL **5.1676 ==
the sidecar baseline 5.1676 exactly** — confirming the host-RAM store + per-step
union page-in + abs→compact-slot remap + compact gather reproduce full-cache
attention bit-for-bit (G-P3-R2.b-2c, engine `725058c`/`33ac632`).

The decoupling thesis, corrected: **SWA layers O(1) at `W`; global layers O(1)
at the GQA union cap `nh·B`.** Both terms are constant in context P. The global
curve goes flat at `nh·B = 4096` and never exceeds it whether P is 32k, 128k, or
1M — and the cap is only *visible* for N > nh·B (at N=2048 the union is
context-bound at ~1500, so no shrink shows at the small-corpus size; the gate
must run at N ≥ 8k).

---

## 3. The router is the load-bearing part: frozen → oracle → learned

The substrate above is bit-exact: it moves the right bytes once the *recall set*
is named. Naming the set is a learned-projection problem, and we measured it in
three stages — in order — on the full wikitext-2 validation corpus
(N=2048 × 3 independent windows = **3072 scored positions**), self-referentially
(FULL full-cache vs sparse-gather on the *same* tokens; baseline FULL SP PPL
**5.1551**). The deflection gate is the series' standard: relative PPL change
versus full attention, on the decode path, common-mode quantization, **bar < 2%**.

**(1) The frozen ±1 router — +4.17%, RED.** Paper 01's ±1 Rademacher projection
selector, ported to the 12B globals. At 8× (B=256) it deflects **+4.17%**, over
the line. A window-reallocation probe floors it at **+3.74%** (W=64) — still 1.74
points over. The failure is dominated by *loss of high-attention global keys the
frozen ±1 router cannot rank well enough*: a router-quality problem, not a
window-coverage one. (4× / B=512 holds at **+1.65%** and is the deployable v0
frozen op-point at N≤2k; 8× on static geometry is RED — and the small-N negative
deflections that had earlier looked like a *win* were the noise illusion of §6.)

**(2) The oracle ceiling — −0.08%, GREEN — measured before training a thing.**
Before committing to train an addresser, we measured whether *perfect* selection
(exact top-B by true q·K, `SP_ARM_ORACLE`) holds the bar. It does: 8× oracle =
**5.1512, −0.08%**; 4× oracle = **5.1544, −0.01%**. This proves 8× is **not
information-bounded** — the entire frozen +4.17% is router quality, and the
frozen→oracle gap (~4.25 PPL-points) is pure addressable headroom. The
mass-captured proxy had said "concede 4×" (exact top-B keeps only 92.3% of
attention mass at 8×); the on-engine oracle PPL flipped it to "8× is learnable,
train it" — the dropped 7.7% was diffuse low-value noise, and discarding it
slightly *denoises* the distribution. (Methodology, paper 10: measure the
ceiling on the real metric before you mutate.)

**(3) The learned 512×32 LSH router — +0.47%, GREEN — at the same per-step cost.**
With the ceiling proven reachable, we trained a single shared **512×r projection
R** so that top-B by `(Rq)·(RK)` matches the oracle's top-B by exact q·K. The
loss is **forward-KL(true ‖ projected)** (mass-weighted by construction, so it
ignores the diffuse noise tail that fooled the mass proxy) **+ 0.2× a
hard-negative hinge + a learnable temperature τ** (`tools/xbar_lsh/train_lsh.py`,
GPU 0.8 s/epoch on the 2060, trained on the `SP_ARM_DUMP` post-RoPE K/q corpus,
strictly held-out validation window). At r=32 — **16,384 parameters** — the
deployed router (M = R·Rᵀ, top-B by `(Mq)·K`, reusing the existing `k_qk_scores`
kernel via a per-head query transform `q' = Mq`, **zero new hot-path kernels,
inference cost independent of r**) lands:

| 8× selector | SP PPL | deflection | gate |
|---|---|---|---|
| frozen ±1 (v0) | 5.3702 | +4.17% | RED |
| **LSH r=32 (learned)** | **5.1791** | **+0.47%** | **GREEN** |
| oracle ceiling | 5.1512 | −0.08% | (best possible) |

**8× global compression is won on a 16,384-parameter learned projection at
+0.47% PPL — identical inference cost to the frozen router, 0.55 points off the
oracle ceiling.** No escalation to r=64/128 was needed. The learned head closed
the frozen→oracle gap (+4.17% → +0.47%). *(Run-record G-P3-R2.b-2b-LSH, engine
`222463a`; weight `tests/fixtures/lsh/lsh_M_r32.bin`.)*

---

## 4. Realizing the win: the sidecar, the slab, and the 8k↔16k VRAM ladder

Proving the *selection* is correct (§3) is not the same as realizing the *VRAM*
saving. A router cannot rank a key it has already evicted, so a compact slab
requires **resident r-dim router state**: a sidecar of projected keys `RᵀK`,
r=32, **16× smaller than the full K**, kept resident while the full K/V lives in
host-RAM Ring-2 (`SP_ARM_LSH_R`, the C-b.1 sidecar — `tests/fixtures/lsh/lsh_R_r32_raw.bin`).
Selection is moved device-side (`SP_ARM_DEVSEL`, top-B on the GPU), severing the
host round-trip, selection-invariant (5.1791 == 5.1791).

With the slab fed by the sidecar and the union capped at `nh·B`, the cache term
goes flat. The ladder (both N > nh·B and > W, so the allocation is byte-identical
by construction):

| N | global slots (Bslab) | SWA slots (W) | union | clip | SP PPL | VRAM steady (MiB) |
|---|---|---|---|---|---|---|
| 8192 | 4400 | 1024 | 2058 | 0 | 5.0549 | ~11440–11476 |
| 16384 | 4400 | 1024 | 2287 | 0 | 5.1371 | ~11477–11524 |

`nvidia-smi` is **flat across a 2× context jump — ~50 MiB of allocator jitter,
NOT growth.** A full O(N) cache would have added **~5.4 GiB** over 8k→16k. The
union grew only 2058 → 2287 (the GQA-overlap ceiling sits far below the
worst-case nh·B=4096), clip events = 0 (no valid key was ever dropped by a
too-small slab). **O(1) KV-cache-in-context is confirmed on the real 12B.**
*(Run-records G-P3-R2.b-2c-8k engine `33ac632`, and the 16k asymptote leg
2026-06-14; receipts `results/g2_cb2_8k_fixed.log` / `g2_cb2_16k_fixed.log` +
their `_smi.csv`.)*

The scope note from §1 applies in full here: the ~11.4 GiB absolute floor is the
resident model in a backend-direct harness; the **~0.8 GiB KV term** (ring W=1024
+ slab Bslab=4400) is the part that is O(1) and the part we claim.

---

## 5. NIAH retention: the needle survives the compaction — and the frozen control MISSES

A cache can be O(1) and useless if the compaction throws away the one key that
mattered. The retention gate (G-P3-R2.b-2c-NIAH, engine `8e35877`/`3218d73`)
plants an out-of-distribution secret in the haystack and asks whether it
survives the O(1) compaction under NaN-poison — and it pre-registered its bounds
*before* the code was written.

**The construction makes a HIT mean only one thing.** The needle is planted so
that `needle_end ≤ n_prompt − W` — strictly outside the W=1024 sliding window at
the generation point. The SWA ring is therefore *physically blind* to it, and the
harness aborts rather than score if that isolation does not hold. Every global
K/V is `0xFF` NaN-poisoned **every step over the whole pass**, so the needle
cannot leak forward through un-poisoned residuals; only the router-recalled union
is served off Ring-2 into the slab. A HIT therefore proves the router *selected*
the needle's global key *and* served it correctly off disk. (The match is in
token space — the 6 secret-digit tokens `837492` as a contiguous subsequence in
the free-decoded tail — so no tokenizer linkage is needed.)

| depth | N | needle pos | SWA gap | condition | result |
|---|---|---|---|---|---|
| 10% (deepest edge) | 16384 | 1634 | 14729 | slab + LSH r=32 | **HIT** (exact 837492) |
| 50% (middle) | 8192 | 4078 | 4093 | slab + LSH r=32 | **HIT** (exact 837492) |
| 90% (SWA boundary) | 16384 | 14714 | 1649 | slab + LSH r=32 | **HIT** (exact 837492) |
| 50% (**NEG CONTROL**) | 8192 | 4078 | 4093 | slab + **FROZEN ±1** | **MISS** (5/6 digits → corrupted `258882` → loop) |

**The negative control is decisive.** The frozen ±1 router recalled the right
*neighborhood* and got *five* of six digits, then corrupted the sixth and looped:
coarse geometry pulls the region but lacks the resolution to land the key. The
learned LSH projection nails all six. So the HIT is the **learned router's**
doing, not residual leakage, and the poison/compaction genuinely severs
un-selected keys. The full-attention 16k baseline is *physically impossible* on
the 2060 — the context-sized softmax shared-memory exceeds 64 KB and the cache
OOMs — which is itself the motivation: condition C reaches a regime the dense
baseline cannot. *(Receipts `results/niah_{C_d10_16k, C_d50_8k, C_d90_16k,
B_d50_8k}.log`.)*

**§P3.2-b-2b / Phase C is closed end-to-end: select (LSH won 8×) → realize (slab
O(1), 8k↔16k flat) → retain (NIAH survives the compaction at all depths).**

---

## 6. The pre-registered gate: bridging bit-exact to lossy

Every other mechanism in this series has a bit-exact floor: it is a strict no-op
when off, argmax-identical to the stock model. A sparse cache cannot be
bit-exact by construction — it drops keys and changes the reduction tree, so
"diffs = 0" dies the moment selection turns on. When a stage crosses from exact
to lossy, the gate **type** must change with it, and the new bar must be
**pre-registered before the code** so it cannot be quietly retuned until a number
passes.

That bar here is the **deflection gate: < 2.0% relative PPL** versus full
attention, fixed before the router was written, the same < 2% paper 01 used at
0.6B. The substrate underneath the router stays bit-exact (the SWA ring is
byte-identical, the slab mechanics are output-invariant, the served-off-disk
gather is `diffs[4..16)=0` under poison) — only the *selection* is lossy, and it
is the selection the 2% bar governs.

One honest-negative episode is part of the evidence the gate discriminates. The
mechanism-closing G2 first ran on a tiny corpus (n_ctx=84, **42 scored
positions**) and showed *negative* deflections (4× −0.31%, 8× −3.21%) that looked
like a quality win. They were small-sample noise — the sign flipped on the full
corpus (3072 scored positions: 4× +1.65%, 8× +4.17%). The rule that caught it:
count scored positions in the hundreds-to-thousands on a real corpus before any
deflection verdict; mechanism-closed ≠ operating-point-validated. We report only
the full-corpus number.

---

## 7. Reproduction

Each headline reproduces from a single `.bat`, with the model, fixture,
environment knobs, gate line, and commit specified. **Honest framing: these
reproduce from the cited commits via the cited commands against the cited receipt
logs — this paper does not claim a fresh re-run** (per series rule 4, a re-gate +
standalone repro is the pre-release step). Expected gate lines are in
[`repro/EXPECTED.md`](repro/EXPECTED.md).

**Prerequisite artifacts.** The **Gemma-4-12B B1 `.sp-model` + `.sp-tokenizer`**
(`gemma4-12b-b1.sp-model` — the OK_Q4B artifact of paper 06, transcoded
`sp_transcode --st`; PPL 4.6665 == gold, the plain `gemma4-12b.sp-model` is the
coarse per-row QAT variant at 7.4M PPL and must not be used). The two learned
LSH weight files: **`tests/fixtures/lsh/lsh_M_r32.bin`** (the deployed M = R·Rᵀ)
and **`tests/fixtures/lsh/lsh_R_r32_raw.bin`** (the resident r=32 sidecar). The
SP-tokenized wikitext-2 validation fixture
`tests/fixtures/ppl/wiki.valid.g4tokens.txt`.

**The knobs** (all in `src/backends/cuda/cuda_forward.cu`, behind `SP_ARM_*`,
byte-inert when off; harness `tests/test_gemma4_cuda.c` `SP_G4_NIAH` mode and
`tests/test_gemma4_ppl_cuda.c`):
- `SP_ARM_SHADOW` / `SP_ARM_GATHER` / `SP_ARM_B` — host-side select + wire the
  recall set into `k_attn_decode_gather`, budget B (8× = 256).
- `SP_ARM_LSH=<M.bin>` — the learned router (M = R·Rᵀ); absent = frozen ±1.
- `SP_ARM_LSH_R=<R_raw.bin>` — the resident r=32 sidecar (slab needs it).
- `SP_ARM_SLAB` / `SP_ARM_BSLAB` — the compact global slab + its depth (4400).
- `SP_XBAR_SWA_RING` — the W-slot SWA ring (no W override = bit-exact).
- `SP_CUDA_DECODE_INT8=1` — the tied-head int8 free-decode path (NIAH).

**(a) The router win — +0.47% @ 8× (X-R2; commit `222463a`).**
```
_run_g2_lsh.bat
```
Prints FULL baseline PPL then LSH 8× (B=256, M = `lsh_M_r32.bin`).
Expected: FULL **5.1551**, LSH r=32 **5.1791** → **+0.47%**, under the 2% bar.
Receipts: `tests/fixtures/lsh/results/` (G2 LSH logs).

**(b) The O(1) VRAM ladder — flat 8k↔16k (X-R2; slab `725058c`/`33ac632`).**
```
_run_g2_cb2_vram.bat 8192  4400 1 8k
_run_g2_cb2_vram.bat 16384 4400 1 16k
```
Expected: 8k PPL **5.0549** union 2058 clip 0 VRAM ~11440–11476 MiB; 16k PPL
**5.1371** union 2287 clip 0 VRAM ~11477–11524 MiB; `VRAM_EXIT=0`. The ~50 MiB
delta across a 2× context jump is the O(1) result (a full cache adds ~5.4 GiB).
Receipts: `results/g2_cb2_8k_fixed.log` / `g2_cb2_16k_fixed.log` + `_smi.csv`.

**(c) NIAH retention — three conditions (X-R2; `8e35877`/`3218d73`).**
```
_run_niah_cc.bat A 50 16384     REM BASELINE  : globals full + SWA ring     -> HIT
_run_niah_cc.bat B 50  8192     REM NEG CTRL  : slab + FROZEN router        -> MISS
_run_niah_cc.bat C 10 16384     REM GATE      : slab + LSH r=32, depth 10%  -> HIT
_run_niah_cc.bat C 50  8192     REM GATE      : slab + LSH r=32, depth 50%  -> HIT
_run_niah_cc.bat C 90 16384     REM GATE      : slab + LSH r=32, depth 90%  -> HIT
```
Expected gate line: `[g4-niah] HIT depth=… LSH=on SLAB=on …` with the 6 secret
tokens (`837492`) in the generated tail; exit 0=HIT / 3=MISS / 2=err. The B
condition MISSES (5/6 digits then corrupts) — the isolating negative control.
Receipts: `results/niah_{C_d10_16k, C_d50_8k, C_d90_16k, B_d50_8k}.log`.

The trainer that produced the weight files (offline, not a per-decode path):
`tools/xbar_lsh/train_lsh.py` (forward-KL distill + hard-negative hinge +
learnable τ; trains on the `SP_ARM_DUMP` post-RoPE K/q dump, strict held-out
validation window).

---

## 8. Honest boundaries

- **One model, one host, proof-of-mechanism.** Gemma-4-12B (B1 artifact) on an
  RTX 2060 12 GB. Not a scaling study, not multi-model, not independently
  reproduced.
- **The O(1) claim is the KV term, not the absolute footprint.** The
  backend-direct harness keeps the 9.4 GB resident model in VRAM (~11.4 GiB
  floor) — a harness artifact. We do **not** claim "12B @ 16k on 12 GB." The
  ~0.8 GiB cache term is what is O(1).
- **Lossy by definition past the substrate boundary.** The router is a heuristic
  selection; bit-exactness lives in the off state and in the substrate
  (ring/slab/served-off-disk). The +0.47% bar is the bounded-degradation gate,
  pre-registered at < 2%.
- **8× is the gated band; further is ungated.** The ≤8× / N≤16k regime is gated;
  32×–64× budgets are exactly where paper 01's composed 32k run MISSed (01-R9),
  and they are not claimed here.
- **The global constant is `nh·B`, not `B`.** The decoupling is real (constant in
  P), but the GQA union sets the constant at `nh·B = 4096` for gemma's diffuse
  globals — corrected by measurement, not assumed.

---

## Receipts

Ledger row: **X-R2** (the full claim — learned router +0.47% @ 8×, oracle −0.08%,
frozen +4.17%; O(1) VRAM 8k↔16k flat ~50 MiB; NIAH 10/50/90% HIT, frozen-control
MISS). Run-records in lattice `papers/CONTRACT-XBAR-P3-ring-on-exec.md`:
G-P3-R2.b-2a (SWA ring), G-P3-R2.b-2b / -N / -ORACLE / -LSH (the router
progression), G-P3-R2.b-2c / -8k / 16k-ladder (the slab + O(1) VRAM), -2c-NIAH
(retention). Engine provenance: `src/backends/cuda/cuda_forward.cu` (the
ring/slab/router + `SP_ARM_*` knobs), `tests/test_gemma4_cuda.c` (`SP_G4_NIAH`),
`tests/test_gemma4_ppl_cuda.c` (the deflection gate), `tools/xbar_lsh/train_lsh.py`
(the trainer). Weights: `tests/fixtures/lsh/lsh_M_r32.bin`,
`tests/fixtures/lsh/lsh_R_r32_raw.bin`. Run-scripts: `_run_g2_lsh.bat`,
`_run_g2_oracle.bat`, `_run_g2_largeN.bat`, `_run_g2_wprobe.bat`,
`_run_g2_cb1.bat`, `_run_g2_cb2.bat`, `_run_g2_cb2_vram.bat`, `_run_niah_cc.bat`.
Receipt logs: `tests/fixtures/lsh/results/`. Commits: LSH win `222463a`, slab
`725058c`/`33ac632`, device-select `7195100`, sidecar `7cd7482`, NIAH
`8e35877`/`3218d73`, ppl-gate repoint `51bdb76`. Companions: 01 (the two-ring
thesis this scales), 06 (the B1 artifact and the gold instrument), 07 (the
crossbar that writes into this cache), 10 (the oracle-ceiling-before-training
discipline and the small-N noise illusion).
