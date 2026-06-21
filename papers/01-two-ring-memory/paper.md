---
type: paper-bite
title: A Two-Ring Memory Architecture for Long-Context Transformers
description: A. Knack. Draft. All quantitative results are proof-of-mechanism on one reference model (Qwen3-0.6B); see §2 for scope and §6 for reproduction.
tags: [paper-bite, memo, two-ring, memory]
timestamp: 2026-06-06T11:57:50Z
resource: ./papers/01-two-ring-memory/paper.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# A Two-Ring Memory Architecture for Long-Context Transformers

### Query-directed sparse recall with byte-addressable KV offload

### Paper 01 of the Shannon-Prime series · receipts-first

*A. Knack. Draft. All quantitative results are proof-of-mechanism on one reference model (Qwen3-0.6B); see §2 for scope and §6 for reproduction.*

---

## Abstract

Long-context transformer inference is bottlenecked by the key–value (KV) cache: resident memory grows linearly with context, attention compute grows quadratically, and naive sparsification of the cache degrades model quality. We present a *memory architecture* — not a new model — that attaches to a frozen pretrained transformer and addresses all three pressures, validating each component as a gated, reproducible measurement. A query-directed ±1 Rademacher projection selects, at each step, a bounded budget of relevant past keys; pinning a handful of leading attention-sink tokens preserves the softmax denominator so that sparsification costs almost nothing; a two-ring design keeps a recent window resident in RAM and offloads the cold tail to byte-addressable storage; and an expected-O(N) selection removes the routing bottleneck. On WikiText at 2k context, 8× KV sparsification changes perplexity by **+0.69%** — and at 2× and 4× the change is *negative*, i.e. sparsification slightly reduces perplexity. The composed system retrieves an out-of-distribution needle at 32k context with the cold KV served off a physical NVMe (Optane) drive, holding the resident KV cache to **8.3 MB — 910× below the dense 7.5 GB** — at single-digit-microsecond reads. Every mechanism is **bit-exact when disabled**: the modifications are provable no-ops in their off state, verified throughout by argmax parity against the unmodified forward pass. We report results as proof-of-mechanism on a single 0.6B model and supply one-command reproductions. A companion develops the algebraic framework that motivated several design choices; none of it is required to run or to validate the system described here.

---

## 1. Introduction: three walls

A decoder-only transformer generating in a context of length N must, at every step, attend over a cache of N past key and value vectors. This cache is the dominant cost of long-context inference, and it presses on the system in three distinct ways.

The **memory wall**: the resident cache is linear in N. At 32k tokens, even on a 0.6B model, it is several gigabytes, and it grows without bound as context extends. The **compute wall**: full attention is quadratic in N, and any scheme that *selects* a subset of keys to attend to must avoid replacing an O(N²) attention with an O(N²) selection. The **intelligence wall**: the obvious fix — keep only the highest-scoring keys — discards information, and done naively it degrades the model's output distribution badly enough to be unusable.

Each wall has been attacked in isolation. Our contribution is not a new primitive for any one of them but a *composition*: a small set of discrete mechanisms, each of which knocks down one wall, each gated against a reproducible measurement, and each provably inert when switched off so that the composition can be trusted. The discipline — every modification is bit-identical to the stock forward pass in its default state, and every reported number traces to a runnable command — is as much the contribution as the mechanisms. Table 1 summarizes the receipts; the sections that follow present each as a self-contained unit of *idea, receipt, payoff, and implementation*.

**Scope, stated before it can be used against us.** All quantitative results are measured on one model (Qwen3-0.6B) on one host. They establish that the mechanisms work and are faithful; they are not a scaling study, a multi-model generalization, or a claim about larger models. We label this throughout as proof-of-mechanism.

**What this paper is not.** It is not a new model architecture or a training method; it attaches to a frozen pretrained network and preserves its outputs. It is not the algebraic theory that motivated parts of the design — that is a separate companion (§8), and nothing here depends on it.

**Table 1 — receipts.** *(R1) 8× KV sparsification at +0.69% perplexity; (R2) needle retrieval at depths 10/50/90 with no recency bias; (R3) retrieval with the cold KV on physical Optane, poison-gated; (R4) 7.57 µs per random block read; (R5) 910× resident-cache shrink at 32k (~1.8 GB live); (R7) O(N) selection, set-equivalent to brute force; (R8) bit-exact when disabled; (R9) the composed 32k retrieval. Full provenance and scope in the shared ledger.*

