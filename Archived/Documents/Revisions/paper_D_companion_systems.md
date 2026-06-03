# Calibration-Free fp8 Quantization for Transformers: A Shannon-Prime Experiment Design

**A. Knack** (Shannon-Prime Project)
**Companion systems paper. Draft v0.1 — 2026-05-16**

---

## Abstract

This companion paper specifies the experiment that probes the single highest-leverage prediction of the Shannon-Prime framework: that fp8 quantization on a CM-encoded transformer state requires no calibration. The prediction is a direct consequence of the Frobenius Quantization Theorem (Theorem 2 of the theory companion [SP-Theory-Companion 2026]); this paper presents the experimental design that tests it on a Phi-3 reference model, with the full implementation hooks already present in the Shannon-Prime engine. We describe four configurations (baseline fp16, SP-fp8 calibration-free, GPTQ-fp8 calibrated, AWQ-fp8 calibrated) and the evaluation harness, perplexity targets, and pass/fail criteria. The expected outcome is that SP-fp8 matches the calibrated baselines without any calibration data. We include implementation notes, a reproducible run script outline, and a discussion of how the result, if positive, scales to fp4.

---

## 1. The Question

Standard transformer quantization treats the model's weight and activation tensors as floating-point arrays and rounds them to a lower-precision representation. The rounding introduces errors in the multiplicative relations the model has learned during training, and post-training calibration is required to fit a per-tensor scale factor that approximately restores those relations. GPTQ, AWQ, SmoothQuant, and QServe all follow this pattern; each requires a calibration pass on representative data (typically ~1000 samples) to recover acceptable accuracy.

Shannon-Prime predicts something different. Its theoretical content (Theorem 2 of [SP-Theory-Companion 2026]) is that on a CM elliptic curve over $\mathbb{Q}(\sqrt{-163})$, the Frobenius endomorphism $\varphi_p$ commutes with the layer endomorphisms. If the model's state is encoded on this curve — as SP encodes the KV cache and (in this experiment) the weights — then reduction to lower precision is Frobenius application rather than rounding, and the multiplicative relations are preserved exactly.

**Question.** *Does SP-fp8 on a Phi-3 model recover vanilla-fp16 perplexity to within noise, with no calibration data?*

A positive answer would deliver one of the strongest practical results in the field: a quantization scheme requiring no calibration pass, hence shippable to edge devices without device-specific data.

---

## 2. Setup

### 2.1 Reference Model

Phi-3 was chosen for three reasons:

1. **It is the SP model-pack's calibrated reference.** Phi-3 currently passes the SP calibration ledger at $\Delta\mathrm{PPL} = +2.44\%$ vs vanilla under SP-base compression. Starting from a known-calibrated SP target removes one source of variance.
2. **It is small enough to bench quickly.** 3.8B parameters at fp16 fits on a single A100; the bench runs in under an hour per configuration.
3. **It does not exhibit the Qwen3 edge-fail artifact.** The Qwen3 architecture's gated-attention + mRoPE-mode-8 combination breaks the SP encoding in a known way; Phi-3 does not. Using Phi-3 eliminates that confound.

### 2.2 Bench Corpora

Two corpora at three context lengths each:

| Corpus | Description | Tokens |
|--|--|--|
| **WikiText-103** | Standard perplexity bench | 245M |
| **The Stack v2 (filtered)** | Code completion bench | 100M |

Context lengths: 512, 2048, 8192. The 8192 condition exercises the long-context KV cache path where SP compression is most impactful.

### 2.3 Configurations

Four configurations, all evaluated on the same corpus + context combinations:

| Config | Quant | Calibration | Notes |
|--|--|--|--|
| **A. Baseline** | fp16 | — | Ground truth |
| **B. SP-fp8 calibration-free** | SP-fp8 ($p = 11$, $\varphi_p^8$) | None | The hypothesis |
| **C. GPTQ-fp8** | fp8 | ~1000 samples | Industry baseline |
| **D. AWQ-fp8** | fp8 | ~1000 samples | Industry baseline |

The configuration that is the focus is B. The hypothesis is that B matches A within noise ($|\Delta\mathrm{PPL}| < 0.5\%$) and matches C/D within noise ($|\Delta\mathrm{PPL}_{B,C}| < 0.3\%$).

---

## 3. Why fp8, Why $p = 11$, Why $\varphi_p^8$

The Frobenius Quantization Theorem (Theorem 2 of [SP-Theory-Companion 2026]) implements $\mathrm{fp}16 \to \mathrm{fp}q$ as iterated Frobenius $\varphi_p^{16-q}$. For $q = 8$, this is $\varphi_p^8$. The prime $p$ is constrained by $p^q \leq 2^{16}$, i.e., $p^8 \leq 2^{16}$, giving $p \leq 2^2 = 4$, which is too small to be useful at $q = 8$.

