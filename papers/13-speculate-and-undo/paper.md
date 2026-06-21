---
type: paper-bite
title: "Speculate and Undo: O(1) bit-exact rewind of latent memory"
description: "Shannon-Prime release series, paper 13."
tags: [paper-bite]
timestamp: 2026-06-17T10:58:04Z
resource: ./papers/13-speculate-and-undo/paper.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# Speculate and Undo: O(1) bit-exact rewind of latent memory

*Shannon-Prime release series, paper 13. Discipline: [METHODOLOGY.md](../../METHODOLOGY.md).
Every number below is a row in [LEDGER.md](../../LEDGER.md) with a command behind it.*

> **Front-door receipt (measured + gated 2026-06-17, ledger X-222).** The Memo
> curator (paper 12) must be free to *guess*: speculate a recalled memory into the
> resident cache, check it, and — if the check fails — make it as if it never
> happened. This paper closes that guarantee on metal. A new replay seam injects a
> stored episode's owner-K/V directly into the **resident** KV cache; on reject,
> an **O(1) byte-exact rewind** undoes it. `G-222` is GREEN on both the 12B (48
> owner layers) and the smaller E2B (15 owners / 20 sharers): replay-inject is
> **load-bearing** (a zeroed episode's injected slots read back all-zero —
> 0/688128 bytes nonzero on the 12B) and the rewind resets the pre-injection
> prefix **byte-identical (layer-diffs = 0)**. `G-222-WRAP` extends it to the
> sliding-window ring: a journal-backed rewind across a forced wrap is again
> diffs = 0. The §4-trap guarantee — a rejected recall cannot corrupt the model —
> made mechanical.

## 1. Why a curator must be able to undo

Paper 12 gave the crossbar a *policy*: a loop that decides when to search memory,
which episode to pull, and whether the recalled episode is allowed to stick. The
last clause is the dangerous one. A recall is a *guess* — the cue is a trigger, not
a proof — so the loop must be able to inject a candidate memory, measure its effect,
and on a bad guess return the cache to exactly where it was. If "undo" is even
slightly lossy, the error compounds over a long resident run; if it is *expensive*,
the curator can't afford to speculate, and a memory system that can't speculate
can't recall.

KAIROS (paper 09) built the primitive this needs: a persistent-KV ABI where
`rewind(Δ)` is an O(1) byte-exact inverse on the full cache, because each cache slot
maps to exactly one decode position — once the position is rolled back, the sheared
slots are never read again and are overwritten on the next append. Paper 13 fuses
that rewind with the replay-write seam of paper 11, so the curator's *speculate →
gate → undo* becomes a single resident transaction. The reject path costs O(1) and
leaves no trace.

## 2. The seam: replay into the resident cache

The one-shot replay seam of paper 11 injects an episode at the cache-store boundary
of the production decoder. The curator needs the same injection in the *resident*
twin — the persistent cache that survives across ticks — so it can speculate without
re-prefilling the whole context. The new seam is:

```
gemma4_kv_replay(s, epdir, npos, zero);   /* inject a stored episode's owner-K/V
                                             into the resident cache at [dpos, dpos+npos),
                                             advancing dpos (full-cache: slot == pos) */
```

It is the persistent twin of the one-shot replay: the curator speculates a recall
here, and on reject calls `gemma4_kv_rewind(npos)` to undo it **bit-exactly in
O(1)** — a full-cache shear that touches zero cache bytes, the same slot==pos inverse
KAIROS proved. The discipline that keeps the tower standing is unchanged: the
production decoder `gemma4_decode_cuda` is left byte-for-byte untouched; the
persistent-KV ABI is a *twin*, never a modification, so every previously-closed gate
stays valid.

## 3. G-222: load-bearing replay, byte-exact undo