---

## 2. Setup and methodology

**Reference model and host.** All measurements use Qwen3-0.6B (f16 GGUF) on a single CPU host (Intel i9-11900KB), with weights served from a quantized (Q8) packed arena. Perplexity uses a WikiText test corpus; retrieval uses a needle-in-a-haystack construction with an out-of-distribution secret injected at a controlled token depth.

**The invariant that makes the numbers trustworthy.** Every mechanism in §3 is controlled by a flag and is a *strict no-op when off*: with all flags cleared, the forward pass is bit-identical to the unmodified reference. We verify this continuously by argmax (token-sequence) parity against the stock decode path. Because the off-state is provably the original model, any on-state result is a controlled delta rather than a confound. This is methodology, not a performance claim — but it is the precondition for believing everything that follows.

**Gate vocabulary** (used throughout):

- *Parity gate* — on-versus-off argmax identity; confirms a change is a faithful no-op when disabled.
- *Deflection gate* — relative perplexity change versus the full-attention baseline, same engine and tokenizer, common-mode quantization; the bar is < 2%.
- *Poison gate* — on the offload path, evicted resident slots are overwritten with NaN, so a correct answer is impossible unless the value was genuinely fetched from storage. It turns a silent-fallback bug into a loud failure.

---

## 3. Mechanisms

Each mechanism below knocks down one of the three walls and is presented in the same four parts — idea and math, the measured receipt, the payoff, and the implementation — so that no claim is separated from its evidence.

### 3.1 Query-directed recall: the ±1 Rademacher router

**(a) Idea and math.** At each step we must choose, from all N cached keys, a budget of B to attend over. The selection score must be cheap and, decisively, *directional*: it must distinguish a key aligned with the current query from one of equal magnitude that is not. We score with a fixed ±1 Rademacher random projection. A single frozen r×d matrix of ±1 entries projects each cached key — once, post-RoPE, into a resident sidecar — and the current query; their projected dot product estimates the true query·key inner product, by the Johnson–Lindenstrauss property that a random projection preserves inner products in expectation with variance falling as 1/r. The ±1 entries keep the projection integer- and register-native: no floating-point projection matrix, and the score is a sum of signed key coordinates. The recall set is then the pinned sinks (§3.2), the top-(B−W−sink) candidates by projected score, and a recent window of W tokens.

**(b) Receipt.** On an adversarial needle-and-decoy shootout — needles aligned with the query, decoys built as permutations of needles with an identical magnitude histogram but near-zero true dot product — a rank-16 projection (32 bytes per token) is exact: 8/8 needles recovered, cosine 1.0000, 0 decoys admitted at budget 64, where a magnitude-histogram signature recovered 0/8. On the real model, the injected needle is retrieved at depths 10%, 50%, and 90% with no recency bias, and survives to 8× sparsification at 2k context.

**(c) Payoff.** Directional, query-dependent selection at 32 bytes per token of index. It finds the *relevant* past rather than the recent past — the mechanism that makes a bounded attention budget viable.

**(d) Implementation.** A frozen-seed ±1 matrix, deterministic across runs and backends; keys projected post-RoPE into a resident sidecar; the recall set assembled as above. The change is a no-op when recall is off (parity gate holds). Reference commit `67f4997`. The router was adopted only after a competing magnitude-signature approach was falsified on the decoy test (§5): direction, not magnitude, is what retrieval requires.

### 3.2 Preserving quality: attention-sink pinning

**(a) Idea and math.** Given the router's budget B, the model attends only over the selected keys — a hard top-B truncation of the softmax. This looks safe: attention output is a convex combination of value vectors, and we are dropping the lowest-weight terms. It is not safe, for two reasons. First, the discarded tail is large in aggregate: many individually small attention weights still carry real distributional mass. Second, and decisively, the first few tokens of the sequence act as *attention sinks* (Xiao et al., 2023): they absorb the excess probability mass the softmax cannot place elsewhere. When the router evicts those tokens — they are old, and rarely score high against the current query — the softmax must redistribute their absorbed mass onto semantically irrelevant keys, and the output distribution destabilizes. The fix is to exempt the first k tokens from the router entirely: pin them in the resident set regardless of score.

