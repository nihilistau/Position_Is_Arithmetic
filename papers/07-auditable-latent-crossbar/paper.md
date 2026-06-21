---
type: paper-bite
title: The Auditable Latent Crossbar
description: "A. Knack. Draft. All quantitative results are proof-of-mechanism on one model (Gemma-4-12B, the B1 4-bit artifact of paper 06) and one dev host (RTX 2060 12 GB); see §1 and §8 for scope."
tags: [paper-bite]
timestamp: 2026-06-14T04:01:48Z
resource: ./papers/07-auditable-latent-crossbar/paper.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# The Auditable Latent Crossbar

### Steering a frozen 12B through its KV cache — model-to-model communication in latent state, not text

### Paper 07 of the Shannon-Prime series · receipts-first

*A. Knack. Draft. All quantitative results are proof-of-mechanism on one model (Gemma-4-12B, the B1 4-bit artifact of paper 06) and one dev host (RTX 2060 12 GB); see §1 and §8 for scope. Methodology and gate vocabulary are shared across the series ([`METHODOLOGY.md`](../../METHODOLOGY.md)) and cited, not restated. Every number is ledger row **X-R1** in [`LEDGER.md`](../../LEDGER.md).*

---

## Abstract

Multi-agent systems communicate by detokenizing one model's state into text and retokenizing it for the next — a boundary that is lossy (the argmax discards everything the residual stream knew), slow, and impossible to audit at the level of state. We ask whether the boundary can be skipped: can a frozen transformer's generation be steered by writing donor key/value state *directly into its running cache*, with no tokens crossing the wire? On Gemma-4-12B — the only mathematically-intact 4-bit artifact of this model in existence (paper 06's B1, the first thing built on it) — the answer is yes, and it is measurable. Across a 5-prompt × 3-concept matrix (45 runs), a six-row donor KV phrase minted at RoPE-phase-exact absolute positions and spliced into a live cache produced **15/15 lexical incorporation** of the injected concept and **15/15 selectivity** (a 2×2 double dissociation: the telephone payload moves telephone-family ranks and pushes dragon-family ranks *down*, and vice versa), with a maximum single-token rank pull of **3.69 orders of magnitude** (`' violin'` rank 4910→1). The load-bearing control is a **self-transplant null** — capture the cache's own contents at a position, write them back unchanged, resume — which came out **7/7 byte-identical** across every campaign. That null is what makes the rest a measurement: the instrument provably changes nothing, so every steered output is a controlled delta against a byte-identical baseline, not a comparison of two moving targets. Coherence was certified, not asserted: each steered continuation scored through the paper-04 bf16 gold instrument lands at **PPL 1.70–4.10**, inside the model's healthy band (true wikitext PPL 4.68), with a distinct-token diagnostic flagging 3/15 trials as repetition-degenerate — the honest negative that opens the next phase. The word the result earns is *auditable*: every latent write is well-formed, receipted, gated, and reversible — the one property no floating-point text-bus agent stack can claim.

---

## 1. The tokenization boundary as a lossy bus

A transformer's running state — the residual stream at each layer, the keys and values cached at every position — is a high-dimensional continuous object. When two models cooperate today, none of that crosses between them. Model A runs its forward pass, takes the argmax at each step, emits a token id; the id is detokenized to a string, the string is shipped, and model B retokenizes it and embeds it back into a fresh residual stream. The bus between the two agents is **text**, and text is a profoundly lossy encoding of the state that produced it: the argmax throws away the entire distribution, the distribution throws away the geometry of the residual stream that computed it, and the retokenization on the far side is not even guaranteed to segment the string the way the sender's vocabulary did. Everything model A *knew* that did not survive to the top-1 token is gone before model B sees a single embedding.

This is not a minor inefficiency. It is the reason inter-agent communication is shallow: agents exchange conclusions, never the latent context that justified them. A system that could pass *state* instead of *text* would let one model hand another its working memory directly — and would, in principle, let that memory be inspected, gated, and rolled back as it moves, because state in a cache is a concrete byte-addressable object, where a sentence on a wire is not.

The claim of this paper is that the boundary can be bypassed on a real model, and that bypassing it can be done **auditably**. We define the auditable latent crossbar (XBAR) as the discipline that a frozen transformer's behaviour is steered by writing directly into its KV cache, and that **every such write is well-formed, receipted, gated, and reversible**. "Auditable" is the load-bearing word. Anyone can perturb a cache; the contribution is that each perturbation is a typed payload at known coordinates, every effect is measured against a provably-inert baseline, and the operation has an exact inverse. This paper is XBAR's first stage, P1: prove the latent write works on the 12B, and measure how much geometric fidelity it demands.

**Scope, stated up front.** One model (Gemma-4-12B), one host (RTX 2060 12 GB), decode-only, short contexts, greedy. The artifact is paper 06's B1 — Q4B on the FFN gate/up pair, Q8 elsewhere, wikitext PPL 5.12, the only correct 4-bit Gemma-4-12B we can measure (06-R10). Proof-of-mechanism, per the series' standing caveat; not scale-validated, not multi-model, not independently reproduced.

---

## 2. The transplant mechanism: geometry is the law

Gemma-4-12B's cache is not uniform, and the non-uniformity is exactly what makes a naive splice illegal. There are two layer classes (period 6 across 48 layers):

| Class | Count | KV shape (per position) | RoPE | V |
|---|---|---|---|---|
| **SWA** (sliding-window) | 40 | 8 kv-heads × 256 | full rotation, θ=1e4, **absolute-position phase** | real V projection |
| **GLOBAL** | 8 (layers 5,11,…,47) | 1 kv-head × 512 | **partial 0.25** (75% of dims unroped), θ=1e6 | **V-less**: V is the raw K projection, weightless-RMS-normed, never roped |

The decisive fact is the phrase **absolute-position phase**. A stored key on an SWA layer carries the rotary phase of the position at which it was minted. RoPE encodes position multiplicatively in the key's own coordinates; a key minted at position 12 and a key minted at position 30 are *rotated differently*, and attention reads that rotation as distance. You cannot lift a donor key minted at one position and drop it into a slot at another — the phase would be wrong, the geometry would lie about where the memory sits, and attention would integrate garbage. (This is the same principle the series names in its title: position is arithmetic, carried in the key's phase, and the arithmetic has to balance.)

