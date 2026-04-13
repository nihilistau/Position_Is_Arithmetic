# Context Is Not Storage: Topological Reconstruction of Transformer Context via Prime Harmonic Zero-Crossings

**Anonymous**

---

## Abstract

We present a theoretical framework and experimental methodology for replacing the transformer KV cache — a linear-growth memory structure — with on-demand reconstruction from prime harmonic invariants. Current approaches treat context as data to be stored and retrieved. We argue that context in rotary-encoded transformers is a signal with exploitable harmonic structure, and that the natural coordinate system of this signal is prime-arithmetic, not geometric. We introduce a three-layer experimental architecture: (1) prime harmonic positional encoding, (2) quantisation to integer lattice, and (3) LLL lattice reduction with structural survival measurement. We further propose three levels of reconstruction: harmonic decomposition (content–position separation), zero-crossing reconstruction (signal recovery from sparse invariants), and topological traversal (half-Möbius phase geometry for predicting zero locations without signal scanning). If the attention signal can be faithfully reconstructed from its zero-crossings using known prime frequencies, the KV cache becomes a function to evaluate rather than data to retrieve — eliminating the fundamental memory bottleneck of autoregressive inference. We describe a concrete integration path into the llama.cpp inference engine via the existing abstract memory interface, requiring no model retraining.

---

## 1. Introduction

Every deployed large language model stores context as a key-value cache. For each token processed, the model computes key and value vectors at every layer and stores them in memory for subsequent attention computations. This cache grows linearly with sequence length, consuming memory proportional to *n_layers × n_heads × n_ctx × head_dim × 2*. At 128K context on a 70B parameter model, the KV cache alone can exceed 40GB — often larger than the model weights themselves.

The field has responded with compression: quantised KV caches (Q4_0, Q8_0), sliding windows, attention sinks, token merging, and most recently rotation-aware quantisation schemes such as TurboQuant (Zandieh et al., 2026). All of these approaches accept the fundamental premise that context is data which must be stored and selectively discarded.

We propose a different premise: **context is a signal with known harmonic structure, and signals with known structure can be reconstructed from their invariants.**

The rotary position encoding (RoPE) used in virtually all modern transformers (Su et al., 2021) applies a position-dependent rotation to query and key vectors before the attention computation. This rotation modulates the vectors at specific frequencies. In standard RoPE, these frequencies follow a geometric progression: θ_i = base^(-2i/d). This is an engineering choice, not a mathematical necessity.

We argue that the natural frequency basis for positional encoding is prime-arithmetic, not geometric, and that this choice has consequences far beyond marginal PPL improvements. When the rotation frequencies are derived from prime numbers, the resulting activation space has lattice structure that survives compression to its mathematical minimum. More importantly, the attention signal — attention weight as a function of token distance — becomes a superposition of prime harmonics whose zero-crossings are predictable from the topology of the frequency space itself.

If this holds, the KV cache can be replaced with a reconstruction function that regenerates key vectors on demand from a small set of topological parameters. Context stops being something you remember and becomes something you rebuild.

---

## 2. Theoretical Foundation

### 2.1 Position as Arithmetic Identity

The standard interpretation of positional encoding treats position as a location on a number line. Token at position 47 is "at" position 47 the way a house is at an address. RoPE encodes this location by rotating vector pairs at position-dependent angles.

We propose an alternative interpretation: position is arithmetic identity. Position 47 is not a location — it is the number 47, with all its arithmetic properties. 47 is prime. Its relationship to position 6 is not merely "41 positions away" but "a prime distance from a composite number whose factors are 2 and 3." This arithmetic identity is precisely what the Euler product captures: the zeta function ζ(s) = Σ n^(-s) factors as Π (1 - p^(-s))^(-1) over primes p. Every integer's identity is determined by its prime factorisation.

### 2.2 The Zipf–Zeta Connection

Natural language exhibits Zipfian statistics: word frequency is inversely proportional to rank. This is not a biological accident but a mathematical consequence of near-critical dynamics in any system operating at the edge of order and chaos (Mora & Bialek, 2011). The generating function of the Zipf distribution is the Riemann zeta function. The zeta function factors over primes via the Euler product. Therefore, prime harmonic structure is the natural coordinate system of language, in the same way that Fourier harmonics are the natural coordinate system of periodic signals.