**(b) Receipt.** We measure perplexity through the *decode* path (teacher-forced autoregressive PPL), so the recall mechanism is actually exercised; a prefill-path measurement would bypass it. Qwen3-0.6B, WikiText, N = 2048, with a full-attention baseline perplexity of 12.683.

| Configuration | 2× (B=1024) | 4× (B=512) | 8× (B=256) |
|---|---|---|---|
| Hard top-B, no sinks | — | +40.0% | +103.6% |
| Top-B + 4 pinned sinks | −0.71% | −0.92% | +0.69% |

Without sinks, 4× and 8× fail the < 2% deflection gate by twenty- to fiftyfold. With four pinned sink tokens, every tier passes; 2× and 4× are *negative* — discarding the lowest-relevance keys slightly denoises the distribution. The most compact statement of the result: four pinned tokens convert a +104% catastrophe at 8× into +0.69%.

**(c) Payoff.** This is the intelligence wall. It is what lets the router sparsify aggressively — up to 8× fewer attended keys at 2k context — without the output distribution degrading. Sparsification stops being a quality/efficiency tradeoff and becomes nearly free in quality terms at these budgets.

**(d) Implementation.** A single integer knob (default 4). The pinned tokens are held in the resident ring (§3.4) and never offloaded or evicted; the router's candidate range and the ring's eviction boundary both exclude them, so the pin is structural rather than a branch in the hot loop. No-op when recall is off. Reference commit `e916365`.

### 3.3 The memory wall: two rings and byte-addressable offload

**(a) Idea and math.** Split the cache into **Ring-1**, a small resident window of recent and pinned tokens held in RAM, and **Ring-2**, the cold tail held on storage. Each step, the router names the old tokens it needs and those blocks are fetched from Ring-2. The access pattern is scattered single-block random reads, not streaming, so the right medium is byte-addressable, low-latency, random-access storage. Optane (3D XPoint) is near-ideal: persistent, byte-addressable, with random reads on the order of ten microseconds.

**(b) Receipt.** The needle is retrieved with the cold KV on a physical Optane NVMe drive, *poison-gated*: Ring-1's evicted slots are overwritten with NaN, so a correct answer is only possible if the value was genuinely read back from the drive. Measured per-block read latency falls 48.7 → 18.9 → 7.57 µs across three implementations — naive per-head blocking reads, then per-layer deduplication (a block holds all heads, so one fetch serves them all), then asynchronous batched completion.

**(c) Payoff.** The memory wall. The KV cache leaves RAM for a storage tier the architecture treats as a genuine third level of memory, with reads cheap enough to stay within the per-step budget.

**(d) Implementation.** On Windows, `FILE_FLAG_NO_BUFFERING` (reads hit the device, not the OS page cache — otherwise a sub-RAM file is served from DRAM and the latency number is meaningless) plus an I/O Completion Port for asynchronous batched reads, deduplicated per layer. The read and write handles must be separate: binding the write handle to the completion port corrupts the synchronous spill path. A POSIX `O_DIRECT` + `pread` fallback exists. Reference commit `e895ef4`. The 7.57 µs figure is syscall-plus-media latency on Optane; a generic NVMe will be higher. Correctness is media-independent; the latency figure is not.

### 3.4 Realizing the footprint: the Ring-1 window shrink

**(a) Idea and math.** With the cold tail on storage, Ring-1 need only hold (sink + W) tokens, not all N. We make the resident f32 cache a ring buffer of that many slots per layer: a sink token maps to its own fixed slot, any other token s maps to sink + (s − sink) mod W. The structural property that makes this clean: a token is overwritten in the ring exactly when token s+W is written — which is exactly the moment the router's eviction condition (s drops below the recent-window start) fires. The buffer and the router agree by construction; there is no separate eviction bookkeeping to get wrong.

**(b) Receipt.** At 32k context the resident KV cache is 8.3 MB versus the dense 7.5 GB — 910×. The live process working set at 32k is ~1.8 GB.

**(c) Payoff.** The memory wall, realized: the gigabyte cache becomes a megabyte window.

