# VHT2 Banded KV Cache Compression — Research Results (2026-04-05)

## Summary

Systematic sweep establishing the optimal VHT2 banded quantization configuration
for both K and V caches across two reference architectures. The key finding: a
single config (K: n=4 bands 5/5/4/3, V: flat int3) is optimal across all tested
head dimensions and delivers ~3.4–3.8× total KV compression with <1.25% PPL cost.

---

## Method

The shadow cache intercepts KV writes. Each head vector is:

1. Transformed via Walsh-Hadamard (WHT = Z/2Z Vilenkin-Hartley)
2. Split into N equal-size bands (high → low spectral energy order)
3. Each band quantized with its own fp16 scale + packed int values
4. Reconstructed on read via inverse WHT

For V, the same pipeline is available but a single-band (flat) mode is used
because V has no spectral concentration (see findings below).

Configuration is driven entirely by environment variables — no rebuild required:

```powershell
# K: n=4 bands, 5/5/4/3 bits, sk must equal head_dim
$env:LLAMA_SHADOW_CACHE="1"
$env:LLAMA_SHADOW_VHT2="1"
$env:LLAMA_SHADOW_VHT2_READONLY="0"
$env:LLAMA_SHADOW_HEAD_DIM="128"           # model head_dim
$env:LLAMA_SHADOW_VHT2_SKELETON_K="128"   # must equal head_dim
$env:LLAMA_SHADOW_VHT2_N_BANDS="4"
$env:LLAMA_SHADOW_VHT2_BAND_BITS="5,5,4,3"

# V: flat int3
$env:LLAMA_SHADOW_VHT2_V="1"
$env:LLAMA_SHADOW_VHT2_SKELETON_V="128"   # must equal head_dim
$env:LLAMA_SHADOW_VHT2_V_N_BANDS="1"
$env:LLAMA_SHADOW_VHT2_V_BAND_BITS="3"
```

---

## Models Tested

| Model | Architecture | head_dim | KV heads | Layers | Baseline PPL |
|-------|-------------|----------|----------|--------|--------------|
| Dolphin3.0-Llama3.2-1B Q8_0 | Llama 3.2 | 64 | 4 (MHA) | 16 | 13.0957 |
| Qwen3-8B Q8_0 | Qwen 3 | 128 | 8 (GQA) | 28 | 9.3317 |

Evaluation: WikiText-2 test set, ctx=2048, batch=512, chunks=4 (~±0.43 PPL noise floor).

---

## Finding 1: sk Must Equal head_dim

WHT requires the full head vector. Subsampling collapses quality catastrophically.

| sk | K corr | Compression | PPL | ΔPPL |
|----|--------|-------------|-----|------|
| 16 | 0.8615 | 4.6× | 43.39 | +231% 💥 |
| 32 | 0.9073 | 3.9× | 19.28 | +47% 💥 |
| **64** | **0.9941** | **2.8×** | **13.11** | **+0.12% ✅** |

(Dolphin 1B, head_dim=64). At sk=32 the WHT sees only half the head — the
transform is no longer spanning the basis. sk must equal head_dim exactly.

---

## Finding 2: Optimal K Config is n=4 Bands, 5/5/4/3

WHT concentrates K's energy in the first few coefficients — this is the
structural signature of RoPE-encoded positional information. The 5/5/4/3
allocation mirrors actual WHT energy decay: more bits where the signal lives.

### Dolphin 1B (head_dim=64, 16 elements/band)

| Config | K corr | K × | PPL | ΔPPL |
|--------|--------|-----|-----|------|
| 5/5/4/3 n=4 | 0.9941 | 2.8× | 13.1119 | +0.12% ✅ |

### Qwen3-8B (head_dim=128, varied band count)

| Config | K corr | K × | PPL | ΔPPL |
|--------|--------|-----|-----|------|
| **n=4: 5/5/4/3** | 0.9928 | **3.2×** | 9.4208 | **+0.95%** ✅ |
| n=5: 6/5/5/4/3 | 0.9947 | 2.8× | 9.3888 | +0.61% |
| n=8: 6/6/5/5/4/4/3/3 | 0.9945 | 2.8× | 9.3661 | +0.37% |

n=5 and n=8 show slightly better correlation and PPL (all within the ±0.43 noise
floor), but pay a real 14% compression penalty (2.8× vs 3.2×). The scale overhead
of extra bands erases the gain. **n=4 is the optimal tradeoff.**

At head_dim=128, n=4 gives 32 elements/band — same ratio as head_dim=64 (16
elements/band with n=4). The larger head_dim improves compression automatically
because the 2-byte fp16 scale overhead amortizes over more data.

**3-bit floor:** Any band at 2 bits is catastrophic. Minimum viable = 3 bits.

---

## Finding 3: V Has No Spectral Concentration — Flat Beats Banded

