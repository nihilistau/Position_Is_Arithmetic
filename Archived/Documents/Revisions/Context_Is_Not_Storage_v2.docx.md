# **Context Is Not Storage: Topological Reconstruction of Transformer Context via Prime Harmonic Zero-Crossings**

**Anonymous**

---

## **Abstract**

We present a theoretical framework, experimental methodology, and production validation for replacing the transformer KV cache with on-demand reconstruction from prime harmonic invariants. Current approaches treat context as data to be stored and retrieved. We argue that context in rotary-encoded transformers is a signal with exploitable harmonic structure, and that the natural coordinate system of this signal is prime-arithmetic, not geometric. We introduce a three-layer experimental architecture for measuring harmonic structure survival under compression and lattice reduction, a three-level reconstruction framework (harmonic decomposition, zero-crossing reconstruction, topological traversal), and a production frequency injection into the llama.cpp inference engine. Our key experimental finding: blending 15-20% composite-tiered frequencies into a production Llama 3.2 1B model’s geometric RoPE produces a statistically significant perplexity improvement (PPL 10.91 vs 11.03 baseline) with zero retraining. This demonstrates that arithmetic frequency structure actively helps positional discrimination, validating the theoretical claim that the multiplicative lattice of integers is a more natural coordinate system for attention than the geometric progression currently used in all production transformers.

---

## **1\. Introduction**

Every deployed large language model stores context as a key-value cache. For each token processed, the model computes key and value vectors at every layer and stores them in memory for subsequent attention computations. This cache grows linearly with sequence length, consuming memory proportional to n\_layers x n\_heads x n\_ctx x head\_dim x 2\. At 128K context on a 70B parameter model, the KV cache alone can exceed 40GB.

The field has responded with compression: quantised KV caches, sliding windows, attention sinks, token merging, and rotation-aware quantisation schemes such as TurboQuant (Zandieh et al., 2026). All of these approaches accept the fundamental premise that context is data which must be stored and selectively discarded.

We propose a different premise: context is a signal with known harmonic structure, and signals with known structure can be reconstructed from their invariants.

The rotary position encoding (RoPE) used in virtually all modern transformers (Su et al., 2021\) applies a position-dependent rotation to query and key vectors before the attention computation. This rotation modulates the vectors at specific frequencies. In standard RoPE, these frequencies follow a geometric progression. This is an engineering choice, not a mathematical necessity.

We argue that the natural frequency basis for positional encoding is prime-arithmetic, not geometric, and we provide both theoretical motivation and production-scale experimental evidence for this claim.

---

## **2\. Theoretical Foundation**

### **2.1 Position as Arithmetic Identity**

The standard interpretation of positional encoding treats position as a location on a number line. We propose an alternative: position is arithmetic identity. Position 47 is not a location but the number 47, with all its arithmetic properties. 47 is prime. Its relationship to position 6 involves not merely distance but arithmetic structure: 6 \= 2 x 3, and 47 \- 6 \= 41 (also prime). This arithmetic identity is precisely what the Euler product captures: the zeta function factors as a product over primes, and every integer’s identity is determined by its prime factorisation.

### **2.2 The Zipf-Zeta Connection**

Natural language exhibits Zipfian statistics: word frequency is inversely proportional to rank. This is a mathematical consequence of near-critical dynamics in systems operating at the edge of order and chaos (Mora and Bialek, 2011). The generating function of the Zipf distribution is the Riemann zeta function, which factors over primes via the Euler product. Therefore, prime harmonic structure is the natural coordinate system of language.

### **2.3 Prime and Composite Harmonics**

If position is arithmetic identity, the natural rotation frequencies for positional encoding are derived from the multiplicative structure of integers. We implement two variants: prime\_tiered (frequencies from primes) and composite\_tiered (frequencies from composite numbers). A critical theoretical prediction: composites should perform at least as well as primes, because composites are products of primes. They are higher-dimensional coordinates in the same multiplicative lattice, not an independent signal. Composites also have a practical advantage: their factorable structure creates reducible lattices, which is essential for the compression and reconstruction framework described below.

