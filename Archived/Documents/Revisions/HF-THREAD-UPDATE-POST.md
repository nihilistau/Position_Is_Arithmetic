# Ready-to-post: HF thread update (discuss.huggingface.co/t/shannon-prime-lattice/176466)

*Post body below the line. Markdown is Discourse-compatible as-is.*

---

**Update — the receipts-first paper series grew three papers, and one of them required indicting an ecosystem**

A lot has happened since the opening post. The short version: the public,
receipts-first paper series at
**https://github.com/nihilistau/Position_Is_Arithmetic** now carries papers
**04, 05 and 06** — and finishing 06 forced us to root-cause something the
whole local-inference community is currently sitting on: every Gemma-4 GGUF
we could measure, including the post-fix rebuilds, carries broken weights.

The series discipline hasn't changed: every number is a row in a shared
ledger with a command behind it, honest negatives stay on the record, and no
throughput number is citable without a quality gate on the same artifact.
That last rule is the reason this update exists.

**Paper 04 — The Oracle & the Teacher** *(oracle-grounded backend verification)*

- *What it solves:* porting a complex architecture to new silicon without the
  weeks-long divergence hunt — and, it turns out, defending yourself when the
  reference implementation itself is wrong.
- *How:* extract a bit-faithful CPU oracle from the reference first (scalar,
  readable, f64-accumulating), grade every backend against the oracle and
  never against a prior port, and gate autoregressive decode by
  teacher-forcing (the oracle re-predicts the port's own generated stream).
  Receipt: a 35-layer variable-geometry MatFormer (per-layer attention
  widths, shared KV, proportional RoPE, softcap) matched its oracle at
  **max KL 2.663e-10** (argmax 12/12), both live runs green first-try, 38/38.
- *How it fits:* this is the verification layer for everything in §1 of the
  opening post — "byte-exact, not small-KL" is only meaningful if the thing
  you're byte-exact *against* is itself proven. The paper's case study is the
  strongest demonstration we have: when llama.cpp scored wikitext PPL 397–506
  on Gemma-4-12B and the ecosystem normalized it, a from-scratch forward
  written off the official safetensors + config alone measured **4.6776** —
  the model was healthy, llama.cpp's forward was exonerated (two independent
  engines agree per-artifact), and the GGUF artifacts themselves were
  convicted. An oracle is not a porting tool; it's the only defense against a
  poisoned reference frame.

**Paper 05 — The Probe Suite** *(bisection, isolation & benchmark hygiene as one set)*

- *What it solves:* the fact that correct numbers about computing systems are
  not read off — they are manufactured. The suite is how.
- *How:* truncated-parity bisection, isolation sweeps, benchmark hygiene and
  oracle-rank telemetry, used together. Documented kills: a 12.65× phantom
  speedup (three stacked artifacts), a 2.8e-3 wrong-arithmetic localized in
  two probe runs, a mixed-precision 0/256 bug the isolated bench passed at
  1.34e-7, and a per-vector activation-quant collapse at oracle-rank 205,596
  on outlier-heavy activations (fixed with per-block scales aligned to the
  kernel's 128-bit loads).
- *How it fits:* the second half turns the same toolset outward, at ecosystem
  scale — tensor-class swap bisection over the broken GGUFs (restoring just
  the per-layer scale class recovered PPL 364→97; restoring norms made it
  *worse*, proving the matmul weights damaged too), per-layer cosine
  forensics (no permutation; in-place damage with a period-6 layer
  signature), and **simulate-before-build**: six quantization recipes
  simulated through the proven reference forward before a line of CUDA
  existed — and the built artifact then matched the simulation **to four
  decimal places** (5.1259), with the GPU kernel agreeing as a third
  instrument (5.1160).

**Paper 06 — Computing on the Zip File** *(the dp4a bandwidth ladder — complete, gated, citable)*

- *What it solves:* memory-bound decode on consumer silicon. The weights'
  byte count is the speed of light, but only if you compute directly on the
  packed integer codes — dequantizing to f32 scratch first measured 3×
  *slower* than plain f32.
- *How:* warp-per-row `__dp4a` GEMV, 128-bit loads, in-ALU nibble unpack
  (~7% tax), exact integer accumulation, one Frobenius lift at the end —
  the isolated ladder runs f32 1× → int8 ~3.8× → Q4 ~7.06×, hugging the
  byte ratios. New this round: the **OK_Q4B** format (per-32-block f16
  scales, store-then-derive discipline) where one weight block is exactly
  one 128-bit chunk in the kernel — zero extra code-bus traffic — and the
  sovereign quantization pipeline: artifact values come from the official
  safetensors checkpoint, never from a GGUF, and every artifact gates
  against the paper-04 oracle before any throughput number is taken.
- *The headline, stated honestly:* **Gemma-4-12B at 26.1 tok/s and wikitext
  PPL 5.12 on an RTX 2060 12GB** (graph path bit-exact, decode 256/256
  top-1, 24/24 gates, clocks pinned). llama.cpp-CUDA on the same card does
  31.29 tok/s — at PPL 192–506, because its artifacts are broken.
  Engine-for-engine we move +18% more bytes/s (245 vs 207 GB/s effective);
  our artifact is heavier because it is the only mathematically intact
  4-bit Gemma-4-12B in existence. And in the spirit of the series: an
  earlier 34.2 tok/s headline is formally **retired** in the ledger —
  it was measured on an artifact that later failed the PPL gate. The rule
  caught our own number first.

**For anyone hitting the Gemma-4 quant weirdness themselves:** we published a
standalone walkthrough — verify the breakage in ~30 minutes with an
engine-independent method, plus the quantization recipe that actually works
on this PTQ-hostile model (blanket 4-bit costs +45% PPL; 4-bit on the FFN
gate/up pair only with 8-bit elsewhere costs +9.6%):
https://github.com/nihilistau/Position_Is_Arithmetic/blob/main/GEMMA4-QUANT-FIX.md
All forensic instruments are MIT, ~130-line numpy/torch scripts, no GPU
required for the verification.

How this fits the lattice overall: the opening post's thesis was that
floating-point drift and un-provable identity are entropy bleeding into the
hardware, and that a discrete substrate makes correctness a property you
prove rather than estimate. This round extended that doctrine one level up
the stack — to the *artifacts*. The same discipline that makes a kernel
byte-exact (oracle, gates, receipts) is what caught an interchange format
silently destroying weights while every smoke test stayed green. The
supply chain is now part of the math.

Papers, ledger, methodology, instruments:
**https://github.com/nihilistau/Position_Is_Arithmetic**

As always — the unflattering numbers are kept attached on purpose.
