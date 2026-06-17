# The organism breathes: a cross-modal continuous→discrete→continuous loop on silicon

*Shannon-Prime release series, paper 18. Discipline: [METHODOLOGY.md](../../METHODOLOGY.md).
Every number below is a row in [LEDGER.md](../../LEDGER.md) with a command behind it.*

> **Front-door receipt (measured + gated 2026-06-18, ledger X-OK-ORG).** Paper 15
> closed step 1 of the organism — real audio written as a curator-indexable episode. This
> paper closes the **full loop**, and it closes it on the integer substrate papers 16–17
> built. `G-XBAR-ORGANISM-FULL` runs end-to-end: a real EAR audio episode (P=114, sensed
> on physical Intel GNA 2.0) plus text decoys (wiki P=294, toy P=56) are indexed by the C2
> 256-bit signature (audio self **256/256**, vs decoys **147 / 129** — far below the
> TAU_BITS=168 accept threshold); the **native integer Ring-3 bind** (paper 16) holds all
> in one store; an **audio cue retrieves its own episode top-1** (cosine +0.47); the C2
> Hamming verify **accepts the audio (256 ≥ 168) and rejects the text decoys** — the
> cross-modal verify; the episode lands through the **integer Frobenius `a16b8` codec**
> (paper 17, K/V relative-L2 ~9e-8); and the integer-decoded episode is injected into the
> **resident 12B cache via the metal `SP_REPLAY`** clean (checks=5, fails=0, LAND_EXIT=0).
> A continuous signal becomes discrete integers and comes back continuous into a live
> model. And the correctness tidy-up paper 15 named: the content hash is **rebased from
> period-8 to the true gemma-4 global period-6** — separation is cleaner (decoy 154→129),
> and every prior gate still stands.

## 1. From step 1 to the whole breath

Paper 15 proved the *write* seam: real audio, heard on the physical GNA, could be
serialized as a well-formed Ring-2 episode whose signature separated from text memories
and which round-tripped through the replay seam. It was honest that this was **step 1, not
the full loop** — the autonomous *audio-cue → shortlist → verify → land* breath was the
named remaining step.

This paper closes it, and does so on the substrate the rest of this set assembled. The
loop is not new floating-point glue; it is the integer bind of paper 16 and the integer
codec of paper 17 wired into a single end-to-end pass that takes a continuous sensory
signal, drives it all the way down into the discrete number-theoretic memory, retrieves
and verifies it there, and lands it back as continuous KV state in a live 12B. The full
arc: **continuous → discrete → continuous**, on one card and one GNA part.

## 2. The full loop, stage by stage

`G-XBAR-ORGANISM-FULL` (`tools/ring3/g_xbar_organism_full.py`). Three real episodes go
in: `ep_audio` (the EAR packet, P=114), `ep_wiki` (P=294), `ep_toy` (P=56). The audio is
the cue; the text episodes are decoys whose only job is to be *rejected*.

**Stage 1 — signature (C2, paper 12).** The 256-bit content signature agreement, audio
cue vs each episode:

| episode | Hamming agreement with audio cue |
|---|---|
| **`ep_audio` (self)** | **256 / 256** |
| `ep_wiki` (decoy) | 147 / 256 |
| `ep_toy` (decoy) | 129 / 256 |

The audio self-recalls at the full 256 bits; the decoys sit at 147 and 129 — both **well
below the TAU_BITS=168 accept threshold**. The cross-modal addressing is clean: a
continuous, noisy audio latent is a first-class discrete address.

**Stage 2 — integer bind + shadow-gate (paper 16, native).** All three episodes are
bound into one Ring-3 superposition on the **native integer `sp_pr_mul` path** (paper 16),
and the nightshift shadow-gate confirms **recall@1 for all** bound episodes — the
integer store holds the cross-modal set without crosstalk.

**Stage 3 — retrieve (dual-route).** The audio cue is unbound against the store and
shortlisted: it retrieves **`ep_audio` top-1**, cosine **+0.47** above the decoys. The
lossy Ring-3 retrieve does its job — it shortlists the right episode.

**Stage 4 — verify (C2 Hamming, the cross-modal verify).** The shortlist is gated by the
C2 integer-Hamming verify: the audio candidate **accepts (256 ≥ 168)**, the text decoys
**reject**. This is the load-bearing cross-modal moment — the verify gate that paper 14
designed for text episodes works *across modalities*: it accepts an audio episode for an
audio cue and rejects text episodes, on the same integer-Hamming machinery, with no
modality-specific code.

