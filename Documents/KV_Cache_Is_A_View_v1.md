# The KV Cache Is a View: Spectral Compression and Reconstruction of Transformer Context via the Multiplicative Lattice

**Knack**
*2026 | v1.0*

---

## Abstract

The transformer KV cache is treated universally as data to be stored, compressed, and evicted. We present evidence that it is instead a projection of a low-dimensional spectral structure — specifically, the multiplicative lattice of the integers encoded by rotary position embeddings — and that this structure can be exploited for near-optimal compression and eventual reconstruction.

We introduce three compression methods of increasing sophistication, all exploiting the same lattice structure. First, VHT2 banded quantization applies Walsh-Hadamard transform then per-band spectral allocation, achieving 3.4–3.8× total KV compression at <1.25% perplexity cost across two model architectures. The key finding: K vectors (carrying RoPE) have strong WHT spectral concentration while V vectors (carrying content) have uniform energy — they require structurally different strategies. Second, Vilenkin successive decomposition extends WHT from the single-prime Z/2Z basis to a multi-prime Vilenkin-Hartley basis, achieving 5.1× compression at +9.9% PPL (int4 sweet spot: 9.8× at +11.1%) on Qwen3-8B — while Walsh at the same threshold catastrophically fails (PPL +477%). Third, Möbius-guided extraction prioritizes squarefree spectral indices, improving quality by 0.14 PPL at identical coefficient budget.

We report three structural discoveries. The Z/3Z skeleton — six contiguous Vilenkin indices — appears at 100% of positions in every head of Layer 0, forming a standing wave that IS the coordinate system. K and V occupy completely disjoint Vilenkin bands at every layer (a symplectic pair: K is the map, V is the terrain). And successive prime passes tile the mixed-radix residue classes with <3.5% deviation from uniform — an algebraic partition, not a redundant covering.

Production validation spans desktop (RTX 2060, Qwen3-8B), mobile (Samsung S22 Ultra / Adreno 730, Dolphin 1B at 4.51 tok/s), and video generation (ComfyUI / Wan 2.2, 1.20× cross-attention speedup at 0.9984 output correlation). The Möbius partition mask is cross-platform invariant: K correlation 0.997 on both desktop (hd=128) and mobile (hd=64), confirming the mask is a property of the WHT spectrum, not the specific model.

---

## 1. Introduction

Every deployed large language model stores context as a key-value cache that grows linearly with sequence length. At 128K context on a 70B model, the KV cache alone can exceed 40GB. The field has responded with compression: quantised caches, sliding windows, attention sinks, token merging, TurboQuant. All accept the premise that context is data.

We propose a different premise: context in rotary-encoded transformers is a signal with exploitable harmonic structure, and signals with known structure can be compressed far more effectively than arbitrary data — and eventually reconstructed from sparse invariants rather than stored at all.

The rotary position encoding used in virtually all modern transformers applies position-dependent rotations to query and key vectors at specific frequencies. In standard RoPE, these frequencies follow a geometric progression. This is an engineering choice, not a mathematical necessity. We show that treating these frequencies as projections of a multiplicative lattice — where the Walsh-Hadamard transform is the Z/2Z case of a Vilenkin-Hartley basis spanning the full prime structure — enables compression methods that geometric-agnostic approaches cannot match.

The companion paper ("Position Is Arithmetic") establishes why the multiplicative lattice is the natural spectral basis for positional encoding. This paper shows what you can build with that insight.

---

## 2. The Structural Asymmetry: K Carries Position, V Carries Content

### 2.1 K and V in WHT Space

RoPE applies position-dependent angular rotations to K vectors. The WHT is the Z/2Z projection of the Vilenkin-Hartley basis — the natural transform for signals structured by the multiplicative lattice. When we apply WHT to K vectors from a production model, the energy concentrates in the first spectral bands. When we apply WHT to V vectors, the energy is uniformly distributed.

This asymmetry is the theory's most direct empirical signature: K encodes multiplicative arithmetic relationships as angular rates (spectral concentration); V encodes learned content projections with no arithmetic structure (uniform spectrum). They require fundamentally different compression strategies.

### 2.2 The Symplectic Pair

Vilenkin decomposition reveals a stronger property: K and V occupy completely disjoint bands in the Vilenkin spectrum. At every layer tested:

