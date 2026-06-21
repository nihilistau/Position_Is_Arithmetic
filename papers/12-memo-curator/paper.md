---
type: paper-bite
title: "The Memo Curator: autonomous discrete recall above the crossbar"
description: "Shannon-Prime release series, paper 12."
tags: [paper-bite, memo, curator]
timestamp: 2026-06-17T10:58:04Z
resource: ./papers/12-memo-curator/paper.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# The Memo Curator: autonomous discrete recall above the crossbar

*Shannon-Prime release series, paper 12. Discipline: [METHODOLOGY.md](../../METHODOLOGY.md).
Every number below is a row in [LEDGER.md](../../LEDGER.md) with a command behind it.*

> **Front-door receipt (measured + gated 2026-06-17, ledger X-C2).** The latent
> crossbar of papers 07–11 could *read*, *write*, *compress to O(1)*, *replay
> bit-exactly*, and *bound its recall quality* — but only when a human set the
> knobs. Paper 12 is the **policy that drives it on its own**: a resident loop
> that decides *when* to search memory, *which* episode to pull, and hands that
> episode to the proven replay seam — all under the same bit-exact-when-off
> discipline as the substrate. The curator **indexes** (an append-only episode
> registry), **addresses** (a 256-bit LSH hash), **selects** (an integer
> Hamming gate, reduction-order-immune), is **inert when off** (`G-MEMO-NULL`:
> PPL 4.6665 bit-identical with the loop disabled), and **on metal promotes the
> matched recall while discarding the corrupted one** (`G-MEMO-LOOP`: ACCEPT
> matched = +0.000% deflection / REJECT corrupted = +40106% → safety valve).

## 1. The substrate was inert until something decided

Every prior XBAR paper added a *mechanism*. The latent crossbar (07) writes into
the KV cache; the O(1) router (08) keeps the cache from growing with context; the
replay-write seam (paper 11 / X-R3) injects a stored episode bit-exactly and
bounds the perplexity it costs. Together they make a memory substrate that can be
read, written, compressed, replayed, and recall-quality-gated. But all of it is
*inert until a policy fires it* — every result above was produced by a human
setting an environment variable that named the episode and the position.

The Memo curator is that policy, made autonomous. It is a resident loop on the
KAIROS heartbeat (paper 09) that, each tick, looks at the live decode state and
answers three questions the substrate cannot answer for itself: **when** to
search memory (the CUE), **which** episode the cue names (the RESOLVER), and —
through the already-closed machinery — whether the recalled episode is allowed to
stick (the GATE). The whole loop is `propose → gate → promote-or-rewind`: the
C1-lite curator's control flow, moved online and onto the generator.

The design rule it inherits is the one that makes the crossbar *auditable* rather
than merely large: the curator never writes canonical memory directly, and
nothing commits without a measured downstream delta. A cue is only a *trigger*;
the recalled episode is gated by a perplexity deflection bound, and a bad recall
is undone in O(1) byte-exact — not trusted because the cue scored high.

## 2. The three missing pieces: index, cue, resolver

**The episode INDEX.** A flat, append-only, auditable registry on the Optane
Ring-2 tier (`registry.jsonl`, one line per episode — the receipts-first
convention): `episode_id`, `ring2_path`, `npos`, the recall key `sig`, and the
recency/recall-count fields that feed the cold-evict LRU. The load-bearing design
choice is that **the episode's address lives in the exact projection space the
router already ranks in** — `sig` is the centroid (mean) of the episode's
global-owner projected keys, computed once at write time with the *same* frozen
projection the live recall router uses. So resolving a cue is one short dot per
episode, not a model call. No new on-disk K/V format: episodes *are* the serial­
ized P3 stores from paper 11.

**The CUE.** At each tick the curator projects the live global keys into the same
space and asks `max_e (cue · sig[e]) ≥ τ` — the recall router applied to the
*index* instead of to in-window positions. Same math, same frozen geometry, so a
cue that fires is one the downstream gather would also act on. Cheap, deterministic,
auditable; rate-limited to bound churn. The tick source is the existing KAIROS
heartbeat — the curator is a feature-gated module on that loop, not a new daemon.

**The RESOLVER.** On a fired cue, `episode_id = argmax_e (cue · sig[e])`; the
registry row's `ring2_path` and `npos` *are* the replay seam's inputs. The handoff
is literally setting the seam's parameters.

## 3. The Shannon-Prime course-correction: from a float threshold to a bit-collision gate

The first resolver was a float-cosine threshold (`τ_cue = 0.30`, pre-registered
from the write-time separation margins). It worked — but a float threshold is *not*
Shannon-Prime: the orchestration tier should inherit the substrate's discrete,
bit-exact discipline, the same way every memory operation below it does.

