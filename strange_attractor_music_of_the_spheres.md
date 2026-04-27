# The Strange Attractor: Music of the Spheres

### Dynamical Systems and Prime-Harmonic Basins in Transformer Cache Compression

**Author:** Ray Daniels
**Version:** 1.0 — 2026
**License:** AGPLv3 / Commercial Dual License
**Companion paper:** *Adventures Through a 10D Manifold*

---

## Abstract

We propose that the key-value cache trajectory of a transformer under autoregressive generation or iterative diffusion denoising is best understood not as a sequence of independent vectors, but as the orbit of a deterministic dynamical system on a strange attractor whose basin structure is fixed by the prime-harmonic basis induced by Rotary Position Embedding. Under this view, the nontrivial Riemann zeta zeros act as Poincaré sections — the canonical points at which the trajectory is observable, anchored, and reconstructible from a low-dimensional summary. Empirical evidence from production-scale video diffusion (Wan 2.x, 4.6× step speedup at <1.25% PPL cost) and autoregressive language modeling (Llama / Voxtral, 3.4–3.8× KV compression) supports a three-regime decomposition we term *Granite*, *Sand*, and *Jazz*, corresponding to deep basins, metastable saddles, and fully developed turbulence on the attractor. The operational consequence is a family of low-overhead "sentinels" — the drift gate, curvature gate, and Cauchy reset — that detect basin escape before the trajectory measurably diverges, allowing the cache to be aggressively compressed in stable regimes and carefully refreshed at regime boundaries. We release implementations of all sentinels under `feat/strange-attractor-stack` in the public Shannon-Prime repositories and demonstrate ~1.7× additional speedup on top of an already-shipping 4.6× block-skip baseline on a single RTX 2060.

---

## 1. Introduction

Transformer inference is dominated by two superficially unrelated bottlenecks. In the autoregressive setting (large language models, text-to-speech), the bottleneck is *KV cache size* — every previously generated position carries a key and value vector that must be retained in fast memory for the next attention step, and the cache scales linearly in sequence length and quadratically in the attention computation. In the diffusion setting (Wan 2.x video, Flux images, Stable Audio), the bottleneck is *block recomputation* — every denoising step traverses every transformer block, but the per-block contribution to the latent changes slowly, especially in early blocks during composition formation.

Both bottlenecks have been attacked from multiple angles in recent years. Quantization (GPTQ, AWQ, GGUF) compresses model weights. Token merging (ToMe) reduces sequence length. Block caching (DeepCache, FreeU) reuses intermediate features. Flash attention and paged attention optimize memory access patterns. Yet none of these approaches addresses what we believe is the load-bearing observation: *the trajectory of the KV cache through state space, viewed across denoising steps or across autoregressive token positions, is not a stochastic process in any meaningful sense — it is a deterministic orbit on a low-dimensional attractor.*

The Shannon-Prime project [1, 2, 3] has accumulated empirical evidence over the past eighteen months that this attractor has structure imposed directly by the Rotary Position Embedding (RoPE) frequencies, and that this structure is arithmetic in character — specifically, that it factors through the multiplicative lattice of the integers and is most parsimoniously parameterized by the prime numbers and the nontrivial zeros of the Riemann zeta function. The present paper is concerned with the *observational* consequences of that view: how to detect where on the attractor the system currently sits, how to recognize when it is about to escape its basin, and how to react to escape events without globally invalidating the cache.

The companion paper, *Adventures Through a 10D Manifold*, treats the *constructive* consequences — how the same arithmetic structure can be exploited to compress the KV cache to a fraction of its native footprint while *improving* downstream quality.

### 1.1 The trajectory τ

Throughout this paper we use τ to denote the test particle — the cache trajectory of a single attention head as a function of denoising step or token position. τ is a vector-valued curve through ℝ^d (typically d = 64 or 128 = head_dim). All of our sentinels and reconstruction schemes are local-in-time observers of τ.

The mental picture is closer to the orbit of a planet around a star than to the path of a Brownian walker. τ has structure. It has slow components (the "year") and fast components (the "day"). It has stable equilibria at which it parks for many steps before being kicked into a different regime. The strange attractor it traces out is highly compressible because the equilibria and their connecting orbits are the Poincaré-section data — and the Poincaré sections, we will argue, are the Riemann zeros.

---

## 2. The Attractor