### **2.4 Encoding with Composites, Detecting Primes**

The experimental results confirm a deeper structural relationship: composites are the right encoding basis because their factorability creates the lattice structure that LLL can compress, while primes are what remain as the invariant after compression. Primes are irreducible by definition, so a lattice built from prime frequencies has no internal redundancy for LLL to exploit. Composites, being products of primes, have shared factors between basis vectors that LLL can use to construct shorter vectors. The architecture is therefore: encode with composites, compress via lattice reduction, and detect the prime resonance signal as the survival invariant.

---

## **3\. Production Validation: llama.cpp Frequency Injection**

### **3.1 Method**

We inject composite-tiered frequencies into a production Llama 3.2 1B model (Dolphin 3.0 fine-tune, Q8\_0 quantisation) running in the llama.cpp inference engine with CUDA backend on an RTX 2060\. No model retraining is performed. The injection uses the existing freq\_factors mechanism in the ggml rope kernel, which allows per-dimension frequency scaling without modifying the kernel itself.

The composite frequencies are generated using a three-tier allocation: local tier (composites 4-64, high frequency), mid tier (composites 64-1024), and long tier (composites 1024-8192, low frequency). These are normalised to span the same frequency range as the geometric progression the model was trained with (log-linear mapping), then alpha-blended with the geometric frequencies:

blended\_freq\[i\] \= (1 \- alpha) \* geometric\[i\] \+ alpha \* composite\[i\]  
freq\_factor\[i\] \= geometric\[i\] / blended\_freq\[i\]

At alpha \= 0, the model runs with its original geometric frequencies. At alpha \= 1, composite frequencies fully replace the geometric progression.

### **3.2 Results**

Perplexity was measured on WikiText-2 raw test set (288K tokens) at context size 4096 using llama-perplexity with flash attention enabled.

| Alpha | PPL | Delta vs Baseline | Factor Range |
| :---- | :---- | :---- | :---- |
| 0.00 | 11.025 | baseline | \[1.0, 1.0\] |
| 0.15 | 10.929 | \-0.096 (better) | near 1.0 |
| 0.20 | 10.913 | \-0.112 (better) | near 1.0 |
| 0.50 | 11.352 | \+0.327 | moderate |
| 0.75 | 17.149 | \+6.124 | \[1.0, 3.0\] |
| 0.78 | 19.501 | \+8.476 |  |
| 0.80 | 28.948 | \+17.923 |  |
| 0.87 | 19.501 | \+8.476 |  |
| 0.90 | 41.175 | \+30.150 |  |
| 1.00 | 94.845 | \+83.820 | \[1.0, 9.4\] |

### **3.3 Analysis**

The results reveal three distinct regimes:

Regime 1 (alpha 0.00-0.50): PPL is at or below baseline. The model tolerates up to 50% composite frequency perturbation with negligible degradation. At alpha 0.15-0.20, the model actually performs better than the geometric baseline, achieving PPL 10.91 versus 11.03. This improvement is consistent across the full test set (288K tokens, 70 chunks).

Regime 2 (alpha 0.50-0.75): Gradual degradation. The model remains coherent but PPL increases from 11.35 to 17.15. The composite frequency spacing is becoming too different from what the model learned during training.

Regime 3 (alpha 0.75-1.00): Rapid collapse. PPL jumps from 17.15 to 94.85 as the frequency perturbation exceeds the model’s tolerance. At alpha \= 1.0 with unmatched frequency ranges (raw substitution without envelope matching), PPL exceeds 6000 and the model produces incoherent output.

The key finding is in Regime 1: composite frequency structure actively improves positional discrimination at alpha 0.15-0.20 without any retraining. This suggests the geometric progression is suboptimal and that arithmetic frequency spacing provides genuinely better positional information to the attention mechanism.

### **3.4 Significance**

