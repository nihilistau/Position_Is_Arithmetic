# 14 — A parameter-free neocortex: VSA/HRR Ring-3 consolidation *(written, citable — X-R3VSA)*

> **STATUS: written — [`paper.md`](paper.md) complete.** Front-door receipts measured
> + gated (ledger **X-R3VSA**).

> **Front-door receipt (measured + gated 2026-06-17, ledger X-R3VSA):** Ring-3 is the
> neocortical gist tier above verbatim Ring-2 — superpose many episodes into one bounded
> store, recall by content address, built from **discrete mathematics (NTT circular
> convolution) with zero training**. It honors the convicted P2.b verdict (generative
> gist-fill is dead; top-5 shortlisting is the door) by being **retrieve-and-verify**:
> Ring-3 shortlists, Ring-2's exact verify carries the fidelity. Four gates, all GREEN,
> all no-budget: `G-R3-BIND` (recall@1=1.0 to N=32 @ D=1024; ±1 carrier ≈ ideal unitary),
> `G-R3-LOSS` (loss is a **step function** — hit +0.000% / miss +8.04% caught by the 2%
> gate), `G-R3-DUALROUTE` (cue→shortlist→verify→land survives a decoy scan),
> `G-R3-NIGHTSHIFT` (idle consolidation: 349.8 MB resident KV → a 16.3 KB Ring-3 index).

## The claim this paper makes

Ring-3 is the crossbar's first *lossy* tier, so the first with an *irreversible* gate.
The §4 trap is the spine: consolidation is consolidation-time only, and recall-time gist
*upsampling* is forbidden (it manufactures confident false history). The store is one
superposition vector `M = Σ (addr ⊛ id)` on the existing NTT/`Z_q` substrate — **no
parameters, no training** — so it tests the whole Ring-3 thesis for the cost of compute,
deferring the operator's budget decision until evidence shows it is needed.

## What's in it (the map)

1. **The §4 trap** — the first lossy tier; recall-time upsampling forbidden.
2. **Retrieve-and-verify** — the P2.b top-5 verdict honored; Ring-3 shortlists, Ring-2
   verifies; the shortlist is pointers, never a generated span.
3. **G-R3-BIND** — superposition recall on real episodes; the ±1 carrier ≈ unitary; the
   metric bug caught (SNR ratio → margin/z-score; math never failed).
4. **G-R3-LOSS** — loss is a step function (hit lossless / miss caught); budget ≤32
   episodes/vector; the directive corrected (pointer, not lossy gist).
5. **G-R3-DUALROUTE + G-R3-NIGHTSHIFT** — the decoy-scan pipe; the idle GC that demotes
   349.8 MB → 16.3 KB; D=128 proves the seal is the math, not a constant.

## Honest scope

Proof-of-mechanism, **one model (12B-b1), one host (RTX 2060)**; the VSA retrieve is
host-numpy (the `Z_q`/NTT engine port is the named deployment follow-on); Path B (the
trained adapter) stays budget-gated and untouched; the provenance tag (`G-R3-PROV`) is
deferred; the deflection numbers carry paper 11's single-chunk caveat.

## Status

**Paper written/complete** ([`paper.md`](paper.md)) — citable via ledger **X-R3VSA**.
Front-door receipts measured + gated in
[shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)
(`tools/ring3/*.py`, `_run_g_r3_loss.bat`; receipts `tests/fixtures/xbar_r3/`);
architecture and pre-registered gates in lattice
`papers/CONTRACT-XBAR-R3-consolidation.md`. Companions: 12 (the Ring-2 verbatim curator
this sits above), 13 (the replay + O(1) rewind the verify scans with), 11 (the
replay-write seam + <2% bound), 10 (the irreversible-gate discipline).
