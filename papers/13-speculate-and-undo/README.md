# 13 — Speculate and Undo: O(1) bit-exact rewind of latent memory *(written, citable — X-222)*

> **STATUS: written — [`paper.md`](paper.md) complete.** Front-door receipts measured
> + gated (ledger **X-222**).

> **Front-door receipt (measured + gated 2026-06-17, ledger X-222):** the curator must
> be free to *guess* — speculate a recalled memory into the resident cache, check it,
> and on a bad guess make it as if it never happened. A new replay seam
> (`gemma4_kv_replay`) injects a stored episode's owner-K/V into the **resident** cache;
> on reject, `gemma4_kv_rewind` undoes it **O(1) byte-exact**. `G-222` GREEN on the 12B
> (48 owners) + E2B (15 owners / 20 sharers): replay-inject is **load-bearing** (zeroed
> episode reads back all-zero — 0/688128 12B bytes nonzero) and the rewind resets the
> pre-injection prefix **byte-identical (layer-diffs=0)**. `G-222-WRAP` GREEN: a
> journal-backed rewind across a forced sliding-window wrap is again diffs=0. RTX 2060.

## The claim this paper makes

A memory system that can't speculate can't recall — and speculation is only safe if the
undo is *perfect* and *cheap*. This paper fuses KAIROS's O(1) byte-exact rewind (paper 09)
with the replay-write seam (paper 11) so the curator's *speculate → gate → undo* is a
single resident transaction: a rejected recall costs O(1) and leaves **no trace**. The
§4-trap guarantee — a rejected recall cannot corrupt the model — made mechanical.

## What's in it (the map)

1. **Why a curator must undo** — a recall is a guess; lossy or expensive undo kills it.
2. **The seam** — `gemma4_kv_replay` as the persistent twin of the one-shot replay;
   `gemma4_decode_cuda` left byte-untouched (the null floor).
3. **G-222** — load-bearing (zeroed injects all-zero) + byte-exact undo (layer-diffs=0)
   on both artifacts; the scope correction (the kv-side scorer is a deferrable optimization).
4. **G-222-WRAP** — the SWA-ring hazard (replay aliases live slots), the KAI-1c
   undo-journal fix, byte-identical across a forced wrap.

## Honest scope

Proof-of-mechanism, **12B-b1 + E2B, one host (RTX 2060)**; the O(1) is in the byte-count
(proven by byte comparison) — the wall-clock latency slope is the KAIROS-02/03 telemetry,
measured separately with its own clock-jitter caveat; the persistent-ABI scorer port and
the compact-slab global rewind are named follow-ons.

## Status

**Paper written/complete** ([`paper.md`](paper.md)) — citable via ledger **X-222**.
Front-door receipts measured + gated in
[shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)
(`gemma4_kv_replay`/`gemma4_kv_rewind` in `src/backends/cuda/cuda_forward.cu`,
`_run_g222.bat`, `_run_g222_wrap.bat`; receipts `tests/fixtures/xbar_c2/G-222*.log`);
architecture in lattice `papers/CONTRACT-XBAR-C2-memo-curator-loop.md` §7 + the KAIROS
contract §5.5–5.7. Companions: 09 (the rewind primitive), 11 (the one-shot replay seam),
12 (the curator this makes degrade-safe), 14 (the dual-route that scans by rejecting+rewinding).
