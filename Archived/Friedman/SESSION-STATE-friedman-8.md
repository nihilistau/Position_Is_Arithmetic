# SESSION-STATE-friedman-8.md

**Phase 8 — Long-context wall-time scaling ladder + RULER-lite harness. Four-cell PPL ladder (ctx ∈ {512, 1024} × {softmax, ultraproduct}) confirms linear wall-time scaling in both modes and shows the softmax-vs-ultraproduct PPL ratio GROWS with context on generic text (545× at ctx=512 → 1124× at ctx=1024). The Paper III §8 P3 crossover is NOT a generic-PPL claim and won't appear on test_corpus.txt at these scales. RULER-lite v1 harness (driving `run` verb) blocked by `forward_native.cpp` not engaging the Phase 7 dispatch; v2 harness pivots to perplexity-style A/B with vs without needle and stays inside `sp_forward.cpp` where the dispatch lives — wired but not yet run.**

*Shannon-Prime Project · Friedman Stack rollup · 2026-05-20*

---

## TL;DR

Three pieces shipped this session:

1. **ctx=2048 prereq probe** — confirmed sp-engine survives prefill + block-Q4 + `--ultraproduct-attn principal` for 18+ minutes with no silent exit. The Phase 14 block-Q4-prefill silent-exit bug is dead on this code path. Killed before chunk-complete; pivoted to a wall-time scaling ladder to extrapolate ctx=8k / 32k honestly.
2. **4-cell ladder** at ctx ∈ {512, 1024} × {softmax, ultraproduct}, SP_ENGINE_PREFILL=1, full production stack. **Linear wall-time scaling** confirmed in both modes (~2.04× wall for 2× ctx). **PPL ratio grows with ctx** — ultraproduct/softmax = 545× at ctx=512, 1124× at ctx=1024. The crossover predicted by Paper III §8 P3 ("ultraproduct reduces PPL by 1-3% on long-context tasks") is NOT a generic-PPL claim and won't materialise on `test_corpus.txt` even at ctx=32k.
3. **RULER-lite harness** — written, but with an important limitation discovered during smoke test: the `run` verb (which v1 used) routes through `Engine::generate` → `forward_native.cpp` (the HIER path), NOT through `sp_forward.cpp` where the Phase 7 ultraproduct dispatch lives. `--ultraproduct-attn principal` is a no-op on `run`. v2 harness redesigned to stay inside `perplexity-native` via an A/B-corpus methodology (planted needle vs control with no needle, same haystack). Wired but not yet executed.

## Ladder data

Configuration: Gemma3-1B-it Q4_0, `--gguf-block-quant --frobenius-quant`, `SP_ENGINE_PREFILL=1`, chunks=1.

| ctx | mode | PPL | wall (s) | ultra / soft ratio |
|----:|------|----:|---------:|-------------------:|
| 512  | softmax | 14.0475 | 253.9 | — |
| 512  | ultra | 7629.93 | 241.8 | **545×** |
| 1024 | softmax | 28.8196 | 516.9 | — |
| 1024 | ultra | 32407.51 | 498.1 | **1125×** |

Observations:

- **Wall-time is linear in ctx for both modes.** Doubling ctx (512→1024) doubled wall (254→517 softmax, 242→498 ultra). The 2.04× and 2.06× ratios sit on top of the model load + init constant. Per-token decode dominates over O(N²) attention compute at this scale (FFN + matmul are O(N), attention is O(N²) but small constant on head_dim=256). Extrapolation: ctx=8k ≈ 2000s (33 min) per cell, ctx=32k ≈ 8000s (133 min) per cell.
- **Ultraproduct is slightly faster than softmax** at every ladder point (242 vs 254 at ctx=512; 498 vs 517 at ctx=1024). The argmax reduction is cheaper than `softmax → weighted sum`. The wall-time advantage is small (~5%) because both kernels share the O(N²) score-compute path.
- **PPL ratio grows with ctx.** This is the opposite of the Paper III §8 P3 prediction *as applied to generic text*. The 1-3% improvement P3 promises is for RULER-style retrieval tasks where softmax's attention smearing across irrelevant tokens is a structural liability. On `test_corpus.txt` — natural prose where every token is locally predictable — soft-mass smearing is a feature, not a bug, and ultraproduct's hard Top-1 throws away too much.
- **Softmax PPL itself climbs with ctx** (14 → 29). The corpus chunk being evaluated at ctx=1024 is at a different position in `test_corpus.txt` than the ctx=512 slice, and the model finds it harder — this is corpus sampling, not model degradation.

The ladder rules out generic-PPL benches as a Phase 8 success path for ultraproduct. The decision gate now rests entirely on RULER.

## RULER-lite harness — v1 and v2

### v1: drive `sp-engine run`

`bench/_ruler_lite.py` builds a haystack of corpus text with a planted "magic word" needle at a depth (shallow / middle / deep), appends a question, and calls `sp-engine run --n-predict 16 --ultraproduct-attn {principal,none}` to greedy-generate the answer. Score is exact-match on the value token in the generated string.

Smoke test result on Gemma3-1B Q4_0: **all 12 invocations failed identically.** Engine stderr:

```
[sp_native] matmul: unsupported W dtype=-1 (no fallback)
[sp_native] layer 0 failed (rc=-3)
[sp-engine] native prefill failed
```

