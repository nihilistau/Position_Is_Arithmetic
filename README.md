# Position Is Arithmetic

> A number-theoretic architecture for transformer inference and memory — where a token's position, index, and routing *are* exact arithmetic, not floating-point metadata about it.

**Live site:** https://nihilistau.github.io/Position_Is_Arithmetic/

**The main project is located at [Shannon-Prime-Lattice](https://github.com/nihilistau/shannon-prime-lattice) — you can join the Discord here: [Shannon-Prime-Lattice-Discord](https://discord.gg/rre9XZmvV).**

---

## What this is

Position Is Arithmetic is the public research home of the **Shannon-Prime** project: a ground-up re-derivation of the transformer forward pass in discrete integer arithmetic, plus a memory architecture (**PPT-ARM**) that attaches to a frozen, pretrained transformer and gives it long, auditable memory on commodity hardware.

The thesis in one line: a transformer's positions, indices, and routing are arithmetic objects — primes, residues, lattices — so they can be **computed exactly** instead of approximated in floating point. That turns operations that are normally lossy (KV-cache compression, quantization, weight offload, and now inter-model memory) into operations that are *bit-exact when disabled*, *gated when enabled*, and *receipted always*.

This repository holds the **receipts-first paper series** and the project's document history. Active code lives in the [linked repositories](#related-repositories); the headline implementation is [Shannon-Prime-Lattice](https://github.com/nihilistau/shannon-prime-lattice).

**Status labels used throughout** (and in [`LEDGER.md`](LEDGER.md)):

- **[PROVEN]** — measured and gated; the number has a ledger row and a command. Citable.
- **[WIRED]** — implemented and gated in-engine/in-core; running today, not yet a public citable row.
- **[DESIGN]** — specified, with its falsification gates pre-stated; not built.

## Measured results (citable)

Receipts-first: every number reproduces from a single command and traces to a row in [`LEDGER.md`](LEDGER.md). The unflattering numbers are kept attached on purpose.

| Result | Number | Scope / caveat |
|---|---|---|
| Resident KV-cache shrink @ 32k context | **910×** (7.5 GB → 8.3 MB) | two-ring offload to byte-addressable storage (01-R5) |
| Needle retrieved off a physical NVMe drive | **HIT at 512 positions** (7.57 µs/read) | poison-gated; latency figure is Optane-specific (01-R3/R4). **At 32k the composed run completed but MISSed** (B=512 = a 64× selection budget, far past the gated 2×–8× regime; 01-R9) — kept here on purpose |
| KV sparsification quality | **8× at +0.69% perplexity** | one corpus, 2k context (2× and 4× go negative) (01-R1) |
| Reducing loader (transcode) | **model → ~50% smaller, bit-faithful forward** | gemma-3 + Qwen3, closure-gated (paper 02) |
| Bit-exact when disabled | **argmax-identical to the stock model** | the invariant under everything (01-R8) |
| 12B GPU decode + quality, same RTX 2060 12GB | **26.1 tok/s at wikitext PPL 5.12** (graph EXACT, 256/256 top-1, 24/24 gates) | gated + citable (06-R10). llama.cpp-CUDA: 31.29 tok/s **at PPL 192–506** — every gemma-4 GGUF measurable in June 2026, incl. the post-fix rebuilds, carries broken weights (06-R8). SP engine bandwidth 245 vs 207 GB/s (+18%); the earlier 34.2 (+9.3%) headline is **retired** — its artifact failed the PPL gate (the series' own rule caught it) |
| The gemma-4 ecosystem finding | true full-precision PPL **4.68** (hand-written reference forward) vs GGUFs **192–506** | engine-independent conviction (06-R8); verification + fix tutorial: [GEMMA4-QUANT-FIX.md](GEMMA4-QUANT-FIX.md) |
| Latent crossbar probe: a 12B steered by direct KV-cache transplant, **no tokens** | **15/15 incorporation, 15/15 selectivity** (2×2 double dissociation), max single-token rank pull **3.69 orders** | gated + citable (X-R1). Coherence held under the gold instrument (steered-text PPL 1.70–4.10 vs gold 4.68); self-transplant null bit-identical 7/7; raw KV splice is a deliberately blunt instrument — the learned-adapter phase exists to refine it |
| O(1) KV decoupled from context on a 12B, needle retained | learned **512×32 LSH router** at **+0.47% PPL @8×** (oracle −0.08%, frozen +4.17%); **O(1) VRAM: 8k↔16k flat within ~50 MiB**; **NIAH needle survives 10/50/90% depth** | gated + citable (X-R2). The **KV term** is O(1); the absolute footprint in this backend-direct harness still carries the resident model. Frozen-router negative control MISSES — isolates the learned projection as the cause |
| Resident 12B daemon: disciplined silence + O(1) bit-exact rewind | **24-tick crucible perfect** (21/21 NO_OP, 3/3 ACTION, 0 false / 0 missed / 0 drift; 0.6B control collapses); **rewind byte-identical across all 48 layers** (diffs=0); metal **0.0073** vs prefix-grow **0.924 s/action** (127×) | gated + citable (KAIROS-01 / KAIROS-02). Scripted 24-event tape, not live sensors. The **≥24 h endurance soak is IN-FLIGHT** (no verdict from a mid-run log) — paper 09's release waits on its receipt |

Honest scope: this is a proof-of-mechanism, not a scaling study and not yet independently reproduced — on a single dev host (RTX 2060, 12 GB). The **0.6B** (Qwen3-0.6B) carries the two-ring memory ladder; the **12B** (Gemma-3-12B, QAT 4-bit — the B1 artifact) carries the XBAR and KAIROS results. CPU decode is ~1.34× behind a tuned llama.cpp at the same quantization. On GPU the citable point is the speed/quality PAIR: 26.1 tok/s at PPL 5.12 — a point no other stack currently occupies on this model at any speed, because their artifacts are broken. The memory envelope remains the primary value claim.

## The paper series

A staggered set of short, independently citable, receipts-first papers — each carries its own one-command reproduction.

- **01 — Two-ring memory** — query-directed recall + byte-addressable KV offload (the needle-off-NVMe result above).
- **02 — The reducing loader** — output-preserving transcode + zero-copy load (the ~50%-smaller, bit-faithful result).
- **03 — Frobenius calibration-free quantization** *(staged).*
- **[04 — The Oracle & the Teacher](papers/04-oracle-teacher/)** *(written)* — oracle-grounded backend verification: KL 2.7e-10 port, teacher-forced decode — plus the case study where a hand-written oracle measured gemma-4's true PPL at **4.68** and convicted the GGUF ecosystem (192–506) while exonerating llama.cpp's forward.
- **[05 — The Probe Suite](papers/05-probe-suite/)** *(written)* — bisection, isolation and benchmark hygiene **as one set** — from the 12.65× phantom and the 0/256 K-quant bug to ecosystem-scale forensics and simulate-before-build (artifact matched the simulator to four decimals).
- **[06 — Computing on the Zip File](papers/06-dp4a-bandwidth-ladder/)** *(complete, citable)* — the dp4a bandwidth ladder (f32 1× → int8 ~3.8× → Q4 ~7.06×), the OK_Q4B block-scaled kernel, the sovereign quantization pipeline, and the gated headline: **26.1 tok/s at PPL 5.12 on an RTX 2060 12GB**.
- **[07 — The Auditable Latent Crossbar](papers/07-auditable-latent-crossbar/)** *(staged draft)* — a frozen 12B steered by direct KV-cache transplant, no tokens: **15/15 incorporation + 15/15 selectivity**, self-transplant null 7/7 bit-identical, gold-instrument coherence (X-R1).
- **[08 — O(1) KV: a context-decoupled cache](papers/08-o1-kv-learned-router/)** *(staged draft)* — a learned **512×32 LSH router** decouples the KV cache O(1) from context: **+0.47% PPL @8×** (oracle −0.08%), **O(1) VRAM (8k↔16k flat ~50 MiB)**, **NIAH needle survives 10/50/90%** (frozen-router control misses) (X-R2).
- **[09 — KAIROS: a resident 12B daemon](papers/09-kairos-resident-daemon/)** *(staged draft — release gated on the in-flight soak)* — disciplined silence + **O(1) bit-exact rewind**: 24-tick crucible perfect, rewind byte-identical across 48 layers, metal **0.0073** vs prefix-grow **0.924 s/action** (KAIROS-01/02). The **≥24 h endurance soak is running now** — no verdict from a mid-run log; the paper ships on the receipt.
- **[10 — Receipts or it didn't happen](papers/10-receipts-or-it-didnt-happen/)** *(staged draft)* — bit-exact-or-bounded as the contribution: the four documented self-corrections that prove the gates discriminate.
- **[GEMMA4-QUANT-FIX.md](GEMMA4-QUANT-FIX.md)** — community tutorial: verify the gemma-4 GGUF breakage yourself (engine-independent, ~30 min) and the working fix recipe. Ready-to-post issue text: [GEMMA4-ISSUE-POST.md](Archived/Documents/Revisions/GEMMA4-ISSUE-POST.md).

See [`SERIES.md`](SERIES.md) for the manifest and release cadence, [`LEDGER.md`](LEDGER.md) for the master claims ledger (every number traced to a command), and [`METHODOLOGY.md`](METHODOLOGY.md) for the gate vocabulary and the "no number without a command" discipline.

## The system: a four-tier memory hierarchy plus a latent crossbar

The original "two-ring" framing has grown into a four-tier hierarchy with an inter-model lane on top. Architecture ground truth lives in the lattice repo (`papers/RFC-XBAR-auditable-latent-crossbar.md`); this is the public map, each component tagged with its status.

```
        ┌────────────────────────── VRAM (owned arena) ───────────────────────────┐
        │                                                                         │
        │   Exec (generator, e.g.               Memo (small curator,              │
        │   gemma-4-12B OK_Q4B)                 frozen-small)                     │
        │   causal forward, generates           non-causal pass over the episode  │
        │        │            ▲                        │             ▲            │
        │        ▼ write      │ attend                 ▼ propose     │ read       │
        │   ┌─ Ring 1 ─┐  ┌── Ring 2 (hippocampus) ┐  ┌─ Ring 2′ (shadow) ─┐      │
        │   │ working  │  │ verbatim Spinor KV,    │◄─│ Memo's proposals   │      │
        │   │ KV       │  │ recent + bounded       │  │ promote-on-accept  │      │
        │   └──────────┘  └────────────────────────┘  └─────────┬──────────┘      │
        │        ▲ recall from BOTH                             │ promote (gated) │
        │        │                ┌── Ring 3 (neocortex) ───┐◄──┘                 │
        │        └────────────────│ adapter pseudo-tokens,  │   G-R3-LOSS bounded │
        │                         │ consolidated long-term  │   (irreversible)    │
        │                         └─────────────────────────┘                     │
        │              modality lanes (one CRT prime per modality):               │
        │              audio adapter, video, ...                                  │
        └─────────────────────────────────────────────────────────────────────────┘
   Ring 2′ promotions: coherence/PPL delta → accept or REWIND (transient, reversible).
   Ring 3 promotions: G-R3-LOSS bounded BEFORE source eviction (permanent, irreversible).
```

### The four tiers

| Tier | Substrate | Representation | Lifetime | Biological analogue | Status |
|---|---|---|---|---|---|
| **Ring 1** | RAM/VRAM working window | verbatim KV, full attention | the live turn | sensory / working memory | **[PROVEN]** — the stock model path; everything else is bit-exact-when-off relative to it |
| **Ring 2** | byte-addressable storage (Optane validated), raw episodic store | verbatim Spinor KV blocks | recent episode (bounded) | **hippocampus** — recent, detailed, lossless | **[PROVEN]** — needle off physical NVMe, poison-gated, 7.57 µs/read (01-R3/R4); bounded on purpose: the composed 32k recall at a 64× selection budget MISSed (01-R9) |
| **Ring 2′** (shadow) | transient staging copy | proposals awaiting the gate | one consolidation pass | (no analogue — it is the *audit* mechanism) | **[WIRED]** — the C1-lite curator: clone → propose → gate → atomic promote / rewind, exercised on real recall, every promotion receipted |
| **Ring 3** | consolidated long-term store | adapter-compressed pseudo-tokens (n→k gist) | long-term | **neocortex** — old, dense, semantic | **[DESIGN]** — under the irreversible-aware **G-R3-LOSS** gate: consolidation loss is quantified and bounded *before* the raw source is evicted; un-compressible episodes stay verbatim in Ring 2 (a valid, logged outcome) |

The point of the split: raw recall degrades past ~16× selection budget (the measured 32k MISS is the honest anchor), so Ring 2 stays **bounded and recent** — where the budget is favorable — and the long tail lives in Ring 3 as compact gist. The Exec queries both per step and attends over the union.

### XBAR — the Auditable Latent Crossbar

Multi-agent systems today communicate by detokenizing model A's state into text and retokenizing it for model B. The boundary is lossy, slow, and discards everything the residual stream knew that the argmax threw away. **XBAR bypasses the boundary:** two models — the **Exec** (generator) and **Memo** (a small, differently-trained curator) — share the ring memory and communicate through **latent state, not tokens**, with every write receipt-backed, gated, and rewindable. "Auditable" is the one word no floating-point agent stack can claim, and it is the entire reason this lane exists.

What is measured so far — **[PROVEN]**, ledger row **X-R1**: a gemma-4-12B's generation steered by **direct KV-cache transplant** (no tokens involved) — 15/15 lexical incorporation across a 5-prompt × 3-concept matrix, 15/15 selectivity with a 2×2 double dissociation, max single-token rank pull 3.69 orders, dose-response from a single row (~4% attention mass) to a 6-row lexical breach, instrumentation null bit-identical 7/7, and coherence certified by the gold instrument (steered-text PPL 1.70–4.10 against the model's true 4.68). Raw KV splice is a deliberately blunt instrument; the learned-adapter phase exists to refine exactly that. *(Paper 07.)*

And the cache the crossbar writes into is now **O(1) in context** — **[PROVEN]**, ledger row **X-R2**: a learned **512×32 LSH router** selects the global top-B keys at **+0.47% PPL at 8× compression** (oracle ceiling −0.08%; the frozen ±1 router was +4.17%, RED), a compact slab realizes **O(1) VRAM** (`nvidia-smi` flat within ~50 MiB from 8k to 16k context, where a full O(N) cache would add ~5.4 GiB), and the **NIAH needle survives the compaction at depths 10 / 50 / 90%** — learned-router-only, with the **frozen-router negative control MISSING** to isolate the projection as the cause, not leakage. The KV *term* is O(1); the absolute footprint in this backend-direct harness still carries the resident model. *(Paper 08.)*

Design rules (fixed, not aspirational):

1. **Memo is small.** It sorts latents, it does not speak; it co-resides with Exec — no weight-swap latency.
2. **Memo is non-causal.** It is offline and sees the whole episode at once — the architectural form of consolidation, not a vague autoencoder.
3. **Shadow ring, promote-on-accept.** Memo never writes canonical Ring 2 directly. Proposals land in Ring 2′; a downstream coherence gate accepts → promote with receipt, or rejects → rewind.
4. **Geometry is the law.** Nothing enters the ring that does not honor the per-layer, per-head, position-exact coordinates.
5. **One CRT prime per modality lane.** Audio/text/video blocks are residue-separable in the same ring; lanes can never alias; provenance stays recoverable.

The honest negative, stated up front: "injected memory as sudden realization" and "confident hallucination from off-manifold state" are the **same event** described twice. The discrete substrate detects *invalid* blocks (Spinor sentinel, Frobenius-lift identity); it cannot detect *semantically-wrong-but-valid* ones. Therefore the coherence gate is load-bearing, not decorative — no promotion without a measured downstream delta, accept-or-rewind, every time.

### KAIROS — the time / agency axis (the resident cognitive loop)

XBAR gives the cache an O(1) *space* axis. KAIROS adds the *time* axis on the same card: a frozen **gemma-4-12B running as a resident background daemon** that wakes each tick, reads one environment event, and replies with exactly `NO_OP` (stay silent) or `<ACTION>…</ACTION>` (intervene). The whole point is **disciplined silence** — a useful resident agent must do nothing, *correctly*, almost all the time — and the machinery that makes that cheap forever is an **O(1) byte-exact rewind**: `rewind(Δ)` logically decrements the decode position, and because each cache slot maps to exactly one position, the sheared slots are never read again, so the rewind is a perfect inverse. The daemon can "think" on a tick and then perfectly un-think it.

What is measured so far:

- **[PROVEN]**, ledger row **KAIROS-01**: the **24-tick crucible is PERFECT** — 21/21 idle → NO_OP, 3/3 salient → coherent contextual ACTION (`start` / `clean` / `renew` for build-finished / disk-95% / ttl-expiring), 0 false-action, 0 missed, 0 malformed, 0 drift. The negative control proves it is *capacity, not plumbing*: the identical harness collapses a **0.6B** model into a deterministic corruption attractor (`NO_克作`); the 12B holds.
- **[PROVEN]**, ledger row **KAIROS-02**: cold-evict happens **at the metal** — after an idle tick + `rewind(Δ)`, the KV is **byte-identical to never-visited across all 48 owner layers (16.5 MB, diffs = 0)**, and re-running the tick reproduces identical tokens. The O(actions)→O(1) telemetry: prefix-grow (host re-ingest) rises at **0.924 s/action**; the metal rewind is flat at **0.0073 s/action** — a **127× shallower slope** — the measured flatline that *is* the O(1) claim.

Honest scope: a **24-event scripted tape** (not live sensors), one model, one card. The **≥24 h unattended endurance soak is IN-FLIGHT** as of this writing — per our own discipline we do not call a verdict from a mid-run log, so paper 09's release waits on the soak's receipt. *(Paper 09.)*

### NIGHTSHIFT — offline consolidation **[DESIGN]**

Sleep does not just tidy the hippocampus; it replays raw episodes and writes compressed semantic traces to neocortex. NIGHTSHIFT does the same, on idle time: it reads aging Ring 2 episodes, compresses spans via the adapter, proposes the gist to Ring 2′, and on gate-accept promotes it to Ring 3 — eviction of the now-redundant raw positions happens under the same receipt or not at all. The association-strength signal already exists in measured form (the recall path's temporal-locality telemetry). A synthetic subconscious whose dreams are auditable.

Honest constraint carried forward: the NIAH budget ladder broke at 16×–32× selection, so v0 NIGHTSHIFT bounds episodes (≤8k tokens) or runs two-stage re-rank; budget scaling is an open risk-register item, not a buried assumption.

## Direction and reasoning: why discrete, why auditable

**The substrate.** Positions, indices and routing computed exactly (CRT-NTT arithmetic, Frobenius lift, KSTE tiering) means internal state can carry *proofs* instead of vibes: a Spinor block is 63 bytes + a sentinel — one cache line — and its Frobenius-lift identity is a bit-level integrity receipt. Floating-point drift and unprovable identity are entropy bleeding into the hardware; the lattice makes correctness a property you *check*.

**The discipline** (in full in [`METHODOLOGY.md`](METHODOLOGY.md)) is as much the contribution as any mechanism:

- **Bit-exact when off.** Every mechanism is a strict no-op in its default state — the baseline is provably the original network.
- **No number without a command.** Nothing is claimed that is not a ledger row reproducible by a specified command.
- **Scope travels with the number.** Every figure carries its model, context, corpus, and what it does not generalize to.
- **No silent gate revisions.** If an implementation can't meet a pre-stated gate, that surfaces upstream — gates are never quietly retuned until a number passes.
- **Falsification pre-stated; honest negatives published.** The 32k NIAH MISS (01-R9) stays on the front page; the 34.2 tok/s headline was retired by the series' own quality rule; a falsified recall signature is reported, not hidden. A result with its caveats attached is one a reader can trust without re-deriving the authors' incentives.

**A note on the latent layer and security.** Deployed AI safety today lives almost entirely at the lexical layer — refusal training, input filters, output classifiers all scan *text* — while the decision is made in the residual stream. The field's trajectory (multimodal projectors, agentic/retrieved context, shared KV-cache serving) steadily adds pathways that reach latent space without passing the layer where safety is enforced. Calibration matters: direct latent writes require runtime ownership — a deployment-isolation threat, not a remote skeleton key — and the structural worry is a *widening gap* on a multi-year horizon, not an imminent break. The connection to this project is the constructive half: latent state has been an un-inspectable continuous blob, and XBAR's premise is the counter — a discrete substrate where a block of internal state is provably well-formed, every memory write carries a receipt, and nothing commits without passing a coherence gate. A verifiable, gated latent substrate is a defense direction the field currently lacks; we record that as motivation, not as a project pivot.

## Older material

The original document history — theory drafts, Friedman/KSTE notes, results, and tools — has been moved to [`Archived/`](Archived/). It is kept for provenance, not as a starting point. Begin with the paper series above or the live project.

## Related repositories

**Main project**

- [shannon-prime-lattice](https://github.com/nihilistau/shannon-prime-lattice) — the lattice: discrete Z_q substrate, the headline implementation
- [shannon-prime-system](https://github.com/nihilistau/shannon-prime-system) — math core
- [shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine) — inference engine

**Earlier / supporting**

- [shannon-prime](https://github.com/nihilistau/shannon-prime)
- [shannon-prime-engine](https://github.com/nihilistau/shannon-prime-engine)
- [shannon-prime-llama](https://github.com/nihilistau/shannon-prime-llama)
- [shannon-prime-bernhard](https://github.com/nihilistau/shannon-prime-bernhard)
- [shannon-prime-burnhard](https://github.com/nihilistau/shannon-prime-burnhard)
- [shannon-prime-lmstudio-server](https://github.com/nihilistau/shannon-prime-lmstudio-server)
- [shannon-prime-comfyui](https://github.com/nihilistau/shannon-prime-comfyui)

**Audio / Voxtral**

- [voxtral-tts.c](https://github.com/nihilistau/voxtral-tts.c)
- [voxtral-mini-realtime-rs](https://github.com/nihilistau/voxtral-mini-realtime-rs)
- [ComfyUI-FL-VoxtralTTS](https://github.com/nihilistau/ComfyUI-FL-VoxtralTTS)

## License and citation

[MIT](LICENSE). Cite via [CITATION.cff](CITATION.cff).

---

*Shannon-Prime-Lattice is an open-source research project by KnackAU — contact: raydaniels@gmail.com*

*Attributed to Transformers and 250 years of Mathematicians.*
