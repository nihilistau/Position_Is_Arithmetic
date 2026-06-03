# PrimePE: Prime Harmonic Positional Encoding System

## Architecture Overview

PrimePE is a modular framework for exploring the hypothesis that the multiplicative structure of the integers is the natural coordinate system for transformer positional encoding. The system consists of six engines, each implementing a different mathematical view of the same underlying structure.

The core claim: **Walsh-Hadamard, LLL lattice reduction, spinor traversal, half-Mobius prediction, zero-crossing reconstruction, the n-ball construction, Archimedes projection, the Redheffer matrix, and complex rotation (RoPE) are all the same mathematical operation** — reading the multiplicative structure of the integers — expressed in different mathematical languages.

## The Six Engines

### Engine 1: Frequency Generation (`prime_freq.h`)

**What it does:** Replaces the geometric frequency progression in RoPE with arithmetic-structured alternatives.

**Where it hooks in:** `llama-model.cpp:get_rope_factors()` — provides freq_factors that the existing rope kernel divides by. No kernel modifications needed.

**Strategies:**

| Strategy | Formula | Validated | Notes |
|----------|---------|-----------|-------|
| `geometric` | base^(-2i/d) | Baseline | Standard RoPE, factors = 1.0 |
| `prime_tiered` | 2pi/p for primes p | PPL validated | Three tiers: local/mid/long |
| `composite_tiered` | 2pi/n for composites n | PPL 10.91 (best) | Composites = coordinates in prime-factor space |
| `spectral_alibi` | 1/p^alpha | PPL 106.6 at 300M | Dissolves RoPE/ALiBi tradeoff |
| `vilenkin` | Z/p_k character frequencies | Tested | Generalises Walsh to all primes |
| `zeta_zeros` | Imaginary parts of zeta zeros | PPL -0.9% at longer ctx | Quasicrystalline structure |

**Key parameter:** `alpha` (0.0 - 1.0) — blend between geometric envelope and arithmetic spacing. Validated optimum: 0.15-0.20. Configurable via `PRIME_ALPHA` environment variable.

**Why composites, not primes?** Composites are coordinates in prime-factor space (12 = 2^2 * 3 lives at position (2,1) in the (p_2, p_3) grid). Primes are the DIMENSIONS, not the coordinates. Composites create reducible lattices; primes emerge as the invariant after compression. The falsification suite confirmed this: primes and composites give identical PPL (129.2 vs 129.4) — it's the lattice structure that matters, not primality per se.

### Engine 2: Rotation/Transform (`prime_transform.h`)

**What it does:** Applies orthogonal transforms before/after attention for decorrelation.

**Where it hooks in:** `llama-graph.cpp` — same hooks as TurboQuant's `ggml_turbo_wht()`.

**Strategies:**

| Strategy | Kernel | Self-inverse? | Complexity |
|----------|--------|---------------|------------|
| `none` | Identity | Yes | O(1) |
| `wht` | H[i][j] = (-1)^(popcount(i&j)) | Yes (H*H = n*I) | O(n log n) |
| `vilenkin_transform` | cas(2pi*k*n/p) = cos + sin | Yes (V*V = N*I) | O(N * sum(p_k)) |
| `redheffer` | R[i][j] = 1 if i divides j | No (inverse = Mobius) | O(n^2) |
| `dense_rotation` | Random orthogonal (QR) | Yes (R^T = R^-1) | O(n^2) |

**The Hartley breakthrough:** The Vilenkin transform uses the Hartley kernel `cas(x) = cos(x) + sin(x)` instead of complex exponentials. This gives a REAL-VALUED transform that is SELF-INVERSE for ALL primes, not just p=2 (Walsh). For p=2, Hartley = Hadamard, so this is the proper generalisation.

**Key result:** Vilenkin-Hartley with 5 primes achieves 0.963 correlation vs Walsh's 0.958 on test signals. Round-trip error = 0.0000 (exact self-inverse confirmed).

### Engine 3: Quantization (`prime_quant.h` + `llama-kv-cache-shadow.cpp`)

**What it does:** Compresses KV cache values exploiting arithmetic structure.

**Strategies:**

