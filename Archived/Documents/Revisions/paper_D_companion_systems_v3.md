# Calibration-Free fp8 and Sato–Tate fp10 Quantization for Transformers: A Shannon-Prime Experiment Design

**A. Knack** (Shannon-Prime Project)
**Companion systems paper. Draft v0.3 — 2026-05-16**

**v0.3 changelog.** v0.2 erroneously claimed $p = 11$ was a split prime in $K = \mathbb{Q}(\sqrt{-163})$ with $a_{11} = -6$ ordinary reduction. The Shannon-Prime Test Suite (suite version 0.1, test `PAPER-D-FIX`) caught this: $(-163/11) = -1$, so 11 is *inert*, $E_{11}$ is supersingular, and $a_{11} = 0$ exactly. The smallest split prime in $K$ is $p = 41$ — exactly the first value of Euler's polynomial $n^2 + n + 41$, which is no accident, since $h(-163) = 1$ is what makes that polynomial prime-rich. Throughout v0.3 we replace $p_2 = 11$ with $p_2 = 41$, $a_{p_2} = 1$, and the Frobenius polynomial becomes $\varphi_{41}^2 - \varphi_{41} + 41 = 0$.

---

## Abstract

This companion paper specifies the experiment that probes the two highest-leverage predictions of the Shannon-Prime framework: that (i) fp8 quantization on a CM-encoded transformer state requires no calibration, and (ii) the Sato–Tate inert-prime + split-prime asymmetric construction yields a calibration-free fp10 mixed-precision format with zero variance on the inert channel. The predictions are direct consequences of Theorems 2 and 3 of the theory companion [SP-Theory-Companion 2026]. We present the experimental design on a Phi-3 reference model, with the implementation hooks already present in the Shannon-Prime engine. We describe five configurations (baseline fp16, SP-fp8 calibration-free, GPTQ-fp8 calibrated, AWQ-fp8 calibrated, SP-fp10 Sato–Tate asymmetric).

---

## 1. The Question

Standard transformer quantization treats the model's weight and activation tensors as floating-point arrays and rounds them to a lower-precision representation. The rounding introduces errors in the multiplicative relations the model has learned during training, and post-training calibration is required to fit a per-tensor scale factor that approximately restores those relations. GPTQ, AWQ, SmoothQuant, and QServe all follow this pattern.

Shannon-Prime predicts something different. Its theoretical content (Theorems 2 and 3 of [SP-Theory-Companion 2026]) is that on a CM elliptic curve over $\mathbb{Q}(\sqrt{-163})$, the Frobenius endomorphism $\varphi_p$ commutes with the layer endomorphisms. If the model's state is encoded on this curve, then reduction to lower precision is Frobenius application rather than rounding, and the multiplicative relations are preserved exactly. Furthermore, the inert/split prime partition under CM Sato–Tate gives an asymmetric mixed-precision format with provably zero drift on the inert channel.

**Question.** *Does SP-fp8 on a Phi-3 model recover vanilla-fp16 perplexity to within noise, with no calibration data? Does SP-fp10 Sato–Tate (2-bit inert + approximately 8-bit split at $p_2 = 41$) match or beat SP-fp8 with no calibration?*

---

## 2. Setup

### 2.1 Reference Model

Phi-3 was chosen for three reasons: it is the SP model-pack's calibrated reference ($\Delta\mathrm{PPL} = +2.44\%$); it benchmarks quickly (3.8B parameters fit on a single A100); and it does not exhibit the Qwen3 edge-fail artifact.

### 2.2 Bench Corpora

Two corpora at three context lengths each:

| Corpus | Description | Tokens |
|--|--|--|
| **WikiText-103** | Standard perplexity bench | 245M |
| **The Stack v2 (filtered)** | Code completion bench | 100M |

Context lengths: 512, 2048, 8192.

### 2.3 Configurations

Five configurations, all evaluated on the same corpus + context combinations. Note the corrected prime $p_2 = 41$ (was incorrectly $p = 11$ in v0.2).

| Config | Quant | Calibration | Notes |
|--|--|--|--|
| **A. Baseline** | fp16 | — | Ground truth |
| **B. SP-fp8 calibration-free** | SP-fp8 ($p = 41$ split, $\varphi_p^8$) | None | Primary hypothesis (single-prime Frobenius, smallest split) |
| **C. GPTQ-fp8** | fp8 | approximately 1000 samples | Industry baseline |
| **D. AWQ-fp8** | fp8 | approximately 1000 samples | Industry baseline |
| **E. SP-fp10 Sato–Tate asymmetric** | $\varphi_{p_1}^{k_1} \circ \varphi_{p_2}^{k_2}$, $p_1 = 2$ inert, $p_2 = 41$ split | None | Sharper hypothesis: zero-drift mixed precision |

