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
| 01-R9 | 32k needle off NVMe @ ~1.8 GB | *pending* | N=32768, B=512, depth 50 | NIAH HIT (poison) | in progress | in progress |

Commit chain: `67f4997` → `f8ea920` (+ `a5e9b86`). Honest negatives (must appear in the paper): CPU decode ~1.34× behind llama.cpp-Q8 (memory is the play, not tok/s); a magnitude-histogram recall signature was falsified and dropped.

## Paper 02 — the reducing loader (staged; re-gate + repro before release)

| # | Claim | Number | Config | Gate | Caveat | Status |
|---|---|---|---|---|---|---|
| 02-L1 | Reducing transcode, output-preserving | .sp-model 16.3 GB < 19.7 GB GGUF, top-1 identical | 35B-A3B MoE | argmax parity | one model; reduction source-dependent | prior work |
| 02-L2 | Zero-copy swivel load | no fp16 inflation of quants (avoids ~4× bw/footprint) | arena load path | arena-alias verified | load-path invariant | prior work |
| 02-L3 | Codec-by-source, no added loss | Q4→packed-Q4, Q8/F16→packed-Q8 | transcode | gate-off bit-faithful | not a new quant scheme | prior work |
| 02-L4 | Bit-faithful on a second arch | Gemma-class within f32-vs-Q8 floor (PPL 86.2 vs 90.7) | gemma-e2b | PPL gate + argmax | **86.2 vs 90.7 is the floor direction, NOT "5% worse"** | prior work |

Paper 02's receipts come from earlier measured work; per series rule 4 they are re-gated and a one-command repro is built **before** the paper releases.

## Not claimed (yet) — kept out of every front door

- The transformer *is* a CM-elliptic-curve endomorphism sequence; training *is* BSD analytic-rank maximization. Real research program; no explicit curve, no model trained this way. Companion only.
- Anything on models larger than the references, multi-model generality, or independent reproduction. Until those exist, the phrase is "proof-of-mechanism."