**(d) Implementation.** Modulo slot indexing, gated to the offload path so the baseline retains the full absolute-indexed cache (parity gate holds). Reference commit `f8ea920`. **Honest accounting:** the ~1.8 GB net is dominated not by the 8.3 MB KV cache but by the router index — the ±1 projection sidecar over all tokens, ~950 MB at 32k. The honest claim is therefore "910× on the KV cache, ~8× net," both stated. The index is itself compressible by the same logic — a sign-packed `popcount` form would cut it roughly 32× — but that is future work, not a current claim.

### 3.5 The compute wall: O(N) selection

**(a) Idea and math.** Selecting the top-B of N scores by repeated maximum-extraction is O(B·N) — and at large N and B that is *worse* than the dense attention it was meant to cheapen. We use quickselect (median-of-three Hoare partition) over [score, index] pairs to place the top-B in expected O(N); their internal order is irrelevant, since the softmax over them is order-free.

**(b) Receipt.** Set-equivalent to the brute-force selection: the parity gate holds, and the needle is retrieved on both the resident and the offload paths after the change.

**(c) Payoff.** The compute wall on the selection step: recall selection scales linearly in context, not quadratically. (The claim here is correctness and complexity; the wall-clock win at 32k is not separately benchmarked, and we do not claim it.)

**(d) Implementation.** Per-thread score scratch, parallel over heads. Reference commit `b7a1f92`.

### 3.6 The codec underneath: Spinor-block KV compression

**(a) Idea and math.** Independently of the two rings, each KV head-vector can be stored as a fixed 63-byte block — a rank-ordered anchor skeleton plus quantized residuals. It is a bounded-divergence overlay, not a lossless code.

**(b) Receipt.** ~3.5× over f32 (1.0–1.7× over f16); on the real model, 29/31 argmax agreement with the f32 cache and KL 0.023 — lossy but bounded. We explicitly do *not* claim "120×" or "lossless": the codec is per-vector and lossy.

**(c) Payoff.** A constant-factor reduction in per-vector KV size that compounds with offload — less to store on the drive and less to move per fetch.

**(d) Implementation.** Gated; off is the f32 cache, bit-identical. The per-vector cosine (0.99996) does not carry to per-token argmax identity (29/31): this overlay is a smoke-bounded approximation, and the bit-exact floor is the gate-off f32 path, not the codec.

### 3.7 Composition and the prefill/decode split

The blocks compose cleanly: the router (§3.1) and sinks (§3.2) decide *what* to attend; the two rings (§3.3) and the window shrink (§3.4) decide *where it lives*; quickselect (§3.5) keeps the deciding linear; the codec (§3.6) shrinks each stored block. One honest seam remains. Engaging recall during the dense *prefill* forces a storage read for nearly every prefill position — an artifact of how the test exercises the system, not the production decode pattern. A decode-only mode runs the prefill dense in RAM (fast, exact) and engages recall only at decode; it trades the always-low-RAM property — peak RAM during ingest returns to the full cache — for fast ingestion. The fusion closes that seam: a dense prefill in a full-position RAM buffer, then a single bulk compact-and-spill of the cold tail to storage at the prefill→decode boundary — the history is written to the drive, the sinks and recent window are copied into the shrunk `sink + W` cache, and the prefill buffer is *freed* — so decode proceeds at window-sized resident RAM while the full context is served back from storage on demand. This recovers both properties at once: fast exact prefill (no per-position storage read during ingest) *and* window-sized decode RAM. It is gated (`SP_RECALL_FUSE`), and verified at 512: the needle is retrieved off the drive after the buffer is freed, with the boundary spill logged (`[fuse] boundary @ pos=512: spilled, freed; resident KV now the sink+window`). All three modes are parity-verified — off is bit-identical to the stock cache. Reference commits `a5e9b86`, `7896bc4`.

---

## 4. Capstone attempt: the composed 32k run — what it proved, and the retrieval it did not

The composed system, run end to end (2026-06-06): an out-of-distribution needle injected at depth 50% of a 32,768-token context, recall budget 512, four pinned sinks, the cold KV served from physical Optane. The run *completed* — 16.3 hours of saturated dual-store `NO_BUFFERING`+IOCP operation, zero errors, 1.35×10⁹ device reads per stream (K 11.1 TB, V 5.5 TB) at 19.6 µs/read at queue depth, a 2 GB LRU temporal cache absorbing 67% of fetches on both streams, the resident KV window at 15.6 MB versus the dense 7.5 GB — **and the needle was not retrieved.**