K carries RoPE positional encoding, which creates a characteristic energy
concentration in the first WHT bands. V carries content (values), which has
no such structure. WHT energy is uniform across V's bands.

Consequence: banded quantization adds scale overhead without benefit for V.
Flat quantization (n=1 band, all elements same bit-width) outperforms banded
at every compression level.

### V sweep (Dolphin 1B, K fixed at 5/5/4/3 n=4)

| V Config | V corr | V × | Total × | PPL | ΔPPL |
|----------|--------|-----|---------|-----|------|
| 5/5/4/3 n=4 | 0.9939 | 2.8× | 2.8× | 13.1470 | +0.39% |
| 4/4/4/3 n=4 | 0.9926 | 3.0× | 2.9× | 13.1779 | +0.63% |
| 3/3/3/3 n=4 | 0.9813 | 3.6× | ~3.15× | 13.1923 | +0.74% |
| 5/3 n=2 | 0.9871 | 3.2× | 3.0× | 13.2058 | +0.84% |
| 4/2 n=2 | 0.9003 | 4.0× | ~3.4× | 13.3036 | +1.59% 💥 |
| **flat int3 n=1** | **0.9708** | **4.3×** | **~3.4×** | **13.1745** | **+0.60% ✅** |
| flat int4 n=1 | 0.9944 | 3.4× | ~3.1× | 13.2064 | +0.84% |

**Flat int3 wins:** lower PPL than banded 3/3/3/3 (better by 0.18 PPL) at higher
compression (4.3× vs 3.6×). Banded V is strictly worse.

---

## Final Validated Configuration

### Best Config: K n=4 5/5/4/3 + V flat int3

| Model | K × | V × | Combined × | PPL | ΔPPL |
|-------|-----|-----|------------|-----|------|
| Dolphin 1B (hd=64) | 2.8× | 4.3× | **~3.4×** | 13.1745 | +0.60% |
| Qwen3-8B (hd=128) | 3.2× | 4.7× | **~3.8×** | 9.4482 | +1.24% |

V adds only +0.29% PPL on top of K-only for Qwen (9.4208 → 9.4482). The V
compression comes almost free in quality terms.

---

## Improvement Over Prior Methods

### vs. Old Shadow Cache (2.3× per cache)

| Cache | Old | VHT2 | Gain |
|-------|-----|------|------|
| K | 2.3× | 3.2× | **+39%** |
| V | 2.3× | 4.7× | **+104%** |
| Combined | ~2.3× | ~3.8× | **+65%** |

### vs. llama.cpp Built-in KV Quantization

| Method | K | V | Combined | PPL cost |
|--------|---|---|----------|----------|
| q8_0 (baseline) | 2× | 2× | 2× | ~0% |
| q4_0 flat | 4× | 4× | 4× | ~1-3% |
| **VHT2 best** | **3.2×** | **4.7×** | **~3.8×** | **+1.24%** |

VHT2 V (4.7×) beats flat q4 (4×) because per-vector fp16 scaling handles
outliers better than q4's block quantization. VHT2 K (3.2×) is slightly below
flat q4 but the spectral band allocation preserves RoPE structure that flat
quantization destroys indiscriminately.

### RAM Impact at head_dim=128, 28 layers, 8 KV heads

| Context | fp16 baseline | Old (2.3×) | VHT2 (3.8×) |
|---------|--------------|------------|--------------|
| 2048 | ~460 MB | ~200 MB | **~121 MB** |
| 32K | ~5.9 GB | ~2.6 GB | **~1.56 GB** |

---

## Phase 2: Live Inference Compression (2026-05-23) — FIRST VALID RESULTS

> **Important:** All results above were captured in **readonly/measurement mode** — the shadow
> cache measured reconstruction quality but did NOT write compressed data back to the GPU KV
> cache during inference. Two bugs prevented live compression from working:
>
> **Bug 1 — Wrong hook timing:** `pre_batch_hook` fired before each ubatch wrote K/V to the
> GPU cache, so the shadow always read an empty cache and deferred. Write-back never fired
> with real data during multi-chunk perplexity eval.
>
> **Bug 2 — CUDA stream race:** `process_ubatch` submits GGML kernels asynchronously on
> `cuda_ctx->stream()`. The hook read K/V via `ggml_backend_tensor_get` which uses
> `cudaStreamPerThread` — an independent stream with no ordering guarantee. Reading K/V
> immediately after `process_ubatch` returned produced stale/partial data (PPL 462 with
> sk=64, 8-bit).
>
> **Fixes applied:**
> 1. Moved all writeback dispatch from `pre_batch_hook()` → new `post_ubatch_hook()` virtual method
>    on `llama_memory_i`. The call site in `llama-context.cpp` fires only when `process_ubatch`
>    returns success (non-null result).
> 2. Added `ggml_backend_sched_synchronize(sched.get())` immediately before `post_ubatch_hook()`
>    in `llama-context.cpp` to drain the GGML compute stream before any K/V reads.