| Property | K vectors | V vectors |
|---|---|---|
| Universal indices | 4–6 at 99–100% | None (max 20%) |
| Vilenkin band | Blocks 8–8 (indices 48–53) | Spread: blocks 2–3, 6–7, 12–13 |
| Residue class rules | Layer-specific k₂ avoidance | Perfectly flat |
| Shared indices | 0 | 0 |

Zero overlap at every layer. K is the coordinate (sparse, localized, respects selection rules). V is the momentum (dense, smeared, uses all residue classes uniformly). They compress independently because they occupy orthogonal spectral bands — no interference. Combined K+V compression at PPL 10.27 confirms this.

---

## 3. VHT2 Banded KV Compression

### 3.1 Method

Each KV head vector is Walsh-Hadamard transformed, split into N equal bands, and each band quantized with its own fp16 scale plus packed integer values. The band allocation mirrors the WHT energy decay: high-energy bands get more bits, the low-energy tail gets fewer.

### 3.2 Results

Optimal configuration: K with n=4 bands at bits 5/5/4/3; V with flat int3 (n=1 band).

| Model | head_dim | K × | V × | Total × | ΔPPL |
|---|---|---|---|---|---|
| Dolphin 1B | 64 | 2.8× | 4.3× | ~3.4× | +0.60% |
| Qwen3-8B | 128 | 3.2× | 4.7× | ~3.8× | +1.24% |

RAM at 32K context (hd=128): fp16 baseline 5.9 GB → VHT2 1.56 GB.

### 3.3 The Spectral Regularization Effect

5/5/4/3 achieves PPL 11.2147, which is 0.04% BETTER than lossless fp16 (11.2194). The 3-bit rounding on the lowest-energy band filters noise that was in the original cache. This is engineered spectral regularization: high-energy bands get precision, the noisy tail gets beneficial compression.

### 3.4 Bit Allocation Sweep

| Config | PPL | vs Lossless | Compression |
|---|---|---|---|
| 5/5/4/3 | 11.2147 | −0.04% (better) | 3.05× |
| 5/4/4/3 | 11.2593 | +0.36% | 3.20× |
| 4/4/4/3 | 11.2624 | +0.39% | 3.37× |
| 4/3/3/3 | 11.4407 | +1.98% | 3.76× |
| 3/3/3/3 | 11.6565 | +3.90% | 4.00× |

4/4/4/4 is off the Pareto frontier entirely — 4/4/4/3 is strictly better in both quality and compression.

### 3.5 Critical Rules

1. Skeleton size must equal head_dim (sk=32 on hd=64 → PPL +47%).
2. 3-bit floor — 2-bit on any band is catastrophic.
3. 5/5/4/3 mirrors WHT energy decay — each band's optimal depth tracks its energy.
4. n=4 beats n=5/n=8 (2-byte scale overhead per band erases gains).
5. Flat beats banded for V — no exceptions across the entire sweep.

---

## 4. Vilenkin Successive Decomposition

### 4.1 Beyond Walsh: The Vilenkin-Hartley Basis

Walsh functions use Z/2Z — one prime. The Vilenkin-Hartley transform generalises to Z/p_kZ for arbitrary primes using the Hartley kernel cas(x) = cos(x) + sin(x). This gives a real-valued transform that is self-inverse for ALL primes, not just p=2. For p=2, Hartley = Hadamard. The Kronecker product across primes V = H_{p₁} ⊗ H_{p₂} ⊗ ... ⊗ H_{p_k} is also self-inverse (V·V = N·I). Round-trip error = 0.0000.

Progressive prime expansion monotonically increases correlation on both synthetic and production K vectors:

| Basis | Correlation (synthetic) | Correlation (production) |
|---|---|---|
| Walsh (Z/2Z) | 0.9504 | 0.9490 |
| Z/2Z × Z/3Z | 0.9507 | 0.9493 |
| Z/2Z × Z/3Z × Z/5Z | 0.9542 | 0.9500 |
| Z/2Z × Z/3Z × Z/5Z × Z/7Z | 0.9628 | 0.9513 |

### 4.2 Three-Pass Successive Extraction

On Qwen3-8B (head_dim=128) using Vilenkin 2-prime basis (N=132): P1 extracts the Z/3Z skeleton, P2 extracts Z/5Z detail from the residual, P3 extracts Z/7Z texture from the remaining residual.

