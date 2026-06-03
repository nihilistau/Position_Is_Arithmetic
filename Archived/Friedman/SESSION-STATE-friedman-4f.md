# SESSION-STATE-friedman-4f.md

**Phase 4f — Calibration sweep on Gemma3-1B at production scale (ctx=128, chunks=4). Result: the dominance-only Friedman sieve in POLICY mode is *non-viable* at this scale across every τ_A on the explored range. Minimum-PPL configuration (τ_A = 0.30) sits at PPL = 34.7317 vs baseline 10.4658 (+231 %), three orders of magnitude outside the T2.3 |Δ| ≤ 0.5 % gate. Capacity is confirmed irrelevant; chunk-cascade is the structural problem.**

*Shannon-Prime Project · Friedman Stack rollup · 2026-05-20*

---

## TL;DR

Phase 4e (ctx=64, chunks=1) found a tame regime: at τ_A = 0.10, PPL drift was +5.79 % with 11.30 % eviction rate. The Phase 4f contract called for the same encoder + sieve under a bigger eval budget (ctx=128, chunks=4) to tighten the variance band so a calibration knee could be resolved inside the T2.3 |Δ| ≤ 0.5 % gate.

The bigger budget revealed a *structural* problem rather than a variance one: at ctx=128, chunks=4 the chunk-to-chunk PPL_running cascades upward as evictions accumulate across the four chunks (each chunk re-uses the previous chunk's sieve state). What looked like a +5.79 % nuisance at ctx=64/chunks=1 expands to +50 %, +200 %, +1500 % as more history is in play.

Across **three independent sweeps** (v1 wide grid τ ∈ {0.07..0.15} × cap ∈ {1024,2048,4096}; v2 high-τ probe τ ∈ {0.20..5.0}; LOW probe τ ∈ {0.00..0.05}) the minimum PPL achievable in POLICY mode was **τ_A = 0.30 → PPL = 34.7317** at 34.35 % eviction. Even that point is 3.3× baseline.

The conclusion: dominance-only subsumption is a viable *equivalence relation* and *theory operator* (Dickson's Lemma, Phase 4c §11.6) but it is too aggressive as a *runtime KV eviction policy* on real attention activations at production context lengths. **POLICY mode is shelved as a default. OBSERVER mode (which is bit-identical to baseline by construction — see Phase 4c) remains the production setting.**

## Configuration

| Parameter | Value |
|-----------|-------|
| Engine | `D:\F\shannon-prime-repos\shannon-prime-engine\build-cuda\bin\sp-engine.exe` |
| Engine commit | 2ccc2f2 (HEAD after Phase 4d wiring + README rewrite) |
| Model | `D:\Files\Models\Mine\gemma-3-1b-it\gemma-3-1b-it-Q4_0\gemma-3-1b-it-Q4_0.gguf` (Gemma3-1B Q4_0) |
| Corpus | `shannon-prime-engine/bench/test_corpus.txt` (198 603 bytes → 121 969 tokens) |
| Verb | `perplexity` with `SP_ENGINE_NATIVE=1` → `perplexity-native` path |
| ctx | 128 |
| chunks | 4 (252 evaluated tokens per run) |
| Quantisation | `--gguf-block-quant --frobenius-quant` |
| Sieve mode | `policy` for sweep cells; baseline runs sieve off |
| α (fixed) | 0.5 (degenerate at current Path-B 4-bucket scale — confirmed) |
| Capacity (fixed after capacity-irrelevance result) | 4096 |
| Baseline PPL | **10.4658** at 252 tokens |
| T2.3 gate band | [10.4135, 10.5181] |

## Headline numbers — every cell across the three sweeps

| Sweep | cap | τ_A | PPL | Δ vs base | Eviction | Admissions | Verdict |
|------:|----:|----:|----:|----------:|---------:|-----------:|--------:|
| baseline | — | — | 10.4658 | — | — | — | (pivot) |
| LOW | 4096 | 0.0000 | 1802.8341 | +17120 % | 72.92 % | 3 605 | FAIL |
| LOW | 4096 | 0.0050 | 719.5411 | +6776 % | 64.99 % | 4 661 | FAIL |
| v1 | 1024 | 0.0700 | 174.5451 | +1568 % | 42.65 % | 7 635 | FAIL |
| v1 (c4096 verify) | 4096 | 0.0700 | 174.5451 | +1568 % | 42.65 % | 7 635 | FAIL (bit-identical to c1024) |
| v1 | 1024 | 0.0800 | 39.5540 | +278 % | 41.26 % | 7 819 | FAIL |
| v1 | 1024 | 0.0900 | 191.2681 | +1727 % | 40.39 % | 7 935 | FAIL |
| v1 | 1024 | 0.1000 | 40.0224 | +282 % | 39.76 % | 8 037 | FAIL |
| v2 | 4096 | 0.2000 | 42.7178 | +308 % | 35.46 % | 8 592 | FAIL |
| v2 | 4096 | 0.3000 | **34.7317** | **+231 %** | **34.35 %** | 8 739 | FAIL (min on grid) |
| v2 | 4096 | 0.5000 | 45.7138 | +337 % | 41.32 % | 7 811 | FAIL |
| v2 | 4096 | 0.7000 | 80.7291 | +671 % | 53.16 % | 6 236 | FAIL |

τ ∈ {1.0, 1.5, 2.0, 3.0, 5.0} cells were killed early once the upturn at τ = 0.7 was confirmed — eviction rate is rising again, not falling.

## Structural findings

### 1 — Capacity is not a lever at the present operating point

c1024 τ = 0.0700 and c4096 τ = 0.0700 produced **bit-identical** PPL = 174.5451, identical eviction count 5677 / 13312, identical admissions 7635, identical wall time within noise. The dominance subsumption fires often enough that the caches never approach `cap`, so capacity choice is irrelevant.

This kills two cells of the original 22-cell sweep contract (the cap dimension); the rest of the report is on cap = 4096 only.

### 2 — Chunk cascade is the structural failure mode

The chunk-by-chunk PPL_running curve at τ = 0.07 (c1024 or c4096, indistinguishable):

| Chunk | PPL_running | Δ vs baseline-chunk |
|------:|------------:|-------------------:|
| 1/4 | 10.1004 | +25 % |
| 2/4 | 18.2699 | +111 % |
| 3/4 | 27.5363 | +252 % |
| 4/4 | 174.5451 | +1568 % |

Each chunk re-uses the prior chunk's sieve cache state. Evictions accumulate. The PPL_running blows up super-linearly. The same pattern shows up at every τ_A across all three sweeps — the slope of the cascade is roughly proportional to the eviction rate.

This is *not* a variance-noise problem; doubling chunks doesn't smooth it out, it amplifies it. The Phase 4e ctx=64 / chunks=1 run only ever saw chunk-1-equivalent damage and so reported the misleadingly tame +5.79 % at τ = 0.10.

### 3 — τ_A semantics are inverted vs naïve expectation

Encoder rule (`sp_kste.c` ll. 153-154): an anchor enters the tree only if `|x| ≥ τ_A · amax`. Naïve reading: higher τ_A ⇒ fewer anchors ⇒ sparser, more distinct trees ⇒ less dominance ⇒ less eviction.

Empirical: eviction rate is **U-shaped** across τ_A:

| τ_A | Eviction rate |
|----:|--------------:|
| 0.00 | 72.92 % |
| 0.005 | 64.99 % |
| 0.07 | 42.65 % |
| 0.08 | 41.26 % |
| 0.09 | 40.39 % |
| 0.10 | 39.76 % |
| 0.20 | 35.46 % |
| **0.30** | **34.35 %** ← minimum |
| 0.50 | 41.32 % |
| 0.70 | 53.16 % |

Floor of the U: τ_A ≈ 0.30 with eviction ≈ 34 %.

Interpretation. At τ_A = 0 the encoder admits every noise-driven anchor, so trees are dominated by random low-amplitude structure → "average-shaped" trees → high pairwise dominance → high eviction. At τ_A = 0.5–1.0 only the top one or two anchors survive, so all trees collapse to a handful of generic shapes → also high pairwise dominance → also high eviction. The middle ground τ_A ≈ 0.30 retains enough detail to distinguish trees but not enough noise to make every tree look like every other one.

Even at the minimum, eviction = 34 % is too aggressive for the chunk-cascade to absorb. PPL at the U-floor (PPL = 34.7317) is still 3.3× baseline.

### 4 — There is no τ_A that clears T2.3 on Gemma3-1B at this scale

T2.3 gate band [10.4135, 10.5181]. Every cell sits 3.3×–172× above the band's upper edge. Refinement around τ_A = 0.30 is not going to recover three orders of magnitude.

## Math state — unchanged

The Phase 4c §11.6 result (the Dickson's-Lemma proof that ⪯_d is a well-quasi-ordering on 𝒯_{60,3} via embedding into ℕ¹⁴ under elementwise product order) is unaffected. ⪯_d remains a *valid algebraic operator* and a *valid runtime classifier* (T2.x tests still 10 / 10 green on MSVC). What Phase 4f says is that ⪯_d-based **hard-eviction during attention** is too aggressive on real activations.

This is consistent with the Phase 4 remediation note (`SESSION-STATE-friedman-4.md`): the resolution probe (`test_sp_kste_resolution.exe`) showed the encoder + strict Kruskal embed has near-zero ROC AUC on naturally-noised K-vectors. The dominance-only relaxation was useful for the cache *as an equivalence-class summariser* (the OBSERVER mode bit-identical result), but it inherits the encoder's noise-sensitivity when used to *gate attention*.

## Engine state — unchanged

`shannon-prime-engine` HEAD = 2ccc2f2 (commit `docs: rewrite README — reference engine for Prime Power Transformer`).

After this session: no new commits to the engine yet. The new bench artifacts (`_sweep_g1b_4f.bat`, `_sweep_g1b_4f_c4096.bat`, `_sweep_g1b_4f_v2.bat`, `_sweep_g1b_4f_low.bat`, all `sweep_4f_*` and `sweep_4f_v2_*` and `sweep_4f_low_*` `.out`/`.err` files, `sweep_4f_progress.txt`, `sweep_4f_v2_progress.txt`, `sweep_4f_low_progress.txt`) will be committed alongside this document.

Test gates post-rebuild (after recovery from the previous-session truncation incident on `sp_forward.{h,cpp}`, `cli/main.cpp`, `tests/test_sp_friedman_cache.cpp` — Windows HEAD was intact; the truncation was a bash-mount cache artefact that `git checkout HEAD --` from PowerShell unstuck):

- `test_sp_kste.exe` → **11 / 11 PASS**
- `test_sp_friedman_cache.exe` → **10 / 10 PASS**

The pre-existing stale `verdict: FAIL` JSON for T2.7 (from an older enum ordering where `SP_FRIEDMAN_ADMITTED` was 0; the current build has it as 1) was overwritten across all three result directories during the test re-run.

## Phase 4g — recommended next step

Phase 4f rules out τ_A calibration as the path to T2.3 gate compliance for POLICY mode at production scale. Three substantive directions remain, in order of leverage-per-effort:

1. **Soft attenuation instead of hard mask.** Replace `attn_score = -∞` for evicted keys with `attn_score *= (1 − γ)` where γ ∈ (0, 1) is calibrated. Equivalent to a probabilistic mask that down-weights subsumed entries without erasing them. The chunk-cascade should attenuate exponentially rather than diverge.

2. **Encoder coarsening (Phase 4 remediation note revisited).** The encoder currently produces over-discriminative trees (cos ≥ 0.995 needed for self-embedding). Coarsening — e.g. quantising the residual ranks to ≤ 8 bins, or applying a low-pass to the Möbius coefficients before bucket attachment — should raise embed rate on naturally-noised K-vectors, which should make ⪯_d a *gentler* operator with a non-pathological eviction rate.

3. **Move the sieve out of the KV write path entirely.** Use ⪯_d as a *block-quant decision* on the resident weight cache (Q8 ↔ Q4 ↔ sparse) instead of as a *runtime activation filter*. The signature is a 24-byte tag per K-vector; the same comparison can run against weight shards at load time rather than against K caches during forward. This sidesteps the chunk-cascade entirely because there's no attention dependency. Would need a new test gate but keeps the math (and the published §11.6 proof) intact.

The recommended starting point for Phase 4g is **option 1 (soft attenuation)** — smallest engine-side change (mask becomes a per-position float instead of a bool), most predictable PPL response curve, and it leaves the encoder and the cache machinery in place to be re-used for option 2 or 3 if option 1 still falls short of T2.3.

## Files touched this session

| File | Purpose |
|------|---------|
| `shannon-prime-engine/bench/_sweep_g1b_4f.bat` | Phase 4f v1 sweep (cap × τ grid) |
| `shannon-prime-engine/bench/_sweep_g1b_4f_c4096.bat` | Phase 4f c4096 isolation sweep |
| `shannon-prime-engine/bench/_sweep_g1b_4f_v2.bat` | Phase 4f v2 high-τ probe |
| `shannon-prime-engine/bench/_sweep_g1b_4f_low.bat` | Phase 4f LOW low-τ probe |
| `shannon-prime-engine/bench/sweep_4f_*.{out,err}` | Per-cell stdout/stderr from v1 |
| `shannon-prime-engine/bench/sweep_4f_v2_*.{out,err}` | Per-cell stdout/stderr from v2 |
| `shannon-prime-engine/bench/sweep_4f_low_*.{out,err}` | Per-cell stdout/stderr from LOW |
| `shannon-prime-engine/bench/sweep_4f*progress.txt` | Running progress logs |
| `papers/PPT-ARM/SESSION-STATE-friedman-4f.md` | This document |
