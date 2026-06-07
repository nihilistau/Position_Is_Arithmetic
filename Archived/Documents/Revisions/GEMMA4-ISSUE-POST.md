# Ready-to-post: Gemma-4 GGUF breakage report

*Two variants below: (A) for the Unsloth repo / HF discussion, (B) a shorter
one for the llama.cpp issue (e.g. as a comment on #22407 "Extreme Perplexity
Values with Gemma 4" or a new issue). Post as-is or trim; every claim links
to a public receipt.*

---

## Variant A — Unsloth issue / HF discussion

**Title: Rebuilt (post-June-5) Gemma-4 GGUFs still carry broken text-tower weights — verified at the tensor level, engine-independent. PPL 192.9 vs true 4.68**

Hi — we spent several days root-causing the Gemma-4-12B perplexity anomalies
and want to share results + reproduction instruments, because the June-5
rebuild did **not** fix the underlying problem.

**Method (engine-independent).** We wrote a from-scratch reference forward
for gemma-4 directly off the official safetensors + config (no llama.cpp, no
transformers — ~130 lines of numpy/torch). On a verified token fixture
(identical to HF `tokenizer.json`, 5431/5431) it measures the TRUE
full-precision wikitext chunk-0 PPL at **4.6776**, with targets at max-logit
(NLL ≈ 0.001). The same script can dequantize any GGUF's tensors and run the
identical arithmetic over them — which removes the inference engine as a
variable entirely.

**Results (same fixture, same protocol, only the weight bytes change):**

| weights | PPL (our forward) | PPL (llama.cpp) |
|---|---|---|
| official bf16 safetensors | **4.68** | — |
| pre-fix Q4_K_M GGUF | 271.2 | 505.9 |
| pre-fix QAT-Q4_0 GGUF | 364.3 | 397.5 |
| **rebuilt (post-June-5) `gemma-4-12B-it-qat-UD-Q4_K_XL`** | **192.9** | — |

Two independent engines agree per-artifact → llama.cpp's forward is NOT the
problem; **the artifacts are**. PR ggml-org/llama.cpp#24118 fixed
vision/audio projector config handling — the text-tower weight damage
predates and survives it.

**Damage anatomy (forensics scripts included):**
- No layer permutation: the blk↔layer mapping is exactly diagonal
  (cross-layer cosines ≈ 0).
- In-place damage with a period-6 signature: vs the official checkpoint,
  layers ≡ 0,1 (mod 6) sit at cos 0.93–0.97 while the other four sit at
  0.24–0.70 (measured on the pre-fix K_M, which shares the bf16 source).
- The per-layer `layer_output_scale` class is independently defective:
  restoring ONLY those scalars from the checkpoint takes the QAT artifact
  from 364 → 97. Restoring norms or embeddings makes it *worse* (they are
  coherent with the damaged weights — so the matmul tensors are damaged too).
- Generation looks deceptively OK (confident positions stay correct), which
  is why this slipped through smoke tests. PPL on a fixed fixture catches it.

**Reproduction:** all instruments + receipts (MIT) are here:
https://github.com/nihilistau/shannon-prime-lattice/tree/main/tests/gemma4_gold
— `_t2_manual_forward.py` (gold), `_t2c_gold_on_gguf.py` (grade any GGUF),
`_t2g_perm_hunt.py` (cosine forensics). A step-by-step verification + fix
write-up: https://github.com/nihilistau/Position_Is_Arithmetic/blob/main/GEMMA4-QUANT-FIX.md

**Suggested fix on your side:** re-convert from the official safetensors and
**verify at the weight level** before publishing — per-layer cosine vs the
checkpoint (should be >0.99 for ≥8-bit tensors, uniform across layers) and a
fixed-fixture teacher-forced PPL within a few percent of 4.68. Happy to help
validate a candidate rebuild with the instruments above.

Also FYI: gemma-4-12B is unusually PTQ-hostile — we measured naive
all-tensor symmetric int4 at +45% PPL even from clean weights; keeping
attention/down-proj/embed at 8-bit and quantizing only FFN gate/up to 4-bit
lands at +9.6%. Recipe table in the write-up.

---

## Variant B — llama.cpp issue comment (short)

We root-caused the Gemma-4 perplexity anomalies with an engine-independent
method and the result exonerates llama.cpp's forward: a from-scratch
reference forward (written off the official safetensors + config only)
measures the true full-precision wikitext PPL at **4.68**, and when run over
the *GGUF-dequantized tensors* it reproduces the same broken numbers
llama.cpp gets (271–364 pre-fix; **192.9 on the post-#24118 rebuilt QAT
UD-Q4_K_XL**). Same arithmetic, same fixture — only the weight bytes differ.
The conversion/artifact pipeline is still damaging the text tower (in-place,
period-6 layer signature, `layer_output_scale` independently defective —
restoring just those scalars from the checkpoint recovers 364→97).

Repro instruments + receipts (MIT):
https://github.com/nihilistau/shannon-prime-lattice/tree/main/tests/gemma4_gold
Step-by-step: https://github.com/nihilistau/Position_Is_Arithmetic/blob/main/GEMMA4-QUANT-FIX.md

Suggestion: gemma-4 conversions need a weight-level verification gate before
release — per-layer cosine vs the checkpoint + fixed-fixture teacher-forced
PPL (target ≈4.68 ±few %). The current failure mode is silent: generation
stays superficially coherent while PPL is 40–100× off.