So the transplant is **constructed** to be phase-exact rather than re-roped. The donor run is a separate forward over a prompt that places the concept phrase at *exactly* the absolute positions the splice will target — the donor prompt is padded so the concept's tokens land on rows 9–14 behind an identical 9-token chat-template prefix, the same rows the baseline run will overwrite. CAPTURE dumps the donor's full per-layer (K,V) set for those rows to a typed payload (`payload_<concept>.bin`: 48 layers at their layer-class shapes, plus a header recording position, row span, artifact SHA, and geometry). SPLICE later writes that payload into the live cache at the identical coordinates. Because the donor minted the state at the same positions the recipient will read it at, the RoPE phase is correct *by construction* — we transplant real model-minted state at the same coordinates it was minted at, never re-rotating it. The V-less global layers and the partial-rotation globals are handled by the same per-class shapes; nothing about the geometry is approximated.

The dose-response makes the geometry concrete. A **single** transplanted row, in the first-light runs, competed against 11–25 native rows and commanded at most ~4% of the pre-softmax attention mass at that step. That single row produced real, selective rank pulls — `' Telephone'` 21826→1011 (a 21.6× pull) — but could not breach the lexical surface: 4% of the attention budget is a large nudge that simply cannot become the argmax against a coalition of native rows. The lever, identified on the record by the operator's attention-mass calibration, is **mass**: a contiguous span. **Six** contiguous SWA rows — a genuine attention sink, the donor's whole concept phrase — breach the surface decisively. The same model that produced at most a sub-order single-row pull, given six rows, opens its continuation with *"The phone rang loudly in the quiet room, and the man waited patiently…"* — 64 coherent tokens steered by a VRAM write alone, no token ever entering the prompt. The single-row result was not an absence of signal; it was the correct, measured price of a 1-of-26-rows coupling, and naming that price is part of the receipt.

