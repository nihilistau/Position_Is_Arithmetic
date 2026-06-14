# Receipts or it didn't happen: bit-exact-or-bounded as a research methodology

*Shannon-Prime release series, paper 10 — the methodology capstone. Discipline:
[METHODOLOGY.md](../../METHODOLOGY.md). Every number cited below is a row in
[LEDGER.md](../../LEDGER.md) with a command behind it; this paper's own evidence
is those rows and the four documented times the discipline overruled its
authors.*

## 0. The claim

Papers 01–09 each report a mechanism: a two-ring memory offload, a reducing
loader, a dp4a byte-diet, a latent crossbar, an O(1) cache, a resident daemon.
This paper reports no new mechanism. Its subject is the discipline those papers
share, and its claim is that the discipline is itself a reproducible
contribution — not a preamble to the results but the reason the results are
believable.

The discipline reduces to one standard with two faces. **Every claimed number is
either bit-exact** — byte-for-byte identical to the untouched production
baseline — **or it passes a bounded-degradation gate that was written down before
the code and never moved to make a result pass.** Everything else (the null
floor, the negative controls, the published failures, the measurement hygiene)
is machinery in service of that one standard.

The evidence that the standard is real, and not a slogan, is that it has caught
its own authors four separate times, in the open, and each catch is recorded —
the wrong call *and* its correction — in the public ledger. A reader can verify
that the discipline actually operated, because the mistakes did not get quietly
deleted. That is the headline: across every campaign, each number is bit-exact
when the mechanism is off or passes a pre-stated gate when it is on — and the
discipline self-corrected four times where it would have been easier not to.

"Auditable" is the one word a floating-point, text-bus agent stack cannot
claim about itself. This paper is the argument that it is also the moat.

## 1. The three rules and the three gates

Three rules govern what may be written down ([METHODOLOGY.md](../../METHODOLOGY.md)):

1. **Bit-exact when off.** Every mechanism is controlled by a flag and is a
   *strict no-op* in its default state. With the flag off, the forward pass is
   bit-identical to the unmodified reference network. The baseline is therefore
   provably the original model, and any on-state result is a controlled delta,
   never a confound between two moving targets. This is the invariant under
   everything else — ledger row **01-R8** records it as a standalone gate
   (argmax-identical to the stock model, "methodology, not perf").

2. **No number without a command.** Nothing appears in a paper, the README, a
   post, or a talk unless it is a row in the ledger reproducible by a specified
   command — model, corpus, flags, gate, commit. A claim you cannot run is not a
   claim. The ledger's own header carries the rule; this paper inherits it by
   citing rows rather than recalling numbers.

3. **Scope travels with the number.** Every figure carries its caveat — which
   model, which context length, which corpus, what it does and does not
   generalize to. "Proof-of-mechanism on one small model, one dev host
   (RTX 2060, 12 GB)" is stated up front, not buried. The standing caveat at the
   top of the ledger is not boilerplate; it is rule 3 made structural.

Three gates make the rules operational — each a different currency for a
different kind of claim:

- **Parity gate** — on-versus-off argmax (token-sequence) identity. It confirms
  a change is a faithful no-op when disabled, and it is what *licenses* rule 1.
  When a port to new silicon is involved, the parity currency tightens to
  distribution identity (argmax + KL) and teacher-forced decode, because raw
  activation error is the wrong currency — norm layers amplify the f32 floor
  ~25× (paper 05, 05-R2), so a port can be perfect at the logits and alarming at
  an intermediate tensor.

- **Deflection gate** — relative perplexity change versus the full-attention
  baseline, measured on the *decode* path (so the mechanism is actually
  exercised), with the same engine, tokenizer, and quantization on both sides so
  the comparison is common-mode. The bar is **< 2%**, set in advance.

- **Poison gate** — for any storage-offload or eviction path, the evicted
  resident slots are overwritten (NaN, or 0xFF). A correct answer is then
  impossible unless the value was genuinely fetched from storage; a
  silent-fallback bug fails *loudly* instead of passing quietly. A bare equality
  could be faked by a leak from a live cache; the poison gate cannot be.

The three rules and three gates are the whole apparatus. The rest of this paper
shows the apparatus working — first as architecture, then at the moment exactness
must be surrendered, then at the four moments it overruled the team.

## 2. The null floor as architecture

The strongest form of rule 1 is not a test you run after the fact; it is a
decision about where code may be written. The production decode path —
`gemma4_decode_cuda` in the engine — is left **byte-untouched** by every
experiment built on top of it. The XBAR cache experiments and the KAIROS
resident-daemon experiments do not edit the decoder; they add a parallel,
flag-gated path beside it and prove the new path equals the old one.