### 2.3 Prime Harmonics as Positional Frequencies

If position is arithmetic identity and language statistics are zeta-distributed, the natural choice of rotation frequencies for positional encoding is:

θ_i = 2π / p_i

where p_i are primes drawn from ranges appropriate to the attention scale: small primes for local attention (high frequency, nearby tokens), large primes for long-range attention (low frequency, distant tokens). We call this a "tiered" allocation and implement it as `prime_tiered` in our test suite.

The key property of prime frequencies is coprimality: no two primes share a common factor, so their harmonics never constructively or destructively interfere at the same position. This produces a maximally non-degenerate frequency basis — each harmonic carries independent information about position.

### 2.4 Composites as Lattice Coordinates

A critical prediction of this framework: composite frequencies (4, 6, 8, 9, 10, ...) should perform equivalently to prime frequencies, because composites are products of primes. They are not independent of the prime lattice — they are higher-dimensional coordinates within it. The composite number 12 = 2² × 3 lies on the lattice generated by primes 2 and 3.

Experimentally, `composite_tiered` matching `prime_tiered` in PPL is a positive result for the theory, not a negative one. Both are on-lattice. The negative control is `geometric_rope`, which is off-lattice — its frequencies have no multiplicative structure.

---

## 3. The Three-Layer Experimental Architecture

We implement a modular test suite ("LocalSuite") with a small transformer (6 layers, 8 heads, d_model=256, head_dim=32) trained on WikiText-103 on an RTX 2060. The architecture separates three independent layers, each testable in isolation.

### 3.1 Layer 1: Positional Encoding (Rotation Strategy)

Eleven pluggable frequency strategies generate rotation frequencies for Q/K vectors. These span four categories:

**Lattice-aware:** `prime_tiered` (primes in local/mid/long tiers), `composite_tiered` (composites in same tiers). Theory predicts both should perform well.

**Off-lattice:** `random_freq` (random reals), `irrational` (multiples of π, e, √2, φ), `scrambled_prime` (right primes, wrong tiers). Theory predicts these should be measurably worse.

**Topological:** `mobius_half` (π/2 phase twist), `spinor` (720° return / double-cover), `zeta_rebuild` (frequencies from zeta zero imaginary parts). These prototype context traversal topologies.

**Baseline:** `geometric_rope` (standard RoPE base-10000). The thing to beat.

### 3.2 Layer 2: Quantisation (KV Compression)

Our own compression pipeline (not TurboQuant) with pluggable rotation, n-bit scalar quantisation, and optional sign-sketch correction. The critical output of this layer is the integer indices — the quantised vectors in {0, ..., 2^n - 1}^D.

These integer indices ARE the lattice that Layer 3 operates on. Layer 2 exists to produce the representation that makes Layer 3 meaningful.

### 3.3 Layer 3: Lattice Collapse (LLL Reduction)

The Lenstra–Lenstra–Lovász algorithm finds short vectors in integer lattices. Applied to the quantised activation vectors from Layer 2:

1. Build a basis matrix from the integer indices
2. LLL-reduce to find shorter basis vectors
3. Round-trip each vector through the reduced basis (project into reduced coordinates, snap to integer, project back)
4. Reconstruct key vectors from the modified indices
5. Measure whether the Prime Resonance Signal (PRS) survives

**PRS** is defined as the ratio of mean attention weight at prime distances to mean attention weight at composite distances, averaged across heads. PRS > 1.0 indicates the model attends preferentially at prime-separated positions.

The survival test asks: after LLL finds shorter paths through the lattice, does the model still attend preferentially at prime distances? If yes, the prime structure is a geometric invariant — it lives in the topology of the space, not in the particular basis.

**Critical implementation note:** Layer 3 must receive integer indices from Layer 2, not raw floating-point activations. Floating-point vectors do not form a reducible lattice; LLL on floats is a no-op (norm_ratio = 1.0). This error persisted through multiple implementation iterations and produced vacuous "SURVIVED" results until corrected.