**Stage 5 — land (integer Frobenius codec, paper 17).** The accepted episode is decoded
from the **integer Frobenius `a16b8` codec** (paper 17): the reconstructed K/V matches at
relative-L2 **~9e-8** — sub-ULP, the codec's measured fidelity carried into the live loop.

**Stage 6 — inject (metal `SP_REPLAY`).** The integer-decoded `ep_audio` is injected into
the **resident 12B KV cache via the metal `SP_REPLAY` seam** (paper 13): **checks=5,
fails=0, LAND_EXIT=0** — a clean land. The perplexity over the wikitext score context is
**88.89 (foreign-by-design)** — the same foreign-context signal paper 15 documented (an
audio episode replayed over a *text* score context *should* deflect; ~0% is the
matched-context number, and matched-context audio recall remains the open follow-on, not a
number claimed here).

The breath is complete: a real continuous audio signal, sensed on dedicated silicon,
becomes a discrete 256-bit address, is superposed and retrieved and verified entirely in
integer arithmetic, is decoded from an integer lattice codec, and re-enters a live 12B as
continuous KV state — with every stage gated. Receipt:
`tests/fixtures/xbar_organism/G-XBAR-ORGANISM-FULL.log`.

## 3. The period-6 rebase: the correctness tidy-up, done

Paper 15 carried one named correctness caveat: the curator / Ring-3 signature pipeline
hashed a **period-8** layer subset (every 8th owner), while the 12B's *true* sliding-window
period is **6**. Paper 15 argued — correctly — that separation is robust to the choice (any
consistent subset distinguishes episodes), so every gate stood; but it logged the re-base
as an owed tidy-up.