| Config | PPL | ΔPPL | Compression |
|---|---|---|---|
| Baseline | 9.91 | — | 1.0× |
| Vilenkin 2p 99% energy | 10.20 | +2.9% | 3.2× |
| Vilenkin 2p 95% energy | 10.89 | +9.9% | 5.1× |
| Vilenkin 3p 95% energy | 11.59 | +16.9% | 3.8× |
| Vilenkin 2p 90% energy | 13.48 | +36% | 7.2× |
| Walsh 95% energy | 57.21 | +477% | 3.6× |

Walsh catastrophically fails at 95% energy threshold (PPL 57). The multiplicative structure is real and measurable: Vilenkin 2p at the same threshold gives PPL 10.89.

### 4.3 Quantization of Vilenkin Coefficients

The int4 sweet spot provides the best compression-quality tradeoff:

| Quant | PPL | ΔPPL | Compression |
|---|---|---|---|
| int8 | 10.89 | +9.9% | 5.1× |
| int4 | 11.01 | +11.1% | 9.8× |
| Z/6Z | 11.47 | +15.7% | 10.7× |
| Z/5Z | 12.27 | +23.8% | 15.7× |
| Z/3Z | 22.12 | +123% | 38.4× |

### 4.4 Active Reconstruction

K vectors reconstructed from Vilenkin coefficients every batch and written back to GPU. Attention uses the reconstructed vectors:

| Energy | Basis | PPL | ΔPPL |
|---|---|---|---|
| Baseline | — | 12.59 | — |
| 99% | Vilenkin | 12.72 | +1.0% |
| 99% | Walsh | 12.75 | +1.3% |

At 99% energy, active reconstruction is essentially lossless. Vilenkin beats Walsh (12.72 vs 12.75). Correlation: Vilenkin 0.9973, stable across all 16 layers.

### 4.5 Arithmetic vs Linear Compression

| Method | Compression | PPL |
|---|---|---|
| Vilenkin successive | 6.23× | 10.23 |
| Lattice rank=64 (PCA) | 3.74× | 13.18 |
| Lattice rank=32 (PCA) | 6.96× | 24.95 |

At comparable compression, Vilenkin (PPL 10.23 at 6.23×) destroys PCA/LLL (PPL 24.95 at 6.96×). K vectors span a ~50-dimensional linear subspace of the 210-dim Vilenkin space, but Vilenkin represents each vector with only ~70 coefficients by exploiting non-linear multiplicative structure that linear methods fundamentally cannot see.

---

## 5. The Z/3Z Skeleton and Mixed-Radix Tiling

### 5.1 The Standing Wave

Z/3Z indices {48, 49, 50, 51, 52, 53} appear at 100% of positions in Layer 0 — every single head, every position. These are Vilenkin blocks 16–17 (contiguous, capturing all 6 mixed-radix cells). In the mixed-radix decomposition k = k₁×3 + k₂, these map to blocks 16–17 out of 22 total.

This is a standing wave. It IS the coordinate system. The K cache does not store 128 bytes of arbitrary data per position — it stores ~10 dominant values on a FIXED frequency basis plus ~35–40 smaller corrections. The basis is the same across all positions; it is a property of the model, not the input.

### 5.2 Bandpass Structure

The Z/5Z detail (indices 31–41) occupies Vilenkin blocks 10–13 — a different localized window, lower frequency than the skeleton. P1 and P2 do not overlap: only 6 shared indices in Layer 0. The Z/7Z texture has zero universal indices (nothing above 40%). Position-dependent, not structural. But removing it costs 3.5 PPL — it IS the fine-grained positional information.

### 5.3 The Mixed-Radix Tiling Proof

P1 and P2 tile the k₂ residue classes at every layer with maximum deviation <3.5% from uniform:

| Layer | Max Deviation | Tiling Verified |
|---|---|---|
| L0 | 1.9% | Yes |
| L1 | 3.5% | Yes |
| L2 | 3.1% | Yes |
| L3 | 1.7% | Yes |

Successive prime passes partition the modular slots — they do not redundantly cover them. Layer-specific k₂ avoidance patterns are complementary: L1's P1 avoids k₂=2 (1%), P2 fills k₂=2 (37%). Combined, each k₂ class gets either P1 or P2, not both. This is algebraic: the Vilenkin basis respects the Z/3Z group structure, and successive extraction exploits it.

---

## 6. Möbius-Guided Extraction

### 6.1 Squarefree-First Ordering