KAIROS-02 states this in its own provenance line: the persistent-KV
`gemma4_kv_*` routines are built *on* `gemma4_decode_cuda`, which is left "byte-
untouched = null floor" (ledger **KAIROS-02**). The rewind result is then a
controlled delta against that floor: after an idle tick plus `rewind(Δ)`, the KV
is byte-identical to never-visited across all 48 owner layers (16.5 MB,
diffs = 0), and the re-run reproduces identical tokens. Because the baseline is
*the same code that ships*, the diff is meaningful — it is the experiment's
effect and nothing else.

This is why the bit-exact-when-off rule is architecture, not etiquette. If the
production path were edited to "support" the experiment, every on-state number
would be a comparison between two modified systems, and "controlled delta" would
be a fiction. The null floor is the discipline made structural: the experiments
orbit the production path; they are forbidden from changing it. The same shape
holds across the series — the gate-off no-op of 01-R8, the oracle-anchored ports
of paper 04, the slab and ring of paper 08 — all are deltas against an untouched
reference.

## 3. When exact dies: the pre-registered bounded gate

Bit-exactness has a hard boundary. The moment a stage crosses from exact to
*lossy* — sparse selection, compression, approximate routing — bit-exactness is
impossible *by definition*: keys are dropped, the reduction tree changes,
the floating-point sum is no longer the same sum. At that boundary the parity
gate cannot survive, and the honest move is not to relax it quietly until a
number passes. The honest move is to name a different gate — a bounded
degradation — and to **pre-register it before writing the code.**

The series crosses this boundary exactly once, at the learned-router work of
paper 08. Everything up to the router is exact: the spill is byte-exact, the
paged read is byte-exact, the SWA ring is byte-identical because it reads the
window in position order so the non-associative float reduction is defeated by
*order*, not merely by key-set. Then the global sparse selector arrives, drops
keys on purpose, and exactness ends. The pre-registered gate that replaces it is
the deflection gate of §1: **PPL < 2%**, fixed in advance, common-mode against
the full-attention baseline. The learned 512×32 LSH router lands at **+0.47% at
8× compression** — green against a bar set before the router existed, not a bar
moved to fit it (ledger **X-R2**).

The rule that makes this trustworthy is *no silent gate revision*: if an
implementation cannot meet the pre-stated gate, that surfaces upstream as a
failure, never as a retuned threshold. The frozen ±1 router at +4.17% is RED
against the same 2% bar and is reported RED (X-R2) — the gate discriminated
against the team's first router, and the number stands. A gate you are allowed to
move after seeing the result is not a gate; it is a decoration.

## 4. The four self-corrections (the heart)

A discipline that never overrules its authors is indistinguishable from one that
is never tested. The evidence that these gates discriminate is the record of the
four times they returned a verdict the team did not want — and each is in the
public ledger with both the wrong call and the correction, so a reader can audit
that the self-correction actually happened.

### 4.1 A faster-but-wrong headline, retired by its own rule

The first 12B speed headline was **34.2 tok/s** — SP 34.2 vs llama.cpp-CUDA
31.29 (+9.3%) on the same RTX 2060 (ledger **06-R6**). It was a real, measured
tok/s number. But the artifact that produced it squeezed Q6_K source tensors down
to per-row Q4: fewer bytes to read (hence the speed) *and* more weight-quant
error. Under the series' quality rule, a speed number is not citable until its
artifact clears the perplexity gate — and this one did not. 06-R6 was filed as
**"NOT citable until the PPL gate closes,"** with the wikitext PPL named as the
release-blocking gate, before the replacement was run.

The honest point is **26.1 tok/s at wikitext PPL 5.12** on the same card,
with the graph path bit-EXACT, 256/256 top-1, 24/24 gates (ledger **06-R10**,
which explicitly "closes 06-R6"). 06-R10 records the retirement in its own caveat
column: *"06-R6's 34.2 is RETIRED with its quality-failed artifact."* The
progression 06-R6 → R8 (the GGUF ecosystem conviction, gold PPL 4.68 vs GGUFs
192–506) → R9 (the sovereign pipeline reproducing ground truth, B1 artifact
PPL 5.1259 sim-matched to four decimals) → R10 (the gated headline) is the full
trail from the wrong headline to the right one. The faster number was withdrawn
*by the project's own quality rule*, and the slower-but-true number is what
ships. **Receipt:** 06-R6 (wrong call, gate-pending) → 06-R10 (correction,
citable), commit chain in §Paper 06; instruments engine
`src/backends/cuda/cuda_forward.cu`, `tools/sp_transcode`, lattice
`tests/gemma4_gold/`.

