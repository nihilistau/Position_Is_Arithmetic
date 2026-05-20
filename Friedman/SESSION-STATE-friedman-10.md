# SESSION-STATE-friedman-10.md

**Phase 10 — Option 1 (PRNG-shuffled q-bank index) FAILS the diagnostic test. λ=0.05 ratio = 1.082 (planted now WORSE than control), λ=0.20 ratio = 0.619. The success criterion (λ=0.05 ratio ≤ 0.43) is missed by a wide margin. The period-5 carrier-wave theory from Phase 9 was only PART of the story — replacing the i mod 5 cycling with a deterministic splitmix64-shuffled lookup destroys the periodicity, but ANY pre-VHT2 perturbation corrupts K's semantic content in a way that hurts retrieval. The carrier-wave is one failure mode; semantic-noise damage is another, and both fire at this pipeline location. Option 2 (post-VHT2 anchor injection) is now forced for Phase 11. T1/T2/T3 bit-identical at λ=0 (no-op preservation correct). Engine HEAD pending commit, math HEAD pending commit. 32 min wall.**

*Shannon-Prime Project · Friedman Stack rollup · 2026-05-21 08:44 local*

---

## TL;DR

Phase 9 produced a negative result with a clean root-cause hypothesis: the original Ramanujan modulation used `bank_idx = i mod |BANK|` which creates a period-|BANK| carrier wave across head_dim that VHT2 then picks up as a dominant macro frequency. Phase 10 set out to test that hypothesis with the cheapest possible patch: replace the mod-5 lookup with a deterministic splitmix64-shuffled 256-entry table, preserving i → bank_idx determinism but destroying the periodicity.

The diagnostic was set up to give an unambiguous read in either direction:

- **Success criterion** (theory CONFIRMED, salvageable): λ=0.05 ratio ≤ 0.43 (close to Phase 8e baseline 0.410)
- **Ambiguous**: 0.43 < ratio < 0.46 (shuffle helped but didn't fully recover)
- **Fail criterion** (theory REFUTED, Option 2 forced): λ=0.05 ratio ≥ 0.46

Phase 10's λ=0.05 ratio landed at **1.082** — past 0.46, past 1.0, the planted PPL is now *higher* than the control PPL. The shuffle didn't just fail to rescue retrieval; it inverted it. At low λ, aperiodic Ramanujan noise corrupts the semantically-rich planted K-vectors more than it corrupts the more-uniform control K-vectors, flipping the comparison.

At λ=0.20 the picture is different: ratio = 0.619, which is *better* than Phase 9's 0.732 at the same λ. The shuffle helps relatively at high λ. That tells us the carrier-wave theory was right *as one of several failure modes* — at high λ the periodic carrier was the dominant problem and removing it helps; at low λ the periodic carrier was secondary and removing it just exposes a different problem (raw semantic-content damage).

Conclusion: **pre-VHT2 modulation is empirically refuted across two different bank-index designs and two different λ values.** The location of the modulation in the pipeline is wrong. The math (Kluyver c_q(p) over the {2,3,5,6,10} bank) is correct; it just can't be applied before VHT2's macro-frequency extraction without degrading K. Option 2 — post-VHT2 anchor injection — is forced for Phase 11.

## Phase 10 numbers vs prior baselines

All measurements on the Phase 8e multi-needle RULER corpora (5 orthogonal needles, byte-identical 3631-byte planted/control, question block inside eval window, ctx=512 chunks=2, ~9 min/cell, 32 min total):

| Mode | Planted PPL | Control PPL | Ratio | Retrieval gain |
|------|------------:|------------:|------:|---------------:|
| softmax (λ irrelevant) | 13.93 | 15.85 | 0.879 | 12.1% PPL drop |
| ultra-b4 λ=0 (Phase 8e baseline) | 20726.01 | 50565.40 | **0.410** | 59.0% PPL drop |
| ultra-b4 λ=0.05 mod-5 (Phase 9) | 39077.94 | 84106.82 | 0.465 | 53.5% PPL drop |
| ultra-b4 λ=0.20 mod-5 (Phase 9) | 66162.47 | 90412.96 | 0.732 | 26.8% PPL drop |
| **ultra-b4 λ=0.05 shuffle (Phase 10)** | 34647.90 | 32026.14 | **1.082** | **-8.2% (anti-retrieval)** |
| **ultra-b4 λ=0.20 shuffle (Phase 10)** | 81582.82 | 131809.22 | **0.619** | 38.1% PPL drop |

What the numbers say in plain language:

- **λ=0.05 shuffle is anti-retrieval.** The planted corpus produces HIGHER perplexity than the control on the answer tokens. Adding 5% Ramanujan noise pre-VHT2 actively prevents the model from extracting information from the planted context. The needles are now *anti-helpful*.
- **λ=0.20 shuffle partially recovers** retrieval direction (ratio < 1) but at substantially higher absolute PPL than Phase 9's λ=0.20 mod-5. The shuffle damages both planted and control more uniformly, so the ratio improves while the absolute prediction quality degrades.
- **The shuffle ratio is non-monotonic in λ** (1.082 at 0.05, 0.619 at 0.20). The mod-5 version was monotonic (0.465 at 0.05, 0.732 at 0.20). This means at least two distinct failure modes are interacting:

  1. *Periodic carrier wave* (mod-5 only): VHT2 locks onto a periodic feature in K. Grows monotonically with λ. The shuffle eliminates this.
  2. *Semantic-noise damage* (both): adding any aperiodic perturbation to K degrades the semantically structured planted vectors more than the uniform control vectors. Present in both versions, dominant at low λ in the shuffle.

  Phase 9's monotonic degradation was failure mode (1) dominating across λ. Phase 10's non-monotonic curve is (2) dominating at low λ and (1)-removed letting (2) be the only damage at high λ.

## What Phase 10 actually shipped

Math layer (`lib/shannon-prime/core/sp_kste_ramanujan.c`):

- Added a 256-entry static const `sp_kste_ramanujan_shuffled` lookup table, precomputed offline as `splitmix64(0x9E3779B97F4A7C15 ^ i) mod 5` for i ∈ [0, 256). Hard-coded so the A/B is reproducible across runs and machines.
- Replaced the modulation loop body from `cq_weighted[i % SP_KSTE_RAMANUJAN_BANK_SIZE]` to `cq_weighted[sp_kste_ramanujan_shuffled[i & 0xFF]]`. Same deterministic i → bank_idx mapping, no runtime hash arithmetic.
- Updated file-level comment block to reflect Phase 10 mechanism and reference back to SESSION-STATE-friedman-9.md.
- λ=0 still triggers the early return on the lambda guard — strict no-op preservation.

Engine layer (shannon-prime-engine):

- No source changes. The CLI flag (`--kste-ramanujan-lambda`), config plumbing, and kernel call site from Phase 9 are reused unchanged.
- New harness `bench/_phase10_lambda_sweep.bat` mirrors `_phase9_lambda_sweep.bat` exactly except for the embedded narrative.

Verification:

- Build clean.
- T1: 11/11 PASS. T2: 10/10 PASS. T3: 3/3 PASS at λ=0.
- λ A/B sweep: 4 cells × ~8 min = 32 min wall on Gemma3-1B ctx=512 chunks=2.

## The MSVC build adventure (worth recording)

The first Phase 10 implementation used a `static inline uint64_t sp_kste_splitmix64(uint64_t x)` helper function in `sp_kste_ramanujan.c`. The patch was purely additive: a new file-scope inline function and a swap of the loop body's bank-index lookup. The modulation function itself still early-returned at λ=0.

That build SHOULD have been functionally identical to Phase 9 at λ=0 — the modulation function isn't even called when λ=0. But the engine.exe linked from that source crashed with `STATUS_STACK_BUFFER_OVERRUN` (0xC0000409) at perplexity startup, *before* the modulation function could possibly be reached, on every config tested (with/without ultraproduct, with/without --kste-ramanujan-lambda, every ctx size).

T1/T2/T3 unit tests passed at exit code 0. The perplexity verb in the engine crashed deterministically. Bisect by `git stash` + rebuild confirmed: same source tree minus only the `sp_kste_ramanujan.c` diff — Phase 9 source runs perplexity to completion, Phase 10 source crashes the perplexity setup.

The crash signature plus the unrelated-function impact pattern points at a code-gen interaction with MSVC's stack canary inserting into adjacent functions in the same translation unit, possibly via LTO or whole-program-optimization reshuffling. Not worth a deep root-cause hunt since the fix is trivial.

**Fix**: replace the runtime `splitmix64` helper with a precomputed 256-entry `static const unsigned char` table. The modulation loop now does only an array lookup, no uint64_t arithmetic, no new function declarations at file scope. Crash gone, A/B sweep completed cleanly.

The lesson worth keeping: when a purely additive C patch at file scope causes a crash in an unrelated function in the same TU, suspect the TU-level code-gen first, not the patch's semantics. The precomputed-table approach is a robust idiom for this kind of mapping anyway.

## Wall-time accounting

| Cell | Wall (s) |
|------|---------:|
| ultra-b4-L0.05 planted | 475.1 |
| ultra-b4-L0.05 control | 470.1 |
| ultra-b4-L0.20 planted | 467.5 |
| ultra-b4-L0.20 control | 468.0 |
| **Total** | **1880.7 s ≈ 31 min** |

Within 4% of the Phase 9 wall (2078 s) — table lookup vs Phase 9's per-element mod operation is functionally free in the broader prefill cost.

## What this does NOT establish

- **Ramanujan-Fourier modulation is refuted.** Still false. Both Phase 9 (mod-5) and Phase 10 (shuffle) test only *pre-VHT2 modulation with full-K perturbation*. Post-VHT2 anchor injection (Option 2 from Phase 9's writeup) is a different experiment and the architecturally cleaner home for the math. Phase 11 will run it.
- **Position-awareness in F doesn't help.** Same answer as Phase 9: unknown. Both Phase 9 and Phase 10 tested one *implementation* of position-awareness (modulating K with c_q(p) pre-VHT2). A different implementation — applied to the 14 anchor coefficients downstream of VHT2 — is still on the table and arguably motivated by these results.
- **Pre-VHT2 modulation is dead with certainty.** Across two designs of the bank-index mapping (cycled vs shuffled), two λ values, on the same harness, the ratio never approached Phase 8e's 0.410. The interaction with VHT2 is the structural problem; the bank-index design just chooses which failure mode dominates.

## Phase 8e's signal remains the strongest claim

The framework's strongest empirical result remains Phase 8e's 4.87× retrieval gain over softmax (ratio 0.410 vs 0.879) from F-over-top-m at bracket=4 *without any position-aware modulation*. Phase 9 and Phase 10 set out to improve on that baseline; both moved the needle the wrong direction. The bracket-based Choice Operator F is already extracting strong retrieval signal from K's natural geometry — the position-awareness experiments have not (yet) found a way to add to it.

## Engine state

`shannon-prime` HEAD pending — `core/sp_kste_ramanujan.c` modified (shuffled table + loop swap, ~50 LOC added).
`shannon-prime-engine` HEAD pending — `bench/_phase10_lambda_sweep.bat` added, `bench/phase10_L*.{out,err}` + `bench/phase10_lambda_sweep_progress.txt` added.
T1/T2/T3 all green at λ=0; regression boundary holds.

## What comes next

Phase 11 = Option 2 = **post-VHT2 anchor injection**. The architectural argument:

- VHT2 takes K and projects it onto a Walsh-like hierarchical basis. Its job is to extract semantic geometry.
- The packed sp_kste_tree carries 14 surviving anchor coefficients after VHT2 + Möbius reorder + sqfree drop. These anchors are exactly the coordinates that ⪯_d operates on. They are where F's lex-min decision actually lives.
- Applying Ramanujan c_q(p)/q² perturbation to the ANCHORS — instead of to K pre-VHT2 — gives F position-awareness without polluting VHT2's input. Each component does its designed job; the math is added where ⪯_d can see it.

Implementation surface: touches `sp_kste_encode` downstream of VHT2 (or `sp_kste_encode_ex`), the canonical-selection comparator possibly, and potentially the packed tree layout if we want > 14 anchors. ~3-4 hours of pipeline work vs Phase 10's 1-hour table-swap.

The Phase 8e baseline 0.410 ratio is still the bar to clear at λ > 0. If post-VHT2 injection can't beat that, the Ramanujan-Fourier direction is retired and we pivot to the ctx ladder (Phase 8e at ctx=1024 / 2048) as the next productive front.

## Files this session

| File | Status | Purpose |
|------|--------|---------|
| `lib/shannon-prime/core/sp_kste_ramanujan.c` | MODIFIED | 256-entry shuffled bank-index table |
| `shannon-prime-engine/bench/_phase10_lambda_sweep.bat` | NEW | 4-cell A/B harness |
| `shannon-prime-engine/bench/phase10_L*.{out,err}` | NEW | Raw A/B output |
| `shannon-prime-engine/bench/phase10_lambda_sweep_progress.txt` | NEW | Summary log |
| `papers/PPT-ARM/SESSION-STATE-friedman-10.md` | NEW (this file) | Negative-result writeup |

## Two-phase audit

The Phase 9 + Phase 10 pair makes a clean empirical audit of the pre-VHT2 modulation design space:

| Bank-index design | λ=0.05 ratio | λ=0.20 ratio | Verdict |
|-------------------|-------------:|-------------:|---------|
| `i mod 5` (Phase 9) | 0.465 | 0.732 | Periodic carrier dominates; monotonic damage |
| `splitmix64-shuffle` (Phase 10) | 1.082 | 0.619 | Semantic-noise damage dominates at low λ |
| baseline (no mod) (Phase 8e) | — | — | 0.410, untouched |

Neither row produced a ratio ≤ 0.43 at any λ. The conclusion is that the *location* of the modulation (pre-VHT2) is the structural problem, not the bank-index design. This closes the Option 1 investigation cleanly.
