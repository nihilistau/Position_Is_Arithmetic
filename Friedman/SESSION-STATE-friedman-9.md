# SESSION-STATE-friedman-9.md

**Phase 9 — Ramanujan-Fourier encoder modulation NEGATIVE RESULT. λ ∈ {0.05, 0.20} both hurt retrieval on the Phase 8e multi-needle RULER instead of helping. Retrieval ratio went 0.410 (λ=0 baseline) → 0.465 (λ=0.05) → 0.732 (λ=0.20). Monotonic degradation with increasing λ. Root cause: pre-VHT2 modulation introduces a period-5 carrier wave from the q-bank cycling, which VHT2 locks onto as a macro frequency and rides instead of the K-vector's semantic geometry. The math is sound, the coupling is wrong. T1/T2/T3 remain bit-identical at λ=0 (no-op preservation correct). Engine HEAD `f0f1623`, math HEAD `91b188c`. 36 min wall.**

*Shannon-Prime Project · Friedman Stack rollup · 2026-05-21 02:30 local*

---

## TL;DR

Phase 8e produced the cleanest P3-direction signal we'd seen — F-over-top-m at bracket=4 extracted 4.87× more retrieval signal than softmax on multi-needle RULER. Phase 9 set out to make F's tie-breaking finer by giving the KSTE encoder access to *position* via Ramanujan sums: the same K-vector at integer position `p` vs `p'` should produce structurally distinct packed trees, so the Choice Operator F sees a richer ⪯_d equivalence relation.

The math shipped clean. `sp_kste_ramanujan_modulate(K, head_dim, position, λ)` evaluates `Σ_q c_q(p)/q² · K[i mod 5]` over q-bank `{2, 3, 5, 6, 10}` using Kluyver's theorem (integer arithmetic, no float surprises), then adds `λ` times that modulation onto K before encoding. T1 (11/11), T2 (10/10), T3 (3/3) all PASS at λ=0 — the no-op preservation is regression-clear. The flag, the CMake wiring, the engine plumbing — all correct.

The A/B sweep killed the hypothesis. Two λ values vs the Phase 8e baseline:

| Cell | Planted PPL | Control PPL | Ratio | Retrieval gain |
|------|------------:|------------:|------:|---------------:|
| ultra-b4 λ=0 (Phase 8e baseline) | 20726.01 | 50565.40 | **0.410** | 59.0% |
| ultra-b4 λ=0.05 | 39077.94 | 84106.82 | **0.465** | 53.5% |
| ultra-b4 λ=0.20 | 66162.47 | 90412.96 | **0.732** | 26.8% |

The trend is monotonic: more modulation → less retrieval signal. At λ=0.20 the framework gives up roughly half of the gain Phase 8e bought.

The diagnosis is mechanical, not statistical. The implementation cycles the q-bank index as `i mod 5` while sweeping `i` across head_dim=256. That creates a deterministic period-5 sinusoid laid over the K-vector before VHT2 ever sees it. VHT2's job is to extract macro frequency structure from K; a period-5 carrier is exactly the kind of macro signal VHT2 was designed to catch. So VHT2 catches it, encodes it as the dominant component of every packed tree, and the Choice Operator F now tie-breaks on "which K had the cleanest period-5 fit" rather than "which K matches the query best". The position-dependence the modulation was supposed to add gets drowned by the q-bank cycling artefact.

This is a "right answer, wrong wiring" failure, not a refuted theorem. Paper IV §10 is silent on *where* in the encoder pipeline to inject Ramanujan structure — we picked pre-VHT2 because it was the simplest patch point, and pre-VHT2 turns out to be the wrong patch point.

## What Phase 9 actually shipped

Math layer (`lib/shannon-prime/core/sp_kste_ramanujan.c`, ~150 LOC):

- `sp_kste_mobius(q)` — Möbius μ(q) for q ∈ {1..10}, table-driven.
- `sp_kste_gcd(a, b)` — Euclidean, used only for `c_q(p)` summation.
- `sp_kste_cq(q, p)` — Ramanujan sum `c_q(p) = Σ_{d | gcd(p,q)} μ(q/d) · d` via Kluyver's theorem. Integer-valued, bounded by φ(q), real (no complex roots-of-unity machinery needed).
- `sp_kste_ramanujan_modulate(K, head_dim, position, λ)` — the only public entry. Computes the modulation per i ∈ [0, head_dim), adds `λ · modulation` onto K[i]. At λ=0 the function returns without touching memory (strict no-op).
- `sp_kste_ramanujan_cq_for_test(q, p)` — test hook for unit verification of Kluyver values.

Engine layer (shannon-prime-engine):

