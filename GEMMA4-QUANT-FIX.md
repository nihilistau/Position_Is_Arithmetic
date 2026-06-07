# The Gemma-4 GGUF quantizations are broken — how to verify it yourself, and how to fix it

*Companion note to the Shannon-Prime release series (papers 04/05/06).
Receipts: [LEDGER.md](LEDGER.md) rows 06-R8/R9/R10; instruments in
[shannon-prime-lattice `tests/gemma4_gold/`](https://github.com/nihilistau/shannon-prime-lattice/tree/main/tests/gemma4_gold).
Everything below is reproducible on one consumer GPU-class machine in under an hour.*

## TL;DR

- Gemma-4-12B-it's TRUE full-precision wikitext perplexity is **≈ 4.68**
  (chunk-0, 512-ctx, teacher-forced — measured by a from-scratch forward
  written directly off the official safetensors + config, no llama.cpp, no
  transformers).
- Every GGUF we could measure in early June 2026 scores **192–506** on the
  identical fixture: the pre-fix wave at 271–364, and — the important part —
  the **post-June-5 "rebuilt" QAT UD-Q4_K_XL still scores 192.9**. The
  llama.cpp PR #24118 conversion fix repaired projector configs, not the
  text-tower weights.
- llama.cpp's *forward pass* is fine: run our reference arithmetic over the
  GGUF's own dequantized tensors and you get the same broken numbers llama.cpp
  gets. Two independent engines agree per-artifact. **The artifacts are
  broken, not the engine.**
- The damage is in-place (no tensor permutation; the blk↔layer mapping is
  exact), heterogeneous with a period-6 layer signature, and the per-layer
  `layer_output_scale` class is independently defective (restoring just those
  scalars from the checkpoint recovers 364 → 97).
- The fix that works today: **quantize from the official safetensors
  yourself** and verify the result against a reference forward. Recipe and
  verification ladder below. On our stack the result is a 4-bit-class 12B
  artifact at **PPL 5.12, decoding at 26.1 tok/s on an RTX 2060 12GB**.

## Part 1 — verify the breakage yourself (≈30 minutes)

You need: the official `google/gemma-4-12b-it` safetensors checkpoint
(~22 GB bf16), any gemma-4-12B GGUF you want to test, python + numpy + torch
(CPU is fine), and a token fixture (dump token IDs once with llama.cpp's
`--verbose-prompt`, or use ours — it is verified identical to HF
`tokenizer.json`, 5431/5431).

**Step 1. Establish gold.** Run a teacher-forced forward of the
full-precision checkpoint over one 512-token wikitext chunk and score
positions [256,512). Our instrument is
`tests/gemma4_gold/_t2_manual_forward.py` (~130 lines, streaming-friendly).
The architectural facts you need if you write your own — all verified by the
4.68 result:

- RMSNorm weights are PLAIN multipliers (`x̂·w`), NOT gemma-classic `(1+w)`.
- Global-attention layers (every 6th, at L≡5 mod 6) have NO v_proj:
  **V is the raw K projection** (pre-k_norm), weightless-RMS-normed, never
  roped.
- Partial rotary 0.25 on globals (θ=1e6; in GGUF terms: the `rope_freqs[256]`
  factor table = 64×1.0 then 192×1e30); SWA layers rotate fully at θ=1e4.
- Attention scale 1.0; GeGLU (tanh); sandwich norms; per-layer `layer_scalar`
  multiplier after the FFN residual; embed ×√3840; tied head; final-logit
  softcap tanh(z/30)·30.

Expected: **PPL ≈ 4.68**, with scored targets sitting at or near the max
logit (NLL ≈ 0.001 at confident positions). If you see hundreds, your forward
is wrong — fix it before judging anyone's artifact.

**Step 2. Grade the GGUF with YOUR forward, not llama.cpp's.** Dequantize the
GGUF's tensors (Q4_0/Q4_K/Q6_K decoders are ~40 lines each in numpy; ours are
in `_t2c_gold_on_gguf.py`) and run the *same* forward over them. This is the
decisive control: it removes the inference engine as a variable entirely.

Expected on current artifacts: **192–364**. Same arithmetic, same fixture,
same protocol — only the weight bytes changed. The artifact is the defect.

**Step 3 (optional). Localize the damage.** Two cheap forensics:

- *Tensor-class swap*: rerun Step 2 but take ONE class of tensors from the
  safetensors instead (e.g. the per-layer `layer_output_scale` scalars).
  Restoring just the scalars took our QAT-GGUF run from 364 → 97 — that class
  is independently defective. Restoring norms or embed made things *worse*
  (they are retrained-coherent with the GGUF's weights — swapping them in
  breaks the package), which tells you the matmul weights themselves are also
  damaged.
- *Per-layer cosine*: cosine of each GGUF matmul tensor against its
  safetensors counterpart, per layer. We measured a clean period-6 signature:
  layers ≡ 0,1 (mod 6) at cos 0.93–0.97, the other four at 0.24–0.70 — with a
  perfect blk↔layer diagonal (no permutation; cross-layer cosines ≈ 0).

## Part 2 — the fix (quantize from the checkpoint, verify against gold)

Until the upstream conversion is actually repaired AND re-verified at the
weight level, do not consume gemma-4 GGUF weight bytes. The working pipeline:

**1. Source of truth = the official safetensors.** Read weight VALUES only
from the checkpoint. (Metadata, tokenizer tables and the rope_freqs table in
existing GGUFs verified clean for us — values did not.)

**2. Know that gemma-4 is PTQ-hostile before you pick a recipe.** Simulate
the quantizer in the reference forward first — minutes per recipe, no kernels
needed. Our measured ladder (12B, vs gold 4.6776):

| recipe | PPL | Δ |
|---|---|---|
| all tensors, symmetric per-32 int4 | 6.79 | +45% |
| + int8 for down-proj/embed | 6.29 | +34% |
| asymmetric per-32 (scale+min) | 5.86 | +25% |
| **int4 per-32 on FFN gate/up ONLY, int8 everything else** | **5.13** | **+9.6%** |
| asymmetric gate/up, int8 rest | 5.01 | +7.0% |

The lesson generalizes: blanket 4-bit on this model is mathematically
bankrupt; keep attention + down-proj + embed at 8-bit and spend your 4-bit
budget on the FFN gate/up pair (the two biggest, least-sensitive tensors).
This is also why Google ships QAT — and why a QAT GGUF *would* be the ideal
artifact if the conversion pipeline were trustworthy.

**3. Quantize with the store-then-derive discipline.** Round the block scale
through its storage type (f16) FIRST, then quantize codes against the stored
scale. Skipping this injects a systematic half-ULP bias across hundreds of
millions of blocks.

**4. Verify the artifact the same way you convicted the broken ones.** Run
the reference forward over your artifact's dequantized tensors and demand the
simulated number back. Ours matched to four decimal places (5.1259 simulated,
5.1259 measured), and the GPU kernel then landed at 5.1160. If the simulator,
the artifact and the device disagree, one of your three implementations is
lying — find it before shipping.

## Part 3 — what we got out the other end

On the sovereign pipeline (safetensors → our transcoder → per-32-block-scaled
int4/int8 mixed artifact → dp4a CUDA kernels): **Gemma-4-12B at 26.1 tok/s
and wikitext PPL 5.12 on an RTX 2060 12GB**, with the decode path verified
256/256 top-1 against a CPU oracle and the graph path bit-exact. For
comparison llama.cpp decodes 31.29 tok/s on the same card — at PPL 192–506,
because of the artifacts above. Engine-for-engine, ours moves 18% more bytes
per second; our artifact is heavier only because it is the one that is
mathematically intact.

## Appendix — instrument index

All in [shannon-prime-lattice](https://github.com/nihilistau/shannon-prime-lattice)
`tests/gemma4_gold/` (MIT):

| file | what it does |
|---|---|
| `_t2_manual_forward.py` | the gold instrument: bf16 safetensors → PPL 4.6776 |
| `_t2c_gold_on_gguf.py` | same arithmetic over GGUF-dequantized tensors (+ tensor-class swap flags) |
| `_t2b_gguf_forensics.py` | GGUF↔safetensors metadata + tensor diffs |
| `_t2g_perm_hunt.py` | per-layer cross-cosine (permutation hunt) |
| `_t2i.._t2o_*_sim.py` | the six quantization-recipe simulators |
| `_t2h_spmodel_gate.py` / `_t2p_b1_gate.py` | artifact gates for our container |
| `_t2_gold.log`, `_t2m_rebuilt.log`, `_shootout2.log`, … | receipts for every number above |