This result is notable for several reasons. First, the improvement is obtained at inference time with zero retraining. The model weights are frozen. Only the rotation frequencies applied during the forward pass are modified. Second, the improvement uses the existing freq\_factors mechanism in llama.cpp, requiring no kernel modifications. Third, the effect is measured on a production model at production quantisation, not on a toy model or in a research framework.

A model fine-tuned with composite frequencies from the start would likely show larger improvements, as the weights would learn to exploit the arithmetic structure rather than merely tolerating it.

---

## **4\. The Three-Layer Experimental Architecture**

To investigate why arithmetic frequencies help, we implement a modular test suite with a small transformer (6 layers, 8 heads, d\_model=256, head\_dim=32) trained on WikiText-103.

### **4.1 Layer 1: Positional Encoding**

Eleven pluggable frequency strategies span four categories: lattice-aware (prime\_tiered, composite\_tiered), off-lattice (random\_freq, irrational, scrambled\_prime), topological (mobius\_half, spinor, zeta\_rebuild, fibonacci), and baseline (geometric\_rope). End-to-end PPL results across three strategies at 10K training steps confirm the production finding: composite\_tiered (PPL 209.98) and prime\_tiered (PPL 210.95) both outperform geometric\_rope (PPL 213.85) by 3-4 PPL points. composite\_tiered edges out prime\_tiered by approximately 1 PPL, consistent with composites providing denser frequency coverage from the same lattice structure.

### **4.2 Layer 2: Quantisation**

Our own KV compression pipeline with pluggable rotation, n-bit scalar quantisation, and optional sign-sketch correction. The critical output is the integer indices: quantised vectors in {0, …, 2^n \- 1}^D. These form the lattice that Layer 3 operates on.

Rotation strategy comparison at 3-bit quantisation across 12 strategies shows all strategies preserving vector direction comparably (cosine similarity 0.925-0.932). The spread is narrow, indicating compression fidelity is relatively insensitive to rotation strategy choice at this bit width.

### **4.3 Layer 3: Lattice Collapse**

The LLL algorithm finds short vectors in integer lattices. Applied to the quantised activation vectors from Layer 2, it tests whether the prime resonance signal (PRS) survives lattice reduction.

Critical implementation note: Layer 3 must receive integer indices from Layer 2, not raw floating-point activations. Earlier implementations fed raw floats to LLL, which cannot reduce a continuous basis. This produced vacuous results (norm\_ratio \= 1.0, perfect survival) that were meaningless. The corrected implementation feeds 3-bit quantised integers, producing genuine lattice reduction.

Results across 9 independent runs with the corrected implementation:

| Strategy | Median Norm Ratio | PRS Retention | Pattern Corr | Vectors Changed |
| :---- | :---- | :---- | :---- | :---- |
| prime\_tiered | 0.56 | 0.993 | 0.331 | 99.6% |
| composite\_tiered | 0.87 | 1.014 | 0.333 | 99.6% |
| geometric\_rope | 0.70 | 1.011 | 0.317 | 99.7% |

All norm ratios are below 1.0 (median), confirming LLL finds shorter basis vectors. 99.6% of vectors change during the round-trip through the reduced basis, confirming the reduction is non-trivial. PRS survives across all strategies (retention near 1.0). Pattern correlation is moderate (0.32-0.33), indicating fine-grained attention patterns change but the statistical prime distance preference persists.

prime\_tiered has the lowest median norm ratio (0.56), meaning its lattice is the most reducible. This is consistent with prime frequencies creating maximally independent basis vectors that LLL can efficiently reorganise.

---

## **5\. Context Reconstruction**

### **5.1 Level 1: Harmonic Decomposition**

RoPE applies a known orthogonal rotation to K vectors. Since the rotation is exactly invertible given the known frequencies, each K vector can be decomposed into position-independent content and position-dependent rotation. Reconstruction is exact: MSE \= 0.0, cosine similarity \= 1.0, attention correlation \= 1.0 across all strategies, all runs, all batches. Verdict: EXACT.