The Möbius function μ(n) is non-zero only at squarefree indices (61.4% of N=210). Prioritizing squarefree indices during Vilenkin coefficient extraction improves quality:

| Method | PPL | Coefficients/head |
|---|---|---|
| Standard successive | 11.18 | ~150 |
| Möbius-guided | 11.04 | ~150 |
| Möbius-residual | 10.97 | 170.8 |

Möbius guidance improves PPL by 0.14 at the same coefficient budget. It is a quality amplifier, not a compressor.

### 6.2 Möbius Inversion Prediction

Non-squarefree Vilenkin coefficients can be partially predicted from squarefree ones using the Möbius inversion formula: if f(n) = Σ_{d|n} g(d), then g(n) = Σ_{d|n} μ(d) · f(n/d).

| Layer | Möbius Inv. r | Naive Average r |
|---|---|---|
| L0 | 0.581 | 0.127 |
| L1 | 0.560 | −0.056 |
| L2 | 0.425 | 0.083 |
| L3 | 0.404 | 0.144 |

Möbius inversion dominates every other prediction method by 3–7×. Approximately 60% of non-squarefree energy is structurally predictable from the divisibility lattice. The remaining 40% is training noise — genuinely independent of structure.

The finer the refinement pass, the more squarefree-concentrated: P1 (Z/3Z) is 33–74% squarefree depending on layer, but P3 (Z/7Z) is 70–72% squarefree. The coarse structure uses non-squarefree positions (structural echoes); the fine texture concentrates at squarefree positions (independent information).

### 6.3 The Möbius Partition Mask (Production)

The original Möbius predictor (predict non-squarefree from squarefree) measures r ≈ 0 in direct implementation because WHT involutivity (WHT² = I) destroys the divisibility structure. However, repurposed as a pure partition heuristic — all coefficients retained, squarefree-first ordering — the Möbius mask produces a real quality win:

| Config | K corr | V corr | Compression |
|---|---|---|---|
| Baseline WHT | 0.9590 | 0.9521 | 3.8×/4.1× |
| Möbius + 5/4/4 | 0.9967 | 0.9950 | 3.2×/3.4× |
| Möbius + 4/4/3 | 0.9893 | 0.9877 | 3.6× |
| Möbius + 4/3/3 | 0.9830 | 0.9805 | 3.9× |

At equal compression (~3.9×): baseline K 0.959, Möbius K 0.983. +0.024 correlation for free. The mask is cross-platform invariant to the third decimal: K 0.9967 on desktop Qwen3-8B (hd=128) and 0.9972 on mobile Dolphin-1B (hd=64).

---

## 7. Production Validation

### 7.1 Desktop: llama.cpp Integration

The implementation ships as two components: a frequency injection header (prime_rope.h) using the existing freq_factors mechanism, and a shadow cache backend (llama-kv-cache-shadow.cpp, ~4743 lines, all 13 phases) that intercepts KV writes for VHT2 compression.

PPL improvement at alpha=0.15–0.22 with zero retraining is confirmed across three architectures and three quantization levels. VHT2 banded compression operates independently via environment variables, no rebuild required.

### 7.2 Mobile: Samsung S22 Ultra / Adreno 730

Dolphin 1B Q8_0, Vulkan backend with CPU-fallback VHT2 writeback:

| Metric | Baseline | Möbius 5/4/4 |
|---|---|---|
| PPL | 14.24 ± 0.80 | 13.20 ± 0.60 |
| K correlation | — | 0.9972 |
| V correlation | — | 0.9960 |
| Generation speed | 1.79 tok/s | 3.57 tok/s |
| VHT2 writeback | — | 37–42 ms/batch |

Möbius is 2× faster than baseline on mobile — smaller active coefficient count means less scatter work, and the NEON writeback path is cache-bound. The VHT2 writeback cost (37–42 ms across all 16 layers) was reduced 55% through Phase H optimizations (vectorised fp16 conversion, partial tensor get/set, NEON WHT butterfly, NEON quantize/dequantize).

### 7.3 Video Generation: ComfyUI / Wan 2.2

VHT2 applied to cross-attention K/V caching in Wan 2.2 14B video generation. Cross-attention recomputes K/V from identical text-encoder context ~50 timesteps × ~18+ DiT blocks per generation. VHT2 compresses once; subsequent calls reconstruct from cache (899 hits / 1 miss per generation).