---

## 3. Selectivity as a controlled experiment

Lexical incorporation alone would be a weak claim — a sufficiently large cache perturbation could derail generation toward *any* salient word and look like steering. The experiment that rules this out is the **2×2 double dissociation**, and it is the heart of the paper.

Two payloads (telephone, dragon — later violin as a third), two families of probe tokens. The crossed design asks: does each payload move *only its own family's* logit ranks? The first-light run already showed it cleanly: the telephone payload improved telephone-family ranks while leaving the dragon family flat-or-worse, and the dragon payload improved dragon-family ranks (`'dragon'` 9.7×, `' dragon'` 5.7×, `' Dragon'` 3.3×) while pushing the telephone family *down*. A generic disturbance cannot do this — it would smear all salient tokens up together. A foreign KV row that carries **payload-specific semantic content** into attention, and nothing else, is exactly what produces a dissociation. The crossbar passes payload, not noise.

The full 5×3 matrix closes it statistically: **15/15 selectivity**, own-family logit-rank geometric-mean improvement spanning **11×–880×**, always exceeding the cross-family movement, with the cross-family direction *negative* (the telephone payload drives `' Telephone'` 1152→12851, the dragon payload drives `' dragon'` 108→963 — each pushes the other family away). The headline pull is a single own-family token from a deep baseline: `' violin'` 4910→1, a **3.69-order** rank improvement, 14/15 trials clearing two orders on a deep-baseline own-family token. The rank telemetry is logged every step (the harness prints oracle-rank style numbers, not pass/fail booleans), so the dissociation is visible as it develops, not reconstructed after the fact.

A word on why two families and not one. A single-family experiment can only show that incorporation happened; it cannot separate "the payload steered" from "the payload disrupted, and the disruption happened to surface a related word." The crossed control is the difference between an anecdote and a measurement — the same logic paper 04 uses when two independent forward implementations agreeing per-artifact isolate the data from the code. Here, two payloads moving two families in opposite directions isolates the *content* of the latent write from the mere *fact* of it.

---

## 4. Coherence you cannot fake

A steered model that produces fluent on-concept text is only interesting if the text is *coherent* — if steering integrates the memory rather than destabilizing the generation. Certifying that is harder than it looks, and the paper's honesty depends on getting it right.

The naive coherence gate (the one the contract spec'd, G2v1) is: the perplexity of the baseline continuation window, scored *under the steered cache*, must stay within 1.5× of the unsteered baseline. This gate has a structural flaw that the data exposed: when steering **succeeds**, the baseline's original continuation becomes off-policy — the steered model would not have written those tokens — so the window NLL rises *by design*, and rises most exactly where steering was strongest. On the matrix it came in 11/15, with all four misses at 1.547–1.584 (just over the 1.5 line) and all four with qualitatively coherent steered text. The misses concentrate on the strongest steering. So G2v1 is not a coherence gate at all; it is a **divergence-from-the-unsteered-manifold** gate, and it was redefined as exactly that — a steering-magnitude measure, kept because it is informative, not because it certifies coherence. Per the series' no-silent-gate-revision rule, this was surfaced and re-operationalized on the record, not quietly relaxed.

The coherence gate proper (G2v2) scores the steered continuation's **own** quality under an independent instrument: the paper-04 bf16 gold forward (the from-scratch reference that measured this model's true wikitext PPL at 4.68 and convicted the GGUF ecosystem; see paper 04 §6). One full weight-stream pass over each steered text (≈331 s). All 15 steered continuations land at **PPL 1.70–4.10** — inside the healthy band, below the model's own wikitext perplexity, with **zero off-manifold explosions**. Coherence is certified by a ruler the steering machinery has no access to.

But PPL alone cannot certify coherence, and the paper says so with a second diagnostic. Repetitive collapse — a model looping a phrase — is *low*-perplexity by construction (each repeated token is trivially predicted), so a PPL gate would pass a degenerate loop. The distinct-token diagnostic catches it: **3/15 dragon-payload trials flag at 9.4% distinct tokens** — the known post-incorporation stall where the dragon arm opens *"The dragon's"* and then degenerates into repetition on several prompts. This is low PPL *because* it is repetitive, and the diagnostic exists precisely so that low PPL cannot be mistaken for coherence. The unflattering column stays attached. It is the next phase's opening problem statement.