### 4.2 A public MISS kept on the front page

The composed 32k needle-retrieval run was the loudest thing the memory paper
could have claimed. It **MISSed** (ledger **01-R9**). At 32k context the run used
B=512 selection — a **64× selection budget**, far past the gated 2×–8× regime —
and it carried a router-config regression (bits-r64 / KVSEL env dropped from the
runner). The run itself completed: 16.3 h, zero errors, 67% LRU absorption,
19.6 µs/read at queue depth, 1.35 billion device reads per stream. The
*infrastructure* half is real and reportable as such. The *retrieval headline* is
not, and 01-R9 is logged as a **"measured MISS — not a claim."**

What the discipline forbids is burying it. Paper 01 releases on the 512-position-
proven row (01-R3), and the 32k MISS stays on the landing page and in the four-
tier hierarchy table as the "honest anchor" for where raw recall degrades. The
README states it inline; the SERIES manifest marks the 32k headline
**WITHDRAWN** while the row stays in the ledger. A negative that survives on the
front page is a negative the reader can trust the authors did not hide.
**Receipt:** 01-R9 (the MISS, with its config regression named), commit chain
`67f4997 → f8ea920 (+ a5e9b86)`; the honest-negatives note under §Paper 01 lists
it explicitly as one that must appear in the paper.

### 4.3 A small-N "improvement" caught as a noise illusion

While tuning the 8× global router, an early read of the perplexity deflection
came back at **−3.21%** — an apparent *improvement* over the full-attention
baseline. It was measured over roughly 42 scored positions. On the full
wikitext-2 validation corpus (~3072 scored positions) the same configuration was
**+4.17%** — a regression, the opposite sign. The small-N read was a noise
illusion: a deflection over tens of scored positions is below the corpus's own
variance, and its sign can flip.

The correction is now a standing rule — *count scored positions before any
deflection verdict; a mechanism being closed is not the same as its operating
point being validated.* It is what justified moving the router work from
"concede" to a proper large-N gate, and the **+4.17% RED at 8×** on the frozen
router is exactly the verdict that triggered the search for a *learned* router
(§4.4). The wrong small-N read and the right large-N read are both on the record.
**Receipt:** the larger-N G2 verdict recorded under ledger row **X-R2** and its
provenance contract `papers/CONTRACT-XBAR-P3-ring-on-exec.md` (run-records
`G-P3-R2.b-2b-*`); the rule is carried in the project's feedback memory as
"small-N deflection is an illusion."

### 4.4 The oracle-ceiling check that flipped "concede 4×" to "train 8×"

When the frozen ±1 router failed the 2% gate at 8× (+4.17%, §4.3), the natural
inference was to *concede the compression ratio* and ship 4×. A proxy supported
it: an offline mass-capture diagnostic showed the exact top-B keys retained
~92.3% of the attention mass at 8× (and ~96.7% at 4×), and the dropped tail
looked like lost signal.

The discipline's answer was to measure the *ceiling on the real metric*, not the
proxy. The on-engine **oracle** — exact top-B by q·K, gathered and scored
through the actual decode — returned **8× PPL = 5.1512, a −0.08% deflection**
versus full attention (and 4× at −0.01%). Both GREEN. The 8× selection was
**not** information-bounded; the 7.7% of mass the proxy mourned was noise, not
signal. The frozen router's +4.17% was therefore 100% a *router-quality* problem,
not a budget ceiling — which meant the right move was to **train a better router
at 8×**, not to concede the ratio. The learned 512×32 LSH router then hit
**+0.47% at 8×** (ledger **X-R2**) — the ratio the proxy would have wrongly
surrendered.

The lesson is exact: *measure the best-possible selection on the real metric
before spending a training cycle, because mass-dropped is not output-perturbed
when the tail is noise.* The mass-capture proxy's "concede 4×" and the oracle
PPL's "train 8×" are both recorded. **Receipt:** the oracle-ceiling measurement
under ledger row **X-R2** and the §3q oracle record in
`papers/CONTRACT-XBAR-P3-ring-on-exec.md`; instruments engine
`tests/test_gemma4_cuda.c` (`SP_ARM_ORACLE` / `SP_ARM_DUMP` hooks in
`cuda_forward.cu`), trainer `tools/xbar_lsh/train_lsh.py`; the rule is carried in
feedback memory as "measure the oracle ceiling before training."

## 5. Measurement hygiene as a prerequisite

None of the gates above mean anything if the instrument lies, and the timing
instrument on this hardware does — in a specific, characterized way. The
hygiene rules are therefore part of the methodology, not a footnote (paper 05,
05-R3; lattice §8).