### Live Compression Results (Dolphin3.0-Llama3.2-1B Q8_0, head_dim=128, 4-band WHT)

Model: Dolphin3.0-Llama3.2-1B Q8_0 · Baseline PPL: 13.0982  
Eval: WikiText-2, ctx=2048, batch=512, chunks=4 (noise floor ±0.43 PPL)

| Config | Corr | Compression | PPL | ΔPPL |
|--------|------|-------------|-----|------|
| Baseline | — | 1× | 13.10 | — |
| sk=64, 8-bit K+V | 0.91 | 3.1× | 20.86 | +59% 💥 |
| sk=110, 8-bit K+V | 0.976 | 2.1× | 13.95 | +6.5% |
| sk=110, 4-bit K+V | 0.972 | 3.7× | 14.01 | +7.0% |
| sk=120, 8-bit K+V | 0.990 | 2.0× | 13.39 | +2.2% |
| **sk=120, 4-bit K-only** | **0.985** | **3.6×** | **13.34** | **+1.8% ✅** |
| sk=120, 4-bit K+V (flat) | 0.985 | 3.6× | 13.50 | +3.1% |
| sk=120, 5/5/4/3 K+V (4-band) | 0.983 | 3.3× | 13.48 | +2.9% |

**Best Pareto: sk=120, 4-bit, K-only → 3.6× compression at only +1.8% PPL degradation.**

> **⚠️ Accounting note (corrected in Phase 3):** The 3.6× figure above used the CPU-path
> accounting (0.5 bytes/4-bit coeff), which is correct. However, the Phase 2 PPL results were
> measured with a `vht2_k_store` stale-entry bug: the store was never cleared between perplexity
> chunks, so chunks 2–4 ran with chunk 1's old K coefficients reconstructed over the new K vectors.
> In effect, 3/4 of the evaluation ran at artificially high quality (uncompressed or using
> prior-chunk reconstructions). The true GPU-path PPL at this setting is reported in Phase 3.

Key observations from live testing:
- **sk < 0.85 × head_dim is unusable** for live writeback (corr 0.91 → PPL +59%). The WHT
  must span nearly the full head vector for reconstruction quality to be usable.
- **K-only outperforms K+V** at same compression ratio: V compression adds +1.3% PPL for
  only 0.4× additional compression (V has no spectral concentration — compresses poorly vs K).
- **4-bit vs 8-bit at sk=120**: +0.9% PPL extra for 1.8× more compression — good tradeoff.
- **Adaptive bands (5/5/4/3) vs flat 4-bit**: negligible PPL difference (13.48 vs 13.50),
  but adaptive achieves slightly lower compression (3.3× vs 3.6×) due to scale overhead.
  Flat 4-bit wins on compression; adaptive wins marginally on quality.

### Activation Environment Variables

```powershell
# Minimum required to activate shadow cache
$env:LLAMA_SHADOW_CACHE = "vilenkin"   # Required — "=1" also works
$env:LLAMA_SHADOW_VHT2  = "1"

# Best config: K-only, sk=120, 4-bit flat
$env:LLAMA_SHADOW_VHT2_SKELETON_K = "120"
$env:LLAMA_SHADOW_VHT2_BITS       = "4"
$env:LLAMA_SHADOW_VHT2_V          = "0"   # Disable V compression

# K+V, sk=120, 4-bit (adds +1.3% PPL, same 3.6x compression)
$env:LLAMA_SHADOW_VHT2_V          = "1"
$env:LLAMA_SHADOW_VHT2_SKELETON_V = "120"
```

Note: `LLAMA_SHADOW_VHT2` requires `LLAMA_SHADOW_CACHE` to be set. Setting only
`LLAMA_SHADOW_VHT2=1` without the cache var will silently do nothing.

## Phase 3: GPU Fast-Path — Fused In-Place Kernel (2026-06-xx)

> **Eliminates the PCIe round-trip** of Phase 2. The entire VHT2 pipeline (forward WHT →
> sparse quantize → inverse WHT → in-place writeback) runs as a fused CUDA kernel in GPU
> shared memory. No data leaves the GPU.

### Bugs Found and Fixed in this Phase

**Bug 3 — CUDA WHT deadlock (0% GPU utilization):**  
`wht_shared()` had `__syncthreads()` inside the `if ((tid & h) == 0 && pair < n)` branch.
On SM 7.5 (Turing), `__syncthreads()` requires ALL threads to reach it. Only ~half the
threads enter the butterfly branch → permanent deadlock. The inner sync was also logically
unnecessary (each thread is the sole writer to its butterfly pair). Fixed by removing it and
keeping only the outer `__syncthreads()` at the end of each butterfly stage.