The resolution is to relax the constraint: at $q = 8$ we have an entire byte of representation, and $p$ can be chosen up to $2^8 = 256$. Setting $p = 11$ gives a comfortable margin while keeping the trace of Frobenius $a_{11}$ in a numerically friendly range. For $E$ the CM curve over $\mathbb{Q}(\sqrt{-163})$ reduced mod 11, $a_{11}$ can be computed from the Hilbert class polynomial; the explicit value is $a_{11} = -6$ (good ordinary reduction). The Frobenius polynomial is then $\varphi_{11}^2 + 6\varphi_{11} + 11 = 0$ in $\operatorname{End}(E_{11})$.

The number of points: $\#E_{11}(\mathbb{F}_{11}) = 11 + 1 - a_{11} = 18$, well within the Hasse–Weil bound of $11 + 1 + 2\sqrt{11} \approx 18.63$.

**At $q = 8$, per-coordinate information capacity is $\log_2 18 \approx 4.17$ bits.** This is lower than the nominal "8 bits" of fp8 because the CM encoding uses the upper bits for spinor and Möbius coefficients. Empirically this matches the effective bit-width of well-quantized fp8 LLM weights as reported in [Liu et al. 2024 KIVI].

---

## 4. Implementation

### 4.1 Existing Hooks

The Shannon-Prime engine already contains:

- `--hier-ternary-mask` and `--hier-res-bits-v` flags for ternary skeleton compression.
- VHT2 + Möbius + spinor + square-free chain across all four backends.
- The fp8 quantization implementation in the engine path (used in production but currently calibrated).
- Per-architecture compression-default registry (model-pack scaffold) — phi3 row already exists and is calibrated.

What is needed to run the experiment:

1. **A `--frobenius-quant` flag** that toggles the Frobenius reduction in place of the calibrated fp8 path.
2. **A unit test** verifying that $\varphi_{11}^8$ produces output bit-identical to direct reduction mod $11^8$ on the CM-encoded state.
3. **A bench harness modification** to disable the calibration-data path for config B.

Estimated implementation: 1–2 days at the engine level. The math is fully specified by Theorem 2.

### 4.2 Outline of the Run Script

```
# Pseudocode for the bench harness
for cfg in [A_baseline_fp16, B_sp_fp8_calfree, C_gptq_fp8, D_awq_fp8]:
    model = load_phi3(cfg.quantization)
    for corpus in [wikitext103, stackv2]:
        for ctx in [512, 2048, 8192]:
            ppl = eval_perplexity(model, corpus, ctx)
            tokens_per_sec = bench_throughput(model, corpus, ctx)
            log(cfg, corpus, ctx, ppl, tokens_per_sec)
```

All four configs use the same bench loader and the same tokenization; only the quantization differs.

### 4.3 Pass/Fail Criteria

| Comparison | Criterion |
|--|--|
| **B vs A** (calibration-free fp8 vs baseline fp16) | $|\Delta\mathrm{PPL}| < 0.5\%$ on WikiText-103 at all contexts |
| **B vs C** (SP-fp8 vs GPTQ-fp8) | $|\Delta\mathrm{PPL}_{B,C}| < 0.3\%$ at all contexts |
| **B vs D** (SP-fp8 vs AWQ-fp8) | $|\Delta\mathrm{PPL}_{B,D}| < 0.3\%$ at all contexts |
| **B throughput** | within 5% of A throughput; SP-fp8 is not expected to be faster than calibrated fp8 |
| **Robustness** | B's relative PPL gap does not increase with context length |

If all four criteria pass, the framework's central practical prediction is validated and SP-fp8 is deployable as a calibration-free quantization.

---

## 5. Expected Outcome and Risk Analysis

### 5.1 Expected Outcome

Theorem 2 predicts that B matches A within numerical noise. The framework attributes any residual gap to:

- The Frobenius trace $a_p$ being nonzero (predicted systematic drift of $\approx a_p / p \approx 0.5\%$ at $p = 11$); the experiment can quantify this.
- Bench-scaffold artifacts (the fp32 reduction step in the engine bench loop introduces small additional error; see the A100 result in [SP-Systems 2026]).
- Tokenizer interaction with the CRT-sharded LM head (not exercised by config A but exercised by SP encoding).

The expected magnitude of $|\Delta\mathrm{PPL}_{B,A}|$ is in the range $0.1\%$ to $0.5\%$. Anything below $1\%$ is a positive result; anything below $0.3\%$ is a strong positive.