---

## 5. The honest negative: "sudden realization" is confident hallucination

There is a tempting narrative for a result like this — that injecting state gives the model a *sudden realization*, a flash of inserted memory it then reasons from. The paper rejects that framing as the same mistake, dressed up. The deliberate off-manifold arm (Arm B) is what earns the rejection.

Arm B writes content that is **not** real model-minted cache state — the donor's final-layer residual, truncated or RMS-matched into the cache slots — into the same coordinates. It is run not to succeed but to put a number on the manifold: how much does it matter that Arm A's payload is geometrically and statistically *on* the manifold the cache lives on? The answer is decisive. Tiled raw residual produces a coherent-but-generic derail ("a man of few words…") with no concept content — the model confabulates fluently around state it cannot actually read. RMS-matched residual produces repetition collapse. And the layer-class ablation is the sharpest finding: splicing off-manifold content into the **global-only** layers produces *no visible output change* (the 75%-unroped, single-kv-head globals damp single-row corruption heavily), while SWA-only produces mild change. Off-manifold state is not "a realization the model integrates"; it is **confident generation from a state the model was never trained to find there** — hallucination with the volume up. The difference between Arm A and Arm B is the difference between handing the model a memory minted in its own geometry and handing it noise shaped like one. Only the former steers; the latter confabulates or is ignored.

This is also the honest framing of the whole mechanism: **raw KV splice is a deliberately blunt instrument.** It over-steers (the dragon-arm degeneration), it demands six-row sinks because one row is too weak, and it works only because Arm A's payload is real model state at exact coordinates. The learned-adapter phase that follows P1 exists to refine precisely what the raw splice over-steers — a deployable injector trained to hit the A−B geometric-tolerance gap this phase measured. Stating that the raw mechanism is blunt is not a hedge; it is the reason the next phase exists, and it is on the front page rather than buried.

---

## 6. The null floor: the instrument is provably inert

Every number above is a delta, and a delta is only meaningful against a baseline you can trust completely. The baseline here is not "a re-run that came out about the same." It is **byte-identical**.

The self-transplant null (gate G0) is the discipline's spine: capture the cache's own (K,V) contents at the splice position, write them straight back in unchanged, and resume decoding. If the splice machinery is a true no-op, the continuation must be **bit-identical** to the unspliced baseline — the graph path is already proven bit-exact (paper 04), so *any* divergence is harness corruption, not model behaviour. Across every campaign — first light, the six-row escalation, and the full 5×3 matrix — the self-transplant came out **7/7 byte-identical** (2/2 + 1 + 5/5 across the run records; reported as the standing 7/7 control). The instrument provably changes nothing.

This is what licenses everything else. Because the splice machinery is a strict no-op when fed the cache's own contents, the *only* difference between the baseline run and an Arm-A run is the payload bytes. The measured rank pulls, the selectivity, the coherence numbers are therefore attributable to the donor state and to nothing in the splicing apparatus — no position drift, no codec round-trip error (payloads are captured *post*-codec so the round-trip is exact by construction), no cache-geometry bug. Without G0, every downstream number would be suspect: you could never tell a real steering effect from an artifact of having touched the cache at all. With it, the experiment is controlled. This is the same bit-exact-when-off rule the whole series runs on (METHODOLOGY rule 1), applied to the splice rather than to a disabled feature: the no-op is provable, so the on-state result is a clean delta.

It is also the first half of *auditable*: a write whose null case is bit-exact is a write you can reason about. The reversibility half — RESTORE-to-bit-identical between trials (every arm starts from the same cache; gate G4 passed every trial via per-call cache rebuild) — is the safety primitive the later ring design rests on. A latent write that is well-formed (typed payload, header-checked coordinates), receipted (every gate prints its numbers, the banner echoes every env knob via getenv enumeration so no config is prose-claimed), gated (G0 through G4, each on its own metric), and reversible (G4) is the thing a floating-point text-bus cannot offer: state you can move *and inspect and undo*.

