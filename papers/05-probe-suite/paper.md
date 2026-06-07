# The Probe Suite

### How correct numbers about computing systems are manufactured

### Paper 05 of the Shannon-Prime series · receipts-first

*A. Knack. Draft. All quantitative results are proof-of-mechanism on one host (RTX 2060) and the reference models named per row; see §2 for scope and the Receipts section for provenance.*

---

## Abstract

Correct numbers about computing systems are not read off; they are **engineered**. This paper ships the measurement suite we run as one set — truncated-parity bisection, isolation sweeps, benchmark hygiene, and oracle-rank telemetry — with the receipt of what each component caught. Used together during one GPU port, the suite localized a wrong-arithmetic 2.8e-3 divergence in two probe runs (05-R1), characterized a ~25× norm-layer error amplification instead of papering over it (05-R2), dissolved a 12.65× phantom speedup into the honest ~1.06× (05-R3), exposed a mixed-precision 0/256 correctness bug that the isolated bench passed at 1.34e-7 (05-R4), and caught a per-vector activation-quant collapse at oracle-rank 205,596 that two easier models had silently absolved (06-R7). It then landed a 35-layer GPU port first-try — the suite is the reason the monolith never needed a debugger. The second half of the paper reports the same toolset turned outward, at ecosystem scale: hybrid tensor-class bisection and per-layer cosine forensics that convicted an entire public ecosystem's quantized artifacts of weight-level damage against a hand-written full-precision reference (06-R8), and a simulate-before-build discipline that mapped a model's quantization-hostility through six candidate recipes before a line of CUDA was written — with the built artifact then matching the simulation to four decimal places and the GPU kernel agreeing as a third instrument (06-R9, 06-R10). The claim of this paper is the suite itself: a debugging kit that turns out to be a manufacturing process for trustworthy numbers, and one that scales from a single kernel to a supply chain.

---

## 1. Introduction: the claim

A measured number arrives carrying every artifact of how it was measured: the clock state of the card, the warm-up state of the runtime, the synthetic-versus-real shape of the test data, the integrity of the weights it ran over, and the reference frame it was compared against. Most published systems numbers are read off a run and trusted on the strength of the run having completed. This series takes the opposite position, stated in [`METHODOLOGY.md`](../../METHODOLOGY.md) and enforced in [`LEDGER.md`](../../LEDGER.md): no number without a command, no command without a gate, no gate without a measured floor.

