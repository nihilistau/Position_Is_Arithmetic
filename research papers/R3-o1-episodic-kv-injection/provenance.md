---
type: paper-provenance
title: R3 provenance — O(1) Episodic Memory by KV-Tensor Replay
description: Genuine-wins assessment, literature positioning, defensibility tier, and honest open items / pre-publication checklist for the R3 O(1) episodic KV-injection paper.
resource: ./paper.md
tags: [provenance, episodic-memory, kv-injection, cross-modal, hamming, gemma4]
timestamp: 2026-06-18T00:00:00Z
sp_status: DRAFT
sp_gate: G-XBAR-ORGANISM-FULL
sp_commit: 15e7051, 6600cf4, d2d7ceb, b4b037a, 24071bc
sp_repro: see paper.md Appendix (engine tests/fixtures/xbar_organism/)
---

# R3 provenance — O(1) Episodic Memory by KV-Tensor Replay

Provenance, literature positioning, and honest status for [the R3 paper](./paper.md)
(*O(1) Episodic Memory by KV-Tensor Replay: bypassing token re-computation in agentic recall*).

## Genuine-wins assessment

**Verdict: REAL.** Instead of storing recalled content as token-ID streams and re-feeding them
(forcing a full prefill re-computation), the system stores the **physical KV tensors** and injects
them directly into the resident cache mid-stream — no token re-computation, no float forward over
the memory. Retrieval is gated by a 256-bit content signature with an **O(1) Hamming check** (a
register-aligned XOR-and-popcount, not a corpus-scaling similarity search). The closed cross-modal
loop is gated on a real 12B: G-XBAR-ORGANISM-FULL — audio → C2 256-bit signature → exact-integer
Ring-3 superposition (with text decoys) → audio-cue top-1 retrieve → C2 Hamming verify (accept
audio / reject text) → Frobenius integer store → injected episode lands clean (checks=5, fails=0).

## Literature positioning

Positioned against **Hippocampus** (arXiv 2602.13594) and the broad class of agentic-memory
systems that store token IDs and re-feed on recall → recompute. The delta is exactly the
recompute that KV-tensor replay deletes. The cross-modal angle is a genuine differentiator: an
audio cue retrieving an audio-conditioned episode *cannot be scored by perplexity* (the cue is
foreign to any text scoring context), so it is evaluated in discrete Hamming space — an exact,
modality-agnostic accept/reject. The undo primitive (O(1) byte-exact rewind, G-222 / G-222-WRAP)
is cited as a dependency, not re-claimed.

## Defensibility tier

**Tier 2.** Real mechanism, gated on a real 12B with a closed cross-modal loop. Held below Tier 1
by scale and by the honest distinction between *well-formed* and *task-improving* (below).

## Honest OPEN items / pre-publication checklist

- [ ] **Small scale: N ≤ 64 episodes.** All quantitative results are proof-of-mechanism at this
      scale on a single dev host; the paper must keep that scope on every figure.
- [ ] **SP_REPLAY is proven WELL-FORMED, not task-IMPROVING.** G-XBAR-ORGANISM-FULL shows the
      recalled episode loads cleanly and injects without corruption (checks=5, fails=0); it does
      **not** show a downstream task improving. The foreign-episode PPL deflection is, by design, the
      *reject* signal — not a quality regression to be hidden. The "O(1)" claim is specifically about
      the inject / verify step, not an end-task win. This distinction must stay explicit.
- [ ] A downstream task that the injection measurably improves would lift this toward Tier 1
      (currently future work).
- [ ] Author list / affiliation (`[Shannon-Prime — author list TBD]`).
- [ ] Prior-art sweep on KV-cache reuse / prefix-cache / state-injection memory systems.

## Anchors

- Primary gate: **G-XBAR-ORGANISM-FULL** (engine `15e7051`).
- Supporting: organism write/signature (`6600cf4`), period-6 rebase (`d2d7ceb`), replay/rewind
  undo primitives G-222 / G-222-WRAP (`b4b037a` / `24071bc`).
- Receipts: engine `tests/fixtures/xbar_organism/` (incl. `G-XBAR-ORGANISM-write.log`),
  `tests/fixtures/xbar_c2/G-222-REWIND-NULL.log`, `.../G-222-WRAP.log`.
- Sibling: [paper.md](./paper.md).