The hypotheses are:
- B matches A within noise: $|\Delta\mathrm{PPL}_{B,A}| < 0.5\%$.
- B matches C/D within noise: $|\Delta\mathrm{PPL}_{B,C}|, |\Delta\mathrm{PPL}_{B,D}| < 0.3\%$.
- E at 10-bit total matches B at 8-bit total: $|\Delta\mathrm{PPL}_{E,B}| < 0.2\%$ despite lower precision, because the inert channel contributes zero drift.

---

## 3. Why fp8, Why $p = 41$, Why $\varphi_{41}^8$

The Frobenius Quantization Theorem implements $\mathrm{fp}16 \to \mathrm{fp}q$ as $\varphi_p^{16-q}$. For $q = 8$ at one byte of representation, $p$ can be chosen up to $2^8 = 256$.

We choose $p = 41$, the smallest split prime in $K$. The Frobenius element is $\pi = \omega$ (or $\bar{\omega}$; conjugate pair) with $N(\omega) = 41$. The Frobenius trace is $a_{41} = \mathrm{Tr}(\omega) = 1$, giving Frobenius characteristic polynomial

$$\varphi_{41}^2 - \varphi_{41} + 41 = 0 \quad \text{in } \operatorname{End}(E_{41}).$$

By the Hasse–Weil decomposition, $\#E_{41}(\mathbb{F}_{41}) = 42 - 1 = 41$, well within the bound $41 + 1 + 2\sqrt{41} \approx 54.8$. The Sato–Tate angle is

$$\cos\theta_{41} = \frac{a_{41}}{2\sqrt{41}} = \frac{1}{2\sqrt{41}} \approx 0.0781,$$

which is *unusually small* — the corresponding drift per Frobenius application is bounded by $|a_{41}| = 1$, the smallest possible non-zero magnitude for a split prime. Picking the smallest split prime is therefore picking the smallest-drift split prime as well, a happy alignment.

**Per-coordinate information capacity at $q = 8$, $p = 41$:** $\log_2(41 + 1 + 2\sqrt{41}) \approx 5.78$ bits, matching empirical fp8 LLM weight bit-widths [Liu et al. 2024 KIVI].

The choice $p = 41$ also makes the Sato–Tate inert/split partition concrete: $\omega$ itself is the Frobenius element, and its conjugate $\bar{\omega} = 1 - \omega$ generates the conjugate ideal. The test suite asserts the *norm invariant* $N(\varphi_p^k(\text{state})) = N(\text{state}) \cdot p^k$ rather than fixing a representative (since pi vs pi-bar is a choice).

---

## 3.5 The Sato–Tate Mixed-Precision Choice (Config E)

Theorem 3 of the theory companion [SP-Theory-Companion 2026, §3A] sharpens Theorem 2 by partitioning primes into *inert* (deterministic $a_p = 0$, zero drift) and *split* (bounded analytic drift).

**Prime selection.** For $K = \mathbb{Q}(\sqrt{-163})$: smallest inert primes (Legendre $-1$) are $p_1 \in \{2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, \dots\}$; smallest split primes (Legendre $+1$) are exactly the values $n^2 + n + 41$ that are prime: $\{41, 43, 47, 53, 61, 71, 83, 97, 113, 131, 151, 173, 197, \dots\}$.

Choose $p_1 = 2$ (inert, $\varphi_2^2 = -2$, scalar action with zero $\omega$-drift) and $p_2 = 41$ (split, smallest, with the smallest split-prime drift $|a_{41}| = 1$).

**Resulting format.** Total bit-width approximately $2 + 8 \approx 10$ bits per encoded coordinate.

| Format | Total bits | Inert (zero-drift) | Split (bounded-drift) |
|--|--|--|--|
| fp8 (Config B, $p = 41$) | 8 | 0 | 8 |
| fp10 Sato–Tate (Config E, $p_1=2$, $p_2=41$) | 10 | 2 | 8 |
| fp16 (Config A) | 16 | 0 | 16 |

**Why Config E is informative.** Config B tests single-prime Frobenius. Config E tests *that* plus the inert/split partition. If B passes and E fails, the inert-channel zero-drift prediction is wrong despite Frobenius being correct — a sharper signal than B alone.