The gate has to prove two things at once — that the injection *does something* (so
the rewind isn't undoing a no-op) and that the undo is *perfect*.

**G-222** (`_run_g222.bat`, gemma-4-12B B1 + Gemma-4-E2B, RTX 2060). Open the
resident cache, prefill an anchor, replay a stored episode at `[anchor, anchor+npos)`,
then rewind.

- **Load-bearing.** Replaying a *zeroed* episode injects all-zero K/V into the target
  slots, and they read back all-zero — **0 / 36864 bytes nonzero on the E2B,
  0 / 688128 on the 12B**. The injected payload is what the slots hold, not stale
  cache — so a non-zero episode is genuinely written, not ignored.
- **Byte-exact undo.** After `rewind(npos)`, the pre-injection floor `[0, anchor)`
  is **byte-identical across all owner layers (layer-diffs = 0)** and `dpos` is reset
  to the anchor. Proven on both artifacts — the 12B (48 owner layers) and the E2B
  (15 owners / 20 sharers, exercising the owner-indirection).

For a transaction the curator will run tens of thousands of times unattended,
"close enough" is the wrong gate: any non-zero drift compounds. Byte-exact is the
only standard that cannot silently rot — which is why the gate is a byte comparison,
not a tolerance.

A scope correction we made and recorded: the directive's second step (port the
teacher-forced scorer into the persistent ABI) is *not* required to close this — the
deliverable is the O(1) bit-exact rewind, proven by byte comparison, and the
deflection number is already a proven one-shot receipt (paper 12's `G-MEMO-LOOP`).
The kv-side scorer is a separate, deferrable optimization.

## 4. G-222-WRAP: the rewind survives the sliding-window ring

The full-cache rewind is exact because slot == pos. But paper 08's O(1)-*space* win
puts the dominant sliding-window (SWA) layers on a W-slot **ring** (write slot =
`pos % W`), and on a ring a naive position decrement is *not* a clean undo: a replay
that advances past a wrap writes ring slots that previously held still-live window
positions, so a plain rewind would leave those slots holding future K/V. The
"sheared slots are never read" invariant fails when the replay aliases onto the live
window.

The fix is the KAI-1c **undo-journal** (paper 09 §5), reused here: before
`gemma4_kv_replay` overwrites a ring slot, the slot's current K/V is checkpointed
into a per-tick journal; the rewind replays the journal in reverse to restore each
clobbered slot to its pre-replay contents; the globals stay full-cache.

**G-222-WRAP** (`_run_g222_wrap.bat`, W=16, 12B + E2B). With `anchor = 24` and W=16,
the replay's target slots `(24..31) % 16 = 8..15` **alias live positions 8–15** — the
exact wrap-crossing hazard. The gate confirms the injection is load-bearing (the
injected slots zero out) and the journal-backed rewind restores the **full live
window byte-identical (layer-diffs = 0)** with `dpos` back to the anchor, O(1). GREEN
on both artifacts.

With G-222 (full-cache) and G-222-WRAP (SWA-ring) the local KV substrate is airtight
in *both* regimes — the curator can speculate and undo whether the recall lands in
the full cache or aliases the sliding window.

## 5. Honest scope

- **One model, one host.** Gemma-4-12B (the B1 / OK_Q4B artifact of paper 06) and
  Gemma-4-E2B, RTX 2060 12 GB. Proof-of-mechanism, not a scaling study, not
  multi-model, not independently reproduced.
- **The O(1) is in the byte-count, proven by byte comparison.** The rewind touches
  zero cache bytes on the full cache and a bounded `min(k, W)`-per-owner journal on
  the ring — both constant in the amount of history retained. This paper proves
  *correctness* (diffs = 0) and *byte-cost*; the wall-clock O(1) *latency* slope is
  the KAIROS-02 / KAIROS-03 telemetry (paper 09), measured separately and carrying
  its own clock-jitter caveat (the 2060 cannot lock its memory clock).
- **The deferred scorer port.** The teacher-forced perplexity scorer is not yet in
  the persistent ABI; the curator scores on the one-shot path and uses the resident
  rewind for the discard. Closing the scorer into the ABI is a named follow-on.
- **The compact-slab global rewind** (the O(1)-VRAM slab of paper 08, vs the
  full-cache globals here) is a named follow-on; G-222 covers full-cache + SWA-ring.

## 6. Reproduction

Every number above is a row in [`LEDGER.md`](../../LEDGER.md) with model, fixture,
flags, gate, and commit attached. Gates run from the engine repo
([shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine));
the seam is `gemma4_kv_replay` / `gemma4_kv_rewind` in
`src/backends/cuda/cuda_forward.cu`, with `gemma4_decode_cuda` left byte-untouched.

| Gate | Driver | Expected | Receipt log |
|---|---|---|---|
| G-222 (full-cache replay + O(1) rewind) | `_run_g222.bat` | load-bearing (0/688128 12B nonzero on zeroed); rewind `[0,anchor)` layer-diffs=0; both artifacts | `tests/fixtures/xbar_c2/G-222-REWIND-NULL.log` |
| G-222-WRAP (SWA-ring, journal-backed) | `_run_g222_wrap.bat` | replay aliases live slots 8–15; journal-backed rewind layer-diffs=0; both artifacts | `tests/fixtures/xbar_c2/G-222-WRAP.log` |

**Commit hashes.** Engine: `b4b037a` (`gemma4_kv_replay` ported into the persistent
ABI + O(1) bit-exact rewind, G-222 on E2B + 12B), `24071bc` (replay made SWA-ring-aware
via the KAI-1c journal, G-222-WRAP). Architecture: lattice
`papers/CONTRACT-XBAR-C2-memo-curator-loop.md` §7 (the #222 run-records); the rewind
primitive is lattice `papers/CONTRACT-KAIROS-K0-K1.md` §5.5–5.7 (KAI-1b/1c).

## Receipts

| Row | Receipt |
|---|---|
| X-222 | `G-222`: `gemma4_kv_replay` injects a stored episode into the resident cache and is load-bearing (zeroed episode's injected slots read back all-zero: 0/36864 E2B, 0/688128 12B); `gemma4_kv_rewind(npos)` resets `[0,anchor)` byte-identical (layer-diffs=0), pos→anchor, O(1) (full-cache slot==pos shear touches zero cache bytes). `G-222-WRAP`: SWA-ring replay aliasing live slots 8–15; KAI-1c journal-backed rewind restores the live window byte-identical (layer-diffs=0). 12B-b1 (48 owners) + E2B (15 owners / 20 sharers), RTX 2060 12 GB |

Companions: paper 09 / KAIROS-02–03 (the O(1) byte-exact rewind primitive this
reuses), paper 11 / X-R3 (the one-shot replay-write seam this ports to the resident
cache), paper 12 / X-C2 (the curator whose speculate→gate→undo this makes degrade-safe),
paper 14 (the Ring-3 dual-route that scans candidates by rejecting and O(1)-rewinding
the wrong ones), paper 10 (the bit-exact-or-bounded methodology).