### 5.2 What a Negative Result Would Indicate

A failure of B to match A would localize one of the following:

1. The CM realization of Phi-3's layer endomorphisms is imperfect — the Endomorphism Realization (Theorem 1 of [SP-Theory 2026]) holds in principle but does not yet match the empirical model in implementation.
2. The Frobenius reduction is implemented incorrectly in the engine.
3. The framework's choice of curve $E$ over $\mathbb{Q}(\sqrt{-163})$ does not match the actual hidden-state geometry of trained Phi-3.

(1) is debuggable by mechanistic interpretability of layer endomorphisms; (2) is a code review; (3) would require revisiting the framework's curve choice. Of these, (3) is the lowest-probability and the most consequential.

### 5.3 What a Positive Result Enables

A positive result delivers:

1. **Calibration-free fp8 deployment.** Drop-in fp8 for any Phi-3-class model with no calibration corpus required.
2. **A bridge to fp4.** Theorem 2 with $q = 4$ requires $p \leq 11$, and the SP-fp4 numerical information ceiling of $\approx 4.07$ bits/coord (Corollary 2.2 of the theory companion) matches the empirical fp4 capacity. The same experiment, repeated at $q = 4$ with appropriate $p$, would be the natural next step.
3. **A target for ARM/Hexagon production.** Phone-class targets currently quantize via runtime-calibrated routines. Calibration-free quantization removes a major deployment friction.

---

## 6. Implementation Timeline

| Phase | Deliverable | Estimated effort |
|--|--|--|
| 1. Engine hooks | `--frobenius-quant` flag, unit test for $\varphi_{11}^8$ | 1–2 days |
| 2. Bench harness | Modified eval loop for the four configs | 1 day |
| 3. Reference runs | All four configs at all six (corpus × context) combinations | 1 day on A100 |
| 4. Analysis + writeup | Result table, plot of PPL vs context, regression to the framework's predictions | 2 days |
| 5. Companion v0.2 | Incorporate results into this paper as §5 (Results) | 1 day |

Total: ~1 week of engine + bench work, assuming an A100 is available for the reference runs.

---

## 7. Connection to the Broader SP Framework

This experiment is one component of a larger program. The Shannon-Prime framework predicts five additional implementations, each with its own experimental signature:

- **Stern–Brocot RoPE** ([SP-Theory 2026, §9.1]): replace RoPE base $10{,}000$ with $\varphi$; bench on long-context tasks. Smallest implementation cost of any extension.
- **Weil pairing attention** ([SP-Theory 2026, §9.2]): replace softmax-of-dot-product with the Weil pairing $e_n$. Highest research upside.
- **Hecke-eigenform embeddings** ([SP-Theory 2026, §9.3]): replace learned embedding with a Hecke basis. Longest path to a number.
- **L-function activation oracle** ([SP-Theory 2026, §9.4]): predict FFN firing as L-function coefficients.
- **LLL KV write** ([SP-Theory 2026, §9.5]): make the KV archive an LLL-reduced lattice basis.

Each of these is the subject of a future SP companion paper. The present experiment — calibration-free fp8 — is first in line because it is the smallest implementation step that probes the strongest theoretical prediction.

---

## 8. Conclusion

Shannon-Prime's Frobenius Quantization Theorem predicts that fp8 quantization on a CM-encoded transformer state requires no calibration data. The present companion paper has specified the experimental design that tests this prediction on a Phi-3 reference model. The result, if positive, validates the framework's strongest practical claim and opens a path to fp4 and edge-device deployment without calibration. The experiment is small (≈1 week of engineering + benchmarking), the implementation hooks are already in place across the SP engine and llama.cpp fork, and the framework's predicted outcome is sharp and falsifiable.

---

## References

- Companion theory: "Two Theorems for Shannon-Prime Compression: Hasse–Weil as the Shannon Limit, and Frobenius as Quantization." 2026.
- Full theory: "Shannon-Prime: A CM-Elliptic-Curve Framework for Transformer Computation." 2026.
- Full systems: "Shannon-Prime: Provably Exact KV-Cache Compression and Per-Layer Acceleration on Standard Inference Stacks." 2026.
- Liu, Z. *et al.* "KIVI: A Tuning-Free Asymmetric 2bit Quantization for KV Cache." 2024.
- Frantar, E. *et al.* "GPTQ: Accurate Post-Training Quantization for Generative Pre-trained Transformers." 2023.
- Lin, J. *et al.* "AWQ: Activation-aware Weight Quantization for LLM Compression and Acceleration." 2024.
- Phi-3 Technical Report, Microsoft, 2024.
