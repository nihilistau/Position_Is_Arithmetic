---
type: paper-provenance
title: R1 provenance — Reduction-Order-Immune Inference
description: Genuine-wins assessment, literature positioning, defensibility tier, and honest open items / pre-publication checklist for the R1 exact-integer deterministic Gemma-4-12B forward-pass paper.
resource: ./paper.md
tags: [provenance, determinism, exact-integer, byte-exact, gemma4, inference]
timestamp: 2026-06-18T00:00:00Z
sp_status: DRAFT
sp_gate: G-BYTEEXACT-FORWARD-12B
sp_commit: 69c0588, d9d96f3
sp_repro: ninja -C build-cuda test_gemma4_ppl_cuda && SP_BYTEEXACT=1 ... (see paper.md Appendix)
---

# R1 provenance — Reduction-Order-Immune Inference

Provenance, literature positioning, and honest status for [the R1 paper](./paper.md)
(*Reduction-Order-Immune Inference: an exact-integer, deterministic Gemma-4-12B forward pass*).

## Genuine-wins assessment

**Verdict: GENUINE WIN, timely.** The contribution is real and well-scoped: the full
Gemma-4-12B forward pass is made exact-integer end-to-end (the four nonlinear fp32 islands —
RMSNorm / softmax / GELU-tanh / RoPE — plus attention's Q·K and p·V dots), so its output is
**reduction-order-immune by construction** rather than order-pinned. The proof is gated:
G-BYTEEXACT-FORWARD-12B reports flag **off** → PPL 4.6665 byte-identical to baseline (the null
floor), flag **on** → 4.6569 parity, run-to-run bit-identical. The daemon drives the real 12B
end-to-end over the L1 ABI (G-WIRE-CUDA-GEMMA4 prefill; G-WIRE-CUDA-DECODE-GEMMA4 32/32 == oracle).

## Literature positioning

Positioned against **Thinking Machines, "Defeating Nondeterminism in LLM Inference"**
(He et al., 2025; SGLang / vLLM batch-invariant kernels). The distinction is the load-bearing
claim of the paper and it is honest:

- **Their guarantee** is order-**PINNED float** determinism — batch-invariant kernels pin one
  reduction order so a given engine reproduces *itself* on the *same* hardware. It is, by
  construction, engine- and hardware-local.
- **Our guarantee** is order-**IMMUNE integer** determinism — every reduction is an exact integer
  sum and every transcendental a deterministic `libm`-free integer function, so *any* reordering
  is bit-identical. This aims at **cross-hardware** reproducibility, which order-pinning cannot
  reach.

The two are complementary, not competing; the paper says so.

## Defensibility tier

**Tier 2 (strong positive).** A real, gated, reproducible systems result on a real 12B model
with a clean conceptual delta against the strongest current work. Not Tier 1 only because the
headline external claim (cross-hardware bit-identity) is not yet directly demonstrated — see open
items.

## Honest OPEN items / pre-publication checklist

- [ ] **The cross-hardware claim needs a true 2-physical-GPU bit-identical logit check.** On-machine
      we currently have run-to-run determinism + reduction-order immunity as the *proxy*; the actual
      "two different physical GPUs produce bit-identical logits" demonstration is EXTERNAL and
      remains open (needs a second machine). This is the single most important pre-pub item.
- [ ] **Per-token speed cost is UNMEASURED.** He et al. report their batch-invariant float path is
      ~60% slower; our exact-integer path's per-token cost vs the float baseline is TBD. The paper
      should not ship without this number (or an explicit statement that it is unmeasured + scoped).
- [ ] **PPL parity measured at n=42 (small-N).** The −0.21% on→off deflection is within noise at
      this N; a larger-N PPL run would firm the parity claim.
- [ ] Author list / affiliation (`[Shannon-Prime — author list TBD]`).
- [ ] Exhaustive prior-art pass on deterministic / integer-only inference beyond He et al.

## Anchors

- Primary gate: **G-BYTEEXACT-FORWARD-12B** (engine `69c0588`, math-core submodule `d9d96f3`).
- Supporting: G-BYTEEXACT-ISLANDS-CUDA, G-ISLANDS-Q-REF, G-WIRE-CUDA-GEMMA4, G-WIRE-CUDA-DECODE-GEMMA4.
- Receipts: `tests/fixtures/xbar_r3/G-BYTEEXACT-*.log`, `.../G-WIRE-CUDA-*.log`.
- Sibling: [paper.md](./paper.md).