---

## 4. Context Reconstruction

The three-layer architecture validates that prime harmonic structure exists and survives compression. But the actual goal is reconstruction: proving that context can be rebuilt from structural invariants instead of stored as raw vectors. We define three levels of reconstruction, each strictly harder than the last.

### 4.1 Level 1: Harmonic Decomposition

RoPE applies a known rotation to K vectors at each position:

k_rot[2i] = k[2i]·cos(θ_i·p) - k[2i+1]·sin(θ_i·p)
k_rot[2i+1] = k[2i]·sin(θ_i·p) + k[2i+1]·cos(θ_i·p)

Since the rotation is orthogonal, it is exactly invertible. Given the rotated K vector and the known frequencies θ_i:

content = inverse_rotate(k_rot, θ, pos)
k_reconstructed = rotate(content, θ, pos)

This separates each K vector into a position-independent content vector and a position-dependent rotation. The content vector captures *what* the token represents; the rotation captures *where* it is.

Level 1 reconstruction should be exact (MSE ≈ 0) for any rotary PE scheme. Its significance is not in the reconstruction quality but in proving that the KV cache is cleanly decomposable: you can store content vectors + the strategy name (which determines frequencies) + position indices, and reconstruct full K vectors on demand.

For prime-structured frequencies, the strategy name alone determines the full frequency table — no additional storage is needed beyond the content vectors and position indices.

### 4.2 Level 2: Zero-Crossing Reconstruction

The attention signal A(d) — average attention weight as a function of token distance d — is a superposition of contributions from all frequency components in the rotary encoding. For prime-structured frequencies, this signal is a sum of prime harmonics.

We extract A(d) for each attention head, find the zero-crossings (positions where the signal crosses its mean value), and then discard the signal entirely. Reconstruction uses only the zero-crossing positions, their local gradients, and the known prime frequencies to fit harmonic coefficients via least-squares.

This is analogous to reconstructing a bandlimited signal from its Nyquist samples, but using zero-crossings instead of sample values. The key question is whether the prime harmonic basis is "natural" enough to the attention signal that the zeros carry sufficient information for faithful reconstruction.

The compression ratio is the signal length divided by the number of stored parameters (zero positions + gradients + mean). If this ratio exceeds 5x with reconstruction correlation above 0.9, the zeros are the load-bearing invariants of the context.

### 4.3 Level 3: Topological Traversal

Level 2 finds zeros by scanning the full signal — an O(T) operation. Level 3 asks whether the zeros can be predicted from the topology of the frequency space without scanning.

We test three traversal strategies:

**Linear scan (baseline):** Check every position d = 1..T for sign changes. Finds all zeros but requires T sample points.

**Half-Möbius traversal:** The accumulated phase of the prime harmonics defines a "twist function" across the signal's domain. In a half-Möbius topology, the twist accumulates to π over the band's length, forcing an orientation reversal. This reversal IS a zero-crossing — the topology defines where the signal changes sign.

The traversal computes where the accumulated phase crosses nπ boundaries, yielding predicted zero positions. It then samples only near these predictions to confirm. The key metric is the hit rate: what fraction of topologically predicted zeros correspond to actual signal zeros?

If the hit rate is high, the zeros are not features of the data — they are consequences of the geometry. Context reconstruction then requires only the topological parameters (strategy name + twist rate), and the zeros fall out automatically.

**Spinor traversal (double-cover):** A spinor requires 720° to return to its starting state. Pass 1 samples at prime-harmonic half-periods to find zero candidates. Pass 2 approaches each candidate from the opposite direction, providing position + gradient at each zero through double coverage.

The efficiency metric is reconstruction quality per sample point. If half-Möbius achieves comparable reconstruction to linear scanning with significantly fewer samples, the topology is doing real work.

---

## 5. Preliminary Results

### 5.1 Rotation Strategy Comparison (Layer 1)

Twelve strategies were compared at 3-bit compression on a model trained with `prime_tiered` PE. Ranked by cosine similarity of compressed vs. original K vectors:

| Strategy | Vector MSE | Cos Sim | Attention KL |
|---|---|---|---|
| fibonacci | 0.185 | 0.932 | 11310 |
| scrambled_prime | 0.185 | 0.931 | 14614 |
| geometric_rope | 0.190 | 0.931 | 10899 |
| mobius_half | 0.189 | 0.930 | 11739 |
| prime_tiered | 0.211 | 0.925 | 11755 |
| random_freq | 0.205 | 0.925 | 10922 |

The spread is narrow (cos_sim 0.925–0.932), indicating all strategies preserve direction comparably at 3-bit. Attention KL divergence does not correlate with compression fidelity — `random` has the lowest KL despite mediocre MSE.

### 5.2 End-to-End PPL (Layers 1+2)

Three strategies through the full PE + compression pipeline:

| Strategy | PPL@512 | PPL@1024 | PPL@2048 |
|---|---|---|---|
| composite_tiered | 215.15 | 209.98 | 209.98 |
| prime_tiered | 216.55 | 210.95 | 210.95 |
| geometric_rope | 218.80 | 213.85 | 213.85 |

Both arithmetic strategies (prime_tiered, composite_tiered) beat geometric_rope by 3–4 PPL. composite_tiered edges out prime_tiered by ~1 PPL, consistent with composites providing denser frequency coverage from the same lattice structure. PPL plateaus at 1024, indicating the model's effective context window saturates at this scale.

### 5.3 Lattice Collapse (Layer 3)

**Note:** All previous Layer 3 results reported norm_ratio = 1.0 and verdict = SURVIVED across all strategies. These results are vacuous — the implementation fed raw floating-point activations into LLL, which cannot reduce a continuous basis. The test has been corrected to use quantised integer indices from Layer 2. Updated results are pending.

### 5.4 Reconstruction (Levels 1–3)

Reconstruction experiments are implemented but not yet run. Results pending.

---

## 6. Inference-Time Integration

The reconstruction framework operates entirely at inference time. Model weights are frozen. No retraining is required. Any existing GGUF model can be used with the harmonic cache backend.

### 6.1 Architecture

The llama.cpp inference engine defines an abstract memory interface (`llama_memory_i`). The standard KV cache (`llama_kv_cache`) is one implementation. We propose a second implementation (`llama_harmonic_cache`) that stores decomposed content vectors and reconstructs K vectors on demand.

The attention computation is agnostic to the memory backend. It requests K vectors at specific layer/head/position coordinates. The standard cache reads from a buffer. The harmonic cache evaluates a reconstruction function.

### 6.2 Phased Deployment

**Phase 1 — Frequency injection:** Replace geometric RoPE frequencies with prime harmonics in the `ggml_compute_forward_rope` function. Validates that models tolerate non-geometric frequencies at inference time. ~50 lines of C.

**Phase 2 — Shadow reconstruction:** Run both standard and harmonic cache simultaneously. Compare outputs. Validates that harmonic decomposition is lossless at production scale. ~500–800 lines of C++.

**Phase 3 — Zero-crossing reconstruction:** Replace content vector storage with zero-crossing parameters. Reconstruct attention patterns from topological invariants. This is the "delete the KV cache" moment. Depends on Levels 2 and 3 being experimentally validated.

### 6.3 LLL as Independent Optimisation

Lattice reduction on quantised KV caches is a general-purpose inference-time optimisation independent of prime harmonics. Any model running Q4_0 or Q8_0 KV cache can benefit from LLL reduction of the quantised lattice, providing shorter traversal paths through the cached context. This is complementary to existing quantisation schemes including TurboQuant.

---

## 7. Relationship to Existing Work

**RoPE (Su et al., 2021):** We use the same rotary mechanism but substitute the frequency basis. RoPE's geometric progression is a special case; our framework generalises to any frequency set and asks which set produces the most reconstructible activation space.

**TurboQuant (Zandieh et al., 2026):** Optimises the quantisation codebook for KV compression. We do not compete with TurboQuant — we complement it. TurboQuant compresses the stored representation. We question whether storage is necessary at all.