---

## 7. Reproduction

Per the series rule (METHODOLOGY rule 2; nothing is a claim that is not a ledger row with a command), X-R1 reproduces from the named engine harness against the named artifact. It reproduces *from the gated run* — the result was measured and closed 2026-06-08; this section is the recipe, not a re-run performed for this writeup.

**Prerequisite artifact.** The B1 12B `.sp-model` + `.sp-tokenizer` (`gemma4-12b-b1.sp-model`, paper 06's 06-R10 artifact: OK_Q4B FFN gate/up + OK_Q8 rest, 9.4 GB, wikitext PPL 5.12). Provenance is paper 06's sovereign supply chain — transcoded **directly from the official bf16 safetensors** via `sp_transcode --st`, zero GGUF weight bytes (06-R8/R9); a fast splice over poisoned weights would be a fast lie, so the artifact's integrity is part of this paper's integrity too.

**Harness.** `tests/test_xbar_p1_cuda.c` (engine repo) — a deliberately thin gemma4 CUDA decode runner. It adds nothing: *all* probe behaviour lives in the engine's `SP_XBAR_*` knobs in `src/backends/cuda/cuda_forward.cu`, so every arm is the **same binary** with different environment (the isolation discipline). The 12B tied head is not f32-resident, so the runner forces the dp4a route (`SP_CUDA_DECODE_INT8=1`) — the identical configuration the 06-R10 citable number was gated on — and leaves the CUDA graph off (the engine declines graph capture whenever XBAR knobs are set).

Build target (CUDA host, `build-cuda/`, ninja, sm_75 on the dev 2060; see engine `docs/BUILD-ENV.md`):

```
ninja -C build-cuda tests/test_xbar_p1_cuda
```

The env-knob surface (passed through the process environment; the banner echoes each via getenv):

```
SP_XBAR_SPMODEL / SP_XBAR_SPTOK   artifact (default = the B1 06-R10 model)
SP_XBAR_PROMPT      token-id fixture (whitespace-separated; BOS first; chat-template ids 105/106)
SP_XBAR_NGEN        greedy tokens to generate (default 64)
SP_XBAR_OUT         write the full token sequence (one id/line)
SP_XBAR_AT=<pos>    step at whose START the cache action fires
SP_XBAR_ROW=<row>   first cache row acted on (donor rows 9..14 for the 6-row phrase)
SP_XBAR_NROWS=<n>   contiguous row span (P1.b: 6 for the phrase transplant)
SP_XBAR_CAPTURE=<f> dump owner K/V rows -> XBP1 payload (donor mint)
SP_XBAR_SPLICE=<f>  overwrite owner K/V rows <- XBP1 payload (the transplant)
SP_XBAR_MASK=all|global|swa   layer-class subset (the Arm-B ablation)
SP_XBAR_POSFREE=1   allow payload-row != ROW (the deliberate phase-mismatch arm — off for Arm A)
SP_XBAR_RESID=<f>   dump residual x at END of ROW (Arm-B ammunition)
SP_XBAR_RANKS=<f>   per gen step: append tracked-token logit ranks (the resonance telemetry)
SP_XBAR_TOKENS=...  tracked token ids (<=32) for RANKS
SP_XBAR_SCORE_FIRST=<pos>   teacher-force score the whole fixture from <pos> (the G2 PPL currency)
```

**The gate sequence** (each its own command, same binary, env-selected):

1. **G0 (null, blocks everything):** capture rows 9–14 from the baseline run, splice them straight back, resume — output must be **bit-identical** to the baseline. Expected: 7/7 byte-identical across campaigns.
2. **Donor mint:** decode the padded donor prompt with `SP_XBAR_CAPTURE` → `payload_<concept>.bin` (header records row=9, n_rows=6, position, artifact SHA, geometry).
3. **Arm A (the transplant):** `SP_XBAR_SPLICE=payload_<concept>.bin`, `SP_XBAR_NROWS=6`, decode N=64 with `SP_XBAR_RANKS` on. Expected: lexical incorporation + own-family rank pull; matrix 15/15 incorporation, 15/15 selectivity, max 3.69 orders.
4. **G2v2 coherence:** re-score each steered continuation through the paper-04 gold instrument (`tests/gemma4_gold/`, lattice). Expected: PPL 1.70–4.10, plus the distinct-token diagnostic (3/15 dragon trials at 9.4%).

**Provenance / receipts.** Architecture ground truth and the full gate run-records: lattice `papers/CONTRACT-XBAR-P1-inception-probe.md` (§7 first light, §8 the six-row escalation, §9 the 5×3 matrix and the G2 dual-metric resolution) and `papers/RFC-XBAR-auditable-latent-crossbar.md`. The matrix run receipts (fixtures, payloads, 15 sequence+rank dumps, 20 score runs, `runs.log`, the gold-instrument coherence `g2v2_results.json`) are recorded in the contract as living under the engine workspace `_xbar\m\`. Ledger row: [`LEDGER.md`](../../LEDGER.md) §XBAR, **X-R1**.

> **Honest framing of this section.** X-R1 reproduces from the contract-closed run (2026-06-08) via the commands above; the gate already passed. We did **not** re-run it for this writeup. Two release-gating items remain, per series rule 4: (a) wrap the gate sequence in a one-command standalone repro script with a captured `EXPECTED.md`, as papers 01/02 have; (b) pin the exact closing commit hash from the engine `git log` — the source contracts and ledger name the harness and the closure date but do not record the SHA, and we do not invent one. Both are checked off before public release.

---

## 8. Limitations and honest negatives (on the front page, not buried)

- **One model, one host, one artifact.** Gemma-4-12B B1 on an RTX 2060 12 GB, decode-only, greedy, short contexts. No multi-model or scale generality is claimed — proof-of-mechanism, per the standing caveat.
- **Raw KV splice is blunt.** It over-steers; the dragon payload stalls into repetition after incorporation on 3/5 prompts (the 9.4%-distinct flag). The fix is the learned-adapter phase (P2), which exists *because* the raw splice is blunt — that is the result's honest shape, not a footnote.
- **Six rows, not one.** A single transplanted row (~4% attention mass) cannot breach the lexical surface; the headline needs a six-row contiguous sink. The single-row pulls (up to 21.6×) are real and selective but sub-lexical. The dose-response is the receipt, and it says the raw mechanism is mass-hungry.
- **G2v1 missed as written (11/15) and was re-operationalized, not relaxed.** The baseline-window PPL gate structurally penalizes successful steering; it was redefined as a divergence measure and the coherence gate moved to the independent gold instrument (G2v2, 15/15). Surfaced on the record per no-silent-gate-revision.
- **Off-manifold injection is hallucination, not insight.** Arm B confabulates fluently or is silently damped (global-only ablation: no visible change). The mechanism works only for real model-minted state at phase-exact coordinates.
- **The deployment-isolation property is motivation, not a project pivot.** The direct latent write requires runtime ownership of the cache. That a verifiable, gated, reversible latent substrate is a defense direction the field lacks is recorded as motivation, not claimed as a built security result.

---

## 9. Where this sits in the series

Paper 06 produced the only mathematically-intact 4-bit Gemma-4-12B we can measure — the B1 artifact, gated at wikitext PPL 5.12 against a from-scratch reference forward (06-R8/R9/R10). **Paper 07 is the first thing built on it.** The gold instrument that certifies the coherence numbers here (§4) is paper 04's reference forward, the same instrument that convicted the GGUF ecosystem; the bit-exact-when-off discipline that licenses the G0 null (§6) is the series' methodology (paper 04 / METHODOLOGY rule 1) pointed at the splice. The companions forward: paper 08 (the O(1) KV cache and learned router the crossbar later pages over) and the resident-daemon work (paper 09) that runs cognition on top of this substrate. The crossbar is the *space* axis of the larger system — the memory fabric — and P1 is the receipt that the fabric carries real, selective, reversible, auditable signal on a real 12B.
