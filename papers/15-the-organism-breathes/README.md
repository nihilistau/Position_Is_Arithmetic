# 15 — The organism breathes: real audio to episodic memory *(written, citable — X-ORG)*

> **STATUS: written — [`paper.md`](paper.md) complete.** Front-door receipts measured
> + gated (ledger **X-ORG**).

> **Front-door receipt (measured + gated 2026-06-17, ledger X-ORG):** the whole stack,
> end to end — **real audio → EAR → episodic memory.** Real speech is heard by a
> fixed-point front-end on a *physical* Intel GNA 2.0 accelerator (0.877 token-recovery
> == software-emulation == FP32, ledger KAIROS-04); that audio drives the resident 12B
> to the correct response **7/8** (paper 09); and the audio-conditioned KV state is
> serialized as a well-formed Ring-2 **episode** in the canonical episode format
> (`ep.k = 48 × 114 × 512 × 4 = 11,206,656 B`), indexed by the curator and round-tripped
> through the replay seam. The audio-derived 256-bit signature **separates cleanly** from
> the text episodes (self 211/256, margin +79). 12B-b1, RTX 2060 + physical GNA 2.0.

## The claim this paper makes

The series has built a way to *hear* (the EAR/GNA line) and a way to *remember* (the XBAR
crossbar) separately. This is the first bridge: what the model hears becomes a memory the
curator can find and replay. Step 1 closes the **write** seam (audio → episode), the
**signature** (the episode is addressable and separates from text memories), and the
**round-trip** (the episode loads and injects cleanly). The full autonomous loop (an
audio cue retrieving its own episode) is the named remaining step.

## What's in it (the map)

1. **Sense → memory** — the two halves of the organism, bridged for the first time.
2. **The bridge + a layout bug** — real audio packet → conditioned cache (npos=114) →
   serialized episode; the jagged-2048 first cut caught and clamped to the canonical
   uniform-512 layout (so the episode is curator-digestible).
3. **The signature gate** — the audio episode self-recalls at 211/256, margin +79, and
   does not blur the text episodes' margins — a noisier latent, still cleanly addressable.
4. **Round-trip** — RT_EXIT=0; the +1989% deflection is **foreign-by-design** (audio
   episode vs a wikitext score context — the reject signal the verify gate needs; ~0% is
   matched-context only).

## Honest scope

**Step 1, not the full loop.** Proof-of-mechanism, **one model (12B-b1), one host (RTX
2060), one GNA part**; the +1989% deflection is the foreign-context reject signal, *not*
an audio-recall quality claim (matched-context audio recall is the open follow-on). The
EAR/GNA numbers (0.877 on silicon, 7/8 pivot) are paper 09's (KAIROS-04), cited here as
the upstream sense. **Noted correctness follow-on:** the signature pipeline hashes a
period-8 layer subset while the 12B's true sliding-window period is 6 — separation is
robust to the choice, so all prior gates stand; the period-6 re-base is a tidy-up.

## Status

**Paper written/complete** ([`paper.md`](paper.md)) — citable via ledger **X-ORG**.
Front-door receipts measured + gated in
[shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)
(`run_kai3_write` / `SP_G4_KAI3_WRITE`, `_run_organism_write.bat`, `_run_organism_rt.bat`;
receipt `tests/fixtures/xbar_organism/G-XBAR-ORGANISM-write.log`); architecture in lattice
`papers/CONTRACT-KAIROS-K0-K1.md` §7.4–§7.6 (the EAR/GNA line) + the C2/R3 contracts (the
memory tiers the episode lands in). Companions: 09 / KAIROS-04 (the EAR that hears the
audio), 12 (the curator that indexes the episode), 13 (the replay + O(1) rewind), 14 (the
Ring-3 tier the full audio loop will shortlist into), 10 (the methodology).