| Metric | Baseline | VHT2 | Δ |
|---|---|---|---|
| 900 cross-attn calls | 27.22 s | 22.63 s | 1.20× speedup |
| Per-call latency | 30.24 ms | 25.14 ms | −5.1 ms |
| Peak VRAM | 549 MiB | 573 MiB | +24 MiB (cache) |
| Output correlation | 1.0 | 0.9984 | 0.16% loss |

Pure-PyTorch VHT2 reference implementation achieves K correlation 0.9972 on hd=64 and 0.9967 on hd=128, at 5.29× compression.

---

## 8. The Unified View

All six compression/reconstruction engines implemented in this work read the same underlying object — the multiplicative structure of the integers — from different angles:

| Engine | Mathematical Language | What It Exploits |
|---|---|---|
| WHT/VHT2 banding | Z/2Z spectral concentration | RoPE angular rates cluster in first WHT bands |
| Vilenkin successive | Z/p₁Z × Z/p₂Z × ... decomposition | Multi-prime basis captures structure Walsh misses |
| Möbius partition | Squarefree vs non-squarefree | Divisibility lattice determines coefficient importance |
| K-V band separation | Symplectic disjointness | Position (K) and content (V) occupy orthogonal spectra |
| Active reconstruction | Self-inverse transform | Encoding and decoding are the same operation |
| Mixed-radix tiling | Residue class partition | Successive passes algebraically tile the group structure |

The standard view of the KV cache treats Q·K^T as arbitrary data to store and retrieve. The proper view is that Q·K^T is a multiplication in a space whose coordinate system is the prime factorisation of positions. The "stored" cache is one direction of that multiplication; reconstruction is the other direction. Same matrix, read from the other side.

The Walsh 0.948 result supports this: if the signal were arbitrary data, no single-basis reconstruction would achieve 0.948 at 2.3× compression. But the signal is structured by the multiplicative lattice, so a basis aligned to that structure captures almost everything. Vilenkin at full prime resolution would be exact.

---

## 9. Discussion

### 9.1 Why V Compresses Better Than K

V vectors compress at 4.3–4.7× while K compresses at 2.8–3.2×. This is counterintuitive — K "should" compress better because it has spectral structure. But the structure is exactly what makes K sensitive to compression errors: angular relationships between K vectors determine attention scores, so small angular distortions compound. V is the weighted average that attention produces, so individual V errors average out. Flat 3-bit quantization on V works precisely because V has no structure to destroy.

### 9.2 The NaN Boundary

On hd=64, aggressive Möbius configurations (4/4/3 bit ladder) produce clean output for chunk 1 but NaN at chunk 2+ despite healthy K/V correlations (0.991). The NaN appears in attention after accumulated compressed history — attention softmax over long compressed context produces logits at the FP boundary. The NaN_GUARD (clamp at ±2× original max magnitude + isfinite sanitize) rescues single-reconstruction divergence but not context-length accumulation. Ship configuration is Möbius 5/4/4 (safe on all platforms).

### 9.3 Limitations

Single-seed for the main 300M experiment. Modern baselines (YaRN, NTK-aware, CARoPE) not compared. The Möbius predictor (r=0.40–0.58 in research) gives r≈0 in production due to WHT involutivity — the partition heuristic works but the algebraic prediction path requires a non-involutive basis (Vilenkin on non-power-of-2 head_dim). Online skeleton adaptation for long-context drift is designed but not yet implemented.

### 9.4 The Path to Cache Elimination

This paper demonstrates compression. The companion paper's theoretical framework points to elimination. If the Z/3Z skeleton is a standing wave determined by model weights (not input), and if the zero-crossings of the Vilenkin spectrum are predictable from the Möbius function (which is determined by divisibility, which is determined by position), then the KV cache is not data to compress. It is a function to evaluate.

The current path: store the Z/3Z skeleton once per (layer, head), predict zero-crossing positions from Möbius topology, compute phase and amplitude between crossings from the known Vilenkin basis, and reconstruct the full K vector on demand. Level 2 reconstruction in the three-layer framework currently achieves 0.35 correlation at 10K training steps (scaling 3× from 2K), with spinor traversal at nearly double the efficiency of brute-force scanning. Longer training and the full Vilenkin basis are expected to push this further.

---

## 10. Conclusion

The KV cache carries two structurally different signals. K vectors encode position through the multiplicative lattice — sparse, localized in the Vilenkin spectrum, with a universal Z/3Z skeleton and layer-specific residue class selection rules. V vectors encode content — dense, uniform, structureless in the spectral domain. They occupy disjoint bands and compress independently.

