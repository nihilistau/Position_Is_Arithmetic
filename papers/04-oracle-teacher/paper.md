# The Oracle and the Teacher

### Bit-faithful porting by checklist — and the day the reference frame itself was broken

### Paper 04 of the Shannon-Prime series · receipts-first

*A. Knack. Draft. All quantitative results are proof-of-mechanism on the named models and one dev host; see §2 for scope and §8 for the ledger rows. Methodology and gate vocabulary are shared across the series ([`METHODOLOGY.md`](../../METHODOLOGY.md)) and cited, not restated.*

---

## Abstract

Porting a complex transformer architecture to new silicon conventionally ends in a divergence hunt: the new backend produces different numbers, and weeks go into discovering why. We present the discipline that removed the hunt, and the receipts. The method has three parts: (1) extract a **bit-faithful CPU oracle** from the reference implementation first — a scalar, readable, f64-accumulating forward, validated against the upstream once, then frozen as the single source of arithmetic truth; (2) grade every backend against the oracle, never against a prior port; (3) gate autoregressive decode by **teacher-forcing** — the oracle re-predicts the port's own generated stream, token by token. Under this discipline, a 35-layer variable-geometry MatFormer (per-layer attention widths, shared KV, proportional RoPE, AltUp, softcap) was ported to a consumer GPU and matched its oracle at **max KL = 2.663e-10** (argmax 12/12), with every generated decode token oracle-predicted, and **both live runs green on the first attempt** — zero debugging sessions on the composed system, after five staged gates (38/38 cumulative). The paper then reports the strongest demonstration of the discipline we have: the case where the *upstream itself* was the broken instrument. When llama.cpp scored wikitext perplexity 397–506 on Gemma-4-12B and the ecosystem treated the magnitude as normal, a from-scratch forward built off the official safetensors and config alone measured **4.6776** — proving the model healthy, exonerating llama.cpp's forward (the two engines agreed per-artifact), and convicting the GGUF weight artifacts themselves. The same oracle then served as the gate for a sovereign replacement pipeline whose simulator and CPU artifact gate agreed to four decimal places (5.1259 / 5.1259), with the GPU kernel as the third instrument within 0.2% (5.1160). The moral: an oracle is not merely a porting tool — it is the only defense against a poisoned reference frame.

---

## 1. Introduction: correctness as a checklist

A port of a transformer forward pass to a new backend can fail in hundreds of places — a transposed weight, a wrong rotary base, a norm applied before instead of after, a quantization scale applied per-weight instead of per-accumulation. The conventional experience is that the composed port produces wrong tokens, and the failure is *global*: every layer's output depends on every prior layer's, so the symptom carries almost no information about the cause.

The claim of this paper is that this experience is optional. If the reference arithmetic is first captured in an oracle that is slow, scalar, and *trusted*, and every backend is graded against it through staged gates, then by the time the composed system runs live, there is nothing left to debug — correctness has been spent down to a checklist. The receipt for that claim is §5: two live runs, both green on the first attempt (04-R3). The receipt for the deeper claim — that the oracle discipline is load-bearing even when you are not porting anything — is §6.

**Scope, stated up front.** The port receipts are one model (Gemma4-E2B) on one host (RTX 2060 vs. its CPU oracle), greedy decode, short streams. The case study is one model family (Gemma-4-12B) and one corpus protocol. Proof-of-mechanism, per the series' standing caveat.

---

## 2. The oracle discipline

An **oracle**, in this series, is a reference-precision CPU forward with four properties:

1. **Scalar and readable.** No SIMD, no fusion, no scratch reuse — every intermediate inspectable, every operation in evaluation order on the page.
2. **Reference precision.** f64 accumulation where it matters (log-softmax, dot products), so the oracle's own floor sits below anything a backend will be graded at.
3. **Validated against the upstream implementation once** — llama.cpp, for the architectures in this series — **then frozen.** From that point it is the single source of arithmetic truth; backends are graded against it, never against each other, and never against a prior port (which would compound drift).
4. **Derived from the artifact, not the documentation.** Comments are aspirations; the oracle and the artifact config are physics. The working example: the E2B's real attention-layer period and KV-sharing factor disagreed with the doc comments in the reference source — the oracle was written to what the stored config and tensors actually say, and the port matched silicon reality rather than the comment.

