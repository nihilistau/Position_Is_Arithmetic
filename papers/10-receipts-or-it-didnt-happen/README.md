# 10 — Receipts or it didn't happen: bit-exact-or-bounded as the contribution *(written / complete)*

> **STATUS: written / complete** — full paper at [`paper.md`](paper.md). This
> paper's "receipts" are the series' own gates and four documented self-
> corrections, all already in [`LEDGER.md`](../../LEDGER.md) and
> [`METHODOLOGY.md`](../../METHODOLOGY.md); no new engine run is required.

> **Front-door claim:** the methodology is the moat. Every result in this series
> is held to one of two standards — it is either **bit-exact** (byte-for-byte
> identical to the untouched baseline) or it passes a **pre-registered
> bounded-degradation gate** (a threshold written down *before* the code, never
> tuned after). The proof that the discipline works is that it has *caught its
> authors* four separate times, in the open.

## The claim this paper makes

The numbers in papers 01–09 are only as good as the discipline that produced
them. That discipline — bit-exact-when-off, no number without a command, scope
travels with the number, gates pre-registered and never silently revised, honest
negatives published — is as much the contribution as any single mechanism. A
claim in this project comes with the command that produced it and the scope it
is valid in. That is what "auditable" means here, and it is the one property a
floating-point, text-bus agent stack cannot offer.

## What's in it (the map)

1. **The two standards** — *bit-exact* (the null floor: the production decode
   path is never touched, so every "on" result is a controlled delta against a
   byte-identical baseline) and *pre-registered bounded gate* (when a stage
   crosses from exact to lossy, bit-exactness dies by definition, so you write
   the degradation threshold down before the code — e.g. PPL < 2% — and never
   move it to pass a number).
2. **Negative controls and poison** — retention is proven by *destroying* the
   live source (NaN-poison) and by showing a *worse router misses*, not by a
   bare equality that leakage could fake. The poison gate and the frozen-router
   control are why the NIAH HITs (papers 08, 09) mean what they say.
3. **The four self-corrections** (the actual evidence the gates discriminate):
   - **A faster-but-wrong headline, retired by its own rule.** The 34.2 tok/s
     12B number (06-R6) was withdrawn when its artifact failed the series' PPL
     gate; 26.1 tok/s at PPL 5.12 (06-R10) is the honest point.
   - **A public MISS kept on the front page.** The composed 32k needle
     retrieval MISSed at the 64× selection budget (01-R9) — it stays on the
     landing page, not buried.
   - **A small-N "improvement" caught as a noise illusion.** An 8× router
     deflection read −3.21% over ~42 scored positions; on the full corpus
     (~3072 positions) it was +4.17%. Count scored positions before any
     deflection verdict.
   - **Measure the oracle ceiling before training.** A mass-captured proxy said
     "concede 4×"; the on-engine oracle PPL (−0.08%) said "8× is learnable" —
     and the learned router then hit +0.47% (paper 08). The proxy would have
     wrongly conceded the compression ratio.
4. **Measurement hygiene as a standing rule** — GPU core clocks pinned for
   timing; and when the RTX 2060 turned out unable to pin its *memory* clock
   (`nvidia-smi`: "not supported"), the rule became *never difference two
   sequential wall-clock series for sub-10% deltas on this card* — use
   within-config slopes or CUDA-event timing. The project catching the limits
   of its own instrument and writing them down rather than reporting a number it
   can't defend.
5. **Why this is the moat** — a verifiable, gated substrate is a property
   floating-point, text-bus stacks structurally cannot offer; the discipline is
   what lets the whole tower of results (space ⊗ time ⊗ cognition) stay standing
   as each layer is added.

## Module

[`paper.md`](paper.md) — the full paper. No new engine receipts: this paper's
evidence is the existing ledger rows and the four documented self-corrections,
each cited with both the wrong call and its correction so a reader can verify the
discipline actually operated —

- **34.2 retired by its own PPL rule** — 06-R6 (gate-pending) → 06-R10 (citable).
- **32k MISS kept public** — 01-R9 (measured MISS, not a claim).
- **Small-N deflection illusion** — −3.21% @ ~42-pos → +4.17% @ ~3072-pos (X-R2 /
  `CONTRACT-XBAR-P3-ring-on-exec.md`).
- **Oracle ceiling flips "concede 4×" → "train 8×"** — proxy 92.3% mass vs oracle
  PPL −0.08%, then learned router +0.47% (X-R2 / the §3q oracle record).

Ground truth: [`METHODOLOGY.md`](../../METHODOLOGY.md) (the gate vocabulary this
paper promotes to a capstone), [`LEDGER.md`](../../LEDGER.md) (every number,
every caveat), and lattice `CURRENT-STATE-OF-PROJECT.md` §6 ("why the results can
be trusted"). Companions: every other paper in the series — this one is the
discipline they all cite.
