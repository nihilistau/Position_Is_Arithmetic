---
type: paper-bite
title: "17 — The Frobenius integer episode store, and the boundary of the algebra *(written, citable — X-OK-FROB)*"
description: "The integer container makes a good episode codec — sub-ULP, smaller than f32, auditable —"
tags: [paper-bite, frobenius, frob]
timestamp: 2026-06-17T21:43:50Z
resource: ./papers/17-frobenius-integer-store/README.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# 17 — The Frobenius integer episode store, and the boundary of the algebra *(written, citable — X-OK-FROB)*

> **STATUS: written — [`paper.md`](paper.md) complete.** Front-door receipts measured
> + gated (ledger **X-OK-FROB**).

> **Front-door receipt (measured + gated 2026-06-18, ledger X-OK-FROB):** paper 16 carried
> the Ring-3 *bind* onto the integer `O_K` substrate; this paper carries the Ring-2
> *episode store* onto it — a rank-2 `O_K` lattice codec `x = a·s_a + b·s_b` that
> reconstructs episodic K/V to **sub-ULP at 24 bits** (`a16b8`: relative L2 **1.2e-7**, 18%
> byte-exact, **0.76× store**), with the `T4` Frobenius `π^k` scale-cancellation replaying
> clean. Losslessness is established by **reconstruction fidelity, not a fake `+0.000%`**:
> the `n=42` single-chunk PPL gate is **blind below ~1%** (frob variants jitter
> non-monotonically in fidelity), and the paper refuses to claim a passing grade from a
> blind gate. Then the boundary the algebra draws, in three measured negatives:
> entropy-coding the codes (**1.02×**), Möbius over the superposition (**sheds memories**),
> and the proposed `T2` transform on real model weights (recon cos **0.032 ≈ random
> 0.039**; `T2` was a *design proposal, never validated*, unlike `T4`).

## The claim this paper makes

The integer container makes a good episode codec — sub-ULP, smaller than f32, auditable —
and that is the *last* thing the algebra wins at. **`O_K` wins on exact arithmetic (the
container); it never wins on structuring the high-entropy content.** The codec is the
proof of the first half; the three negatives are the proof of the second. The
methodological spine is the refusal in §3: a blind perplexity gate is reported as blind,
not laundered into a `+0.000%`.

## What's in it (the map)

1. **The container, made into a codec** — the rank-2 `O_K` lattice `a·s_a + b·s_b`, `T4`
   `π^k` scale free.
2. **The fidelity ladder** — `a16` → `a8b4` → **`a16b8` (24b sub-ULP, 0.76×)** → `a16b16`
   (32b, 98.9% byte-exact).
3. **The PPL gate is blind** — `n=42` jitters −2.27%…+3.37% **non-monotonically** ⇒ no
   `+0.000%` claimed; lossless = reconstruction fidelity.
4. **The boundary (three negatives)** — entropy 1.02×; Möbius-on-`M` sheds memories
   (`6/π²` real but recall 1.000→0.969); `T2`-on-weights ≈ random (a falsified proposal).
5. **The boundary thesis** — container vs content, stated plainly.

## Honest scope

Proof-of-mechanism, **one model (12B-b1), one host (RTX 2060)**; losslessness is
reconstruction fidelity, **not** a PPL pass (the `n=42` gate is blind below ~1%); the
negatives are negatives, kept on the record; `T2` was a design proposal that never passed
a gate (only `T4` was validated); the `T2`-weights probe is one tensor of one model.

## Status

**Paper written/complete** ([`paper.md`](paper.md)) — citable via ledger **X-OK-FROB**.
Front-door receipts measured + gated in
[shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)
(`tools/curator/frob_episode.py`, `tools/ring3/{g_r3_mobius_probe,g_t2_weights_probe}.py`;
receipts `tests/fixtures/xbar_r3/`); architecture in lattice
`papers/CONTRACT-XBAR-R3-consolidation.md` + the C2 curator contract. Companions: 03 (the
validated `T4` `π^k` lever this reuses — and the contrast that makes the `T2` falsification
honest), 16 (the integer bind + the Leg-B carrier negative this boundary generalizes), 13
(the replay seam the decoded episode lands through), 11 (the single-chunk caveat that makes
the `n=42` gate blind), 10 (the no-fake-zero discipline).