Property 3 carries a hidden assumption that §6 will break and repair: *that the upstream was healthy when you validated against it.* The discipline as stated above is sufficient for porting. It is not sufficient for trusting a measurement ecosystem.

---

## 3. Gate currency: argmax, KL, and the teacher

Cross-backend correctness is graded in two currencies, and deliberately not in a third.

**Distribution identity: argmax + KL.** The end-to-end gate compares the port's output distribution to the oracle's, position by position, as argmax agreement plus KL divergence computed under f64 log-softmax. This is the quantity the model's consumer actually experiences.

**Teacher-forced decode.** For autoregressive generation, the gate is the **teacher**: the oracle is fed the port's own generated token stream and asked to re-predict each token. If every generated token is the oracle's prediction at that position, the port's decode loop — KV cache writes, position handling, cache geometry, sampling plumbing — is correct *as a system*, not merely per-step. A port can pass single-forward gates and still corrupt its cache; the teacher catches it.

**What is deliberately not the currency: raw activation error.** Norm layers amplify the f32 floor roughly 25-fold (measured; mechanism and the probe protocol in paper 05, row 05-R2). A relative-error gate placed at a norm output fails healthy ports and passes broken ones. Intermediate gates in this series are absolute, placed at telemetry-then-pinned floors; the *currency* gates are distributional.

---

## 4. Oracle arithmetic, enforced — not approximated

The oracle does not merely define the right answer; it defines the right *evaluation order*. The packed-weight matmul is the inline Frobenius lift: integer codes accumulated exactly in integer arithmetic, with ONE scale multiplication at the end of the row. A backend that instead dequantizes per-weight and accumulates in f32 computes something *algebraically equivalent* — and measurably different: an extra f32 rounding per term, which composed to a **2.8e-3** divergence at the matmul boundary before the inline lift restored the floor (04-R4).

The rule this receipt buys: **the GPU must compute what the oracle computes, not what is algebraically equivalent to it.** Equivalence under exact arithmetic is not equivalence under f32, and the gap is large enough to fail distributional gates. Every backend kernel in §5 and §6 is built to the oracle's accumulation order.

---

## 5. The port: Gemma4-E2B to CUDA, 38/38, first try

The test case is deliberately hostile: Gemma4-E2B is a 35-layer variable-geometry MatFormer — per-layer attention widths, shared-KV layers (a jagged cache), proportional RoPE, AltUp, logit softcapping. Almost every conventional porting assumption (uniform layer geometry, one cache shape, one rotary table) is false on this model.

The campaign ran as five staged gates — each a truncated or component-level parity check against the frozen CPU oracle, each pinned before the next stage began — and then two live runs:

- **Full forward (gate E_G4_CU_FULL):** the composed 35-layer GPU forward vs. the oracle — **argmax 12/12, max KL 2.663e-10, max |Δlogit| 1.84e-4** (04-R1). The KL figure is the f64 log-softmax comparison of §3; at 2.663e-10 the two distributions are identical for any downstream purpose.
- **Autoregressive decode (gate E_G4_CU_DEC):** the GPU decode loop with the jagged shared-KV cache and per-step AltUp — **all 12 generated tokens teacher-force-predicted by the oracle** (04-R2).

Both live runs lit green on the **first attempt**. Zero debugging sessions on the composed system; 38/38 checks cumulative across the staged trail (04-R3). The process claim is the receipt: the gate trail *is* the evidence that correctness had been fully spent before composition. Provenance: `tests/test_gemma4_cuda.c` in the engine repo, tag `stage-eta-phase1-closed-2026-06-06`.

---

## 6. Case study: the oracle that indicted an ecosystem (Gemma-4, June 2026)

Everything above treats the oracle as a porting instrument, with the upstream as its calibration source. This section is what happened when the upstream was the broken part — and it is the strongest demonstration of the discipline we have.

### 6.1 The anomaly

During the perplexity-gate campaign for the Gemma-4-12B speed work (paper 06), llama.cpp-CUDA scored wikitext chunk perplexities of **505.91** on a Q4_K_M GGUF and **397.49** on the QAT-Q4_0 GGUF — on a fixture whose tokens were verified identical to the HF tokenizer's output, 5431/5431 (06-R8). Numbers of that magnitude on a healthy 12B are absurd, but the ecosystem record normalized them: an open llama.cpp issue (#22407) cataloged extreme gemma4 quant perplexities, and the working calibration assumption — ours included, on the record — was that an instruction-tuned model on raw wikitext "honestly" scores in the hundreds. Every quality measurement in the campaign to that point had been made against this reference frame.

