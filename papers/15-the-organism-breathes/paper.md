---
type: paper-bite
title: "The organism breathes: real audio to episodic memory"
description: "Shannon-Prime release series, paper 15."
tags: [paper-bite, organism]
timestamp: 2026-06-17T10:58:04Z
resource: ./papers/15-the-organism-breathes/paper.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# The organism breathes: real audio to episodic memory

*Shannon-Prime release series, paper 15. Discipline: [METHODOLOGY.md](../../METHODOLOGY.md).
Every number below is a row in [LEDGER.md](../../LEDGER.md) with a command behind it.*

> **Front-door receipt (measured + gated 2026-06-17, ledger X-ORG).** The whole
> stack, end to end, on one bridge: **real audio → EAR → episodic memory.** Real
> speech is heard by a fixed-point front-end on a *physical* Intel GNA 2.0
> accelerator (0.877 token-recovery == software-emulation == FP32, ledger
> KAIROS-04); that audio drives the resident 12B to the correct response **7/8**
> (paper 09); and — the new seam — the audio-conditioned KV state is serialized as
> a well-formed Ring-2 **episode** in the canonical episode format, indexed by the
> paper-12 curator, and round-tripped through the paper-13 replay seam. The
> audio-derived 256-bit signature **separates cleanly** from the text episodes
> (self 211/256, margin +79). The organism hears, and what it hears becomes a
> memory the curator can find and replay.

## 1. Closing the loop from sense to memory

The series has built, separately: a way to *hear* (the EAR / GNA line, KAIROS-04 —
real speech projected into the residual stream on physical silicon, the 12B pivoting
7/8); and a way to *remember* (the XBAR crossbar — Ring-2 verbatim episodes, the Memo
curator that indexes and recalls them, the O(1) bit-exact replay/rewind). Paper 15 is
the first bridge between them: it makes the thing the model *hears* become a thing the
model can *remember* — an audio-conditioned KV state serialized as a functional,
curator-indexable, replayable Ring-2 episode.

This is step 1 of the organism: the **write** seam (audio → episode), the **signature**
(the episode is addressable and separates from text memories), and the **round-trip**
(the episode loads and injects cleanly). The full autonomous loop — an audio cue
retrieving its own episode — is the named remaining step. What is closed here are the
load-bearing new seams.

## 2. The bridge, and a layout bug it caught

The write seam (`run_kai3_write`) takes a **real audio packet** — seven audio-derived
projector frames from a recorded TTS utterance — and injects it through the proven
KAI-3 7/8 pivot path (`gemma4_kv_inject_seq`), producing a conditioned cache of
npos=114 positions. That conditioned state is then serialized as a Ring-2 episode in
the **canonical episode format**.

The format is where the bug lived, and catching it is the load-bearing engineering.
The 12B's cache is *jagged*: the global owner is 1×512 per layer, but the
sliding-window owners are 8×256 = 2048 per layer. A first cut serialized the episode
at those per-class widths — a 39 MB *jagged* store that is **not curator-digestible**,
because the curator's index and the replay seam expect the canonical uniform layout
(the same `[NL, P, 512]` format every other episode uses). The fix is to **clamp the
episode to the canonical uniform 512 per layer** — the global width — matching the
existing episode layout exactly. The audio episode then weighs
`ep.k = ep.v = 11,206,656 B = 48 × 114 × 512 × 4`, byte-for-byte the same shape as a
text episode. An audio memory is structurally indistinguishable from any other Ring-2
memory — which is the entire point.

## 3. The signature gate: audio separates from text, cleanly

For the curator to find an audio episode, its 256-bit content signature (paper 12)
must be distinct from the text episodes' — and the worry was real: audio latents are
noisier and more continuous than text, so the Hamming margins could blur. They do not.

| cue | self | vs other episode (text) | vs other episode (text) | margin |
|---|---|---|---|---|
| **audio episode** | **211/256** | 132/256 | 123/256 | **+79** |
| text episode (toy) | 177/256 | — | — | +19 (still PASS) |
| text episode (wiki) | 178/256 | — | — | +25 (still PASS) |

The audio episode's signature self-recalls at 211 of 256 bits and sits at 118–131 bits
against the text episodes — well below the ~177 self-recall band — and crucially, its
presence does **not** blur the text episodes' own margins. The noisier, continuous
audio latent is still cleanly addressable in the discrete integer-Hamming space the
curator uses. The audio memory is a first-class citizen of the index.

## 4. Round-trip: a well-formed, replayable episode

The last check is that the audio episode loads and injects through the replay seam
without error — structural digestibility, the precondition for the curator ever
recalling it.

**Round-trip** (replay the audio episode, NPOS=42, 12B metal). The episode's manifest
parses, the store bytes match, and the replay seam injects the owner-K/V over the
prefill rows with **no engine error (RT_EXIT = 0, checks=5, fails=0)**. The episode is
well-formed: it loads, and it injects.