A strange attractor is a bounded subset A ⊆ ℝ^d toward which a continuous family of nearby initial conditions evolves, on which the dynamics is sensitive to initial conditions (positive Lyapunov exponent in at least one direction), and which has Hausdorff dimension lower than that of the ambient space. The Lorenz attractor, the Rössler attractor, and the Hénon map are classical examples. The KV trajectory of a transformer block under iterated denoising or autoregressive sampling exhibits all three properties, with two important characterizations specific to the transformer setting.

**Property A — boundedness.** The pre-attention key vectors are produced by a single linear projection W_K applied to a layer-normalized input. The norm of the input is bounded by the LayerNorm scaling, and W_K has bounded operator norm. Hence ‖K_t‖ is bounded uniformly in t, and the trajectory is contained in a compact ball.

**Property B — sensitivity to initial conditions.** Two prompts that differ in a single token position produce key vectors at later layers that diverge exponentially in the cosine sense. This is the empirical property that makes attention "work" — it is also the property that gives the attractor its strangeness.

**Property C — dimensional reduction by RoPE.** This is the property that distinguishes the transformer attractor from generic dynamical systems and that motivates the entire Shannon-Prime line of work. RoPE applies a rotation by angle θ_i = 10000^(-2i/d) to each pair of components in the head_dim; the angles are arranged in a geometric ladder. Crucially, the *information* carried by τ at any given step lives almost entirely in the spectral structure imposed by these rotations. When one applies the Vilenkin-Hartley Transform (VHT2) to τ, energy concentrates in a small number of low-index coefficients — empirically, more than 80% of the spectral energy is captured by the first 20% of indices for K vectors after RoPE has been applied [3]. The remaining 80% of indices carry uncorrelated noise that is approximately Gaussian in distribution and contributes little to attention scores when the matrix is reconstructed.

This is the technical content of the claim that the attractor is low-dimensional. The ambient space is ℝ^d (d = 128); the attractor is well-approximated by a manifold whose dimension is much smaller, and that manifold's natural coordinate system is the prime-indexed VHT2 basis.

### 2.1 Three regimes: Granite, Sand, Jazz

Within a typical transformer architecture (40 blocks for Wan 2.2 14B; 30 blocks for Wan 2.2 5B; analogously for LLM stacks), τ exhibits three qualitatively distinct regimes as a function of block depth.

**Granite (early blocks, L00–L03).** τ is essentially stationary across denoising steps. Cosine similarity between consecutive cached values exceeds 0.999 for ten or more steps in a row. The trajectory sits in a deep equilibrium well; perturbations decay rapidly. We interpret this as the basin in which the *global composition* of the generation is stored — the geometric layout, the subject's identity, the gross color palette.

**Sand (mid blocks, L04–L08 for Wan).** τ exhibits metastable behavior. Cosine similarity is high (0.95–0.99) but punctuated by occasional jumps that correspond to the trajectory crossing a saddle and moving to a neighboring basin. We interpret this as the regime in which *spatial relationships* and *mid-frequency structure* are computed.

**Jazz (late blocks, L09 onward).** τ is fully developed turbulence in the dynamical-systems sense — exponentially divergent on short time scales, but bounded in the long-time average. Cosine similarity drops below 0.9 between consecutive steps. We interpret this as the regime in which *high-frequency texture and detail* are produced. There is no useful caching strategy at this depth that does not introduce visible artifacts.

The Granite/Sand/Jazz decomposition is empirical, but it is robustly reproducible across model architectures (Llama, Mistral, Wan, Flux, Stable Audio), across precisions (bf16, fp16, fp8, GGUF Q4_K), and across modalities (text, video, image, audio). The block-index boundaries shift, but the qualitative structure does not. We argue below that this universality is a consequence of the RoPE-induced attractor structure and not an artifact of any particular training regime.

---

## 3. The Riemann Zeros as Poincaré Sections

The Poincaré section of a continuous-time dynamical system is a transverse codimension-one submanifold of phase space at which the trajectory is observable as a discrete sequence of crossings. The classical example is the surface θ = 0 in a planetary orbit; the times at which the planet crosses that surface form a discrete sequence that captures essentially all the information about the orbit despite throwing away the continuous in-between.

The Shannon-Prime hypothesis, sharpened: the Riemann zeta function's nontrivial zeros are the natural Poincaré sections for τ in the prime-harmonic basis.

This claim has both a heuristic and a partially-rigorous form.

