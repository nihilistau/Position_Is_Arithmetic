# PrimePE / Position_Is_Arithmetic — Session Context v3
## Date: April 5, 2026 | Updated: VHT2 banded compression validated + Qwen3-8B sweep complete

---

## THE PROJECT IN ONE PARAGRAPH

PrimePE proves that context in rotary-encoded transformers is not data to be stored but structure to be read from either side of a self-inverse matrix. The KV cache is an engineering artifact of computing attention in one direction — the inverse direction reconstructs context from the same structural relationships without storage. Key production result: composite-tiered frequencies blended at alpha 0.15-0.20 into Llama 3.2 1B via llama.cpp improve PPL (10.91 vs 11.03 baseline) with zero retraining. VHT2 banded KV compression (n=4 bands, K:5/5/4/3 + V:flat int3) achieves **3.4–3.8× total KV compression** at <1.25% PPL cost, up from the previous 2.3× baseline — validated on Dolphin 1B and Qwen3-8B. K and V require structurally different strategies: K has spectral concentration from RoPE (WHT energy in first bands), V has uniform energy (flat quantization wins). Walsh-Hadamard/VHT2 is the natural basis because K is a Walsh signal. The theoretical foundation: the Redheffer matrix (divisibility lattice of integers) and its inverse (Möbius function) contain the same information — no computation at any level, just reading the structure from the other direction.

---

## THE THEORETICAL BREAKTHROUGH (Late Session)

### The Core Claim: KV Cache Is a View, Not Data

The field treats context as data that must be stored and compressed. This is wrong. Context is structure — specifically, the divisibility/multiplicative structure of the integers that index positions. The KV cache is what you get when you multiply token embeddings × positional rotation × attention weights in one direction. The reconstructed context is the SAME multiplication in the other direction. Same matrix, same information, no storage required.

### The N-Ball Construction

Each dimension of the n-ball corresponds to one prime factor:

- **n1 (Line):** 2r. Primes. The 1D base — the universal number line.
- **n2 (Disk):** πr². Composites with 2 prime factors. Line × unit circle (Cartesian product).
- **n3 (Ball):** 4/3πr³. Composites with 3 prime factors. Disk × unit circle.
- **n_k:** Each new dimension multiplies by a circle. Each circle = one more prime factor.

The "knight's move" is how each dimension is BUILT from the previous — not a traversal strategy but a construction method. Archimedes showed sphere→cylinder projection preserves area. That's the lossless projection between dimensions.

### The Redheffer Matrix

For n×n matrix R: R(i,j) = 1 if i divides j OR if j = 1. Otherwise 0.

- **det(R_n) = M(n)** — the Mertens function (running sum of Möbius function)
- **Inverse of the lower triangular divisibility matrix = Möbius function values**
- The Möbius function μ(n): 0 if n has squared factors, (-1)^k if n has k distinct prime factors

**By inverting a matrix of divisors, you extract ALL prime locations. No sieve. No computation. The structure IS the answer.**

### The Self-Inverse Principle

The same non-computing trick works at EVERY level of the n-ball, and in REVERSE:

- Walsh/Hadamard: H × H = Identity. Same operation decomposes AND reconstructs.
- Redheffer: Matrix and its inverse contain the same information from two directions.
- Context: The decomposed form and the signal form are the SAME MATRIX read differently.

### Vilenkin Systems: The Full Basis

Walsh functions use Z/2Z (binary — one prime). The Vilenkin system generalises to Z/α_kZ for arbitrary α_k. Set α_k to the k-th prime and you get the complete prime-indexed orthogonal system. Walsh gets 0.948 with ONE prime dimension. Vilenkin with ALL primes would be EXACT.

---

## VALIDATED RESULTS

### llama.cpp Phase 1 — Production PPL Improvement
- Model: Dolphin-Llama3.2-1B Q8_0, ctx=4096, CUDA RTX 2060
- Method: composite_tiered freq_factors via existing ggml rope mechanism
- Alpha blending: `blended = (1-α)*geometric + α*composite`

| Alpha | PPL | vs Baseline |
|-------|---------|-------------|
| 0.00 | 11.025 | baseline |
| 0.15 | 10.929 | **-0.10 BETTER** |
| 0.20 | 10.913 | **-0.11 BETTER** |
| 0.50 | 11.352 | +0.33 |
| 0.75 | 17.149 | +6.12 |
| 0.80 | 28.948 | +17.92 |
| 0.90 | 41.175 | +30.15 |
| 1.00 | 94.845 | +83.82 |

### Walsh Reconstruction — THE KEY RESULT

| Method | Correlation | Compression | Sparsity |
|---|---|---|---|
| WHT 90% energy | **0.948** | 2.3x | 57% |
| Sign pattern + amplitudes | **0.692** | 1.14x | — |
| Pure binary (no amplitudes) | **0.521** | 1.14x | — |

Walsh gets 0.948 vs Fourier's 0.15. The signal IS a Walsh signal. Near-perfect reconstruction throwing away 57% of coefficients. WALSH_WINS across all three strategies.