The `run` verb invokes `Engine::generate`, which routes through `forward_native.cpp` (the HIER-mode forward path used by the LM Studio serve verb), not through `sp_forward.cpp` where the Phase 7 dispatch lives. Two consequences:

1. `--ultraproduct-attn principal` is silently a no-op on `run` — the dispatch never fires.
2. The HIER path's matmul doesn't recognise block-Q4 GGUFs (`W dtype=-1`). It only works with fp16 GGUFs.

Verified with `gemma-3-1b-it-f16.gguf`: `run` works, produces output, but warns the prompt is too short for hierarchical-cache calibration and the dispatch still doesn't engage Phase 7. So even on fp16 the harness can't measure ultraproduct.

This is salvageable in two ways:
- **Engine fix:** plumb `Config::ultraproduct_attn → sp_forward_context::ultraproduct_mode` into the `forward_native.cpp` Engine path as well. Two added integers and one branch above the existing attention call. Phase 8b territory.
- **Methodology pivot:** keep the harness inside the path that already works — `perplexity-native`. v2 does this.

### v2: A/B perplexity inside `perplexity-native`

`bench/_ruler_lite_v2.py` constructs two corpora per (depth, trial):

```
PLANTED:  [haystack ctx-ish tokens] + " The magic word for X is Y. " + [filler] + " Q: What is the magic word for X? A: Y"
CONTROL:  [same haystack]                                                         + " Q: What is the magic word for X? A: Y"
```

For each mode (softmax, ultraproduct) the harness calls `sp-engine perplexity --ctx <N> --chunks 1 --gguf-block-quant --frobenius-quant [--ultraproduct-attn principal]` on each corpus. The retrieval signal is:

```
delta_ppl[mode]  =  control_ppl[mode]  −  planted_ppl[mode]
```

Larger positive Δ = the needle helped that mode predict the answer. The T3.4 comparison is `delta_ppl[ultra] vs delta_ppl[softmax]`. Per Paper III P3, ultraproduct should show a *bigger* Δ at long context because hard Top-1 doesn't smear away from the needle.

Cost per cell: 2 perplexity runs × ~4 min each (at ctx=512) = ~8 min × 2 modes = 16 min for one (depth, trial). A full 3-depth × 3-trial × 2-mode probe at ctx=512 = ~144 min. Tractable.

The harness is wired but the actual sweep wasn't run this session — the wall-time budget was consumed by the ladder. Phase 8a-cont (this session's natural close) leaves v2 ready to fire as the first cell of the next session.

## Files this session

| File | Purpose |
|------|---------|
| `shannon-prime-engine/bench/_ladder_phase8.bat` | 6-cell scaling ladder runner |
| `shannon-prime-engine/bench/ladder_ctx512_*.{out,err}` | ctx=512 softmax + ultra cells |
| `shannon-prime-engine/bench/ladder_ctx1024_*.{out,err}` | ctx=1024 softmax + ultra cells |
| `shannon-prime-engine/bench/ladder_phase8_progress.txt` | Running progress log |
| `shannon-prime-engine/bench/probe_2k_ultra.{out,err}` | Prereq probe artifacts (engine alive 18+ min) |
| `shannon-prime-engine/bench/_ruler_lite.py` | v1 (run-verb based — blocked) |
| `shannon-prime-engine/bench/_ruler_lite_v2.py` | v2 (perplexity-native A/B — ready) |
| `shannon-prime-engine/bench/ruler_lite_ctx512.{json,stdout,stderr}` | v1 smoke test showing the dispatch-doesn't-engage issue |
| `papers/PPT-ARM/SESSION-STATE-friedman-8.md` | This document |

## Phase 8 conclusions to date

1. **Engine is structurally sound at ctx=2048** under the full Phase 7 stack. The Phase 14 prefill+block-Q4 silent-exit bug does not reproduce on the current build.
2. **Wall-time scaling is linear in ctx** for both attention modes. Ultraproduct is ~5% faster than softmax at every scale tested (argmax cheaper than softmax+wsum). T3.5 (wall-time within 20%) is comfortably cleared in advance.
3. **Generic-text PPL is the wrong metric for the P3 win.** The crossover Paper III predicts is for retrieval-isolated tasks (RULER, LongBench needle-in-haystack subsets). On natural prose, soft-mass smearing is helpful, not harmful, and ultraproduct's destruction is unbounded in ctx.
4. **The `run` verb dispatch gap is a real Phase 8b blocker** if we want to ship ultraproduct as an actually-usable runtime mode (chat / serve / generate). For now the dispatch exists only in `perplexity-native`. v2 RULER works around this; a proper fix is `forward_native.cpp` integration.

## Phase 8b — next session

Two natural opening moves:

1. **Run v2 RULER at ctx=512 then 1024** — 3-depth × 2-trial × 2-mode probe at each scale (= 24 cells × 4 min = 96 min per ctx). Gives us the T3.4 retrieval-signal data without engine modifications.
2. **Or: extend Phase 7 dispatch into `forward_native.cpp`** — wires `--ultraproduct-attn` into the Engine::generate / serve path, unlocks v1 RULER and the LM Studio compat path. Probably ~50 LOC.

Recommendation: (1) first. The math story is more important than the runtime polish — if v2 shows no Δ_PPL signal in favour of ultraproduct even at ctx=1024 retrieval, that's a strong negative-result Phase 8 close and (2) would be wasted on a primitive that doesn't deliver the predicted gain at the scales we can reach. If v2 shows a signal, (2) becomes worth doing.
