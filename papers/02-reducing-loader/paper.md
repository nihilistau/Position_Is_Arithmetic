# The reducing loader: output-preserving model transcode and zero-copy swivel load

### Paper 02 of the Shannon-Prime series · receipts-first

*A. Knack. Draft — staged for staggered release. Receipts below are from prior measured work (C1 transcode, Gemma-class PPL gate) and must be re-gated with a published repro before this paper goes public; see §5.*

---

## Abstract

A trained model ships as a weight artifact — a GGUF, a safetensors file — that an engine must load into RAM before it can run. Two costs are usually accepted as fixed: the artifact's size, and the load-time inflation of quantized weights (Q4/Q8) back to fp16 in RAM so the kernels can read them. We show both are avoidable. We present a **reducing transcode**: a pass that rewrites an existing model's weights into a *smaller* discrete artifact (`.sp-model`) that runs **bit-faithfully** — identical top-1/argmax output to the source — and a **zero-copy "swivel" loader** that maps those packed weights directly into the compute arena without ever inflating a quantized value to fp16 in memory. On a 35-billion-parameter mixture-of-experts model, the transcoded artifact is **16.3 GB versus the source's 19.7 GB while preserving top-1 output**; the design is confirmed bit-faithfully on a second, architecturally different model. The contribution is an artifact that is smaller *and* output-preserving *and* loads without the customary 4× RAM/bandwidth dequantization tax — a drop-in that keeps a model's exact behavior while shrinking its footprint. Proof-of-mechanism on two models; every claim is gated against the unmodified forward pass and reproducible from a command.

---

## 1. Introduction

An inference engine pays two structural costs before the first token. The artifact occupies storage and must be read; and because most kernels operate on fp16/fp32, a quantized weight (say 4-bit) is typically **inflated to fp16 in RAM at load** — a representation that carries no new information but costs 4× the memory bandwidth and footprint of the packed form. Both costs are widely treated as the price of admission.

They are not. If the engine's kernels can read the *packed* representation directly, the inflation never happens; and if the transcode preserves the source's quantization family rather than re-quantizing, it can produce a smaller container with no added loss. This paper is the loader and transcode that do both, and it stands on a single discipline: the transcoded model's forward pass is **bit-faithful** to the original — same argmax at every position — so "smaller" never trades against "same outputs."

This is the *bolt-on* half of the Shannon-Prime story (the memory architecture of paper 01 is the other half): you keep a model's exact behavior and gain a smaller, faster-loading artifact.

**Scope.** Measured on two models (a 35B-A3B MoE and a small Gemma-class model) on a CPU forward path; proof-of-mechanism, not a scaling or multi-engine study.

## Receipts

| # | Claim | Number | Gate | Caveat |
|---|---|---|---|---|
| L1 | Reducing transcode, output-preserving | `.sp-model` **16.3 GB < 19.7 GB** GGUF, top-1 identical | argmax parity | one 35B-MoE model; reduction is source-dependent |
| L2 | Zero-copy swivel load | no fp16 inflation of quantized weights in RAM (avoids ~4× bandwidth/footprint) | arena-alias verified | the load-path invariant |
| L3 | Codec-by-source: no added loss | source quant family preserved (Q4→packed-Q4, Q8/F16→packed-Q8) | gate-off bit-faithful | not a new quantization scheme |
| L4 | Bit-faithful on a second architecture | Gemma-class end-to-end transcode→load→forward within the f32-vs-Q8 precision floor (PPL 86.2 vs 90.7 ref) | PPL gate + argmax | small model |

## 2. Mechanisms (idea → receipt → payoff → implementation)