| Strategy | Method | Correlation | Compression |
|----------|--------|-------------|-------------|
| `none` | FP16 | 1.000 | 1x |
| `polarquant` | Norm + direction + centroids | 0.987 (3-bit) | 5.3x |
| `lattice_quant` | Scalar + LLL reduction | 0.854 (3-bit) | 5.3x |
| **`vht2_banded_k`** | **WHT + n-band spectral alloc** | **0.9928 (5/5/4/3)** | **3.2x** |
| **`vht2_flat_v`** | **WHT + flat 3-bit** | **0.9652** | **4.7x** |
| `nball_quant` | Prime-factor coordinate quant | Stub | TBD |

PolarQuant matches TurboQuant's quality exactly — same Lloyd-Max centroids, same magnitude/direction separation. The insight: if the signal has arithmetic structure (from Engine 1), then lattice quantization PRESERVES that structure because the lattice IS the structure.

**VHT2 Banded Quantization — VALIDATED (2026-04-05).** The shadow cache (`llama-kv-cache-shadow.cpp`) implements VHT2 banded compression as the active production path. Each KV head vector is WHT-transformed, split into N equal energy bands, and each band quantized with its own fp16 scale + packed int values.

**Critical discovery: K and V are structurally different.**

- **K vectors carry RoPE positional encoding** → WHT concentrates energy in the first bands (spectral structure from arithmetic RoPE frequencies). Banded quantization with 5/5/4/3 bits mirrors WHT energy decay exactly.
- **V vectors carry content** → WHT energy is uniform across all bands. Flat quantization (n=1 band, all elements same bit-width) outperforms banded at every compression level.

**Validated optimal config: K n=4 bands 5/5/4/3 + V flat int3**

| Model | head_dim | K corr | K × | V corr | V × | Total × | ΔPPL |
|-------|----------|--------|-----|--------|-----|---------|------|
| Dolphin 1B | 64 | 0.9941 | 2.8× | 0.9708 | 4.3× | ~3.4× | +0.60% |
| Qwen3-8B | 128 | 0.9928 | 3.2× | 0.9652 | 4.7× | ~3.8× | +1.24% |

vs old shadow cache 2.3× each: **+65% combined compression** at better quality.

**Critical rules (empirically confirmed, no exceptions):**
1. `sk` (skeleton size) must equal `head_dim` — WHT requires the full vector. `sk=32` on `hd=64` → PPL +47%.
2. 3-bit floor — 2-bit on any band is catastrophic.
3. `5/5/4/3` mirrors WHT energy decay — any single-bit deviation worsens PPL.
4. n=4 beats n=5/n=8 — extra scale overhead (2 bytes/band) erases quality gains.
5. Flat beats banded for V — no exceptions in the sweep.

Full data: `docs/prime/VHT2_COMPRESSION_RESULTS.md`

### Engine 4: Reconstruction (`prime_reconstruct.h`)

**What it does:** Reconstructs signals from structural invariants instead of stored values. This is the engine that could REPLACE the KV cache.

**Strategies:**

| Strategy | Method | Correlation | Notes |
|----------|--------|-------------|-------|
| `walsh_recon` | WHT -> top-k -> inverse WHT | 0.958 @ 90% energy | Validated in Python suite |
| `vilenkin_recon` | Vilenkin -> top-k -> inverse | 0.963 (k=5) | More primes = higher |
| `zero_crossing` | Prime-frequency least-squares from crossing constraints | 0.891 (C++), 0.686 (6 crossings) | Frequency-aware: uses known prime harmonics |
| `redheffer_inv` | Invert divisibility matrix | Structural | Extracts Mobius values |

**The frequency-aware zero-crossing fix:** The original implementation used blind sinc interpolation (correlation: -0.004). The new implementation uses known prime frequencies as basis functions and solves for amplitudes via least-squares on crossing constraints (value = 0 at crossing, derivative = gradient). Result: 0.891 correlation in Python, 0.686 in C++ (different solver).

### Engine 5: Traversal (`prime_traverse.h`)

**What it does:** Finds zero-crossings efficiently using topological predictions.