`G-PERIOD6-REBASE` does it. The content hash is rebased onto the true gemma-4 global
layers — `{5, 11, 17, 23, 29, 35, 41, 47}`, the layers where
`L_i % g4_period == g4_period − 1` with `g4_period = 6` (the period defined in
`cuda_forward.cu`'s global-attention selection). The old period-8 hash was sampling
*non-global* layers; the period-6 hash samples exactly the global crossbar layers the
content actually flows through. Re-gated **GREEN**, and the separation is **cleaner**: the
decoy agreement drops from **154 → 129** — the same content, hashed on the right layers,
separates better. The caveat is retired, not merely acknowledged. Receipt:
`tests/fixtures/xbar_organism/G-PERIOD6-REBASE.log`.

## 4. Honest scope

- **The full loop is closed; matched-context audio recall is not claimed.** The loop
  retrieves, verifies, and lands the correct audio episode — every stage gated. The
  **88.89 / +foreign deflection** is the **cross-context reject signal** (audio episode
  over a wikitext score context), exactly as paper 15 framed it; a matched-context
  audio-recall *quality* number is the open follow-on, not stated here.
- **One audio episode, two text decoys.** The cross-modal verify is proven on a real EAR
  audio episode against real text decoys; a larger cross-modal registry is a named stress
  lever, not run here.
- **The `+0.47` cosine and the `~9e-8` land fidelity are this loop's measurements** — the
  retrieve margin and the integer-codec reconstruction carried into the live pass; the
  underlying capacity and codec numbers are papers 16–17.
- **One model, one host, one GNA part.** Gemma-4-12B (the B1 / OK_Q4B artifact of paper
  06), RTX 2060 12 GB; the audio front-end on a physical Intel GNA 2.0 (the KAIROS-04 EAR
  line, paper 09). Proof-of-mechanism, not a scaling study, not multi-model, not
  independently reproduced.
- **The EAR/GNA numbers are paper 09's (KAIROS-04), cited as the upstream sense.** This
  paper's *new* claim is the closed cross-modal loop on the integer substrate plus the
  period-6 rebase.

## 5. Reproduction

Every number above is a row in [`LEDGER.md`](../../LEDGER.md) with model, fixture, flags,
gate, and commit attached. Gates run from the engine repo
([shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)),
`tools/ring3/g_xbar_organism_full.py`; the bind is the native `sp_pr_mul` path (paper 16),
the codec is `tools/curator/frob_episode.py` (paper 17), the inject is the metal
`SP_REPLAY` seam (paper 13); `gemma4_decode_cuda` is left byte-untouched.

| Gate | Driver | Expected | Receipt log |
|---|---|---|---|
| G-XBAR-ORGANISM-FULL | `tools/ring3/g_xbar_organism_full.py` | sig: audio self 256, decoys 147/129 (< TAU 168); native bind recall@1 all; audio cue → `ep_audio` top-1 (cos +0.47); C2 verify accept audio / reject text; Frobenius `a16b8` land K/V relL2 ~9e-8; `SP_REPLAY` checks=5 fails=0 LAND_EXIT=0 (PPL 88.89 foreign-by-design) | `tests/fixtures/xbar_organism/G-XBAR-ORGANISM-FULL.log` |
| G-PERIOD6-REBASE | (same harness, period-6 hash) | content hash rebased to true gemma-4 globals `{5,11,17,23,29,35,41,47}` (`L_i%6==5`); re-gated GREEN; separation cleaner (decoy 154→129) | `tests/fixtures/xbar_organism/G-PERIOD6-REBASE.log` |

**Commit hashes.** Engine: `15e7051` (G-XBAR-ORGANISM-FULL — the end-to-end cross-modal
loop on the native integer substrate), `d2d7ceb` (G-PERIOD6-REBASE — content hash rebased
to the true gemma-4 global period-6 layers, separation cleaner, all gates re-GREEN). The
native integer bind is paper 16 (engine `0019b86`/`1f0f6be`); the Frobenius `a16b8` codec
is paper 17 (engine `dbe4103`); the metal `SP_REPLAY` is paper 13 (X-222); the EAR/GNA
sense is paper 09 (KAIROS-04). Architecture: lattice
`papers/CONTRACT-KAIROS-K0-K1.md` §7.4–§7.6 (the EAR/GNA closure) + the C2 curator and R3
consolidation contracts (the memory tiers the loop traverses).

## Receipts

| Row | Receipt |
|---|---|
| X-OK-ORG | The organism breathes end-to-end on the integer substrate — a cross-modal continuous→discrete→continuous loop. **`G-XBAR-ORGANISM-FULL`:** real episodes `ep_audio` (EAR, P=114, sensed on physical Intel GNA 2.0) + `ep_wiki` (P=294) + `ep_toy` (P=56). C2 256-bit signature: audio self **256/256**, vs wiki **147**, vs toy **129** (decoys ≪ TAU_BITS=168). Native integer Ring-3 bind (paper 16) shadow-gate recall@1 all. Dual-route: audio cue → `ep_audio` **top-1** (cos **+0.47**). C2 integer-Hamming verify: **accept audio (256 ≥ 168), reject text decoys** — the cross-modal verify. Land: integer Frobenius `a16b8` decode (paper 17) K/V relative-L2 **~9e-8**. Inject: metal `SP_REPLAY` (paper 13) of the integer-decoded `ep_audio` into the resident 12B cache **checks=5, fails=0, LAND_EXIT=0** (PPL 88.89 foreign-by-design — the cross-context reject signal, not an audio-recall quality claim; matched-context recall is the open follow-on). **`G-PERIOD6-REBASE`:** content hash rebased period-8 → true gemma-4 global period-6 `{5,11,17,23,29,35,41,47}` (`L_i % 6 == 5`); re-gated GREEN, separation **cleaner** (decoy 154→129) — the paper-15 caveat retired. 12B-b1, RTX 2060 12 GB; EAR on physical Intel GNA 2.0 (KAIROS-04). Open: matched-context audio recall, larger cross-modal registry; NEXT = the `T4` `π^k` Frobenius codec on the 9.4 GB model weights |

Companions: paper 15 / X-ORG (the step-1 write seam this completes into the full loop, and
the period-8-vs-6 caveat this retires), paper 16 / X-OK-BIND (the native integer bind the
loop's superposition runs on), paper 17 / X-OK-FROB (the integer Frobenius codec the
episode lands through), paper 13 / X-222 (the metal `SP_REPLAY` inject), paper 12 / X-C2
(the 256-bit signature and the integer-Hamming verify, here used cross-modally), paper 09 /
KAIROS-04 (the physical-GNA EAR sense upstream), paper 10 (the foreign-by-design framing
that keeps the 88.89 honest).