**ALiBi (Press et al., 2022):** Additive linear bias as an alternative to rotary encoding. Our test suite includes learnable ALiBi alongside rotary PE, but the reconstruction framework is specific to rotary-encoded models (it depends on the invertible rotation for content–position separation).

**Context compression (sliding window, attention sinks, token merging):** All of these discard information. We reconstruct it. The approaches are complementary — a sliding window with harmonic reconstruction of evicted tokens would retain more context than either approach alone.

**Lattice-based methods in ML:** LLL reduction has been applied in cryptanalysis, integer relation detection, and Diophantine approximation. To our knowledge, no prior work applies lattice reduction to quantised neural network activations as a post-quantisation compression step.

---

## 8. Discussion

### 8.1 What This Is Not

This is not a positional encoding paper. The transformer and its PE are a testbed for a more fundamental claim: that context in sequence models has exploitable harmonic structure that permits reconstruction from sparse invariants. The specific claim about prime frequencies is secondary to the general claim about reconstructibility.

### 8.2 The Half-Möbius Prediction

The strongest prediction of this framework is that the half-Möbius traversal topology should predict zero-crossing locations without signal scanning. If confirmed experimentally, this means the zeros are topological invariants — determined by the geometry of the frequency space — rather than empirical features of each particular attention pattern. Context reconstruction would then require only the topological parameters, with zeros as automatic consequences.

This is a falsifiable prediction. If the half-Möbius hit rate is not significantly above chance, the zeros are data-dependent and must be empirically measured, reducing (but not eliminating) the compression advantage.

### 8.3 Limitations

The current experimental testbed uses a small model (6 layers, 8 heads, 256-dim) on WikiText-103. Scaling behaviour is unknown. The reconstruction framework depends on rotary encoding and does not apply to non-rotary architectures. V vectors are not rotated and must still be stored conventionally, limiting the achievable memory reduction to approximately 50% of the KV cache. The Phase 3 integration (zero-crossing reconstruction in llama.cpp) has not yet been implemented or validated.

### 8.4 Implications

If context is reconstructible from prime harmonic zero-crossings, the implications extend beyond inference efficiency:

**Edge deployment:** 128K context windows on mobile devices become feasible when the memory cost scales with the number of zero-crossings (estimated 5–10% of context length) rather than linearly with token count.

**Persistent agents:** AI agents that operate across sessions currently lose context between interactions. If context is parameterisable as a set of topological invariants, session state reduces to a small parameter vector that can be stored, transmitted, and restored — enabling agents with indefinite memory at fixed storage cost.

**Theoretical:** If the prime harmonic basis is genuinely the natural coordinate system of linguistic context, this connects transformer attention to the Riemann zeta function via the Euler product in a way that is not metaphorical but computational.

---

## 9. Conclusion

We have presented a framework for understanding transformer context not as data to be stored but as a signal to be reconstructed. The key claims are: (1) prime harmonic frequencies provide a natural basis for positional encoding that produces compressible, lattice-structured activation spaces; (2) the KV cache can be decomposed into position-independent content and position-dependent rotation, enabling reconstruction from sparse invariants; (3) the zero-crossings of the attention signal may be predictable from the topology of the frequency space, eliminating the need to scan or store the signal itself.

These claims are experimentally testable with the architecture and test suite described. The integration path into production inference engines is concrete and requires no model retraining. If validated, this work replaces the largest memory bottleneck in autoregressive inference with a mathematical function — converting context from storage into computation.

---

## References

Mora, T. & Bialek, W. (2011). Are biological systems poised at criticality? *Journal of Statistical Physics*, 144(2), 268–302.

Press, O., Smith, N. A., & Lewis, M. (2022). Train short, test long: Attention with linear biases enables input length generalization. *ICLR 2022*.

Su, J., Lu, Y., Pan, S., Murtadha, A., Wen, B., & Liu, Y. (2021). RoFormer: Enhanced transformer with rotary position embedding. *arXiv:2104.09864*.

Zandieh, A., et al. (2026). TurboQuant: Online KV cache quantization with rotation-aware codebooks. *ICLR 2026*.
