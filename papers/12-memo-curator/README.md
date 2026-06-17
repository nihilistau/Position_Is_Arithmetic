# 12 — The Memo Curator: autonomous discrete recall above the crossbar *(written, citable — X-C2)*

> **STATUS: written — [`paper.md`](paper.md) complete.** Front-door receipts measured
> + gated (ledger **X-C2**).

> **Front-door receipt (measured + gated 2026-06-17, ledger X-C2):** the latent
> crossbar could read, write, compress to O(1), and replay — but only when a human set
> the knobs. The Memo curator is the **policy that drives it on its own**: a resident
> loop that decides *when* to search memory, *which* episode to pull, and gates whether
> the recall sticks. It **indexes** (an append-only registry), **addresses** (a 256-bit
> LSH hash), **selects** (an integer Hamming gate, reduction-order-immune), is **inert
> when off** (`G-MEMO-NULL`: PPL 4.6665 bit-identical), and **on metal promotes the
> matched recall while discarding the corrupted one** (`G-MEMO-LOOP`: ACCEPT matched
> +0.000% deflection / REJECT corrupted +40106% → safety valve). 12B-b1 + E2B, RTX 2060.

## The claim this paper makes

The XBAR substrate is inert until a policy fires it. The Memo curator is that policy,
made autonomous — `propose → gate → promote-or-rewind` on the KAIROS heartbeat. The
load-bearing course-correction is from a float-cosine threshold to a **discrete
bit-collision resolver**: a 256-bit LSH hash matched by XOR + popcount under an integer
Hamming radius, so the address is reduction-order-immune and hardware-independent. A
drift-check's "the dot product *is* a Hamming distance" reframe was verified **false as
built** (real centroids ≠ sign bits) and turned into a real, costed win by an r-sweep
(sign-binarize collapses at r=32, recovers at r≥128, ship r=256).

## What's in it (the map)

1. **The substrate was inert** — why every prior result needed a human to set the knobs.
2. **Index, cue, resolver** — the registry, the cue (router applied to the index), the
   one-dot resolver; the address lives in the projection space the router already ranks in.
3. **Float → bit-collision** — the verified-false Hamming reframe, the r-sweep, the
   r=256 integer-Hamming gate, and why discrete is the right (not cosmetic) call.
4. **The loop** — propose→gate→promote/rewind; why SELECT transfers offline→online for
   free (order-immunity).
5. **Gates** — `G-MEMO-NULL` (inert when off, bit-identical) + `G-MEMO-LOOP` (ACCEPT
   +0.000% / REJECT +40106% safety valve), plus the three Shannon-Prime corrections to
   the directive.

## Honest scope

Proof-of-mechanism, **one model (12B-b1) + E2B, one host (RTX 2060)**; the registry is two
real episodes vs synthetic noise (a large-registry stress run is a named lever); the
deflection numbers carry paper 11's single-chunk caveat; Ring-3 gist, a learned cue, and
dual-candidate recall are out of scope (this is Ring-2 *verbatim* recall only).

## Status

**Paper written/complete** ([`paper.md`](paper.md)) — citable via ledger **X-C2**.
Front-door receipts measured + gated in
[shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)
(`tools/curator/*.py`, `_run_memo_null.bat`, `_run_memo_loop.bat`; receipts
`tests/fixtures/xbar_c2/`); architecture in lattice
`papers/CONTRACT-XBAR-C2-memo-curator-loop.md`. Companions: 07 (the crossbar it drives),
08 (the O(1) cache it recalls into), 11 (the replay-write seam it gates), 13 (the O(1)
rewind that makes discard degrade-safe), 14 (the gist tier above this verbatim loop).