- **Pin the GPU clocks before any timing run.** Cold-start lazy-load measured a
  **12.65× phantom speedup** that was ~1.06× real, and an idle SM at 405 MHz
  versus a pinned 2100 MHz swings the number on its own. The core clock is locked
  before any tok/s is read.

- **The memory clock cannot be pinned on this card.** The RTX 2060 returns
  "not supported" to `nvidia-smi -lmc`. Because decode is bandwidth-bound, a
  free-running GDDR6 clock leaves an **irreducible ±~12% wall-clock jitter
  floor**. This is the instrument catching its own limit and writing it down,
  rather than reporting a number it cannot defend — and the limit is honest about
  the 12B headline too: in 06-R6 the memory clock free-ran for *both* engines, so
  the comparison was apples-to-apples even though neither was pinnable.

- **Never difference two sequential wall-clock series for sub-10% deltas on this
  card.** With a ±12% jitter floor, subtracting one noisy series from another
  manufactures impossible numbers — the KAI-1c journaled-ring telemetry sweep
  (engine `results/kai1c_ring_telemetry.log`) produced a physically-impossible
  −137 ms "negative tax" with 210% coefficient of variation, since a journal can
  only *add* work; the figure was inter-leg memory-clock drift, not journal cost.
  The standing rule is to use
  *within-config slopes* (drift-robust — the O(1) rewind result survived precisely
  because its 0.0073 vs 0.924 s/action *slope* is immune to a constant clock
  offset) or **CUDA-event timing**, never a difference of two sequential
  wall-clock series. PPL and VRAM are clock-invariant, so the quality and
  footprint gates are unaffected; only the timing currency needs the guard.

The rule that ties this section to the rest: an instrument's limits travel with
its numbers exactly as scope travels with a claim. A timing figure on this card
is only citable inside the regime where the instrument is trustworthy, and that
regime is part of the receipt.

## 6. Why this is the moat

The mechanisms in this series are individually replaceable — a better router, a
faster kernel, a larger model would supersede any single result. What does not
supersede is the property that every one of those numbers is auditable: it comes
with the command that produced it, the scope it is valid in, and either a
bit-exact baseline or a gate fixed before the code. The discrete substrate is
what makes the bit-exact half *possible* — positions, indices, and routing
computed exactly means a block of internal state can carry a proof (a Spinor
sentinel, a Frobenius-lift identity) rather than a vibe, so "byte-identical to
the untouched baseline" is a statement you can actually check. The discipline is
what makes the bounded half *honest* — a threshold written down in advance and
never moved.

A floating-point, text-bus agent stack cannot offer this. Its inter-model
boundary detokenizes state into text and retokenizes it, discarding everything
the residual stream knew that the argmax threw away; its internal state is an
un-inspectable continuous blob; its "improvements" are differences of noisy
measurements with no bit-exact floor underneath. It can report numbers. It cannot
make them auditable, because there is no untouched baseline to be exact against
and no proof a block of its state is even well-formed.

That is why this is the methodology capstone and the series finale. The whole
tower — space (the O(1) cache), time (the resident rewind), cognition (the
disciplined daemon) — stays standing as each layer is added *because* each layer
is a controlled delta against a floor that was never moved. Take the discipline
away and the tower is a pile of plausible numbers. Keep it, and the one word the
competing stack cannot say about itself is the project's. The receipts are the
result.

## Status

**Written / complete.** This paper introduces no new engine receipts; its
evidence is the existing ledger and the four documented self-corrections, each
recorded with both the wrong call and its correction so the discipline can be
audited as having operated:

- **34.2 retired by its own PPL rule** — 06-R6 (gate-pending) → 06-R10 (citable
  correction), §Paper 06.
- **32k MISS kept public** — 01-R9 (measured MISS, not a claim), §Paper 01;
  surfaced on the README and SERIES manifest.
- **Small-N deflection illusion** — −3.21% @ ~42-pos flipping to +4.17% @ ~3072-
  pos, under X-R2 / `CONTRACT-XBAR-P3-ring-on-exec.md`.
- **Oracle ceiling flips "concede 4×" to "train 8×"** — proxy 92.3% mass vs
  on-engine oracle PPL −0.08%, then learned router +0.47%, under X-R2 / the §3q
  oracle record.

Ground truth: [`METHODOLOGY.md`](../../METHODOLOGY.md) (the rules and gate
vocabulary this paper promotes to a capstone), [`LEDGER.md`](../../LEDGER.md)
(every number, every caveat), and lattice `CURRENT-STATE-OF-PROJECT.md` §6
("why the results can be trusted"). Companions: every other paper in the series —
this is the discipline they all cite, written down once so 01–09 are trustworthy
without re-deriving the authors' incentives.