| Strategy | Samples | Crossings Found | Sample Reduction |
|----------|---------|-----------------|-----------------|
| `linear` | N | All | 0% (baseline) |
| `half_mobius` | ~0.65N | 83-100% of linear | 31-41% |
| `spinor` | 2N | 100% of linear | -100% (2x samples, but with curvature) |

**Independence confirmed:** Traversal methods work on ALL signal types (prime harmonic, geometric, noise, chirp) — they're not tied to a specific rotation or construction.

### Engine 6: Coordinate Systems (`prime_coords.h`)

**What it does:** Maps positions between coordinate systems.

- `integer_line`: Standard — position 47 is just the integer 47
- `prime_factor`: Position 12 = 2^2 * 3 maps to (2, 1, 0, ...) in the (p_2, p_3, p_5, ...) basis
- `nball`: Each prime factor = one dimension of an n-ball (Cartesian product with S^1)
- `archimedes_proj`: Lossless area-preserving projection between dimensions

**Archimedes' theorem:** Sphere surface area = cylinder surface area. This means projecting from n-ball to (n-1)-ball preserves area exactly. The round-trip error is < 0.01%.

**The n-ball construction (from the user's diagram):**
- n1: Line segment [-1,1]. 2r. Primes.
- n2: Disk. pi*r^2. Line x unit circle. One prime factor.
- n3: Ball. 4/3*pi*r^3. Disk x circle. Two prime factors.
- n4+: Each dimension = one more prime factor via Cartesian product with S^1.

At each level, choosing z leaves a circle x^2+y^2 = 1-z^2 — a unit circle scaled by sqrt(1-z^2). The area = line * unit circle, independent and factored. This is why the construction gives exact dimensional extension.

## LLL Lattice Collapse (`prime_lattice.h`)

Implements the Lenstra-Lenstra-Lovasz basis reduction algorithm and measures Prime Resonance Survival (PRS) across ALL strategies.

**Key results (C++ test, frequency_matrix construction):**

| Strategy | OD Before | OD After | Collapse | PRS |
|----------|-----------|----------|----------|-----|
| geometric | 409.87 | 1.20 | 0.201 | 14.92 |
| prime_tiered | 205.67 | 1.33 | 0.226 | 17.85 |
| composite_tiered | 209.46 | 1.32 | 0.223 | 17.70 |
| vilenkin | 75.23 | 1.52 | 0.315 | 19.37 |
| zeta_zeros | 505.18 | 1.37 | 0.218 | 14.92 |

**Reading the results:**
- **Vilenkin starts closest to orthogonal** (OD=75 vs geometric's 410)
- **Vilenkin has the highest PRS** (19.37 vs geometric's 14.92) — prime structure survives best
- **Prime and composite are nearly identical** (PRS 17.85 vs 17.70) — confirming the falsification result
- **Geometric and zeta have lowest PRS** — least prime structure

## Configuration

All parameters are configurable via:
1. `prime_config.h` — compiled defaults
2. Environment variables — runtime overrides (no rebuild needed)
3. CLI flags — per-invocation

**Engine 1 — Frequency generation:**
```bash
PRIME_FREQ_STRATEGY=composite_tiered  # Engine 1 strategy
PRIME_ALPHA=0.20                       # Blend factor (optimum: 0.15-0.22)
PRIME_VILENKIN_K=4                     # Number of primes for Vilenkin
PRIME_VERBOSE=1                        # Print diagnostics
```

**Engine 2/3 — Transform + quantization:**
```bash
PRIME_TRANSFORM=none                   # Engine 2 strategy
PRIME_QUANT_BITS=3                     # Quantization bit-width
```

**Shadow Cache + VHT2 (Engine 3 production path):**
```powershell
# Optimal config — works on all models, no rebuild needed
$env:LLAMA_SHADOW_CACHE="1"
$env:LLAMA_SHADOW_VHT2="1"
$env:LLAMA_SHADOW_VHT2_READONLY="0"
$env:LLAMA_SHADOW_HEAD_DIM="128"           # your model's head_dim (64 or 128 typical)
$env:LLAMA_SHADOW_VHT2_SKELETON_K="128"   # MUST equal head_dim
$env:LLAMA_SHADOW_VHT2_N_BANDS="4"
$env:LLAMA_SHADOW_VHT2_BAND_BITS="5,5,4,3"
$env:LLAMA_SHADOW_VHT2_V="1"
$env:LLAMA_SHADOW_VHT2_SKELETON_V="128"   # MUST equal head_dim
$env:LLAMA_SHADOW_VHT2_V_N_BANDS="1"
$env:LLAMA_SHADOW_VHT2_V_BAND_BITS="3"
```

## File Structure

### C++ Headers (in `src/`)
```
prime_math.h           — Number theory: sieve, factorise, Mobius, Redheffer, zeta zeros
prime_config.h         — Unified config with env var overrides
prime_freq.h           — Engine 1: 6 frequency strategies
prime_transform.h      — Engine 2: WHT + Vilenkin-Hartley + Redheffer + dense
prime_quant.h          — Engine 3: PolarQuant + lattice quantization
prime_reconstruct.h    — Engine 4: Walsh + Vilenkin + frequency-aware zero-crossing
                         (~4126 lines, N-band VHT2 math engine)
prime_traverse.h       — Engine 5: Linear + half-Mobius + spinor
prime_coords.h         — Engine 6: Prime-factor coords + n-ball + Archimedes
prime_lattice.h        — LLL reduction + PRS measurement
prime_rope.h           — Original (kept for backward compatibility)
prime_spectral_attn.h  — Oracle compression masks: compress_mode, compress_config,
                         build_compress_mask, compress_vector (Z3/Z3Z5/MOBIUS/TOPK modes)
```

### Shadow Cache (in `src/`)
```
llama-kv-cache-shadow.h    — shadow_config struct (all VHT2 fields), clear() fix
llama-kv-cache-shadow.cpp  — Full shadow cache implementation (~4743 lines)
                             All 13 phases (P1-P13), vht2_writeback() active path
                             Pre-batch hook: defers first batch, active from batch 2+
```

### Spectral Analysis (in `src/`)
```
llama-graph.cpp  — Spectral analysis infrastructure (restored):
                   vilenkin_analyzer, spectral_attn_state
                   Custom ops: spectral_fwd_op, spectral_compress_op
                   build_attn() hooks for K/Q transform (MHA/MLA/ISWA variants)
```

### Python Module (in `tests/Prime/TestSuite_v4/LocalSuite2/`)
```
prime_engines.py      — All 6 engines + LLL + comprehensive tests
run_prime_engines.py  — Full comparison runner (local or RunPod)
```

### Test & Deployment
```
tests/test-prime-engines.cpp  — 73 C++ unit tests across 12 stages
tests/test-prime-context.sh   — Context degradation sweep script
scripts/runpod-setup.sh       — Complete RunPod deployment
```

### Research Docs (in `docs/prime/`)
```
VHT2_COMPRESSION_RESULTS.md  — Full VHT2 sweep data, all tables, key principles
RESULTS_UPDATE.md             — Engine implementation results (2026-04-03)
PRIMPE_SYSTEM.md              — This file
Context_Is_Not_Storage_v2.md  — Full theoretical paper
```

## How to Use

### Quick start (C++)
```bash
# Build test binary
cl /EHsc /O2 /std:c++17 /Isrc tests/test-prime-engines.cpp /Fe:test.exe
# or: g++ -O2 -std=c++17 -Isrc -o test tests/test-prime-engines.cpp -lm

# Run all tests
./test --verbose

# Run specific stage
./test --stage 5  # Up to reconstruction tests
```

### Quick start (Python)
```bash
cd tests/Prime/TestSuite_v4/LocalSuite2/
python prime_engines.py           # Unit tests
python run_prime_engines.py       # Full comparison
python run_prime_engines.py --full --train  # With model training
```

### Production (llama.cpp)
```powershell
# Build (CPU, target perplexity binary)
cmake --build build-cpu --config Release --target llama-perplexity

# Baseline (no compression)
$env:LLAMA_SHADOW_CACHE="0"
.\build-cpu\bin\Release\llama-perplexity.exe -m model.gguf --ctx-size 2048 -b 512 --chunks 4

# VHT2 K+V best config (head_dim=128 models — Qwen3, Llama3.1-8B etc.)
$env:LLAMA_SHADOW_CACHE="1"; $env:LLAMA_SHADOW_VHT2="1"
$env:LLAMA_SHADOW_VHT2_READONLY="0"; $env:LLAMA_SHADOW_HEAD_DIM="128"
$env:LLAMA_SHADOW_VHT2_SKELETON_K="128"; $env:LLAMA_SHADOW_VHT2_N_BANDS="4"
$env:LLAMA_SHADOW_VHT2_BAND_BITS="5,5,4,3"
$env:LLAMA_SHADOW_VHT2_V="1"; $env:LLAMA_SHADOW_VHT2_SKELETON_V="128"
$env:LLAMA_SHADOW_VHT2_V_N_BANDS="1"; $env:LLAMA_SHADOW_VHT2_V_BAND_BITS="3"
.\build-cpu\bin\Release\llama-perplexity.exe -m model.gguf --ctx-size 2048 -b 512 --chunks 4

# For head_dim=64 models (Llama3.2-1B, Dolphin etc.) — change 128 → 64 above

# Prime rope (Engine 1)
$env:PRIME_ALPHA="0.20"
.\build-cpu\bin\Release\llama-perplexity.exe -m model.gguf --ctx-size 2048 -b 512
```

### RunPod deployment
```bash
# Upload and setup
rsync -avz . runpod:/workspace/llama-cpp-tqp/
ssh runpod 'cd /workspace/llama-cpp-tqp && bash scripts/runpod-setup.sh'

# Run tests
ssh runpod 'bash /workspace/run-quick-test.sh'  # 5 min
ssh runpod 'bash /workspace/run-all-tests.sh'   # Full suite
```

## The Unified Theory

All six engines implement different projections of the same mathematical object:

**The multiplicative structure of the integers is self-inverse at every level.**

- **Engine 1** reads it in the frequency domain: 2pi/n for composites n
- **Engine 2** reads it via orthogonal transforms: Hartley generalises Hadamard to all primes
- **Engine 3** reads it through quantization: lattice structure preserves prime invariants. **VHT2 banded compression confirms the deepest prediction: K vectors (WHT-transformed, energy-concentrated) compress at 3.2× with spectral banding; V vectors (uniform spectrum) compress at 4.7× with flat encoding. The K/V structural asymmetry IS the theory — K carries the arithmetic structure, V does not.**
- **Engine 4** reads it from the OTHER direction: reconstruction = the inverse of the same operation
- **Engine 5** reads it through topology: Mobius function predicts zero-crossing locations
- **Engine 6** reads it geometrically: the n-ball construction, one prime per dimension

The Redheffer matrix R(i,j) = 1 if i|j encodes this entire structure. Its inverse contains the Mobius function. Its determinant equals the Mertens function. The primes are not computed — they are already THERE in the divisibility structure. You just read them from the other side.

This is why the KV cache is a VIEW, not data. The same structure that encodes position (Engine 1) is the same structure that decorrelates for compression (Engine 2), survives quantization (Engine 3), enables reconstruction (Engine 4), predicts topology (Engine 5), and maps to geometry (Engine 6). One structure. Six views. Same math.

## Current Status (2026-04-05)

| Component | Status | Key Result |
|-----------|--------|------------|
| Engine 1: Prime RoPE | ✅ Validated | +0.82% PPL improvement at alpha=0.22 |
| Engine 2: VHT transform | ✅ Validated | Vilenkin corr=0.963, round-trip exact |
| Engine 3: VHT2 KV compression | ✅ Validated | 3.4-3.8× combined, <1.25% PPL |
| Engine 4: WHT reconstruction | ✅ Validated | 0.958 corr @ 2.3× (57% sparse) |
| Engine 5: Traversal | ✅ Validated | Spinor 100% crossings, Mobius 31-41% reduction |
| Engine 6: Coordinates | ✅ Validated | Archimedes round-trip <0.01% error |
| Shadow Cache (P1-P13) | ✅ Active | All 13 phases running |
| Spectral hooks (Stage 5-11) | ✅ Restored | llama-graph.cpp + prime_spectral_attn.h |
| Combined PrimePE + VHT2 | 🔲 Planned | Next: run both together |
| Vilenkin full basis | 🔲 Planned | Replace WHT Z/2Z with Z/p_k Z |