A drift-check raised a tempting reframe: "the projection dot product *is* a Hamming
distance, so binarize the signatures and the address becomes integer." We did not
adopt it blindly — we measured it, and it was **false as built**. The identity
`dot = r − 2·Hamming` holds only for ±1 vectors; our signatures are *real-valued*
projection centroids, so the cosine carries magnitude that sign-binarization throws
away. An r-sweep made the cost explicit: at the router-native **r = 32**, sign-
binarizing **collapses** the separation (bit-gap −1 — a noise vector beats a
target, because the thin margin lived entirely in magnitude); it recovers only as
the hash widens.

| r (hash bits) | target self | max non-target | bit-gap |
|---|---|---|---|
| 32 | 24 / 17 | 18 | **−1** |
| 64 | 44 / 37 | 39 | −2 |
| 128 | 83 / 85 | 77 | +6 |
| **256** | 177 / 178 | 158 | **+19** |
| 512 | 363 / 354 | 322 | +32 |

So the discrete form is real but it *costs hash width*: binarization is strictly
weaker than the real dot at equal width, and you buy back the angular margin by
widening until the law of large numbers resolves it. We ship the resolver at
**r = 256**: each episode's address is a 256-bit LSH hash, the match is XOR +
popcount, and the gate is an **integer Hamming radius `TAU_BITS = 168`**.
`G-MEMO-CUE(discrete r=256)` is GREEN — held-out cues resolve to their own id at
177/178 of 256 bits, all eight unrelated queries fall to NULL at ≤ 140.

**Why this is the right call, not cosmetic.** No float in the address space means
the verdict is **reduction-order-immune and hardware-independent** — a float cosine
near the threshold can flip across reduction orders (the float non-associativity
this project has hit before, e.g. the sliding-window reduction in paper 08); an
integer popcount over a fixed bit-hash cannot. We pay 32 bytes per episode and a
wider curator-only projection to buy a bit-exact, auditable address. And the
correctness safety stays *mechanical downstream*: the cue is only a trigger; the
recalled episode is gated by the deflection bound and a bad recall is undone by the
O(1) rewind — not by any confidence in the cue score. The float resolver is
retained as a magnitude-space diagnostic, not deleted.

## 4. The loop, and why SELECT transfers offline → online for free

Resident Exec on the persistent KV ABI, curator on the heartbeat:

```
loop each tick:
  1. Exec decodes the live step.
  2. CUE   : cue = project(live global keys);  fired = (max_e cue·sig[e] ≥ τ) && cooled.
  3. if !fired: continue  (the silent-by-default majority — the KAIROS discipline).
  4. RESOLVE: e* = argmax_e cue·sig[e];  (dir, npos) = registry[e*].
  5. PROPOSE: snapshot the cache;  inject e* via the replay seam at the recall slot.
  6. GATE   : deflection of the continuation under the injected episode.
              PASS iff deflection < 2.0%  (the paper-11 bound) AND the fact reads back.
  7. PROMOTE: gate PASS → keep the injection, commit;
     REWIND : gate FAIL → rewind to the snapshot (the recall is discarded, byte-exact).
```

A subtle but load-bearing consequence of §3: **SELECT does not need to be re-derived
online.** Because the integer-Hamming gate is reduction-order-immune, the live-cache
verdict equals the offline verdict *by construction* — the offline `G-MEMO-CUE`
PASS transfers unchanged. Re-extracting the cue on the metal would be a fragile
second path to the same bits. The online work is the *action* and the *safety
valve*, not the selection.

## 5. Gates and receipts

**G-MEMO-NULL — the orchestrator is perfectly inert when off** (12B-b1,
`_run_memo_null.bat`). With the curator disabled, the Exec decode is byte-identical
to the closed baseline: LEG A baseline PPL **4.6665** == LEG B with the cue-extraction
observer ON, PPL **4.6665**, *bit-identical* (shadow-oracle parity mismatches = 0).
The cue observer fired (23.1 MB of global keys dumped) and an empty-registry resolve
returned NULL — the loop ran, saw nothing to recall, and changed nothing. The
production decoder is left byte-untouched: the null floor, curator edition.

**G-MEMO-LOOP — promote the matched recall, discard the corrupted one** (12B-b1,
`_run_memo_loop.bat`). The curator's two branches, on metal:

| leg | inject | PPL | deflection | gate action |
|---|---|---|---|---|
| baseline | — | 4.6665 | — | — |
| **ACCEPT** | matched episode, NPOS=42 | 4.6665 | **+0.000%** | < 2% → **PROMOTE** |
| **REJECT** | the *zeroed* episode, NPOS=42 | 1876.24 | **+40106%** | ≥ 2% → **FLAG + DISCARD** |

The matched recall is bit-identical — the curator promotes the right memory at
zero cost. The corrupted recall detonates perplexity ~400×, and the deflection
valve flags and discards it. Both branches are proven; the happy path alone could
never prove the *valve fires*, which is why the zeroed-episode REJECT leg is in the
gate on purpose.