This paper is the suite that makes that position operable. It is not a framework or a library; it is a small set of practices, each of which exists because it caught something, and each of which is presented here with its kill. The components are exercised live in the engine repo (`tests/test_gemma4_cuda.c` — the staged harness; `tests/bench_gemv_int8.cu` — the isolated sweep; the system repo's `CONVENTIONS.md` — the binding benchmark rules) and, since June 2026, in the lattice repo's forensic instruments (`tests/gemma4_gold/`).

**Scope, stated before it can be used against us.** Every receipt below is proof-of-mechanism on one development host and the specific model named in its ledger row. The suite's components are general practice; the numbers that validate them are not a generality claim.

---

## 2. Setup and methodology

The suite presupposes one thing: an **oracle** — a reference implementation whose outputs are trusted at a characterized floor. Paper 04 of this series builds that oracle (a CPU forward proven against the model's own arithmetic, staged gate by gate); this paper assumes it and grades against it. The methodology rules of the series apply throughout and are cited rather than restated: bit-exact-when-off, no number without a command, scope travels with the number ([`METHODOLOGY.md`](../../METHODOLOGY.md)).

Two suite-internal disciplines recur in every section and are named once here:

- **Telemetry-then-pin.** No gate tolerance is invented. The first run of any probe measures the floor; the gate is then pinned at roughly 3× the measured floor. A gate that cannot be met is surfaced upstream as a finding, never silently revised.
- **ABS at floors.** Relative error inflates without bound on near-zero values. Wherever a probe sits at a floor dominated by small magnitudes — norm outputs are the canonical case — the gate currency is absolute error, with the magnitude regime stated.

---

## 3. The suite

Each tool below is presented as *idea, kill, rule* — the practice, the documented failure it caught, and the binding convention it left behind.

### 3.1 Truncated-parity bisection

**Idea.** To localize a divergence in a ported forward pass, build a CPU mirror from the oracle's own primitives and *truncate it at staged boundaries* — embed, norm, projection, attention, pre-norm, residual — then diff the port against the mirror at the same boundary. A divergence that appears between boundary k and boundary k+1 lives in the code between them. This converts debugging (stepping through a monolith) into bisection (two probe runs bracket the fault).

**Kill (05-R1).** A 2.8e-3 divergence in the GPU port was localized to the matmul arithmetic itself in two probe runs: the dequant-then-multiply path rounds in a different order than the oracle's inline-lift arithmetic, and the difference is model-agnostic f32 rounding order (the mechanism is row 04-R4 of the companion paper). The same harness proved the hardest seam in the architecture — the L15 shared-KV cross-layer VRAM addressing — exact at 1.11e-5 absolute.

**Kill (05-R2).** The stage-5 pre-norm probe read 6.3e-5 absolute while the residual after the norm read 1.59e-3 — a ~25× amplification. The cause is structural, not a bug: the RMS denominator at that boundary is ≈0.04, so the norm *divides by a near-zero* and magnifies the incoming f32 floor. Telemetry-then-pin characterized it; a naive fixed tolerance would have failed the port forever, and a silently widened one would have hidden real faults behind it.

**Rule.** Gates at norm boundaries are pinned in ABS, at the measured amplified floor — never raw relative error at a norm output.

### 3.2 Isolation sweeps — and the pairing rule

**Idea.** To measure a kernel, strip everything else: one variable (the kernel) against one axis (matrix size), in `tests/bench_gemv_int8.cu`. The sweep answers *regime* questions a production run cannot: where overhead-bound becomes bandwidth-bound, and therefore where a byte-diet kernel can possibly win.

**Kill (05-R5).** The sweep located the overhead→bandwidth crossover at N≈2K and showed int8/Q4 GEMV *tying* f32 on the 0.6B model at full clocks — the bus was not the binding bottleneck there, so the byte diet bought nothing — while delivering ~7× where the bus binds. The Amdahl rule this leaves behind: a faster kernel on a non-binding bottleneck measures as a tie, so every kernel claim must name the bottleneck it relieves. This is what proved paper 06's dp4a ladder without paying a 12B integration tax per data point.

**Kill (05-R4) — the pairing rule.** The isolated bench validates kernel *math*; only the production gate validates the *data-structure handoff*. A uniform-synthetic Q4 bench passed at 1.34e-7 while the real K-quant-mix arena — Q8 head, Q4 body, the shape every Q4_K_M-style artifact actually has — returned 0/256 top-1 in the production decode loop. The bug was invisible to any test whose data was homogeneous; it was fixed with per-tensor precision dispatch (06-R5) and caught *only* because the bench and the end-to-end gate run as a pair. The pairing is the method: neither half is sufficient alone.

### 3.3 Benchmark hygiene

**Idea.** A GPU throughput number is a function of clock state, runtime warm-up, window length, and regime — and each of these manufactures phantoms if uncontrolled. The rules are binding in the system repo's `CONVENTIONS.md`: warm up (CUDA lazy-load alone is a ≈13× cold-start phantom); use long windows (sub-second jitter swung one number 32→88→92); lock **both** clocks (`-lgc` pins the SM only — an idle card sits at 405 vs 2100 MHz, and a weight-GEMV tracks the free-running GDDR6 memory clock, which GeForce `-lmc` does not reliably pin); regime-check before claiming a win; prefer within-run ratios over absolutes.

**Kill (05-R3).** A CUDA-graph decode "win" of 12.65× dissolved, under warm-up plus n_gen≥256 plus both clocks accounted, into ~1.06× — and the honest 1.06× then *held* across reruns, which the phantom never would have. Three stacked artifacts (lazy-load, idle clocks, short window) had compounded into a number that looked like a breakthrough and was a measurement of the measuring process.

**Rule.** No throughput number is reported from a cold start, a short window, or an unpinned clock state; within-run ratios are the signal on hardware where the memory clock cannot be pinned.

### 3.4 Oracle-rank telemetry

**Idea.** Top-1 agreement is a pass/fail bit; it cannot tell a near-miss from a catastrophe, and it is monotonic-blind — a transformation that preserves argmax can still be distributionally wrong. The fix is to print, at every gate, the *rank* of the oracle's chosen token in the candidate distribution, and the logit gap. Rank ≤ 2 with a small gap is currency; rank 10⁵ is a conviction.

**Kill (06-R7).** Per-vector int8 activation quantization — one scale per activation vector — had passed every gate on two models. On the 12B's layer 11, the oracle-rank print read **205,596** (gap 27.9): the layer carries a trained `out_scale` of 0.005, the model's own flag for activation outliers, and a single scale per vector collapses under them. Per-16-block scales, aligned to the GEMV's 128-bit loads so the fix costs zero extra bus traffic, brought it to **rank 2** (gap 0.31). The instructive part is the silence: the easy models never tripped it, so without the rank print the failure would have shipped inside a passing top-1 suite the first time an outlier-heavy model arrived.

**Rule.** The oracle-rank print is standing gate equipment on every top-1 gate, not a diagnostic bolted on after failure.

### 3.5 Structural ingest probes

A smaller member, listed for completeness: every weight-set upload gate prints the *resolved* geometry — layer types, owner/sharer split, elastic widths, per-tensor precision — before any forward runs. Its kill: the reference artifact's real attention period was 5 with kv-full-stride 15, where the documentation said 6 and 20-15. Code that trusts documentation over the artifact's own header inherits the documentation's errors; the probe makes the artifact testify first.

---

## 4. The suite at ecosystem scale: the Gemma-4 forensics (June 2026)

Everything above is the suite pointed *inward*, at our own port. In June 2026 the same toolset was pointed *outward*, at a public model ecosystem — and the methods transferred without modification, because bisection, isolation, and oracle-grading do not care whether the system under test is our kernel or someone else's supply chain.

The triggering observation (06-R8): a hand-written, from-scratch full-precision forward — the *gold instrument*, lattice `tests/gemma4_gold/_t2_manual_forward.py`, built from the official safetensors checkpoint and config alone — scored wikitext PPL **4.68** on the gemma-4-12B, where llama.cpp on the publicly distributed GGUF artifacts of the *same checkpoint* scored 397–506. Running the gold arithmetic over the GGUFs' own dequantized tensors scored 271–364 pre-fix and 192.9 on the post-June-5 rebuilt artifact: two independent engines agreeing per-artifact exonerated the forward and **convicted the artifacts** — the published weights themselves were damaged, across an entire ecosystem's distribution chain, and corroborated by the ecosystem's own record (llama.cpp PR #24118; the distributor's "bugs were universal" rebuild notice — which did not fix the text tower).

### 4.1 Hybrid tensor-class swaps: bisection over weight classes

The truncated-parity idea generalizes: instead of truncating a forward at *layer boundaries*, substitute trusted tensors into the suspect set one *weight class* at a time and re-measure. Starting from the broken GGUF at 364, swapping in the safetensors **layer-scale class alone** dropped the score to **97** — isolating a single defective tensor class carrying a multiple-fold damage factor. Swapping in the norms *as well* moved it to **114 — worse**: the GGUF's norms are coherent with the GGUF's damaged weights, which is itself evidence (innocent of independent damage, and consistent with in-place corruption rather than a class-level swap error). The embeddings: innocent. Three probe runs, one defective class isolated, two classes exonerated — bisection, at the granularity of a supply chain's tensor classes (06-R8; receipts and instrument paths in lattice `tests/gemma4_gold/`).

### 4.2 Per-layer cosine forensics: killing the permutation hypothesis

The obvious mechanism for ecosystem-scale damage is a layer permutation — weights written to the wrong layer index during conversion. The probe: the full cosine matrix between the GGUF's layers and the safetensors' layers. Result: the **diagonal is exact and the cross-layer cosines are ≈0** — no permutation, anywhere. The damage is *in-place*, and it carries a **period-6 severity structure**: layers ≡ 0,1 (mod 6) survive at cosine 0.93–0.97 against the trusted weights, the other four classes sit at 0.24–0.70 (06-R8). A hypothesis killed and a mechanism fingerprinted in one matrix — the same falsify-first discipline as the decoy test that killed paper 01's magnitude-histogram router.

### 4.3 Simulate-before-build: the newest member of the suite

With the trusted weight source established, the question became which quantization recipe to build. The old way is to build each candidate's kernel and artifact and measure; the suite's way is to **simulate the recipe through the proven reference forward** — quantize-dequantize the weights per recipe in the gold instrument and run the already-validated arithmetic. Each simulation costs minutes; each avoided kernel costs days.

Six recipes were simulated against gold 4.6776 (06-R9; full matrix in the contract): naive all-symmetric per-32 Q4 landed at **+45%** — the model is quantization-hostile, which is *why* its vendor ships QAT — and the recipe search walked the matrix down to **B1** (Q4 block-scaled on the FFN gate/up classes only, Q8 everywhere else) at **+9.6%**, predicted PPL 5.1259, before a line of CUDA existed. The recipe decision was made on simulated evidence, with the VRAM budget computed per recipe alongside.

Then the receipts landed in sequence (06-R9, 06-R10): the sovereign pipeline (safetensors → SP transcoder, zero GGUF bytes) produced the OK_Q8 artifact at **4.7396 (+1.33% vs gold)**, with per-layer residual norms tracking the bf16 run digit-for-digit; the built B1 artifact, gated through the gold instrument, scored **5.1259 — matching the simulation to four decimal places**; and the GPU kernel built for it landed at **5.1160**. Three instruments — simulation, CPU artifact gate, GPU engine — agreeing on one artifact's quality is the strongest form of the number this suite knows how to manufacture. The throughput half closed the same way: **26.1 tok/s at PPL 5.12 on an RTX 2060 12GB**, 24/24 gates, decode 256/256 top-1, graph replay exact, with the comparison stated honestly — the incumbent runs faster (31.29 tok/s) on artifacts this paper's instruments showed scoring PPL 192–506, and the engine-efficiency decomposition (245 vs 207 GB/s effective decode bandwidth, +18%) is reported separately from the artifact-size difference (06-R10).

### 4.4 What transferred

Every element of §3 reappears in §4 unchanged: the oracle (§2) became the gold instrument; truncated-parity bisection (§3.1) became tensor-class swaps; the falsification habit became the cosine matrix; telemetry-then-pin set the artifact-gate floors; the bench/production pairing (§3.2) became sim/CPU-gate/GPU-gate triple agreement; benchmark hygiene (§3.3) governed the shootout. The suite did not need an "ecosystem mode." It needed a target.

---

## 5. Limitations and honest negatives

- **One host, named models.** Every receipt is proof-of-mechanism on one development card (RTX 2060) and the model in its ledger row. The practices are general; the validating numbers are not a generality claim.
- **The suite presupposes an oracle.** Without a trusted reference (paper 04), bisection has nothing to grade against. Building the oracle is the expensive precondition, and on the 12B its serial CPU cost became economically absurd (a 331-minute in-engine run was killed undiagnosed); the contract's harness fixes — progress narration, score-only positions — are open work, and the in-engine 12B regate waits on them (06-R9 caveat).
- **The phantom kills are one-time receipts.** We show that the hygiene rules caught these specific artifacts; we do not claim the rule set is complete. The 32→88→92 jitter case and the GeForce memory-clock gap are documented precisely because new hardware will manufacture new phantoms.
- **The ecosystem conviction is corroborated but not independently reproduced.** Two engines agreeing per-artifact, the ecosystem's own fix record, and the rebuilt artifact still scoring 192.9 through our instruments (06-R9 addendum) is strong; an independent third party rerunning the gold instrument is the missing receipt.

## 6. Reproduction

Every number above is a row in [`LEDGER.md`](../../LEDGER.md) with model, fixture, flags, gate, and provenance attached. The instrument locations, as the contract cites them:

- engine `tests/test_gemma4_cuda.c` — the truncated-parity harness and its staged gates;
- engine `tests/bench_gemv_int8.cu` — the isolated crossover sweep;
- system repo `CONVENTIONS.md` — the binding benchmark-hygiene rules;
- lattice `tests/gemma4_gold/` — the gold instrument, the class-swap and cosine probes, and the artifact gates, with receipts (`_t2_gold.log` and the per-probe logs) alongside.

The formal amendment chain for §4 is the speed contract's 2026-06-07/08 addenda. The artifact gates run in 67–105 seconds each (06-R9) — reproduction of the quality numbers is minutes, not hours.

## 7. Related work

The individual practices have ancestors: differential testing and delta-debugging (bisection against a reference); microbenchmark methodology and the long literature on benchmarking crimes (hygiene); quantization-error simulation in PTQ toolchains (simulate-before-build); logit-level agreement metrics in speculative decoding (rank telemetry). Our position relative to these is the same as paper 01's relative to its ancestors: the contribution is the *composition under a binding discipline* — the tools run as one set, every tolerance is telemetry-then-pinned, every kill is a ledger row, and the pairing rule (isolated bench + production gate, simulation + built artifact + device kernel) is enforced rather than recommended. The ecosystem-forensics application (§4) — grading a public distribution chain's artifacts against a from-scratch oracle and bisecting the damage by tensor class — is, to our knowledge, the unusual part.

## 8. Conclusion

The probe suite is not a debugging kit. It is the manufacturing process by which this series' numbers acquire the right to be believed: bisection localizes, isolation names the regime, hygiene strips the phantoms, rank telemetry sees what pass/fail cannot, and simulation now front-runs construction. Inward, it landed a 35-layer GPU port without a debugger; outward, it convicted a supply chain and then manufactured the replacement number to four-decimal agreement across three instruments. The tools are small, the discipline is the product, and it scales from one kernel to an ecosystem because correct measurement was never about the size of the thing measured.

---

## Receipts

All claims trace to these ledger rows ([`LEDGER.md`](../../LEDGER.md)); scope travels with each.

| Row | Receipt |
|---|---|
| 05-R1 | Bisection localizes without debugging: 2.8e-3 → matmul arithmetic in 2 probe runs; sharer seam exact at 1.11e-5 abs |
| 05-R2 | Norm layers amplify the f32 floor ~×25 (6.3e-5 → 1.59e-3; rms≈0.04); ABS gates at norm boundaries |
| 05-R3 | Phantom speedups: "12.65×" → ~1.06× under warm-up + long windows + both clocks |
| 05-R4 | Isolated bench ≠ production gate: synthetic 1.34e-7 PASS vs production 0/256; the pairing is the method |
| 05-R5 | Amdahl regime-check: int8/Q4 ties f32 where overhead binds; ~7× where the bus binds |
| 06-R7 | Per-vector activation quant collapses on outlier-heavy models: oracle-rank 205,596 → 2 after per-16-block scales |
| 06-R8 | The ecosystem ships broken weights: gold 4.68 vs GGUF 271–364 (rebuilt 192.9), llama.cpp 397–506; class swaps + cosine forensics; in-place period-6 damage |
| 06-R9 | Sovereign pipeline reproduces ground truth: OK_Q8 4.7396 (+1.33%); B1 5.1259, sim-predicted to four decimals |
| 06-R10 | SHOOTOUT-2: 26.1 tok/s at PPL 5.12 on a 2060-12GB; sim 5.1259 / CPU 5.1259 / GPU 5.1160 triple agreement; 24/24 gates |

Companions: paper 04 (the oracle the probes grade against), paper 06 (the result the suite certified).