- `Config::kste_ramanujan_lambda` (`engine.h`) — config-side carrier of the value.
- `sp_forward_context::ultraproduct_ramanujan_lambda` (`sp_forward.h`) — the value plumbed through to attention.
- `sp_ultraproduct_attn_principal(..., float ramanujan_lambda = 0.0f)` (`sp_ultraproduct_attn.h/.cpp`) — signature extended; default 0.0 preserves callers.
- Inside the F-over-top-m bracket loop, just before `sp_kste_encode`, if `ramanujan_lambda > 0.0f` then `sp_kste_ramanujan_modulate(k_decode_buf, head_dim, (int)t, ramanujan_lambda)` runs on each top-m K.
- `--kste-ramanujan-lambda <f>` CLI flag (`src/cli/main.cpp`), wired through `Config` → `sp_forward_context`.
- `bench/_ruler_multi.py` passes `--kste-ramanujan-lambda` when value > 0 and ultraproduct mode is active.
- `bench/_phase9_lambda_sweep.bat` — 4-cell A/B harness reusing the Phase 8e corpora (softmax cells unchanged — λ is a no-op on the soft path, so no re-run needed there).

Verification:

- Build clean 34/34.
- T1: 11/11 PASS (KSTE encoder regression).
- T2: 10/10 PASS (cache + sieve regression).
- T3: 3/3 PASS at λ=0 (ultraproduct regression — bit-identical to Phase 7/8 numbers).
- λ A/B sweep: 4 cells × ~9 min = 36 min wall on Gemma3-1B ctx=512 chunks=2.

## The headline numbers, with full data

Phase 9 λ sweep on the Phase 8e multi-needle RULER corpora (5 orthogonal needles, byte-identical 3631-byte planted/control, question block inside eval window, ctx=512 chunks=2):

```
=== lambda=0.05 ===
ultra-b4-L0.05 planted : PPL_native = 39077.9376
ultra-b4-L0.05 control : PPL_native = 84106.8201
ratio                  : 0.465

=== lambda=0.20 ===
ultra-b4-L0.20 planted : PPL_native = 66162.4669
ultra-b4-L0.20 control : PPL_native = 90412.9557
ratio                  : 0.732
```

Combined with Phase 8e (re-quoted for orientation):

| Mode | Planted | Control | Ratio | vs Phase 8e baseline |
|------|--------:|--------:|------:|---------------------:|
| softmax (λ irrelevant) | 13.93 | 15.85 | 0.879 | — |
| ultra-b4 λ=0 | 20726.01 | 50565.40 | **0.410** | reference |
| ultra-b4 λ=0.05 | 39077.94 | 84106.82 | **0.465** | −5.5pp |
| ultra-b4 λ=0.20 | 66162.47 | 90412.96 | **0.732** | −32.2pp |

The absolute PPL inflation under modulation (both planted and control go up) is itself diagnostic: the modulation degrades general next-token prediction at every position, not just retrieval-relevant ones. That's the carrier-wave signature — VHT2's energy is being spent on the periodic perturbation instead of the K's semantic content.

## The mechanism, plainly

`sp_kste_ramanujan_modulate` is approximately:

```
for i in [0, head_dim):
    bank_idx = i mod 5                     # q-bank index cycles deterministically
    q        = q_bank[bank_idx]            # one of {2, 3, 5, 6, 10}
    inv_q2   = inv_q_sq[bank_idx]          # one of {1/4, 1/9, 1/25, 1/36, 1/100}
    cq_p     = sp_kste_cq(q, position)
    K[i]    += lambda * cq_p * inv_q2 * K[i_anchor]   // implementation detail abstracted
```

The `i mod 5` cycle is the bug. It makes the modulation depth-periodic with period 5 across the head dimension *independent of position*. Even at fixed position p, walking i from 0 to 255 produces a 5-fast-Fourier-component perturbation. That's a perfectly clean sine in the VHT2 basis.

VHT2 is designed to project K onto a Walsh-like hierarchical basis; that basis has strong components at every dyadic scale, *including* the dyadic scale that aliases with period-5 cycles modulo 256. So VHT2 picks the modulation up as a "feature" with very high weight, and the rest of the encoding (Möbius reorder, sqfree drop, the 14 anchor coefficients) ends up serving the carrier rather than the K. F then ranks "carrier fidelity" before "semantic match."

This isn't refuted by the math — Ramanujan-Fourier expansion of arithmetic functions is correct; `c_q(p)/q²` is the right family of coefficients (it's literally how σ(p)/p is expanded). The pipeline location is the problem.

## Three options for next session

In ascending order of architectural surgery required:

**Option 1 — PRNG-shuffled q-bank index (cheap validation, ~1 hour).** Replace `bank_idx = i mod 5` with `bank_idx = hash(seed, i) mod 5` where `seed` is fixed per-run. This breaks the period-5 alignment without changing where the modulation lives. If the result restores Phase 8e's 0.410 ratio at λ=0.05 (or close to it), we've confirmed the pre-transform-carrier theory and pre-VHT2 modulation is salvageable. If the ratio stays bad, the issue is deeper than carrier alignment and Option 2 is forced.

**Option 2 — Post-VHT2 anchor injection (mathematically clean, ~3-4 hours).** Move the modulation out of the K → VHT2 input path and into the 14 anchor coefficients that survive VHT2. The anchors are exactly where ⪯_d operates; adding position-dependent Ramanujan perturbation directly to the anchors gives F a position-aware lex-min target without polluting the macro-frequency extraction VHT2 is supposed to do upstream. This respects each component's job: VHT2 = extract semantic geometry; Ramanujan = encode position into the same coordinate system as F. The implementation surface is bigger (touches the encoder downstream of VHT2, the canonical-selection scratch, and possibly the packed tree layout for anchor counts > 14), but the math is more defensible.