### 6.2 The gold instrument

The oracle discipline's answer to a suspect reference is to build the reference again from a lower layer. `tests/gemma4_gold/_t2_manual_forward.py` (lattice repo) is a from-scratch forward written off the **official bf16 safetensors checkpoint and its config alone** — no llama.cpp, no `transformers`, every architectural convention read out of the stored weights rather than out of any implementation: plain-multiplier RMSNorm (not the gemma-classic 1+w), V-less global-attention layers (V is the raw K projection, weightless-normed, never roped), partial rotary 0.25 via the stored factor table over θ=1e6 with full-rotation θ=1e4 on SWA layers, attention scale 1.0, GeGLU tanh, sandwich norms, per-layer output scalar, tied head, softcap 30. Section 2's property 4, executed in full.

On the identical fixture and protocol (chunk 0 of 512, teacher-forced, targets [256,512), f64 log-softmax): **PPL 4.6776**, with scored targets sitting at the maximum logit at nll ≈ 0.001 (06-R8; receipt `_t2_gold.log`). The model is healthy — supremely confident on raw wikitext. The 397–506 reference frame was off by roughly two orders of magnitude, and every number measured inside it was measured against a broken ruler.

### 6.3 The discriminator: forward exonerated, artifacts convicted

Two suspects remained: llama.cpp's gemma4 forward, or the GGUF weight artifacts it was fed. The discriminator (`_t2c_gold_on_gguf.py`) runs the *gold arithmetic* — the proven 4.68 forward — over the GGUFs' own dequantized tensors. Same math, swapped weights:

| weights | gold forward | llama.cpp |
|---|---|---|
| official bf16 safetensors | **4.68** | — |
| Q4_K_M GGUF (same checkpoint) | **271.18** | 505.91 |
| QAT-Q4_0 GGUF | **364.33** | 397.49 |

K-quant noise costs percents, not 58×. Both engines agree, per artifact, that the GGUF weights produce catastrophic perplexity — so **llama.cpp's forward is exonerated and the artifacts are convicted** (06-R8). This is the oracle discipline's grading rule of §3 turned outward: two independent implementations agreeing on each input is exactly the cross-check that isolates the data from the code.

### 6.4 Anatomy of the damage

The same instrument supports forensics by tensor-class swap and per-layer cosine (06-R8; receipts in the contract). Hybrid runs — GGUF weights with the safetensors' values substituted class by class — put the GGUF `layer_scalar` set alone at a 3.75× damage factor (hybrid PPL 97.07); the norms and embeddings are innocent (substituting them makes things *worse* — they are coherent with the damaged weights, at 113.6/113.7). There is no layer permutation (the blk↔layers cosine diagonal is exact, cross-layer ≈ 0); the damage is **in-place**, with a period-6 severity pattern — layers ≡ 0,1 (mod 6) at cosine 0.93–0.97 against the safetensors, the other four classes at 0.24–0.70.

The ecosystem record corroborates the conviction: llama.cpp PR #24118 ("Fix Gemma 4 Unified conversion", merged 2026-06-04), issue #22407, and Unsloth's June-5 GGUF rebuild notice ("re-download mandatory"; "the bugs were universal, affected all training packages"). And the epilogue receipt: a rebuilt post-June-5 GGUF, downloaded after the fix wave, still scores **192.94** through the gold arithmetic — better than the old wave's 364, still ~41× above gold (06-R8, 06-R9). The conversion fix repaired projector configs, not the text tower. For this model, the GGUF lane is dead.

### 6.5 The oracle as gate: the sovereign pipeline and triple-instrument agreement

With the only trusted weight source identified (the safetensors, 4.68-proven), the oracle became the *acceptance gate* for a replacement pipeline that touches zero GGUF weight bytes: `sp_transcode --st` reads values directly from the bf16 checkpoint (06-R9). Each produced artifact is graded by the gold instrument itself — `_t2h_spmodel_gate.py` parses the container, dequantizes, and runs the proven forward (67–105 s per gate):