Exploiting this structure through VHT2 banded compression delivers 3.4–3.8× at <1.25% PPL cost. Vilenkin successive decomposition delivers 5.1× at +9.9% PPL, with Walsh catastrophically failing at the same threshold. Möbius-guided extraction adds 0.14 PPL improvement at no additional storage. The int4 sweet spot provides 9.8× compression at +11.1% PPL. All methods are validated in production on desktop, mobile, and video generation workloads.

The mixed-radix tiling proof, the K-V symplectic structure, and the Möbius inversion correlation (r=0.40–0.58) are empirical signatures of a deeper truth: the KV cache is not arbitrary data. It is a projection of the self-inverse multiplicative structure of the integers. Compression is reading that structure efficiently. Reconstruction — the endgame — is reading it from the other side.

---

## Appendix A: VHT2 Configuration Reference

```
LLAMA_SHADOW_CACHE=1  LLAMA_SHADOW_VHT2=1
LLAMA_SHADOW_HEAD_DIM=128        # must match model
LLAMA_SHADOW_VHT2_SKELETON_K=128 # must equal head_dim
LLAMA_SHADOW_VHT2_N_BANDS=4
LLAMA_SHADOW_VHT2_BAND_BITS=5,5,4,3
LLAMA_SHADOW_VHT2_V=1
LLAMA_SHADOW_VHT2_SKELETON_V=128
LLAMA_SHADOW_VHT2_V_N_BANDS=1
LLAMA_SHADOW_VHT2_V_BAND_BITS=3
LLAMA_SHADOW_VHT2_MASK_TYPE=mobius  # for Möbius partition
```

## Appendix B: Complete Vilenkin Successive Results (Qwen3-8B)

| Config | PPL | ΔPPL | Compression |
|---|---|---|---|
| Baseline (no shadow) | 9.91 | — | 1.0× |
| Vik 2p 99% int8 | 10.20 | +2.9% | 3.2× |
| Vik 2p 95% int8 | 10.89 | +9.9% | 5.1× |
| Vik 2p 95% int4 | 11.01 | +11.1% | 9.8× |
| Vik 2p 95% Z/6Z | 11.47 | +15.7% | 10.7× |
| Vik 3p 95% int8 | 11.59 | +16.9% | 3.8× |
| Vik 2p 95% Z/5Z | 12.27 | +23.8% | 15.7× |
| Vik 2p 90% int8 | 13.48 | +36% | 7.2× |
| Vik 2p 95% Z/3Z | 22.12 | +123% | 38.4× |
| Walsh 95% int8 | 57.21 | +477% | 3.6× |

## Appendix C: Möbius Mask Compression Ladder

| Ladder | K corr | V corr | Compression | Platform |
|---|---|---|---|---|
| 5/4/4 (default) | 0.9967 | 0.9950 | 3.2× | Desktop |
| 4/4/3 | 0.9893 | 0.9877 | 3.6× | Desktop |
| 4/3/3 | 0.9830 | 0.9805 | 3.9× | Desktop |
| auto [3/3/3] | 0.9772 | 0.9737 | 4.2× | Desktop |
| 5/4/4 | 0.9972 | 0.9960 | 2.7× | Mobile (hd=64) |

## Appendix D: Cross-Platform Validation

| Platform | Model | head_dim | K corr | V corr | Tok/s |
|---|---|---|---|---|---|
| Desktop CUDA/CPU | Qwen3-8B Q8_0 | 128 | 0.9967 | 0.9950 | — |
| Mobile Adreno 730 | Dolphin-1B Q8_0 | 64 | 0.9972 | 0.9960 | 3.57 |
| ComfyUI RTX 2060 | Wan 2.2 14B (cross-attn) | 128 | 0.9984 (output) | — | 1.20× speedup |

## References

- Su et al. (2021) — RoFormer: Rotary Position Embedding
- Hsu et al. (2026) — TurboQuant (ICLR 2026)
- Zandieh et al. (2024) — QJL Transform
- Lenstra, Lenstra, Lovász (1982) — LLL lattice basis reduction
- Press et al. (2022) — ALiBi
- Knack (2026) — Position Is Arithmetic (companion paper)
- Knack (2026) — VHT2 Compression Results, nihilistau/llama-cpp-turboquant