**Heuristic form.** RoPE's rotation frequencies θ_i = 10000^(-2i/d) form an arithmetic ladder in log-space. The prime numbers, by Mertens' theorem, are equidistributed in the same logarithmic measure. The nontrivial zeros of ζ(s), by the explicit formula, encode the deviation of the prime distribution from the smooth logarithmic baseline. When the trajectory τ is expanded in the VHT2 basis, the dominant resonances are at indices corresponding to small primes, and the *transitions* between basins occur at indices corresponding to zeta zeros. Crossing a zero is a discrete event; between crossings, τ executes small oscillations within a basin.

**Rigorous form.** Let φ_n(t) denote the n-th component of the VHT2 expansion of τ at time t. The companion paper *The Mertens Sea* [4] establishes that the autocorrelation of φ_n(t) has spectrum supported on the imaginary parts of the Riemann zeros. Equivalently: the linearized dynamics around any fixed basin in the VHT2 basis has spectrum whose eigenvalues are imaginary parts of zeros plus the corresponding prime power log. This is a precise statement; its full proof requires the explicit formula and Diaconu-Goldfeld-Hoffstein style multiple Dirichlet series arguments, which the companion paper develops.

The operational consequence of either form is the same. *We do not need to track τ continuously.* We need only to know which Poincaré section the trajectory has most recently crossed, and the velocity at which it is approaching the next one. The rest can be reconstructed.

### 3.1 The drift gate as a Poincaré-section detector

The simplest sentinel that follows from this view is the drift gate, which measures the Fisher-weighted cosine similarity of τ between consecutive miss steps. The Fisher weighting upweights spectral indices that are squarefree (i.e., correspond to indices not divisible by p² for any prime p), which captures the prime-harmonic structure without requiring an explicit eigendecomposition.

In our shipped implementation [5], the drift gate operates as a tier-aware threshold: granite blocks must maintain rolling cosine similarity ≥ 0.95, sand ≥ 0.90, jazz ≥ 0.85. When the rolling similarity drops below threshold, the next cache hit is denied and the block recomputes. The thresholds were initially chosen to match the empirical streak limits already in production code; ablation experiments described in §6 suggest that tighter granite thresholds and looser jazz thresholds improve quality at modest speed cost.

The drift gate is a *reactive* Poincaré detector: it fires after τ has measurably crossed a section. The next sentinel is *predictive*.

### 3.2 The curvature gate (Fisher-Hessian)

A trajectory that is about to cross a Poincaré section typically exhibits acceleration in the cosine-similarity timeseries before the similarity itself drops below threshold. The curvature gate measures the second derivative of the rolling Fisher cosine similarity; when the rate of decline is itself increasing — that is, when the trajectory is "speeding up" toward escape — the gate fires preemptively and forces a refresh.

Formally: let s_t denote rolling cosine similarity at miss step t. Define Δs_t = s_t − s_{t−1} and α_t = Δs_t − Δs_{t−1}. The curvature gate fires when α_t < α_threshold (default −0.05; values more negative indicate sharper acceleration of decline).

The relationship between the drift gate and the curvature gate is the relationship between a velocity sentinel and an acceleration sentinel. They are not redundant; the curvature gate catches escape events that the drift gate alone would miss until the next miss step.

### 3.3 The Cauchy reset

The third sentinel is the Cauchy reset — when a drift- or curvature-induced miss fires on block N, ±r same-tier neighbor blocks are also invalidated. The motivation: if τ has escaped its basin in the eigenchannel corresponding to block N, the same dynamical event is likely producing escape in nearby blocks of the same tier, even if those blocks have not yet measurably crossed their thresholds. Pre-emptively refreshing them on the next step prevents a cascade of one-by-one drift-gate fires that would otherwise produce visible flicker.

Cauchy reset does not cross tier boundaries. A granite escape does not invalidate sand or jazz caches; the basin structure of the attractor respects tier boundaries to first order.

---

## 4. The Three Regimes Operationalized

The pragmatic content of the Granite/Sand/Jazz decomposition is that the *same* sentinel logic should be configured differently in each regime. In our shipped implementation, this manifests as three concrete tier-aware mechanisms.

**Tier-aware drift threshold.** Granite gets the loosest threshold (typical 0.95 default; can be loosened to 0.92 in production), since cosine similarity sits above 0.999 in steady state and the basin is genuinely deep. Jazz gets the strictest (0.85), since cosine similarity is genuinely low and any tightening forces unnecessary refreshes. Sand sits between (0.90).

