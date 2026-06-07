# Shannon-Prime — master claims ledger

Single source of truth for the whole series. Rule: nothing appears in any paper, README, post, or talk unless it is a row here, *with its scope attached*. Rows are tagged by paper. See [`METHODOLOGY.md`](METHODOLOGY.md) for the gates.

**Standing caveat:** proof-of-mechanism on small models, one dev host. The mechanisms work and are bit-faithful/gated; they are not scale-validated, multi-model, or independently reproduced. Say exactly that, everywhere.

## Paper 01 — two-ring memory

| # | Claim | Number | Config | Gate | Caveat | Status |
|---|---|---|---|---|---|---|
| 01-R1 | Quality at 8× KV sparsification | +0.69% PPL (2× −0.71, 4× −0.92) | Qwen3-0.6B, wiki, N=2048, q8, sinks=4 | <2% deflection | 1 model/2k/1 corpus | done |
| 01-R2 | Needle retrieval, no recency bias | HIT d10/50/90, to 8× @2k | ±1 proj, decode path | NIAH HIT | 1 model, 1 needle type | done |
| 01-R3 | Two-ring on physical Optane | HIT off NVMe | NO_BUFFERING+IOCP | poison-gated | 512 proven; 32k = R9 | done(512) |
| 01-R4 | Optane read latency | 7.57 µs/read (48.7→18.9→7.57) | IOCP batch, 4 KB | timed, no page cache | syscall+media, Optane-specific | done |
| 01-R5 | KV-RAM footprint | 910× cache (1.8 GB live) | (sink+W) ring buffer | measured alloc+RSS | net ~8×, projk-dominated (~950 MB) | done |
| 01-R6 | KV codec | ~3.5×/f32, lossy | Spinor 63 B | 29/31 argmax, KL .023 | not bit-exact | done |
| 01-R7 | O(N) recall selection | set-equivalent | quickselect | parity + HIT | time win not benchmarked | done |
| 01-R8 | Bit-exact when disabled | bit-identical | gate-off no-op | argmax parity | methodology, not perf | done |
| 01-R9 | 32k needle off NVMe @ ~1.8 GB | **MISS** (run completed: 16.3 h, zero errors; 67% LRU absorption; 19.6 µs/read at QD; 1.35B device reads/stream) | N=32768, B=512 (= **64× selection** — gated regime was 2×–8×), depth 50, f32 r=16 router (config regression: bits-r64/KVSEL env dropped from the runner) | NIAH HIT (poison) — **not met** | no full-attention 32k control yet; router-dilution vs 0.6B model ceiling unseparated; RAM ladder diagnostic open | **measured MISS — not a claim** |

Commit chain: `67f4997` → `f8ea920` (+ `a5e9b86`). Honest negatives (must appear in the paper): CPU decode ~1.34× behind llama.cpp-Q8 (memory is the play, not tok/s); a magnitude-histogram recall signature was falsified and dropped; **the composed 32k retrieval MISSed at the 64× selection budget (R9)** — the infrastructure half of that run (16.3 h saturated dual-store IOCP, 67% temporal-cache absorption, queue-depth latency measured) is real and reportable as such, the retrieval headline is not. Paper 01 releases on the 512-position-proven R3, not R9.

## Paper 02 — the reducing loader (staged; re-gate + repro before release)

| # | Claim | Number | Config | Gate | Caveat | Status |
|---|---|---|---|---|---|---|
| 02-L1 | Reducing transcode, output-preserving | .sp-model 16.3 GB < 19.7 GB GGUF, top-1 identical | 35B-A3B MoE | argmax parity | one model; reduction source-dependent | prior work |
| 02-L2 | Zero-copy swivel load | no fp16 inflation of quants (avoids ~4× bw/footprint) | arena load path | arena-alias verified | load-path invariant | prior work |
| 02-L3 | Codec-by-source, no added loss | Q4→packed-Q4, Q8/F16→packed-Q8 | transcode | gate-off bit-faithful | not a new quant scheme | prior work |
| 02-L4 | Bit-faithful on a second arch | Gemma-class within f32-vs-Q8 floor (PPL 86.2 vs 90.7) | gemma-e2b | PPL gate + argmax | **86.2 vs 90.7 is the floor direction, NOT "5% worse"** | prior work |

Paper 02's receipts come from earlier measured work; per series rule 4 they are re-gated and a one-command repro is built **before** the paper releases.

## Paper 04 — the Oracle & the Teacher (staged 2026-06-06; gated in engine, repro before release)