We report that plainly, because the number teaches: B=512 at 32k positions is a **64× selection budget**, and every retrieval-quality gate in §3 was measured at 2×–8× (N=2048). The miss is an extrapolation failure we should not have been surprised by — compounded by a run-config regression (the as-run router was the lowest-resolution f32 r=16 configuration, not the bit-packed r=64 selector the run was designed around), and unguarded by any full-attention 32k control for a 0.6B model, so router dilution and the model's own long-context ceiling are not yet separated. The storage thesis — that a physical drive can serve as a live KV memory tier at single-digit-to-QD microsecond latency — is *strengthened* by this run; the retrieval-at-64×-budget claim is withdrawn until diagnosed. The poison-gated retrieval off the drive stands as proven at 512 positions (R3).

> *Editorial note: an earlier draft of this section described the 32k retrieval in the present tense ahead of the reference run, with figures to be filled on completion. The run completed and missed. Per this series' own rule — no number anywhere that is not a ledger row — the section now reports what was measured. The reproduction in §6 demonstrates the storage-retrieval mechanism itself; the 32k-budget regime is an open diagnostic (ledger row R9).*

## 5. Limitations and honest negatives

We state these plainly: for a receipts-first paper the negatives are part of the evidence that the gates discriminate.

- **One model, proof-of-mechanism.** All results are on Qwen3-0.6B on one host. No scaling study, no multi-model generalization, no independent reproduction yet.
- **Speed.** The CPU decode at Q8 (~39.5 tok/s) is ~1.34× *behind* a tuned llama.cpp at the same quantization (52.8 tok/s) on the same model. The value proposition is the memory envelope, not raw throughput; we do not claim a speed win.
- **A falsified competitor.** An order-statistic, magnitude-histogram recall signature was direction-blind on the adversarial decoy test and was discarded in favor of the ±1 projection. We report it because a falsified hypothesis demonstrates the gates discriminate.
- **Partial coverage.** Perplexity deflection is measured on one corpus at 2k context; 8k and 32k deflection are pending. Net RAM is router-index-dominated, and index compression is unimplemented.
- **The composed 32k retrieval missed (§4).** At a 64× selection budget — 8× past the gated regime — the needle was not retrieved, and the run carried a router-config regression. The infrastructure receipts from that run are real and quoted; the retrieval headline is not claimed. Diagnosis (budget-ratio ladder in RAM, full-attention control) is open work.

## 6. Reproduction

Each headline number is reproducible from a single command, with the model, corpus, environment flags, gate, and commit specified. The 32k retrieval reproduces drive-agnostically for *correctness* — any NVMe will surface the needle — while only the latency figure requires Optane. The reproduction harness and its expected output ship with the code.

## 7. Related work

Streaming and windowed attention with sink tokens (StreamingLLM); heavy-hitter and eviction policies (e.g. H2O); KV-cache quantization and offload; retrieval-augmented decoding. Our position relative to these: an integer/discrete, gated, storage-*tiered* composition in which the eviction boundary is *derived from* the router rather than bolted on, the cold tier is genuine byte-addressable storage rather than host RAM, and every mechanism is bit-exact when disabled.

## 8. Companion: the algebraic framework

Several design choices — Möbius/square-free embedding reconstruction, Frobenius-structured quantization — were motivated by a complex-multiplication elliptic-curve framework over the imaginary quadratic field of discriminant −163, whose ring of integers is a unique factorization domain. That framework is developed separately and is explicitly *not required* for any claim in this paper; the mechanisms above stand on their measurements alone. The companion is a door for the curious, not a dependency.

## 9. Conclusion

The contribution is a composition and a discipline. Each of the three walls of long-context inference — memory, compute, intelligence — is met by a discrete mechanism that is individually gated, reproducible, and provably inert when disabled, and the mechanisms compose into a system that retrieves at 32k context with the cache on storage and a megabyte-scale resident window. The numbers are proof-of-mechanism on a single small model and reproducible from a command. Validating the composition at scale, fusing dense prefill with offload, and compressing the router index are the next work.