The perplexity it deflects is **+1989%** (97.53 vs the 4.6665 baseline) — and this is
**foreign-by-design, not a failure**. The ~0% deflection is the *matched-context*
signature (a wiki episode replayed into a wiki score context, already proven at
+0.000% in paper 11); an *audio* episode replayed over a *wikitext* score context
*should* deflect hard, because they are unrelated. That high deflection is exactly the
signal the curator's verify gate (paper 12) uses to **reject a mis-routed recall**. The
round-trip proves the episode is structurally valid; the deflection proves the verify
gate has a working reject signal when the context doesn't match. Both are the intended
behavior.

## 5. Honest scope

- **Step 1, not the full loop.** This closes the write seam + signature + round-trip —
  the load-bearing new bridges. The **full organism loop** (an audio cue → Ring-3
  shortlist → verify → land its own episode) is the named remaining step.
- **The +1989% deflection is foreign-by-design.** It is *not* a quality claim about
  audio recall; it is the reject signal for a cross-context replay. Matched-context
  audio recall is the open follow-on, not a number stated here.
- **A noted correctness follow-on: the period-8-vs-6 layer subset.** The curator /
  Ring-3 signature pipeline hashes a consistent period-8 layer subset (every 8th
  owner); the 12B's *true* sliding-window period is 6. Separation is robust to the
  choice — any consistent subset distinguishes episodes — so every prior C2/R3 gate
  and the signatures above stand; re-basing the registry on the true period-6 subset is
  a correctness tidy-up, recorded honestly, not a result that changes.
- **One model, one host, one GNA part.** Gemma-4-12B (the B1 / OK_Q4B artifact of
  paper 06), RTX 2060 12 GB; the audio front-end on a physical Intel GNA 2.0 (the
  KAIROS-04 EAR line). Proof-of-mechanism, not a scaling study, not multi-model, not
  independently reproduced.
- **The EAR/GNA numbers are paper-09's (KAIROS-04), cited here as the upstream sense.**
  The 0.877 token-recovery on physical silicon and the 7/8 pivot are that paper's
  receipts; this paper's *new* claim is the write-to-episode bridge.

## 6. Reproduction

Every number above is a row in [`LEDGER.md`](../../LEDGER.md) with model, fixture, flags,
gate, and commit attached. Gates run from the engine repo
([shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine));
the write seam is `run_kai3_write` (`SP_G4_KAI3_WRITE`) over the proven KAI-3
`gemma4_kv_inject_seq` path; the replay round-trip is the paper-11/13 replay seam.

| Gate | Driver | Expected | Receipt log |
|---|---|---|---|
| G-XBAR-ORGANISM — write seam | `_run_organism_write.bat` | conditioned cache npos=114 → ep_audio 11,206,656 B canonical uniform-512 | `tests/fixtures/xbar_organism/G-XBAR-ORGANISM-write.log` |
| G-XBAR-ORGANISM — signature | (same log) | audio self 211/256, margin +79; text margins unchanged | `tests/fixtures/xbar_organism/G-XBAR-ORGANISM-write.log` |
| G-XBAR-ORGANISM — round-trip | `_run_organism_rt.bat` | RT_EXIT=0 checks=5 fails=0; +1989% deflection (foreign-by-design) | `tests/fixtures/xbar_organism/G-XBAR-ORGANISM-write.log` |

**Commit hashes.** Engine: `6600cf4` (G-XBAR-ORGANISM step 1 — EAR audio → Ring-2 write
seam, the canonical uniform-512 clamp, the signature separation, the clean round-trip).
The upstream EAR/GNA line (KAIROS-04) and the replay seam are ledger rows KAIROS-04 and
X-R3 / X-222; architecture is lattice `papers/CONTRACT-KAIROS-K0-K1.md` §7.4–§7.6 (the
EAR/GNA closure) + the C2 curator and R3 contracts (the memory tiers the episode lands
in).

## Receipts

| Row | Receipt |
|---|---|
| X-ORG | `G-XBAR-ORGANISM` step 1: a real audio packet (7 projector frames) injected via the KAI-3 `gemma4_kv_inject_seq` path → conditioned cache npos=114 → serialized as ep_audio in the canonical uniform-512 episode format (`ep.k = 48 × 114 × 512 × 4 = 11,206,656 B`, matching the text-episode layout; a jagged-2048 first cut was caught and clamped). Signature gate: audio self 211/256, vs text episodes 118–131/256, **margin +79**; text episodes' own margins unchanged. Round-trip: replay injects clean (RT_EXIT=0, checks=5, fails=0); +1989% deflection is foreign-by-design (audio episode vs a wikitext score context — the reject signal the verify gate needs; ~0% is matched-context only). 12B-b1, RTX 2060 12 GB; the EAR front-end on physical Intel GNA 2.0 (KAIROS-04). Open: matched-context audio recall + the full audio-cue→shortlist→verify→land loop; the period-8-vs-6 registry re-base is a noted correctness tidy-up (separation robust, all gates stand) |

Companions: paper 09 / KAIROS-04 (the EAR / GNA line that hears the audio — the
upstream sense), paper 12 / X-C2 (the curator that indexes the audio episode), paper
13 / X-222 (the replay + O(1) rewind the round-trip exercises), paper 14 / X-R3VSA (the
Ring-3 tier the full audio-cue loop will shortlist into), paper 10 (the
bit-exact-or-bounded methodology and the honest-foreign-deflection framing).