| # | Claim | Number | Config | Gate | Caveat | Status |
|---|---|---|---|---|---|---|
| 04-R1 | Full variable-geometry forward == oracle | argmax 12/12, max KL 2.663e-10, \|dlogit\| 1.84e-4 | Gemma4-E2B (35L, MatFormer), RTX 2060 vs CPU oracle | E_G4_CU_FULL (f64 log-softmax KL) | one model, one host | gated (engine) |
| 04-R2 | Autoregressive decode == oracle, teacher-forced | ALL 12 generated tokens oracle-predicted | jagged shared-KV cache, per-step AltUp | E_G4_CU_DEC | greedy only; short stream | gated (engine) |
| 04-R3 | First-try composition | both live runs green on first attempt; 0 debug sessions on composed code | after 5 staged gates (38/38 cumulative) | the gate trail itself | process claim — receipts are the trail | gated (engine) |
| 04-R4 | Oracle arithmetic must be enforced, not approximated | per-weight dequant diverges 2.8e-3; inline lift restores the floor | gemm_w_lift vs k_dequant_arena path | L0 staged parity | f32-rounding-order effect, model-agnostic mechanism | gated (engine) |

Engine provenance: `tests/test_gemma4_cuda.c`, tag `stage-eta-phase1-closed-2026-06-06`.

## Paper 05 — the Probe Suite (staged 2026-06-06; every tool live in engine)

| # | Claim | Number | Config | Gate | Caveat | Status |
|---|---|---|---|---|---|---|
| 05-R1 | Bisection localizes divergence without debugging | 2.8e-3 → matmul arithmetic in 2 probe runs; sharer seam proven at ao 1.11e-5 abs | truncated-parity harness, 6 boundaries | staged ABS gates, telemetry-then-pin | needs an oracle (paper 04) | gated (engine) |
| 05-R2 | Norm layers amplify the f32 floor ~×25 | pre-norm 6.3e-5 abs → residual 1.59e-3 (rms(ap)≈0.04) | post_attn_norm, E2B L0 | stage-5 pre-norm probe | gate ABS at floors; never raw rel at norm outputs | gated (engine) |
| 05-R3 | Cold-start + clock-state manufacture phantom speedups | "12.65×" → ~1.06× real (CUDA lazy-load ≈13×; idle SM 405 vs 2100 MHz; GDDR6 free-running under `-lgc`) | CUDA-graph decode, RTX 2060 | warm + n_gen≥256 + both clocks | GeForce `-lmc` flaky; within-run ratios are the signal | gated (engine) |
| 05-R4 | Isolated bench ≠ production gate | synthetic-Q4 bench 1.34e-7 PASS while production K-quant-mix path was 0/256 | Q4_K_M-style arena (Q8 head/Q4 body) | bench + E2E decode gate pair | the pairing IS the method | gated (engine) |
| 05-R5 | Amdahl regime-check before claiming kernel wins | int8/Q4 GEMV ties f32 at 0.6B/full-clock (overhead-bound); ~7× where the bus binds | decode vs isolated sweep | convergence + crossover | bottleneck must be named per claim | gated (engine) |

Engine provenance: `tests/test_gemma4_cuda.c` (harness), `tests/bench_gemv_int8.cu` (sweep), system `CONVENTIONS.md` (the binding benchmark rules).

## Paper 06 — computing on the zip file: the dp4a ladder (staged 2026-06-06)

