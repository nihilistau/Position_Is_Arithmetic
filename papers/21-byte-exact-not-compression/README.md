---
type: paper-bite
title: "21 — Byte-exact, not compression: the boundary thesis, the honest negatives, and a re-derivation kept on the record *(written, citable — X-BX-BOUNDARY)*"
description: "The de-conflation is the contribution: byte-exact (papers 19–20) is an auditability result,"
tags: [paper-bite, byte-exact, compression]
timestamp: 2026-06-18T05:41:21Z
resource: ./papers/21-byte-exact-not-compression/README.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# 21 — Byte-exact, not compression: the boundary thesis, the honest negatives, and a re-derivation kept on the record *(written, citable — X-BX-BOUNDARY)*

> **STATUS: written — [`paper.md`](paper.md) complete.** The reflective / honest-record paper
> of the byte-exact set (ledger **X-BX-BOUNDARY**). No new performance number — the forward's
> measured results are papers 19–20.

> **Front-door (the reflective record, 2026-06-18, ledger X-BX-BOUNDARY):** papers 19–20 made a
> 12B forward exact-integer; this paper says, at equal length, what that did **not** do.
> **Byte-exact buys auditability — exact arithmetic, reduction-order immunity, cross-machine
> determinism — not speed, not size.** The adjacent compression levers were *convicted*:
> incoherence rotation **`~1.37×`** @ int4 and column reorder **`~1.05×`** are both **redundant
> vs the per-32-block `OK_Q4B`** (already gold PPL). The **boundary thesis** holds on the
> forward as on the memory tier: `O_K` is the exact-arithmetic **container**, never a way to
> structure *content* — four inert content-side attempts (split-prime Dirichlet carriers,
> Möbius-on-`M`, entropy-on-Frobenius-codes, `T2` on the real 12B embedding, recon cos **0.032 ≈
> random**). And our own honest negative: the byte-exact **linear algebra was already in the
> bounded crate, bit-exact-gated** — re-deriving it offline was the campaign's one wasted motion.

## The claim this paper makes

The de-conflation is the contribution: byte-exact (papers 19–20) is an **auditability** result,
not a compression or speed result, and the paper proves that by convicting the compression levers
that look adjacent and by mapping the boundary beyond which the algebra is measured-inert. "Use
the algebra for the arithmetic, never for the meaning." The re-derivation of the already-bounded
linear algebra is kept on the record as the campaign's one wasted motion — the same discipline
that kept the 32k MISS on the front page and retired the first speed headline.

## What's in it (the map)

1. **The de-conflation** — compression vs byte-exactness, two missions, this set is only the
   second.
2. **The compression levers were convicted** — `~1.37×` / `~1.05×`, redundant vs `OK_Q4B`.
3. **The boundary thesis, now on the forward** — the four inert content-side levers (`T2` ≈
   random on real weights, &c.).
4. **The re-derivation** — the byte-exact linear algebra already lived in the crate,
   bit-exact-gated; the offline re-derivation was the wasted motion.
5. **What discreteness does and does not buy** — the ledger of it (yes: order-immunity,
   determinism, auditability; no: size, speed, content-structure).

## Honest scope

**No new performance number** — this is the honest-record paper; the measured forward is papers
19–20. The negatives are negatives, kept attached (`T2` was a design proposal that never passed a
gate). The compression conviction is scoped to *this artifact* (`OK_Q4B` already at gold PPL; the
3-bit-unlock axis — QAT/codebook/mixed-precision — is out of scope). One model (12B-b1), one host
(RTX 2060). The cross-machine determinism the thesis is *about* has its two-physical-GPU check
still open (papers 19–20).

## Status

**Paper written/complete** ([`paper.md`](paper.md)) — citable via ledger **X-BX-BOUNDARY**.
Receipts measured + gated in
[shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)
(`G-WEIGHT-{TRANSFORMS,FOLD-ORACLE}` for the convicted compression levers; the four content-side
negatives are papers 16–17's `G-R3-BIND-on-OK-legB` / `G-R3-MOBIUS` / `G-R2-FROB-ENTROPY` /
`G-T2-WEIGHTS`); the byte-exact forward it reflects on is engine `69c0588` / submodule `d9d96f3`;
architecture in lattice `papers/CONTRACT-BYTEEXACT-forward.md` §0–§1. Companions: 19 + 20 (the
measured byte-exact forward this de-conflates and bounds), 06 (the `OK_Q4B` artifact that makes
the compression levers redundant), 16 + 17 (the content-side negatives this generalizes), 03 (the
validated `T4` lever that makes the `T2` falsification honest), 10 (the receipts discipline this
paper instantiates).