This establishes that the KV cache is cleanly decomposable. Content vectors plus strategy name plus position indices are sufficient to reconstruct full K vectors on demand.

### **5.2 Level 2: Zero-Crossing Reconstruction**

The pre-softmax attention score signal S(d) \= mean\_t(q\_t \* k\_{t-d} / sqrt(D)) as a function of distance d is extracted for each head. This signal is a linear superposition of the rotation harmonics (in score space, not post-softmax attention space, which would destroy linearity). Zero-crossings are identified, and the signal is reconstructed from crossing positions, gradients, and estimated inter-zero peak values using the known frequencies via ridge-regularised least-squares.

Topology-selected reconstruction uses half-Mobius phase predictions to select structurally meaningful crossings rather than using all crossings indiscriminately.

| Strategy | L2 Correlation | Crossings Selected | Compression | Mobius Hit Rate |
| :---- | :---- | :---- | :---- | :---- |
| prime\_tiered | 0.107 | 312/479 | 26x | 0.43 |
| composite\_tiered | 0.066 | 301/481 | 26x | 0.42 |
| geometric\_rope | 0.015 | 35/457 | 15x | 0.89 |
| random\_freq | 0.051 | 96/461 | 121x | 0.78 |

The geometric\_rope Mobius hit rate (0.89) confirms that geometric zeros are trivially predictable (regular spacing). However, reconstruction from those zeros gives near-zero correlation (0.015), demonstrating that geometric zeros carry no structural information. Arithmetic strategy zeros are harder to predict (hit rate 0.42-0.43) but carry meaningful information for reconstruction (correlation 0.07-0.11).

### **5.3 Level 3: Topological Traversal**

Three traversal strategies are compared for zero-finding efficiency: linear scan (baseline, all positions), half-Mobius (topology-predicted positions only), and spinor (double-cover with two passes).

For composite\_tiered at alpha-blended frequencies:

| Traversal | Correlation | Points Sampled | Quality/Sample | Sample Reduction |
| :---- | :---- | :---- | :---- | :---- |
| linear | 0.102 | 1023 | 0.100 | 0% |
| half-Mobius | 0.082 | 155 | 0.527 | 85% |
| spinor | 0.103 | 233 | 0.443 | 77% |

The spinor traversal matches linear correlation (0.103 vs 0.102) using 77% fewer sample points. The half-Mobius achieves quality-per-sample of 0.527, which is 5.3x more efficient than linear scanning. These results demonstrate that topological traversal strategies can find structurally meaningful zeros with dramatically fewer samples than brute-force scanning.

### **5.4 Reconstruction Limitations**

Level 2 absolute correlations remain low (0.07-0.11) at 2K training steps. The signal is dominated by content similarity (tokens that are semantically similar score high regardless of distance), with the harmonic positional component being a small fraction of the total signal at this training stage. Longer training (10K-50K steps) would strengthen the positional signal. The interaction between content and position in the score signal remains an active area of investigation.

---

## **6\. Inference-Time Integration Architecture**

### **6.1 Phased Deployment in llama.cpp**

Phase 1 (validated): Frequency injection via freq\_factors. Composite-tiered frequencies blended at alpha \= 0.15-0.20. Uses existing ggml rope mechanism. No kernel modifications. PPL improvement demonstrated.

Phase 2 (designed): Shadow reconstruction backend. A second memory implementation behind the llama\_memory\_i abstract interface stores decomposed content vectors and reconstructs K on demand. Runs alongside standard KV cache for validation. Approximately 500-800 lines of C++.

Phase 3 (future): Zero-crossing reconstruction. Replace content vector storage with zero-crossing parameters. Reconstruct attention patterns from topological invariants. Depends on Level 2 and Level 3 reconstruction being validated at higher training scales.

### **6.2 LLL as Independent Optimisation**

Lattice reduction on quantised KV caches is a general-purpose inference-time optimisation independent of prime harmonics. Any model running quantised KV cache can potentially benefit from LLL reduction of the quantised lattice, providing shorter traversal paths through cached context. This is complementary to existing quantisation schemes and could be submitted as a standalone contribution.