| # | Claim | Number | Config | Gate | Caveat | Status |
|---|---|---|---|---|---|---|
| 06-R1 | f32 GEMV is bus-saturated at scale | ~290 GB/s = 87% of 336 GB/s peak, flat N=3K..16K | RTX 2060, cuBLAS SGEMV, clocks pinned | isolated sweep | one card | gated (engine) |
| 06-R2 | int8 dp4a ladder rung | ~3.8× f32 at N≥8K (4:1 bytes) | warp-per-row, 128-bit loads, shuffle reduce | sweep + 256/256 top-1 in decode | naive GEMV ≈ cuBLAS absolute at small N | gated (engine) |
| 06-R3 | Q4 dp4a ladder rung | **~7.06× f32** at N≥12K (8:1 bytes − ~7% nibble-unpack ALU tax) | in-ALU unpack, (n^8)-8 sign-extend | sweep + host-ref 1.34e-7 + 256/256 top-1 | activation int8 quant = top-1-lossless, not byte-exact | gated (engine) |
| 06-R4 | Dequant-before-GEMM destroys the advantage | ~9 B/weight; 3× slower than f32 | dequant→f32-scratch→SGEMM | same sweep | the anti-pattern, measured | gated (engine) |
| 06-R5 | Per-tensor precision dispatch for K-quant mixes | 0/256 → 256/256 after `DevTensor.prec` routing | Q8-head/Q4-body arena | production decode gate | required for any Q4_K_M-style artifact | gated (engine) |
| 06-R6 | 12B end-to-end tok/s (the headline) | **SP 34.2 vs llama.cpp-CUDA 31.29 ± 0.20 (+9.3%)** | Gemma-4-12B, RTX 2060, tg256, SM pinned 2100 (GeForce `-lmc` unsupported — memory free-ran for BOTH engines); SP = reducing .sp-model 5.56 GB w/ graph+dp4a; llama.cpp b8861 Q4_K_M ngl 99 | tok/s measured both engines, same card/model/text; SP decode oracle-anchored (argmax or measured top-2) | **NOT citable until the PPL gate closes**: the SP artifact squeezes Q6_K source tensors to Q4 (fewer bytes read AND more weight-quant error); wikitext PPL vs llama.cpp is the release-blocking gate | measured — PPL gate pending |
| 06-R7 | Per-vector int8 activation quant collapses on outlier-heavy models (honest finding) | oracle-rank 205596 (gap 27.9) at the 12B's L11 → **rank 2 (gap 0.31)** after per-16-block scales | 12B L11 carries a TRAINED out_scale of 0.005 — the model flags its own activation outliers; blocks align with the GEMV's 128-bit loads (zero extra bus) | LIFT-arithmetic discriminator (structure at 1.5e-4 floors everywhere) + oracle-rank telemetry | E2B/qwen3 never tripped it — the failure is silent on easy models; the rank print is now standing gate equipment | gated (engine) |
| 06-R8 | The gemma4 GGUF ecosystem ships broken weights; a hand-written reference exposed it (honest finding, ecosystem-scale) | full-precision wikitext PPL = **4.68** (from-scratch forward off the official safetensors); the SAME arithmetic over GGUF-dequantized weights: pre-fix wave **271–364**, post-June-5 rebuilt **192.9**; llama.cpp on the same artifacts 397–506 (two engines agree per-artifact → forward exonerated, ARTIFACTS convicted) | chunk-0/512-ctx/[256,512) teacher-forced, llama-dumped tokens (== HF tokenizer 5431/5431); damage anatomy: in-place, period-6 layer severity, layer-scale class defective, no permutation | gold instrument + hybrid tensor-class swaps + per-layer cosine forensics (lattice `tests/gemma4_gold/`) | corroborated by llama.cpp PR #24118 + Unsloth's "bugs were universal" rebuild notice — which did NOT fix the text tower | measured, receipts in-repo |
| 06-R9 | Sovereign quantization pipeline (safetensors → SP transcoder, zero GGUF bytes) reproduces ground truth | **OK_Q8 artifact: PPL 4.7396 (+1.33% vs gold)**; mixed OK_Q4B/Q8 "B1" artifact (9.4 GB, fits a 12 GB card): **5.1259 (+9.6%, sim-predicted 5.1259 — match to 4 decimals)**; ecosystem's rebuilt 6.3 GB GGUF on identical math: 192.9 | `sp_transcode --st` (values from bf16 checkpoint; GGUF supplies metadata/tokenizer only; mapped-but-missing = hard error); Q4B = per-32 f16 block scales, store-then-derive | gold-instrument artifact gates (67–105 s each), per-layer residual norms tracking bf16 digit-for-digit | per-row Q4 (06-R6's artifact) is formally superseded; 12B tok/s re-anchor (SHOOTOUT-2 on the B1 artifact + q4b kernel) is the remaining open leg | measured — kernel leg pending |

| 06-R10 | SHOOTOUT-2: the honest 12B speed/quality point (closes 06-R6) | **26.1 tok/s at wikitext PPL 5.12 on an RTX 2060 12GB** (graph+dp4a, tg256, SM 2100; decode 256/256 top-1, graph 256/256 EXACT, 24/24 gates); llama.cpp-CUDA same card: 31.29 tok/s — at PPL 192–506 (its artifacts are broken; 06-R8) | B1 artifact 9.4 GB (OK_Q4B gate/up + OK_Q8 rest, per-32 f16 block scales, k_gemv_q4b dp4a — one weight block per 128-bit chunk); GPU PPL gate 5.1160 vs gold 4.6776 (+9.4%, PASS; sim 5.1259 / CPU 5.1259 / GPU 5.1160 triple-agreement) | clock-pinned tok/s + the full PPL gate ladder on the SAME artifact | effective decode bandwidth: SP 245 GB/s vs llama 207 GB/s (+18% engine efficiency); SP's artifact is 42% heavier BECAUSE it is the only mathematically intact 4-bit gemma4-12B — a like-for-like speed race does not exist: no other stack runs this model correctly at 4-bit. 06-R6's 34.2 is RETIRED with its quality-failed artifact | **measured + gated — citable** |

Engine provenance: `src/backends/cuda/cuda_forward.cu`, `tests/bench_gemv_int8.cu`, `tests/test_qwen3_decode_cuda.c` (28/28); gold instruments: lattice `tests/gemma4_gold/`.

## Not claimed (yet) — kept out of every front door

- The transformer *is* a CM-elliptic-curve endomorphism sequence; training *is* BSD analytic-rank maximization. Real research program; no explicit curve, no model trained this way. Companion only.
- Anything on models larger than the references, multi-model generality, or independent reproduction. Until those exist, the phrase is "proof-of-mechanism."