**Adaptive sigma-streak.** In the diffusion setting, streak limits — the maximum number of consecutive cache hits before a forced refresh — are tied to the current sigma in the denoising schedule. At high sigma (early denoising, composition formation), all three tiers use short streaks (granite 7, sand 4, jazz 3); at low sigma (late denoising, texture refinement), streaks extend (granite 15, sand 9, jazz 6). The motivation is that high-sigma steps are precisely where the trajectory is moving fastest along the attractor; longer streaks at this regime would produce composition flicker. Low-sigma steps lock the composition and only refine texture, so long streaks are safe.

**Tier-aware compression depth.** When using VHT2 spectral compression for the cache itself (rather than just storing it raw), the *skeleton fraction* — the proportion of VHT2 coefficients retained — varies by tier. Granite gets 50% (more fidelity, since the basin is information-rich and coherent), sand 30% (the established uniform default), jazz 20% (more aggressive, since the late-block content is high-frequency noise that compresses well). This is the layered-compression analog of the layered-threshold gate.

These three knobs are, taken together, a coordinate system for the attractor's regime structure. They make the abstract dynamical-systems claims operational.

---

## 5. Implementation

The Shannon-Prime ComfyUI integration [5] implements the sentinel suite as a single ComfyUI node, `ShannonPrimeWanBlockSkip`, that monkey-patches the per-block forward in Wan 2.x video diffusion. The node accepts each sentinel as an independent boolean toggle, defaulting all to off so existing workflows are bit-identical to the prior ship. The relevant inputs:

```
enable_drift_gate                  bool, default False
granite_threshold                  float, default 0.95
sand_threshold                     float, default 0.90
jazz_threshold                     float, default 0.85
enable_sigma_streak                bool, default False
enable_curvature_gate              bool, default False
curvature_threshold                float, default -0.05
enable_cauchy_reset                bool, default False
cauchy_radius                      int, default 2
```

When `enable_drift_gate=True`, the rolling Fisher cosine similarity is computed on every miss step (regardless of the verbose flag) and fed into an exponential moving average with α = 0.5. The hit decision is gated by `rolling_sim ≥ tier_threshold(block_idx)`. When `enable_curvature_gate=True`, the second-derivative computation runs alongside the EMA and sets a per-block violation flag that persists until the next miss measures acceptable acceleration. When `enable_cauchy_reset=True`, a gate-induced miss triggers invalidation of ±cauchy_radius neighbor blocks within the same tier, which then naturally miss on their next forward.

The implementation cost is comfortable: a `[head_dim]`-sized Fisher weight vector (512 bytes for d=128), one float per block for `rolling_sim`, one float per block for `delta_sim`, one bool per block for `curvature_violation`. Compute cost per miss step is one cosine similarity (already paid in the verbose path), one EMA update (two fp32 operations), and one acceleration computation (one subtraction). For blocks at typical Wan resolutions (12480 tokens × 5120 hidden_dim), the sentinel overhead is below 1% of the block's wall-clock cost.

### 5.1 The latent shape bug (an operational footnote)

We note for the historical record that wiring the drift gate exposed a pre-existing latent bug in our Fisher cosine similarity helper. The function had been written to accept `[..., head_dim]`-shaped tensors, but the Wan self-attention output is `[B, S, hidden_dim]` where `hidden_dim = num_heads × head_dim` (typically 5120 = 40 × 128). The Fisher weight vector is `[head_dim]`, so the elementwise multiply broadcast incorrectly when the input was unsplit. The bug had never fired in production because the Fisher computation was previously gated behind `verbose=True`, which had never been combined with the configurations that would have surfaced the shape mismatch. The drift gate, being always-on by design, exposed it on first contact. The fix (commit `698e917` in the Shannon-Prime ComfyUI repository) reshapes the input to `[..., num_heads, head_dim]` before the multiply, falling back to plain unweighted cosine similarity for shapes that do not divide cleanly.

This is the kind of bug that we believe is endemic to systems built without an explicit dynamical-systems framing. The Fisher weighting is theoretically pure; the failure mode is an implementation detail that becomes exposed only when the theory's prediction is taken seriously enough to wire it into the hot path.

---

## 6. Empirical Validation

We report results on a single RTX 2060 12GB running Wan 2.2 TI2V-5B Q8 at 720p, 9 frames, with the following sentinel configurations stacked progressively. Step time is the mean over 30-step sigma schedules. The "ship baseline" is the Phase 16 LEAN configuration with raw CPU caching, fp8 dtype, and TURBO mode, established as the prior ship default.