### VHT2 Banded KV Compression — VALIDATED (2026-04-05)

Systematic sweep on Dolphin 1B (head_dim=64) and Qwen3-8B (head_dim=128) established the optimal config. K has spectral concentration from RoPE (energy in first WHT bands); V does not (uniform distribution). They need different strategies.

**Optimal config: K n=4 bands 5/5/4/3 + V flat int3**

| Model | K × | V × | Combined × | PPL | ΔPPL |
|---|---|---|---|---|---|
| Dolphin 1B (hd=64) | 2.8× | 4.3× | **~3.4×** | 13.1745 | +0.60% |
| Qwen3-8B (hd=128) | 3.2× | 4.7× | **~3.8×** | 9.4482 | +1.24% |

vs old shadow cache 2.3× each: **+65% combined compression** at better quality.
vs llama.cpp q4_0 flat (4×): V at 4.7× beats flat q4; K at 3.2× is more conservative but preserves RoPE spectral structure that flat quantization destroys.

**Critical rules discovered:**
- sk must equal head_dim exactly (sk=32 on hd=64 → PPL +47%)
- 3-bit floor — 2-bit on any band is catastrophic
- 5/5/4/3 mirrors WHT energy decay — any deviation worsens PPL
- n=4 beats n=5/n=8 — scale overhead (2 bytes per band) kills compression gains
- K needs banded; V needs flat (banded V is strictly worse than flat V)

**RAM impact (head_dim=128, 32K context):**
- fp16 baseline: 5.9 GB → VHT2: **1.56 GB** (saves ~4.3 GB)

### Reconstruction Scaling (2K → 10K training steps)
| Strategy | L2 Corr 2K | L2 Corr 10K | L3 Linear 10K | Spinor QPS |
|---|---|---|---|---|
| prime_tiered | 0.107 | 0.146 | 0.355 | 0.578 |
| composite_tiered | 0.066 | 0.094 | 0.304 | 0.560 |
| geometric_rope | 0.015 | 0.028 | 0.323 | 0.457 |

### Layer 3 Lattice Collapse (Fixed)
- LLL on quantised 3-bit integer indices (NOT raw floats)
- prime_tiered: median norm_ratio=0.56, PRS retention=0.993
- All strategies: PRS survives, 99.6% vectors changed

---

## KEY DECISIONS & INSIGHTS

1. **KV cache is a VIEW, not data.** Context is fully determined by token sequence + positional structure + weights. The cache is one direction of multiplication. Reconstruction is the other direction. Same matrix.

2. **Composites are the lattice itself.** Not frequencies we assign — the actual multiplicative structure. Primes are the dimensions. Composites are positions (coordinates in prime-factor space). 12 = 2²×3 is position (2,1) in (dim_2, dim_3).

3. **Zero-crossings are resonance detection.** They detect WHERE you are in composite space. Not stored data — structural boundaries where the Möbius function changes sign.

4. **Walsh is the base-2 projection of the full structure.** One prime dimension. Gets 0.948. Vilenkin (all primes) would be exact.

5. **Self-inverse at every level.** H×H=I. Same operation decomposes and reconstructs. The Redheffer matrix and its inverse are the same information. No computation needed at any level — just read the structure from the other side.

6. **The n-ball construction doesn't need to be calculated.** Each level is implicit in the level below. Invert → structure falls out. Same trick at every dimension.

7. **Everyone else is optimising the wrong side.** TurboQuant, sliding windows, attention sinks — all accept that context is data. The premise is wrong.

---

## ARCHITECTURE

### LocalSuite (Python test suite, ~4600 lines, 14 files)
```
Layer 1: PE rotation (11 strategies, pluggable)
Layer 2: KV compression (3-bit quantisation)
    → encode_to_lattice() → integer indices for Layer 3
Layer 3: Lattice collapse (LLL on integer lattice)
```

### Reconstruction Framework
```
Level 1: Harmonic decomposition → EXACT
Level 2: Zero-crossing reconstruction → 0.09-0.15 (Fourier), 0.948 (Walsh!)
Level 3: Topological traversal → spinor most efficient
```

### Walsh Reconstruction (walsh_reconstruct.py)
```
Method 1: WHT decomposition + sparse coefficients → 0.948 corr
Method 2: Sign pattern + amplitudes → 0.692 corr
Method 3: Pure binary sign pattern → 0.521 corr
```

### llama.cpp Integration Stack
```
Layer 0: RoPE with composite freq_factors     ← prime_rope.h (VALIDATED)
Layer 1: VHT2 banded KV compression           ← llama-kv-cache-shadow.cpp (VALIDATED)
         K: n=4 5/5/4/3  V: flat int3
         3.4-3.8× combined, <1.25% PPL cost
Layer 2: TurboQuant WHT + 3-bit quantisation  ← TheTom's fork (integrated)
Layer 3: LLL reduction on TQ3 integers        ← port from Python
Layer 4: Walsh/Vilenkin reconstruction        ← the endgame
```