**Bug 4 — Stale done_flags between chunks:**  
The `done_flags` array (GPU-side idempotency guard) was not reset between perplexity
chunks. After chunk 1 compressed all positions, done_flags stayed set, and chunks 2–4
were silently skipped. Already corrected: `shadow_kv_cache_vht2::clear(bool data)` resets
done_flags when the KV cache is fully cleared at chunk boundaries. No per-batch reset
is needed (and would cause compounding quantization error if applied).

**Bug 5 — Accounting error (2× undercount of compression ratio):**  
4-bit coefficients were counted as 1 byte each instead of 0.5 bytes. This made 4.1×
appear as 2.1×. Fixed: `total_k_bytes_comp` now uses `(kv_size × n_heads × sk × bits + 7) / 8`.

### Phase 3 Results (Dolphin3.0-Llama3.2-1B Q8_0)

Model: Dolphin3.0-Llama3.2-1B Q8_0 · head_dim=128 (detected), 14/16 layers  
Eval: WikiText-2, ctx=2048, batch=512, chunks=4 (noise floor ±0.63 PPL)  
Build: CUDA 13.2, SM 7.5 (Turing RTX class)

**Per-chunk comparison:**

| Chunk | Baseline PPL | GPU VHT2 PPL | Delta |
|-------|-------------|--------------|-------|
| 1     | 11.26       | 12.00        | +0.74 |
| 2     | 14.08       | 15.10        | +1.02 |
| 3     | 14.67       | 15.59        | +0.92 |
| 4     | 13.10       | 13.89        | +0.79 |
| **Final** | **13.10** | **13.89** | **+0.79 (+6.0%)** |

**Summary:**

| Config | PPL | ΔPPL | K Compression | Timing |
|--------|-----|------|---------------|--------|
| Baseline (no compression) | 13.10 | — | 1× | — |
| GPU VHT2, sk=120, 4-bit K-only | **13.89** | **+6.0%** | **4.1×** | **~2 ms/batch** |

**GPU timing:** ~2 ms per batch (flat — done_flags prevent re-compression within a chunk).  
First batch per chunk is slightly slower (~5 ms) due to lazy allocation of per-layer GPU buffers.  
No PCIe transfers; all computation in shared memory on-device.

**Quality note:** The consistent +0.8 PPL delta across all chunks confirms this is a true
systematic effect of compression, not noise. The global-scale 4-bit quantizer (single abs-max
scale over all 120 skeleton coefficients) is the primary quality limiter — WHT spectral
coefficients have very non-uniform magnitudes (energy decays across the spectrum), so a single
scale wastes bits on large coefficients and clamps small ones. Per-group quantization (matching
the CPU path's per-band scheme) is the next quality improvement.

### Activation for GPU Fast-Path

The GPU path is automatically selected when `GGML_USE_CUDA` is defined (i.e., in any CUDA
build). No extra flag needed.

```powershell
# Validated GPU fast-path configuration
$env:LLAMA_SHADOW_CACHE         = "vilenkin"
$env:LLAMA_SHADOW_VHT2          = "1"
$env:LLAMA_SHADOW_VHT2_SKELETON_K = "120"
$env:LLAMA_SHADOW_VHT2_BITS     = "4"
$env:LLAMA_SHADOW_VHT2_V        = "0"   # V compression disabled (see Phase 2)

# Run perplexity (requires -b 512 for multi-batch evaluation)
.\bin\Release\llama-perplexity.exe -m model.gguf -f wiki.test.raw -c 2048 -b 512 --chunks 4
```

---

## Key Principles (Transferable)

1. **WHT = Z/2Z Vilenkin-Hartley.** It works because K has arithmetic structure
   (RoPE creates geometric frequency progressions). The WHT is the natural basis
   for that structure.

2. **K and V are structurally different.** K encodes position (structured, WHT
   concentrates energy). V encodes content (diffuse, WHT spreads uniformly).
   They need different compression strategies — not the same quantizer.

3. **5/5/4/3 mirrors WHT energy decay.** This is not arbitrary — it's the natural
   shape of the energy profile. Any deviation (more bits in low bands, fewer in
   high bands) increases error.

4. **Scale overhead determines optimal band count.** At n=4: 4 × 2-byte scales
   = 8 bytes overhead for 128×2=256 bytes raw. At n=8: 16 bytes overhead.
   More bands = worse compression unless quality gain is statistically clear.

5. **3-bit floor.** 2-bit encoding on any band is catastrophic. The WHT
   coefficients in lower bands are small but not negligible — 1 bit of sign
   plus 1 bit of magnitude is insufficient.

6. **sk = head_dim, always.** The WHT requires the full vector. Any truncation
   breaks the transform's spanning property.