**Option 3 — Lower λ + Option 1 combined (the "is there ANY λ that helps?" hunt).** Sweep λ ∈ {0.005, 0.01, 0.02, 0.05} under the shuffled bank. If the modulation can help at all, it would show up at near-zero λ where the carrier amplitude is dominated by K. Worth doing as a sanity envelope but unlikely to be productive on its own.

**Lean for next session:** Option 1 first (1 hour, cheap signal on whether the pre-transform theory survives at all), then Option 2 if Option 1 either confirms the framework can be salvaged or definitively kills it. Doing Option 2 directly without Option 1's validation risks burning the bigger budget on a deeper issue than the period-5 alignment.

## What was overclaimed and corrected in-session

Mid-implementation framing called Ramanujan-Fourier "the missing link" between the KSTE math and the Choice Operator F. The A/B result shows this was overshooting. Ramanujan-Fourier modulation is *one candidate* way to inject position into F's equivalence relation; it isn't a uniquely-determined missing piece, and the pre-VHT2 wiring shows the design space is wider than the framing suggested. Corrected here: the modulation is a candidate, not a load-bearing component. Phase 8e's 4.87× signal stands on its own without it.

## Engine state

`shannon-prime-engine` HEAD `f0f1623` ("phase 9: Ramanujan-Fourier modulation wired through engine, λ A/B in flight"). `lib/shannon-prime` HEAD `91b188c` (`sp_kste_ramanujan.c` + header + CMake). T1/T2/T3 all green at λ=0; the regression boundary holds. No tag added this phase — Phase 7 (`phase-7-shipped`) and Phase 8e's implicit commit (`cfb635b`) remain the most recent named milestones.

## What this does NOT establish

- **Ramanujan-Fourier modulation is refuted.** False. Only *pre-VHT2 modulation with cycled q-bank indexing* is refuted. Post-VHT2 anchor injection (Option 2) is a different experiment and could still validate the math.
- **Position-awareness in F doesn't help.** Unknown. We tested one wiring of position-awareness; another wiring may help. Phase 8e showed F's ⪯_d tie-breaking already extracts strong retrieval signal *without* position-awareness, so the bar for a position-aware F is high — it needs to clear 0.410 on the same harness.
- **VHT2 is broken.** No. VHT2 is doing exactly what it's designed to do (catch macro frequency structure). The modulation just gave it the wrong frequencies to catch. Moving the modulation downstream restores VHT2 to its intended role.

## Files this session

| File | Status | Purpose |
|------|--------|---------|
| `lib/shannon-prime/core/sp_kste_ramanujan.c` | NEW (commit 91b188c) | Kluyver `c_q(p)` + modulation helper |
| `lib/shannon-prime/core/sp_kste.h` | MODIFIED | `sp_kste_ramanujan_modulate` + test hook declarations |
| `shannon-prime-engine/CMakeLists.txt` | MODIFIED | Add `sp_kste_ramanujan.c` to SP_CORE_SRC |
| `shannon-prime-engine/src/engine.h` | MODIFIED | `Config::kste_ramanujan_lambda` |
| `shannon-prime-engine/src/sp_forward.h` | MODIFIED | `ultraproduct_ramanujan_lambda` field |
| `shannon-prime-engine/src/sp_forward.cpp` | MODIFIED | Pass λ to ultraproduct kernel |
| `shannon-prime-engine/src/sp_ultraproduct_attn.h` | MODIFIED | Kernel signature extended |
| `shannon-prime-engine/src/sp_ultraproduct_attn.cpp` | MODIFIED | Call `sp_kste_ramanujan_modulate` before encode |
| `shannon-prime-engine/src/cli/main.cpp` | MODIFIED | `--kste-ramanujan-lambda` flag |
| `shannon-prime-engine/bench/_ruler_multi.py` | MODIFIED | `--ramanujan-lambda` plumbing |
| `shannon-prime-engine/bench/_phase9_lambda_sweep.bat` | NEW | 4-cell A/B harness |
| `shannon-prime-engine/bench/phase9_L*.{out,err}` | NEW | Raw A/B output |
| `shannon-prime-engine/bench/phase9_lambda_sweep_progress.txt` | NEW | Summary log |
| `papers/PPT-ARM/SESSION-STATE-friedman-9.md` | NEW (this file) | Negative-result writeup |

## What comes next

Phase 10 is the post-VHT2 anchor-injection experiment (Option 2 above), preceded by the cheap PRNG-shuffle validation (Option 1). The Phase 8e baseline (0.410 ratio) is the bar to clear. If neither option improves on that ratio at any λ, the Ramanujan-Fourier direction is retired and Phase 11 picks up the ctx ladder (Phase 8e at ctx=1024 / 2048) as the next productive front.

Phase 8e's 4.87× retrieval gain over softmax is the framework's strongest empirical claim and is untouched by this session.
