---
type: paper-bite
title: "09 — KAIROS: a resident 12B daemon that stays silent and rewinds at the metal *(staged draft — release gated on the in-flight soak)*"
description: "A useful resident agent must do nothing, correctly, almost all the time —"
tags: [paper-bite, kairos, daemon]
timestamp: 2026-06-14T04:25:06Z
resource: ./papers/09-kairos-resident-daemon/README.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# 09 — KAIROS: a resident 12B daemon that stays silent and rewinds at the metal *(staged draft — release gated on the in-flight soak)*

> **STATUS: written (mechanism) — `paper.md` complete.** Front-door receipts
> measured + gated (ledger **KAIROS-01 / KAIROS-02 / KAIROS-03**). **Full release
> is held pending the ≥24 h endurance soak receipt — that run is IN-FLIGHT, not
> passed.** Per our
> own discipline we do not call a verdict from a mid-run log; this paper does
> not ship until the soak closes with a receipt.

> **Front-door receipt (measured + gated 2026-06-14, ledger KAIROS-01 /
> KAIROS-02):** a frozen **Gemma-4-12B** runs as a **resident background
> daemon** — mathematically silent until a high-salience event, stable after it
> acts. The **24-tick crucible is PERFECT: 21/21 idle → NO_OP, 3/3 salient →
> coherent contextual ACTION** (`start` / `clean` / `renew` for build-finished
> / disk-95% / ttl-expiring), **0 false-action, 0 missed, 0 malformed, 0 drift**
> — the exact condition that collapses a 0.6B into a deterministic corruption
> attractor (`NO_克作`). And cold-evict happens **at the metal**: after an idle
> tick + `rewind(Δ)`, the KV is **byte-identical to never-visited across all 48
> owner layers (16.5 MB, diffs = 0)**, and re-running the tick reproduces
> identical tokens. Idle-tick latency vs retained-action count: prefix-grow
> (host re-ingest) **0.924 s/action** vs metal **0.0073 s/action — a 127×
> shallower slope** — the measured flatline that *is* the O(1) claim.

## The claim this paper makes

A useful resident agent must do nothing, correctly, almost all the time —
*disciplined silence*. KAIROS is a background kernel daemon that wakes each
tick, reads one environment event, and replies with exactly `NO_OP` (stay
silent) or `<ACTION>…</ACTION>` (intervene) under a salience policy. The thing
that makes it cheap to run unattended forever is that "forgetting" an idle
thought is a single **O(1) memory-coordinate operation** — `rewind(Δ)`
logically decrements the decode position, and because each cache slot maps to
exactly one position, the sheared slots are never read again, so the rewind is
a **perfect, byte-exact inverse**. The daemon can "think" on a tick and then
perfectly un-think it.

## What's in it (the map)

1. **Disciplined silence as the spec** — why the load-bearing requirement is
   *NO_OP almost always*; the salience≥0.5 policy; the gemma `<start_of_turn>`
   template runtime-encoded via the parity-validated `.sp-tokenizer`.
2. **Cold-evict at the metal (KAIROS-02)** — the persistent-KV ABI
   (`gemma4_kv_open / prefill / decode / rewind / commit / pos / snapshot /
   close`) built as a *separate twin* of the one-shot decode path (left
   **byte-untouched** = the null floor that keeps every prior gate valid);
   `rewind(Δ)` as a logical position decrement; the G-1b-REWIND-NULL bit-exact
   proof across all 48 owner layers.
3. **O(actions) → O(1), as a slope not an assertion** — the latency-vs-A sweep
   (A ∈ {1,2,4,8,16}): prefix-grow rises at 0.924 s/action (linear recompute
   tax), the metal rewind is flat at 0.0073 s/action (127× shallower, 16.7×
   faster at A=16). The flatline *is* the result.
4. **The crucible (KAIROS-01)** — `run_kairos_metal` wiring the decision loop
   onto the ABI: NO_OP → rewind to the anchor (cold-evict the tick), ACTION →
   commit (retain, advance the anchor); the 24-tick perfect pass; the tick-5
   post-action reversion that proves the daemon reverts cleanly.
5. **The negative control — capacity, not plumbing** — the identical harness
   collapses a 0.6B into a corruption attractor and false-fires after a
   retained action; the 12B holds. The discipline is a property of model
   capacity exercised through correct machinery — both halves proven. **(This
   is the 0.6B-vs-12B scope line: 0.6B is the control, the 12B carries the
   headline.)**
6. **pos-discipline as a gate** — asserting idle ticks return the position
   *exactly* to the anchor and action ticks advance it, so an off-by-one in the
   rewind/commit math fails loudly; the semantic pass and the metal correctness
   are checked simultaneously.
7. **The endurance soak (IN-FLIGHT — no verdict)** — `run_kairos_soak` loops
   the deterministic tape with bounded per-loop re-anchoring and arms
   in-process tripwires (CUDA error, false-action/missed, pos-violation,
   consecutive-malformed, latency, VRAM leak, thermal). A 3-loop smoke passed
   clean; the full **≥24 h run (~36,700 ticks) is executing now**. Three
   outcomes, all informative: a clean GREEN, a tripwire abort that *found* an
   endurance bug, or a semantic surprise. **This paper releases on the receipt,
   not on the in-flight log.**

## Honest scope

Proof-of-mechanism on a **24-event scripted tape** (not live sensors — that is
a follow-on), **one model (Gemma-4-12B), one host (RTX 2060 12 GB)**, ~8–17
s/tick, 10.8 GB resident. KAIROS-02's rewind is exact on the *full* cache; the
idle tick still carries the O(context) attention-read term — the O(actions)
elimination is in the *step count*. The SWA-ring wrap-aware rewind (KAI-1c) and
the daemon-resident loop are companions/follow-ons. **The ≥24 h soak has not
passed; this paper's release waits on its receipt.**

## Status

**Paper written/complete for the MECHANISM** ([`paper.md`](paper.md), with its
Reproduction section) — citable via ledger **KAIROS-01 / KAIROS-02**. The
**endurance claim and the full release are HELD on the in-flight ≥24 h soak**
(`G-KAIROS-1`): that run is executing, and per this series' discipline no
verdict is read from a mid-run log. Front-door receipts
measured + gated in
[shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)
(`tests/test_gemma4_cuda.c` `SP_G4_KAIROS`, persistent-KV `gemma4_kv_*`,
`tools/sp_daemon/src/kairos*.rs`; receipt `results/kairos_12b_pathB_crucible.log`);
architecture in lattice `papers/CONTRACT-KAIROS-K0-K1.md` §4. Ledger rows in
[`LEDGER.md`](../../LEDGER.md) §KAIROS (**KAIROS-01 / KAIROS-02**). Companions:
08 (the O(1)-space machinery this loop runs underneath it), 07 (the latent
crossbar the resident daemon curates), 10 (the bit-exact-or-bounded discipline
the soak enforces).