- **OK_Q8 artifact: PPL 4.7396 — +1.33% vs. gold** (06-R9). Per-layer residual norms track the bf16 run digit-for-digit; +1.33% is the measured Q8 cost on this model.
- **Mixed OK_Q4B/Q8 "B1" artifact (9.4 GB, fits a 12 GB card): PPL 5.1259** — and the recipe was *chosen* by simulating candidate quantization schemes through the gold instrument first, with the simulator predicting 5.1259 before the artifact existed: a match to four decimals (06-R9).
- **The GPU kernel on the same artifact: 5.1160** (06-R10).

That last line is the modern form of oracle grading: **the simulator, the CPU artifact gate, and the GPU dp4a kernel agree — 5.1259 / 5.1259 / 5.1160** — three independent instruments, one number. With the gate green, the speed claim of paper 06 became citable: **26.1 tok/s at wikitext PPL 5.12 on an RTX 2060 12GB** (24/24 gates, decode 256/256 top-1, graph capture exact), against llama.cpp-CUDA's 31.29 tok/s on the same card — at PPL 192–506, on artifacts this section convicted (06-R10). On effective decode bandwidth the engines stand 245 vs. 207 GB/s; the SP artifact is heavier *because* it is, as far as we can measure, the only mathematically intact 4-bit gemma4-12B in existence. A like-for-like speed race does not exist, and we say so rather than manufacture one.

### 6.6 The moral

The oracle discipline of §2 says "validated against the upstream once, then frozen." This case study adds the clause experience wrote in: **re-run the validation when the upstream itself becomes suspect.** An oracle is not just for porting. It is the only defense against a poisoned reference frame — the situation where every instrument you own agrees, because every instrument you own inherits the same broken artifact or the same broken assumption. The hand-written forward cost a day; it re-based an entire campaign's quality axis, retired a non-citable headline number (06-R6's 34.2 tok/s, retired with its quality-failed artifact), and demoted llama.cpp from oracle to cross-check for this model family. The cheapest instrument in the toolbox turned out to be the one that could not be lied to.

---

## 7. Reproduction

Per series rule (METHODOLOGY rule 2 and the standing re-gate requirement), every number above is a ledger row with a named instrument:

- The port gates re-run from the engine harness (`tests/test_gemma4_cuda.c`, tag `stage-eta-phase1-closed-2026-06-06`): the staged trail, E_G4_CU_FULL, and E_G4_CU_DEC.
- The gold number reproduces from `_t2_manual_forward.py` against the official safetensors bucket and the pinned fixture (`_g4_12b_wiki_tokens.txt`, chunk 0 of 512, BOS first, targets [256,512), teacher-forced f32 log-softmax) — expected 4.6776, receipt `_t2_gold.log`.
- The conviction reproduces from `_t2c_gold_on_gguf.py` over the named GGUFs (expected 271.18 / 364.33 against llama.cpp's 505.91 / 397.49 on the same artifacts).
- The artifact gates reproduce from `_t2h_spmodel_gate.py` over the transcoded `.sp-model` files (OK_Q8 expected 4.7396; B1 expected 5.1259), and the GPU leg from the engine's M_GEMMA4_CUDA_PPL gate (expected 5.1160).

One-command repro packaging is the release gate for this paper, per the series rule; the instruments and expected outputs above are what it wraps.

## 8. Limitations and honest negatives

- **One model per receipt, one host.** The port receipts are E2B-on-2060; the case study is the 12B family on one fixture/protocol. No multi-model generality is claimed.
- **Teacher-forced decode is gated greedy and short** (12 tokens on the port). It exercises the cache machinery, not long-horizon sampling.
- **The gold instrument is Python/torch**, not the in-engine C path; the artifact gates of §6.5 validate the *artifacts* through it. The in-engine C forward is separately bit-faithful (E2B-gate-proven) but its own 12B perplexity run is pending harness instrumentation — stated in the contract, not glossed here.
- **The conviction is per-artifact, time-stamped.** The GGUFs we measured — pre-fix wave and one post-June-5 rebuild — are broken; a future correctly-converted GGUF would re-open the lane, and the gold instrument is exactly the tool that would verify it.

## 9. Related discipline

Differential testing against a reference implementation is standard practice; golden-model verification is the norm in hardware design, where RTL is graded against a slow, trusted behavioral model before tape-out. The position here is the software-inference transposition of that norm, with two specifics: the grading currency is distributional 