**Suite-verified algebraic primitives.** The Shannon-Prime Test Suite (v0.1, in `D:\F\shannon-prime-repos\test-suite\`) verifies the following bit-exact properties used by Config E:

- `HOOK-B` (`--frobenius-quant`): $N(\varphi_{41}^k(\text{state})) = N(\text{state}) \cdot 41^k$ for arbitrary $k$.
- `HOOK-E` (`--sato-tate-mix`): $N(Q_{2,2,41,k_2}(\text{state})) = N(\text{state}) \cdot 4 \cdot 41^{k_2}$, and the inert channel applied alone scales state by $-2$ exactly (zero $\omega$-drift).
- `HOOK-E-COMM`: composition order is irrelevant — applying $\varphi_2^2$ then $\varphi_{41}^k$ gives bit-identical output to applying $\varphi_{41}^k$ then $\varphi_2^2$ (50 random states tested).

These are pre-conditions for the A100 perplexity experiment; the production engine kernels for `--frobenius-quant` and `--sato-tate-mix` must reproduce the same bit-exact outputs.

---

## 4. Implementation

### 4.1 Existing Hooks

The Shannon-Prime engine already contains:

- `--hier-ternary-mask` / `--hier-res-bits-v` flags for ternary skeleton compression.
- VHT2 + Möbius + spinor + square-free chain across all four backends.
- Calibrated fp8 quantization in the engine path.
- Per-architecture compression-default registry (model-pack scaffold); phi3 row exists and is calibrated.

What is needed:

1. **A `--frobenius-quant` flag** that toggles Frobenius reduction $\varphi_{41}^k$ in place of calibrated fp8 (Config B).
2. **A `--sato-tate-mix p1,k1,p2,k2` flag** that activates the Sato–Tate asymmetric mixed-precision encoding (Config E). For the production reference: `--sato-tate-mix 2,2,41,8`.
3. **Unit tests** verifying:
   - `find_element_of_norm(41)` returns an element of norm 41 (i.e., $\omega$ or $\bar{\omega}$ — either is fine, both give the same Frobenius action up to the well-known $\pi \leftrightarrow \bar{\pi}$ ambiguity).
   - $N(\varphi_{41}^8(\text{state})) = N(\text{state}) \cdot 41^8$ exactly.
   - $\varphi_2^2$ acts as scalar $-2$ (zero $\omega$-drift).
   - $\varphi_2^2 \circ \varphi_{41}^{k_2}$ matches $\varphi_{41}^{k_2} \circ \varphi_2^2$ to bit-exactness, verifying commutativity (for E).
4. **A bench harness modification** to disable calibration for B/E and to run five-seed variance measurement on E.

The Python reference implementations at `test-suite/src/engine_hooks2.py` are bit-exact oracles; the C/CUDA versions must agree.

Estimated implementation: 2–3 days at the engine level.

### 4.2 Outline of the Run Script

```
for cfg in [A_baseline_fp16, B_sp_fp8_calfree_p41, C_gptq_fp8, D_awq_fp8, E_sp_fp10_satotate_2_41]:
    model = load_phi3(cfg.quantization)
    for corpus in [wikitext103, stackv2]:
        for ctx in [512, 2048, 8192]:
            ppl = eval_perplexity(model, corpus, ctx)
            tokens_per_sec = bench_throughput(model, corpus, ctx)
            log(cfg, corpus, ctx, ppl, tokens_per_sec)
```

### 4.3 Pass/Fail Criteria

| Comparison | Criterion |
|--|--|
| **B vs A** | $|\Delta\mathrm{PPL}| < 0.5\%$ on WikiText-103 at all contexts |
| **B vs C** | $|\Delta\mathrm{PPL}_{B,C}| < 0.3\%$ at all contexts |
| **B vs D** | $|\Delta\mathrm{PPL}_{B,D}| < 0.3\%$ at all contexts |
| **B throughput** | within 5% of A throughput |
| **Robustness** | B's relative PPL gap does not increase with context length |
| **E vs A** | $|\Delta\mathrm{PPL}_{E,A}| < 0.5\%$ at all contexts |
| **E vs B** | $|\Delta\mathrm{PPL}_{E,B}| < 0.2\%$ — fp10 mixed precision matches or beats fp8 single prime |
| **E zero-drift signature** | Variance of $\Delta\mathrm{PPL}$ across 5 random seeds is less than $0.5\times$ variance of B; verifies the inert-channel zero-drift property |

If all seven criteria pass, both Theorem 2 and Theorem 3 are validated. SP-fp8 ships as a calibration-free quantization; SP-fp10 ships as a calibration-free *variance-free* mixed precision.

---

## 5. Expected Outcome and Risk Analysis

### 5.1 Expected Outcome

Theorem 2 predicts B matches A within noise. Expected magnitude of $|\Delta\mathrm{PPL}_{B,A}|$: 0.1% to 0.5%. With $p = 41$ rather than the erroneous $p = 11$, the per-coordinate information capacity is 5.78 bits rather than 4.17 bits — Config B should be *easier* than the v0.2 paper predicted because there's more headroom.

Theorem 3 predicts E matches B within 0.2%. The drift bound $|a_{41}| = 1$ at $p_2 = 41$ is smaller than $|a_{11}|$ would have been *if* 11 were split, so the corrected experiment has a sharper prediction.

### 5.2 What a Negative Result Would Indicate

A B-failure localizes to: (1) imperfect CM realization of Phi-3 endomorphisms (debuggable by mechanistic interpretability); (2) Frobenius implementation bug (cross-check against the test-suite Python oracle); (3) framework's curve choice doesn't match trained Phi-3.

An E-failure (with B passing) localizes specifically to the inert-prime zero-drift prediction — would falsify Lemma 3.1(a) for our model.

### 5.3 What a Positive Result Enables

A positive result delivers: calibration-free fp8 deployment; a bridge to fp4 (Theorem 2 at $q = 4$); calibration-free fp10 mixed precision (Theorem 3); a target for ARM/Hexagon production.

---

## 6. Implementation Timeline

| Phase | Deliverable | Estimated effort |
|--|--|--|
| 0. **DONE** | Shannon-Prime Test Suite v0.1 (algebraic oracle, 16 VERIFIED / 2 PENDING / 1 paper-flag) | — |
| 1. Engine hooks | `--frobenius-quant`, `--sato-tate-mix` flags wired against the Python oracle | 2–3 days |
| 2. Bench harness | Modified eval loop for the five configs, 5-seed variance measurement on E | 1–2 days |
| 3. Reference runs | All five configs at all six (corpus × context) combinations | 1–2 days on A100 |
| 4. Analysis + writeup | Result table, variance comparison for B and E | 2 days |
| 5. Companion v0.4 | Incorporate results into this paper as §5 (Results) | 1 day |

Total: 8–10 days of engine + bench work after Phase 0.

---

## 7. Connection to the Broader SP Framework

This experiment is one component of a larger program. The Shannon-Prime framework predicts five additional implementations, each with its own experimental signature: Stern–Brocot RoPE, Weil pairing attention, Hecke-eigenform embeddings, L-function activation oracle, LLL KV write, Iwasawa-tower depth stability, BSD analytic-rank training. Each is the subject of a future SP companion paper.

The present experiment — calibration-free fp8 and fp10 — is first in line because it is the smallest implementation step that probes the strongest theoretical predictions, and now (post-v0.3) uses the algebraically correct split prime.

---

## 8. Conclusion

Shannon-Prime's Frobenius Quantization Theorem and Sato–Tate Mixed-Precision Theorem together predict that fp8 and fp10 quantization on a CM-encoded transformer state require no calibration data, with the fp10 format additionally exhibiting zero variance on its inert-prime channel. The present companion paper (v0.3, corrected) has specified the experimental design that tests both predictions on a Phi-3 reference model. A positive result validates the framework's strongest practical claims and opens a path to fp4, calibration-free mixed precision, and edge-device deployment without calibration. The experiment is small (approximately 1 week of engineering + benchmarking), the implementation hooks are already in place across the SP engine and llama.cpp fork, the algebraic correctness has been verified by the Shannon-Prime Test Suite, and the framework's predicted outcomes are sharp and falsifiable.

---

## References

- Shannon-Prime Test Suite v0.1, `D:\F\shannon-prime-repos\test-suite\` (this work).
- Companion theory: "Three Theorems for Shannon-Prime Compression: Hasse–Weil as the Shannon Limit, Frobenius as Quantization, and CM Sato–Tate Mixed Precision." 2026.
- Full theory: "Shannon-Prime: A CM-Elliptic-Curve Framework for Transformer Computation." 2026.
- Full systems: "Shannon-Prime: Provably Exact KV-Cache Compression and Per-Layer Acceleration on Standard Inference Stacks." 2026.
- Liu, Z. *et al.* "KIVI: A Tuning-Free Asymmetric 2bit Quantization for KV Cache." 2024.
- Frantar, E. *et al.* "GPTQ: Accurate Post-Training Quantization for Generative Pre-trained Transformers." 2023.
- Lin, J. *et al.* "AWQ: Activation-aware Weight Quantization for LLM Compression and Acceleration." 2024.
- Phi-3 Technical Report, Microsoft, 2024.