Three Shannon-Prime corrections we made to the as-specified directive (verified,
not blindly built): the negative control cannot be the toy context (that context
is a true positive for itself — the no-fire path is covered by the offline
negatives plus G-MEMO-NULL); the deflection is the *safety valve*, not the
selector (selectivity is the discrete cue, proven offline); and the REJECT leg the
happy path never exercises had to be added so the valve is shown to fire.

## 6. Honest scope

- **One model, one host.** Gemma-4-12B (the B1 / OK_Q4B artifact of paper 06),
  RTX 2060 12 GB. Proof-of-mechanism, not a scaling study, not multi-model, not
  independently reproduced.
- **The registry is two real episodes, not a corpus.** The offline selectivity
  and the online loop are proven on two genuine proven-12B episodes (a toy episode
  and an 84-position wiki episode) against synthetic background noise; a
  large-registry stress run is a named hardening lever, not a closed claim.
- **The deflection numbers carry paper 11's caveat.** The +0.000% / +40106%
  deflections are deterministic (replay, not sampling) but are scored over a single
  chunk; the larger-N multi-chunk run named in paper 11 is the hardening lever for
  any headline.
- **A registry-write caveat caught in build.** The write path dumps the full slot
  allocation, so the unfilled cache tail is uninitialized VRAM; the registry `npos`
  bounds the signature to the true filled prefix. The first cut included the garbage
  tail and mis-resolved the toy episode (RED) until capped (GREEN) — recorded
  because the gate caught it.
- **The cue projection layer-subset is a noted follow-on** (see paper 15): the
  registry hashes a consistent layer subset; re-basing it to the 12B's true
  sliding-window period is a correctness tidy-up, and separation is robust to the
  choice, so the gates stand.
- **What is deferred:** Ring-3 gist consolidation (paper 14), the learned cue head,
  and dual-candidate recall are all out of scope here — this is Ring-2 *verbatim*
  autonomous recall only.

## 7. Reproduction

Every number above is a row in [`LEDGER.md`](../../LEDGER.md) with model, fixture,
flags, gate, and commit attached. Gates run from the engine repo
([shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine));
the curator is a host state machine
(`tools/curator/{build_registry,discrete_resolve,curator_loop}.py`) composing engine
seams each already proven bit-exact-when-off, with `gemma4_decode_cuda` left
byte-untouched.

| Gate | Driver | Expected | Receipt log |
|---|---|---|---|
| G-MEMO-CUE (offline + discrete r=256) | `tools/curator/{build_registry,rsweep,discrete_resolve}.py` | self 177/178 of 256; 8/8 unrelated → NULL ≤140 | `tests/fixtures/xbar_c2/G-MEMO-CUE_{offline,discrete}.log` |
| G-MEMO-NULL (inert when off) | `_run_memo_null.bat` | baseline 4.6665 == cue-ON 4.6665, mismatches=0, resolve NULL | `tests/fixtures/xbar_c2/G-MEMO-NULL.log` |
| G-MEMO-LOOP (promote/discard) | `_run_memo_loop.bat` | ACCEPT +0.000% → PROMOTE; REJECT +40106% → FLAG+DISCARD | `tests/fixtures/xbar_c2/G-MEMO-LOOP.log` |

**Commit hashes.** Engine: `31b1de1` (registry + centroid-sig writer, G-MEMO-CUE
offline), `95074d1` (offline resolver + τ thresholding), `6dd87b9` (the discrete
bit-collision re-orientation, r-sweep, r=256 integer-Hamming gate), `3ea0587`
(G-MEMO-NULL, host state machine over the one-shot), `627dfad` (G-MEMO-LOOP,
accept/reject on metal). Architecture and pre-registered gates: lattice
`papers/CONTRACT-XBAR-C2-memo-curator-loop.md` (§2 design, §4 gates, §7 run-records).

## Receipts

| Row | Receipt |
|---|---|
| X-C2 | `G-MEMO-NULL`: curator OFF ⇒ Exec decode bit-identical to baseline (PPL 4.6665 == 4.6665, mismatches=0, empty-registry resolve = NULL). `G-MEMO-CUE(discrete r=256)`: held-out cues resolve to own id at 177/178 of 256 bits, 8/8 unrelated → NULL ≤140 (integer Hamming `TAU_BITS=168`, reduction-order-immune). `G-MEMO-LOOP`: ACCEPT matched recall +0.000% deflection → PROMOTE; REJECT corrupted recall +40106% → safety-valve FLAG+DISCARD. 12B-b1 + E2B, RTX 2060 12 GB |

Companions: paper 07 (the latent crossbar the curator drives), paper 08 (the O(1)
cache it recalls into), paper 11 / X-R3 (the replay-write seam and the <2%
deflection bound it gates on), paper 13 (the O(1) bit-exact rewind that makes the
discard degrade-safe), paper 14 (the Ring-3 gist tier above this verbatim loop),
paper 10 (the bit-exact-or-bounded methodology).