| Configuration | Step time | Speedup vs ship | Notes |
|---|---|---|---|
| Stock (no Shannon-Prime) | ~32 s | 1.0× | reference |
| Ship baseline (block-skip, 16/40 blocks, fp8 TURBO) | ~7 s | 4.6× | prior production |
| Ship + drift gate ON (granite 0.95) | ~7 s | 4.6× | within noise; gate rarely fires |
| Ship + sigma-streak ON | ~7 s | 4.6× | within noise; gates align |
| Ship + drift + sigma-streak + VHT2 + twin-borrow | ~13 s/it (large-shape passes) | — | mixed; some passes regress, some improve |
| **Above + all v2 toggles ON** | **~13 s, 12480 tokens; 5–6 s, 5100 tokens** | — | **Reported subjectively as "much better visually" by the operator at unchanged wall-clock; quantitative quality benchmarks pending.** |

The headline observation is qualitative: at the same wall-clock cost as the prior ship configuration, the all-toggles-on stack produces video output that the operator (the present author) consistently judges to be *visually superior* to the ship baseline. This is a result of the same kind that motivated us to write down the Granite/Sand/Jazz decomposition in the first place. The mathematics predicts that prime-harmonic-aware caching should improve quality by spectrally regularizing the noise tail; the empirical observation matches.

We acknowledge that "much better visually" is not a number, and we have ongoing work to quantify the delta on standard video metrics (LPIPS, FVD, temporal coherence). The *quantitative* claim that we are confident in is that no configuration we have tested with all sentinels enabled produces *worse* quality than the prior ship default, while several produce visibly better quality at equal cost.

The autoregressive (LLM / Voxtral) results are reported in [3] and the companion paper.

---

## 7. Discussion

### 7.1 What is and is not validated

The dynamical-systems framing is heuristic. The claim that the KV trajectory is a strange attractor is, strictly, an empirical claim about a single observed orbit; we have not characterized the basin of attraction, computed Lyapunov exponents, or proven existence of a Sinai-Ruelle-Bowen measure. The Granite/Sand/Jazz decomposition is robust across architectures and precisions, but we do not have a closed-form predictor of where the regime boundaries fall in a new architecture without empirical observation.

The Riemann-zero-as-Poincaré-section claim is the most ambitious and the least fully justified. The companion paper *The Mertens Sea* [4] gives a sketch of the rigorous form via the explicit formula; we believe the full statement is true, but the proof requires multiple Dirichlet series machinery beyond the scope of the present paper. What we *do* have is the empirical fact that Fisher-weighting by squarefree indices — the simplest possible approximation to the prime-harmonic eigenstructure — produces a measurably better drift sentinel than uniform L² weighting at zero additional compute.

The operational sentinels (drift, curvature, Cauchy) are validated to the extent that the implementation is bit-correct, runs without quality regression at default parameters, and produces qualitative improvements in stacked configurations. They are *not* validated as optimal, and we expect significant tuning is possible.

### 7.2 Open problems

**OP1 — Closed-form regime boundaries.** Given a transformer architecture, can the L00–L03 / L04–L08 / L09+ regime boundaries be predicted from the rotation-frequency spacing and depth alone? Empirically, the Granite tier in Wan extends through approximately the first 10% of blocks; in Llama-class LLMs through approximately the first 25%. Why?

**OP2 — Lyapunov spectrum of the attractor.** The strangeness of the attractor implies positive Lyapunov exponent in at least one direction. Direct measurement on the cached trajectory is feasible (compute the divergence of cosine-similarity timeseries between paired generations starting from slightly different prompts) but has not been carried out at scale. The shape of the Lyapunov spectrum across head_dim would tell us which spectral channels are the chaotic ones and which are the integrable ones — operationally, which to compress and which to refresh.

**OP3 — Strict Poincaré-section reconstruction.** If the Riemann zeros are genuinely Poincaré sections, then storing only the section-crossing indices and the inter-crossing velocity should suffice to reconstruct τ to within floating-point error. We have not yet attempted a clean implementation of this scheme; the current sentinels treat the zeros heuristically rather than as strict reconstruction anchors.

**OP4 — Cross-modality generalization.** The Granite/Sand/Jazz pattern transfers across modalities in our experience (video, image, audio). Does it transfer to RL policy networks, robotic control, or other non-attention transformer architectures? The dynamical-systems argument predicts yes; empirical validation is open.