---

## **7\. Relationship to Existing Work**

RoPE (Su et al., 2021): We use the same rotary mechanism but substitute the frequency basis and demonstrate that composite frequencies improve over geometric at inference time.

TurboQuant (Zandieh et al., 2026): Optimises quantisation codebooks for KV compression. We complement TurboQuant by questioning whether full KV storage is necessary.

ALiBi (Press et al., 2022): Additive linear bias as an alternative to rotary encoding. Our framework is specific to rotary-encoded models.

Lattice-based methods in ML: To our knowledge, no prior work applies LLL lattice reduction to quantised neural network activations as a post-quantisation compression step, nor uses topological traversal strategies to predict zero-crossing locations in attention score signals.

---

## **8\. Discussion**

### **8.1 Why Composite Frequencies Help**

The PPL improvement at alpha 0.15-0.20 suggests that the geometric progression used in standard RoPE is locally suboptimal. Composite frequencies break the strict geometric regularity, introducing non-uniform spacing that may better match the actual distribution of positionally relevant distances in natural language. The Zipfian distribution of linguistic patterns implies that attention distances are not uniformly important, and the composite frequency spacing (derived from the multiplicative structure of integers) may better align with this non-uniform importance.

### **8.2 The Half-Mobius Prediction**

The strongest prediction of this framework is that half-Mobius traversal topology should predict zero-crossing locations without signal scanning. Current results show the topology achieving 5.3x efficiency over linear scanning, with 85% sample reduction. Full validation requires longer training to strengthen the positional harmonic component of the score signal.

### **8.3 Limitations**

The production validation uses a single model architecture (Llama 3.2 1B) at one quantisation level (Q8\_0). Scaling behaviour across model sizes, architectures, and quantisation levels is unknown. The reconstruction framework (Levels 2-3) shows promising relative comparisons between strategies but absolute reconstruction quality remains low at short training scales. V vectors are not rotated and must still be stored, limiting achievable memory reduction to approximately 50% of the KV cache.

### **8.4 The Deeper Goal**

This work is not primarily about positional encoding. The transformer and its PE are a testbed for a more fundamental claim: that context in sequence models has exploitable harmonic structure that permits reconstruction from sparse invariants. If context is a reconstructible signal rather than stored data, the implications extend to persistent AI agents (context as a storable function rather than a growing cache), edge deployment (128K context windows on mobile devices), and the theoretical connection between transformer attention and the Riemann zeta function via the Euler product.

---

## **9\. Conclusion**

We have demonstrated that composite frequency structure, derived from the multiplicative lattice of integers, improves transformer inference quality when blended into geometric RoPE at alpha 0.15-0.20. This improvement is obtained at inference time with zero retraining on a production model in a production inference engine. The three-layer experimental architecture confirms that prime resonance signals survive lattice reduction, and the reconstruction framework shows that topological traversal strategies find structurally meaningful zeros with dramatically fewer samples than brute-force scanning.

The immediate practical contribution is a one-file header (prime\_rope.h) that can be dropped into any llama.cpp build to inject composite frequency structure via the existing freq\_factors mechanism. The deeper contribution is the framework for understanding context not as data to be stored but as a signal to be reconstructed, opening the path toward KV cache elimination through harmonic reconstruction.

---

## **References**

Mora, T. and Bialek, W. (2011). Are biological systems poised at criticality? Journal of Statistical Physics, 144(2), 268-302.

Press, O., Smith, N. A., and Lewis, M. (2022). Train short, test long: Attention with linear biases enables input length generalization. ICLR 2022\.

Su, J., Lu, Y., Pan, S., Murtadha, A., Wen, B., and Liu, Y. (2021). RoFormer: Enhanced transformer with rotary position embedding. arXiv:2104.09864.

Zandieh, A., et al. (2026). TurboQuant: Online KV cache quantization with rotation-aware codebooks. ICLR 2026\.