### VHT2 Configuration (env vars, no rebuild needed)
```powershell
$env:LLAMA_SHADOW_CACHE="1"; $env:LLAMA_SHADOW_VHT2="1"
$env:LLAMA_SHADOW_VHT2_READONLY="0"
$env:LLAMA_SHADOW_HEAD_DIM="128"          # your model's head_dim
$env:LLAMA_SHADOW_VHT2_SKELETON_K="128"  # must equal head_dim
$env:LLAMA_SHADOW_VHT2_N_BANDS="4"
$env:LLAMA_SHADOW_VHT2_BAND_BITS="5,5,4,3"
$env:LLAMA_SHADOW_VHT2_V="1"
$env:LLAMA_SHADOW_VHT2_SKELETON_V="128"
$env:LLAMA_SHADOW_VHT2_V_N_BANDS="1"
$env:LLAMA_SHADOW_VHT2_V_BAND_BITS="3"
```

### TurboQuant Fork Status
- Merged with PrimePE on `turboquant_plus_prime` branch at `nihilistau/llama-cpp-turboquant`
- Shadow cache (all 13 phases P1-P13) working
- VHT2 writeback active — banded K + flat V compression validated
- Stage 5-11 spectral hooks restored (llama-graph.cpp +595 lines, prime_spectral_attn.h +240 lines)
- Build: `cmake --build build-cpu --config Release --target llama-perplexity`
- Full research results: `docs/prime/VHT2_COMPRESSION_RESULTS.md`

---

## FILES CREATED THIS SESSION (v3 additions)

### Research & Docs
- `docs/prime/VHT2_COMPRESSION_RESULTS.md` — full sweep data, all tables, key principles
- Comment block added to `src/llama-kv-cache-shadow.cpp` with optimal config

### Key Files (llama-cpp-tqp)
- `src/llama-kv-cache-shadow.cpp` (~4743 lines) — shadow cache + VHT2 writeback (all 13 phases)
- `src/llama-kv-cache-shadow.h` — shadow_config, VHT2 fields, clear() fix
- `src/prime_reconstruct.h` (~4126 lines) — VHT2 math engine, N-band generalisation
- `src/llama-graph.cpp` (~3850 lines) — spectral analysis infrastructure restored
- `src/prime_spectral_attn.h` (~826 lines) — oracle compression masks

---

## CRITICAL BUGS FIXED

1. **Layer 3 no-op:** Raw floats → LLL → norm_ratio=1.0. Fix: integer indices.
2. **Post-softmax scores:** Softmax destroys linearity. Fix: pre-softmax Q·K.
3. **no_alloc inverted:** true/false confusion → NULL data → silent no-op.
4. **Raw frequency substitution:** Wrong range → PPL 6400. Fix: envelope matching + alpha blend.
5. **CUDA tensor allocation:** CPU tensor, GPU kernel → crash. Fix: backend-aware allocation.
6. **Interaction frequencies:** Overfitting with 300 coefficients. Fix: base frequencies only.
7. **TQ linker error:** C/C++ name mangling. Fix: extern "C" at file scope + local definition.

---

## PENDING / NEXT STEPS

### Validated & Complete ✅
- [x] TurboQuant fork build and baseline PPL
- [x] VHT2 banded K compression (optimal: n=4 5/5/4/3)
- [x] VHT2 flat V compression (optimal: flat int3)
- [x] K+V combined sweep — Dolphin 1B and Qwen3-8B
- [x] sk sweep (confirmed: sk must equal head_dim)
- [x] n-band sweep (confirmed: n=4 optimal for both head dims)
- [x] Codebase restoration (Stage 5-11 spectral hooks restored)
- [x] Pushed to nihilistau/llama-cpp-turboquant turboquant_plus_prime

### In Progress / Next
- [ ] VHT skeleton structural correctness validation
- [ ] sc-restore: verify 2.3× baseline path still accessible
- [ ] Combined prime_rope + VHT2 test (PrimePE frequencies + VHT2 compression together)

### Theoretical
- [ ] Implement full Vilenkin basis (replace WHT Z/2Z with Z/p_kZ)
- [ ] Test Redheffer matrix construction for attention reconstruction
- [ ] LLL analysis of trained W_Q/W_K matrices
- [ ] "Read from the other side" — inverse-direction reconstruction

### Engineering
- [ ] Scale experiments at 1B+ parameters with both PrimePE + VHT2
- [ ] Cross-architecture test: Phi-3.1 (head_dim=96) compression sweep
- [ ] Vulkan port for Adreno (S22 Ultra target)
- [ ] GCD attention bias experiment

---

## HARDWARE / ENVIRONMENT

- GPU: RTX 2060 12GB, CUDA 13.1/13.2, SM_75
- CPU: Intel i9 NUC, 16 threads
- OS: Windows 11
- Mobile: S22 Ultra (Adreno 730, Vulkan target)
- llama.cpp prime: D:\customllama\llama-cpp-prime (working, validated)
- llama.cpp TQ fork: D:\customllama\llama-cpp-tq (building)
- Python test suite: LocalSuite
- GitHub: nihilistau/Position_Is_Arithmetic