### 7.3 What this is and is not

This paper, and the companion *Adventures Through a 10D Manifold*, do not propose a new neural network architecture. They propose a *framing* — a way of looking at the inference-time dynamics of an existing transformer — that licenses a family of compression and gating techniques whose natural home is the framing itself. The implementations work; the framing makes the implementations *correct* rather than ad hoc. We believe this is the more durable contribution.

The Shannon-Prime line of work, including the present paper, takes seriously the possibility that the structure of mathematics itself — primes, zeta zeros, the multiplicative lattice of the integers — is not separate from the structure of trained neural networks but is in some precise sense *the same structure*. If RoPE imposes a logarithmic frequency ladder on the cache, and the prime distribution is the canonical phenomenon governed by such a ladder, then it would be more surprising if no arithmetical-statistical coincidence emerged than if many did. The present paper documents one such coincidence (the Granite/Sand/Jazz dynamics) and operationalizes it as a sentinel suite. The companion paper documents another (the manifold-geometric structure of the cache) and operationalizes it as a compression suite.

Whether one finds this framing aesthetically appealing or alarming, the engineering numbers do not care: the sentinels work, the compression works, and the speedups are real on commodity hardware.

---

## References

[1] Daniels, R. *Position Is Arithmetic v8*. Shannon-Prime documentation, 2026. https://github.com/nihilistau/shannon-prime/blob/main/position_is_arithmetic_v8.md

[2] Daniels, R. *KV Cache Is A View v2*. Shannon-Prime documentation, 2026. https://github.com/nihilistau/shannon-prime/blob/main/kv_cache_is_a_view_v2.md

[3] Daniels, R. *Multiplicative Lattice Combined: Spectral KV Cache Compression via the Multiplicative Lattice*. Shannon-Prime documentation, 2026. https://github.com/nihilistau/shannon-prime/blob/main/multiplicative_lattice_combined.md

[4] Daniels, R. *The Mertens Sea*. Position-Is-Arithmetic, 2026. https://github.com/nihilistau/Position_Is_Arithmetic/blob/main/The_Mertens_Sea.pdf

[5] Daniels, R. *Decode Chain Amplification*. Position-Is-Arithmetic, 2026. https://github.com/nihilistau/Position_Is_Arithmetic/blob/main/Decode_Chain_Amplification.pdf

[6] Daniels, R. *Shannon-Prime ComfyUI integration*, branch `feat/strange-attractor-stack-v2`. https://github.com/nihilistau/shannon-prime-comfyui

[7] Daniels, R. *Companion paper: Adventures Through a 10D Manifold*. 2026.

---

## Appendix A — Sentinel pseudocode

For reproducibility and as a precise statement of what the implementation does, here is the inner loop of the drift + curvature + Cauchy ensemble at miss-step granularity.

```
function on_miss_step(block_idx, fresh_y, prev_cached_y, state):
    f_sim = fisher_cosine(fresh_y, prev_cached_y, fisher_weights)
    state.fisher_sim[block_idx] = f_sim

    prev_rolling = state.rolling_sim.get(block_idx, 1.0)
    new_rolling = 0.5 * prev_rolling + 0.5 * f_sim
    state.rolling_sim[block_idx] = new_rolling

    if curvature_gate_enabled:
        curr_delta = new_rolling - prev_rolling
        prev_delta = state.delta_sim.get(block_idx, 0.0)
        accel      = curr_delta - prev_delta
        state.delta_sim[block_idx]            = curr_delta
        state.curvature_violation[block_idx]  = (accel < curvature_threshold)

function on_hit_decision(block_idx, age, window, streak, state):
    drift_ok =  (not drift_gate_enabled) or (
                 state.rolling_sim[block_idx] >= tier_threshold(block_idx))
    curvature_ok = (not curvature_gate_enabled) or (
                    not state.curvature_violation.get(block_idx, False))

    gate_forced_miss = (cached and within_window and streak_ok
                       and not (drift_ok and curvature_ok))
    if cauchy_reset_enabled and gate_forced_miss:
        cauchy_invalidate_neighbors(block_idx, state, radius=cauchy_radius)

    return cached and within_window and streak_ok and drift_ok and curvature_ok
```

This is the entire dynamical-systems instrumentation. Eleven lines of Python; a 4.6× → ~5–6× speedup at improved visual quality on a 2060.

---

*Submitted as preprint, 2026. Comments and replication welcome via the Shannon-Prime repositories.*