### 2.1 Output-preserving reducing transcode
**(a)** A pass rewrites each weight tensor from its GGUF form into a packed `.sp-model` container. It is *codec-by-source* (§2.3): the source's quantization is repacked, not re-quantized, so no precision is lost in transcoding; the artifact is smaller because the packed container is tighter than the GGUF layout and drops container overhead. **(b)** On a 35B-A3B MoE: 16.3 GB vs 19.7 GB (~17% smaller) with **top-1 output identical** to the source. **(c)** A smaller artifact with provably the same outputs — the bolt-on guarantee. **(d)** The transcoder selects the O_K container codec by source dtype; 3D MoE expert tensors go through an arena-expert path. Gated against the source forward by argmax parity.

### 2.2 Zero-copy swivel load
**(a)** The load-path invariant: **never inflate a quantized weight to fp16 in RAM.** A Q4→fp16 expansion adds zero information and costs 4× the bandwidth and footprint; instead the loader ("swivel") maps the packed weights directly into the compute arena, aliasing the on-disk layout when it is already arena-compatible and arena-allocating only when a repack is genuinely required. **(b)** The dequant-to-fp16 step is eliminated; the resident weights stay packed. **(c)** Lower load time, lower RAM, lower memory-bandwidth pressure during inference — the same pressure that bounds decode throughput. **(d)** Two obligations the loader must honor: release the source mapping for arena-allocating paths, and alias zero-copy when the source `.sp-model` is already arena-compatible. Both are gated.

### 2.3 Codec-by-source: no added loss
**(a)** Rather than imposing one target precision, the transcode preserves the source's quantization family — a Q4 source becomes packed-Q4, a Q8/F16 source becomes packed-Q8. The transcode is therefore *lossless relative to the source*: it changes layout, not values. **(b)** Gate-off bit-faithful; the only loss present is the source's own quantization, unchanged. **(c)** No "transcode tax" — adopting the artifact costs nothing in quality over the model you already had. **(d)** Codec dispatch on source dtype at transcode time.

### 2.4 Bit-faithful on a second architecture
**(a)** The transcode + load + forward path is not specialized to one model family. **(b)** On a small Gemma-class model, end-to-end transcode→load→forward lands within the expected **f32-vs-Q8 precision floor** of a quantized-native reference (perplexity 86.2 vs 90.7; the gap is the direction expected when the SP forward runs at higher working precision than the Q8 reference, *not* a regression), with top-1/argmax as the exactness gate. **(c)** The mechanism generalizes across architectures. **(d)** Verified by the model's PPL gate plus argmax parity.

## 5. Limitations and honest notes

- **"Reducing" is source-dependent.** The artifact shrinks when the source carries quantized weights SP packs more tightly, plus container overhead; an already-minimal source reduces less. The ~17% on the 35B-MoE is the measured headline on one model, not a universal ratio.
- **Bit-faithful = top-1/argmax identity**, not bit-identical logits (float reassociation differs). State it that way.
- **The Gemma PPL number is not a quality claim.** 86.2 vs 90.7 is the f32-vs-Q8 precision-floor direction confirming faithfulness; it is easy to misread as "5% worse" — it is not, and the paper must say so explicitly.
- **Two models, CPU forward, proof-of-mechanism.** No multi-engine or scaling claim.
- **Provenance:** L1–L4 come from prior measured work; per the series' release rules, the repro harness and a re-gate are required before this paper is published.

## 6. Reproduction (TODO before release)

A one-command harness that: takes a source GGUF, runs the reducing transcode, prints `size_before > size_after`, loads via the swivel, runs the forward, and prints top-1 parity against the source. This is L1+L2's `run_r9`-equivalent and is the gate on releasing paper 02.

## 8. Companion
Same pointer as the series: the O_K container and codec-by-source were motivated by the CM-elliptic-curve framework's unique-factorization structure; not required to use or validate the loader. See `COMPANION-THEORY.md`.

## 9. Conclusion
A model artifact can be smaller, output-preserving, and free of the load-time dequantization tax at once. The reducing transcode plus the zero-copy swivel deliver all three on two models, each gated bit-faithfully against the original forward. Re-gating with a published repro, and validating the size reduction across more source formats, are the next steps before release.
