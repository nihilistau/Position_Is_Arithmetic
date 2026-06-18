---
type: research-paper
title: "O(1) Episodic Memory by KV-Tensor Replay: bypassing token re-computation in agentic recall"
description: A proof-of-mechanism preprint storing physical KV tensors and injecting them into the resident cache on recall (no token re-computation), gated by a 256-bit content signature with an O(1) Hamming verify, on a real Gemma-4-12B.
resource: ./provenance.md
tags: [research-paper, episodic-memory, kv-injection, cross-modal, hamming, gemma4]
timestamp: 2026-06-18T00:00:00Z
sp_status: DRAFT
sp_gate: G-XBAR-ORGANISM-FULL
sp_commit: 15e7051, 6600cf4, d2d7ceb
sp_repro: see Appendix: Reproduction (engine tests/fixtures/xbar_organism/)
---

# O(1) Episodic Memory by KV-Tensor Replay: bypassing token re-computation in agentic recall

**Authors:** [Shannon-Prime — author list TBD]

> **DRAFT / preprint — not yet submitted.** All quantitative results are proof-of-mechanism on a
> single model (Gemma-4-12B, the B1 4-bit artifact) on a single dev host (RTX 2060, 12 GB) at small
> scale (N ≤ 64 episodes); every figure carries its scope. See §5 for the honest negatives — in
> particular, the injection is proven *well-formed*, not proven to *improve* a downstream task.

---

## Abstract

Agentic LLM memory systems almost universally store recalled content as **token-ID streams**, and
on recall they **re-feed those tokens to the model** — which forces a full re-computation of the
key/value (KV) cache for the recalled span before the model can use it. The recall therefore costs
a prefill: it scales with the length of the recalled memory in both compute (a float forward pass
over every recalled token) and latency. We take a different route. We store the **physical KV
tensors** that the model produced when it first encountered the content, and on recall we inject
those tensors **directly into the resident cache** mid-stream — no token re-computation, no float
FLOP of forward over the memory. Retrieval is gated by a **256-bit content signature** with an
**O(1) Hamming check** (a register-aligned XOR-and-popcount over a fixed-width word array, not a
similarity search whose cost grows with the corpus per query). A consequence we lean on
deliberately: **cross-modal recall** — for example a continuous-audio cue retrieving an
audio-conditioned episode — *cannot be scored by perplexity*, because the cue is foreign to any
text scoring context; it must be evaluated in **discrete Hamming space**, where an accept/reject
verdict is exact and modality-agnostic. We report **G-XBAR-ORGANISM-FULL** (engine `15e7051`): a
closed loop on real episodes — continuous audio → a C2 256-bit signature → an exact-integer Ring-3
superposition (mixed with text decoys) → an audio-cue top-1 retrieve → a C2 Hamming verify
(**accept audio / reject text**) → a Frobenius integer store → the decoded episode injected into
the resident Gemma-4-12B cache via the SP_REPLAY seam (**checks = 5, fails = 0**, a clean inject).
We position this precisely against the most directly comparable prior art, *Hippocampus* (arXiv
2602.13594), which shares the binary-signature / Hamming-ball idea but reconstructs by storing a
**lossless token-ID stream** and **re-tokenizing + re-computing** on recall; the distinction is the
contribution. We are explicit about what we have **not** shown: the loop is small (N ≤ 64); the
inject is proven well-formed (RT_EXIT = 0, checks = 5, fails = 0), not proven to *improve* a task —
a foreign episode injected into a mismatched context deflects perplexity hard *by design* (the
reject signal, not a quality regression and not a quality gain); and the O(1) claim is the
inject/verify step, not an end-to-end pipeline.

---

## 1 Introduction

A long-running agent has to remember. The dominant pattern for giving an LLM memory — RAG, episodic
buffers, scratchpads, vector stores feeding a context window — is, underneath the abstraction, the
same mechanism: **store text (or token IDs), retrieve text, and paste it back into the prompt.** The
retrieved memory re-enters the model as tokens, and the model must run a forward pass over those
tokens to rebuild the KV cache the memory needs in order to participate in attention. Recall, in
other words, **pays a prefill** proportional to the length of the recalled content.

This is wasteful in a specific, structural way. The model *already computed* those keys and values
the first time it saw the content. The act of detokenizing the memory back to a string and
retokenizing it on recall throws that work away and pays for it again — and, worse, it routes the
memory through the lossy text bottleneck (the same argmax-and-retokenize boundary that makes
inter-agent communication shallow). The KV tensors the model produces are a richer, byte-addressable
object than the token IDs that summarize them; storing the IDs and recomputing the tensors is the
expensive, lossy direction.

We invert it. **Store the KV tensors; inject them.** When the memory is recalled, its stored
owner-K/V are written **directly into the resident cache** at the recall position, and decoding
continues — the model attends over the injected memory with **no forward pass over it at all**. The
injection is a tensor copy; it does not scale with anything the model has to *compute*. This is the
"latent crossbar" mechanism of our companion work (the auditable KV-write substrate) applied to the
specific problem of episodic recall.

Two further design commitments follow.

**Retrieval is gated by a content signature with an O(1) check.** Each episode carries a **256-bit
content signature** (a discrete hash of a consistent subset of its per-layer KV state). Retrieval
verification is an integer **Hamming distance** — a fixed number of XOR-and-popcount operations over
a register-aligned word array — so the *verify* step is constant-time per candidate, independent of
the embedding dimension or the precision of the underlying state. (Shortlisting candidates is a
separate Ring-3 superposition retrieve; the verify that *accepts or rejects* a shortlisted candidate
is the O(1) part.)

**Cross-modal recall forces the discrete-space evaluation, and that is a feature.** When the cue is
**continuous audio** and the retrieved episode is an audio-conditioned KV state, there is no text
scoring context against which to compute a perplexity — the cue is foreign to any wikitext or
chat-template score window, and a perplexity number would be meaningless or, worse, misleadingly
large. The only sound way to ask "did the right memory come back?" is in the **discrete Hamming
space** of the signatures: does the audio cue's signature land within the accept-ball of its own
episode and outside the ball of the text decoys? That question has an exact integer answer, and it
is the same question whether the modality is text, audio, or anything else that can be hashed to a
signature. The discrete substrate is what makes the memory **modality-agnostic**.

Contributions:

1. **Episodic recall as KV-tensor injection, not token re-feed** (§3.1): the recalled memory enters
   the resident cache as the tensors the model originally produced, with **no re-tokenization and no
   forward FLOP** over the memory.
2. **An O(1) content-signature verify** (§3.2): a 256-bit signature with a register-aligned Hamming
   check that accepts or rejects a shortlisted candidate in constant time, and that works across
   modalities because it is discrete.
3. **A closed cross-modal loop on a real 12B** (§3.3, §4): G-XBAR-ORGANISM-FULL — audio →
   signature → integer Ring-3 superposition (with text decoys) → audio-cue top-1 retrieve →
   accept-audio/reject-text Hamming verify → Frobenius integer store → clean inject into the
   resident Gemma-4-12B cache (checks = 5, fails = 0).
4. **A precise position against the closest prior art** (§2): same Hamming-signature idea as
   *Hippocampus*, but tensors-not-tokens on the reconstruction side.

A note we restate where it matters: the inject is shown to be **well-formed and load-bearing**, not
to **improve a downstream task**. §5 makes that boundary unmissable.

## 2 Background & Related Work

**The closest prior art: Hippocampus (arXiv 2602.13594).** *Hippocampus: An Efficient and Scalable
Memory Module for Agentic AI* is the work this paper is most directly in dialogue with, and it is
genuinely the same neighborhood of ideas: it stores **binary signatures** of memories and performs
**Hamming-ball search** over them (accelerated by a Dynamic Wavelet Matrix data structure) to find
candidate memories fast. The shared insight is real — a discrete signature with a Hamming metric is
the right addressing primitive for a scalable agentic memory. The divergence is on the
**reconstruction side**: Hippocampus stores a **lossless token-ID stream** for each memory, and on
recall it returns those token IDs to be **re-tokenized and re-fed to the model**, which re-computes
the KV cache for the recalled span. Our store is the **KV tensors themselves**, and our recall is a
**direct tensor injection** — no token stream, no re-computation. The two designs agree on *how to
find* a memory (a Hamming signature) and differ on *what a memory is* and *what recall costs* (a
token stream re-prefilled, versus a tensor injected). We credit Hippocampus for the signature/Hamming
framing and claim the tensor-injection reconstruction as the distinct contribution.

**Token-recompute memory systems generally.** The broad family — retrieval-augmented generation,
vector-DB episodic memory, long-context "memory tokens," scratchpad/notebook agents — all share the
re-feed-as-text property: the recalled content re-enters as tokens and is re-encoded by a forward
pass. They differ enormously in *retrieval policy* and *what to store*, but not in this respect. The
cost of recall in all of them includes a prefill over the recalled content. KV-tensor injection is
orthogonal to the retrieval policy and removes that prefill.

**KV-cache reuse / prefix caching.** Production engines already cache and reuse KV for *shared
prefixes* (e.g., a fixed system prompt) so that repeated prefixes are not recomputed. This is the
same physical idea — reuse stored KV instead of recomputing it — but applied to *contiguous prefix
reuse within a session*, not to *content-addressed episodic recall of arbitrary past spans injected
mid-stream*. Our contribution sits on top of that idea: a content signature decides *which* stored
KV to splice, and the splice happens at an arbitrary recall position, not only at a shared prefix.

**The latent-write substrate this builds on.** The injection mechanism — writing donor owner-K/V
directly into a running cache, with a provably-inert null and an O(1) byte-exact rewind on reject —
is our companion crossbar work. That work established that a KV write into Gemma-4-12B can be
*well-formed, receipted, gated, and reversible* (a self-transplant null that is byte-identical; a
rewind that resets the pre-injection prefix to layer-diffs = 0). This paper reuses that substrate as
the *reconstruction engine* for episodic memory; the new claim here is the **content-addressed,
cross-modal, end-to-end loop**, not the splice primitive itself.

**The exact-integer memory substrate.** The Ring-3 superposition and the Frobenius integer store are
carried on the project's exact-integer dual-prime negacyclic NTT (the same algebraic container as our
companion exact-arithmetic work). The relevant property here is that the superposition and the
signature arithmetic are **reduction-order-immune integer operations** — the address is bit-stable —
so "the audio episode's signature" is a fixed integer object, not a float that drifts with summation
order. We use that stability; we do not re-derive the substrate.

## 3 Method

### 3.1 Recall as KV-tensor injection

An **episode** is a stored snapshot of the model's owner-K/V state over a span of positions, in the
project's canonical uniform episode layout (`[NL, P, 512]` per layer: 48 layers, P positions, the
global owner width). Crucially, an episode is *the tensors the model produced*, captured
**post-codec** so that the round-trip is exact by construction — not a token stream and not a
re-derived approximation.

Recall is the **SP_REPLAY** seam: `gemma4_kv_replay(s, epdir, npos, zero)` injects the episode's
owner-K/V directly into the **resident** KV cache at `[dpos, dpos + npos)` and advances `dpos`.
Because the cache slot maps one-to-one to a decode position (full-cache: slot == pos), the injected
state occupies exactly the positions the subsequent attention will read, and decoding continues
**without any forward pass over the recalled content**. The cost of recall is the tensor copy plus
the signature verify — neither of which is a model forward.

The reject path is the companion O(1) byte-exact rewind: `gemma4_kv_rewind(npos)` resets the
pre-injection prefix `[0, dpos)` to **byte-identical** and rolls `dpos` back, touching zero cache
bytes (the slot==pos shear), so a speculated recall that fails its verify leaves **no trace**. (That
rewind, and its SWA-ring journal-backed variant, are gated separately in the companion replay/rewind
work as G-222 / G-222-WRAP; we cite them as the undo primitive this loop depends on.)

### 3.2 The 256-bit content signature and the O(1) Hamming verify

Each episode is addressed by a **256-bit content signature** (the project's "C2" signature): a
discrete hash computed over a consistent subset of the episode's per-layer KV state (a fixed
period-k layer subset; the registry uses the model's true global-layer period). The signature lives
in the **discrete integer-Hamming space**, and the verify that decides whether a retrieved candidate
is the right memory is an **integer Hamming distance** — a register-aligned XOR-and-popcount over the
256-bit word array, with an accept threshold (a Hamming-ball radius). This verify is **O(1) per
candidate**: a fixed number of machine words, independent of the model dimension, the episode length,
or the precision of the underlying state.

Two stages should not be conflated. **Shortlisting** a candidate from a store of many episodes is a
Ring-3 superposition retrieve (a content-addressed top-1 over the superposed memory); its cost is
the retrieve, not the verify. The **verify** — does this shortlisted candidate's signature fall
inside its own accept-ball and outside the decoys' — is the O(1), constant-time, discrete step, and
it is the step that makes the recall *safe to speculate*: a wrong shortlist is rejected by an exact
integer check and rewound at O(1).

### 3.3 Why cross-modal recall must be scored in Hamming space

When the cue is **continuous audio**, perplexity is not available as a verdict. An audio-conditioned
episode replayed into a *text* scoring context is foreign to that context by construction — the audio
latent was never a wikitext continuation — so its perplexity against a text window is large *because
the contexts are unrelated*, not because the memory is wrong. Companion work measured exactly this:
an audio episode replayed over a wikitext score window deflects perplexity by **+1989%** (97.53
versus the 4.6665 baseline) — and that high deflection is the **reject signal**, the thing the verify
gate *wants* to see when a memory is mis-routed; the matched-context deflection (a wiki episode into a
wiki window) is ~0%. Perplexity, in other words, is a *same-modality* ruler; it cannot adjudicate a
cross-modal recall.

The discrete signature can. The accept/reject question — "is the audio cue's signature within its own
episode's Hamming ball and outside the text decoys'?" — has an exact integer answer regardless of
modality. This is why the loop's verdict is a Hamming **accept-audio / reject-text**, not a
perplexity comparison. The discrete substrate is what lets a single mechanism address text, audio, or
any hashable modality with the same constant-time check.

### 3.4 The closed loop

The full loop chains: **continuous audio** (the EAR front-end, an audio-conditioned KV state) →
**C2 256-bit signature** of that state → **exact-integer Ring-3 superposition** that mixes the audio
episode with **text decoys** → an **audio-cue top-1 retrieve** off the superposition → a **C2 Hamming
verify** that **accepts the audio episode and rejects the text decoys** → a **Frobenius integer
store** of the verified episode → **SP_REPLAY injection** of the decoded episode into the resident
Gemma-4-12B cache. Every arithmetic stage between the audio in and the KV out is the exact-integer
substrate; the verdict is discrete; the reconstruction is a tensor inject, not a token re-feed.

## 4 Results

All results are proof-of-mechanism on **Gemma-4-12B (the B1 / OK_Q4B artifact)** on a single
**RTX 2060 (12 GB)**, with the audio front-end the project's EAR line. Receipts-first: the loop is
gate **G-XBAR-ORGANISM-FULL**, engine commit **`15e7051`**.

### 4.1 The closed cross-modal loop — gate G-XBAR-ORGANISM-FULL

The loop runs end to end on **real episodes** and closes with **checks = 5, fails = 0**:

| stage | mechanism | verified outcome |
|---|---|---|
| sense | continuous audio → audio-conditioned KV state (EAR front-end) | audio episode in the canonical episode layout |
| address | C2 256-bit content signature of the audio state | discrete, integer, reduction-order-immune |
| superpose | exact-integer Ring-3 superposition, audio episode **+ text decoys** | content-addressable store |
| retrieve | audio-cue **top-1** retrieve off the superposition | the audio episode shortlisted |
| **verify** | C2 **Hamming** check | **ACCEPT audio / REJECT text** (discrete-space verdict) |
| store | Frobenius integer Ring-2 store | integer episode persisted |
| reconstruct | **SP_REPLAY** inject into the resident 12B cache | **clean inject, checks = 5, fails = 0** |

The verdict is the load-bearing one: the audio cue retrieves and the Hamming verify **accepts the
audio episode and rejects the text decoys** — a cross-modal recall adjudicated entirely in discrete
space, with **no perplexity in the loop**, because (§3.3) perplexity cannot score a cross-modal cue.
The reconstruction is a **KV-tensor injection** (SP_REPLAY), so the recalled memory enters the model
with **no token re-feed and no forward pass over the memory**.

### 4.2 The signature separates cleanly (the address is real)

The signature gate from the upstream organism step (the precondition for any of the above) shows the
audio episode is genuinely addressable and distinct from text in the discrete space:

| cue | self-recall | vs text episodes | margin |
|---|---|---|---|
| **audio episode** | **211 / 256 bits** | 118–131 / 256 | **+79** |
| text episode (toy) | 177 / 256 | — | +19 (PASS) |
| text episode (wiki) | 178 / 256 | — | +25 (PASS) |

The audio signature self-recalls at 211/256 and sits at 118–131/256 against the text episodes — well
below the ~177 self-recall band — and its presence does not blur the text episodes' own margins. The
noisier, continuous audio latent is still cleanly separated in the discrete integer-Hamming space the
verify uses. The period-6 registry rebase (aligning the signature's layer subset to the model's true
global-layer period) preserves separation (decoy separation 154 → 129, still well outside the
accept-ball). Receipt: the organism write/signature gate (engine `6600cf4`) and the period-6 rebase
(`d2d7ceb`).

### 4.3 The inject is load-bearing and reversible (the reconstruction is real)

The SP_REPLAY reconstruction is proven *load-bearing* (it writes real state, not a no-op) and
*reversible* (a bad recall rewinds at O(1) byte-exact), by the companion replay/rewind gates this
loop depends on: a **zeroed** episode injected into the resident cache reads back all-zero
(**0 / 688,128 bytes nonzero** on the 12B's 48 owner layers — so a non-zero episode is genuinely
written), and after `rewind(npos)` the pre-injection prefix is **byte-identical (layer-diffs = 0)**
with `dpos` reset. The injection costs a tensor copy; the undo costs zero cache bytes. (Gates G-222 /
G-222-WRAP, engine `b4b037a` / `24071bc`.)

## 5 Limitations & Honest Negatives

We put these on the front page because the framing (O(1) episodic memory) is stronger than what the
loop has *yet proven on a downstream task*.

- **The inject is proven WELL-FORMED, not proven to IMPROVE a task.** This is the single most
  important caveat. G-XBAR-ORGANISM-FULL shows the recalled episode loads cleanly and injects
  (RT_EXIT = 0, checks = 5, fails = 0), and the companion gates show the inject is load-bearing
  (zeroed episode reads zero) and reversible (rewind to layer-diffs = 0). It does **not** show that
  injecting the episode makes the model *answer better* on a held-out task. The well-formed-and-
  reversible property is the precondition for a useful memory, not the demonstration of one.

- **The +1989% deflection is the reject signal, NOT a regression and NOT a gain.** A foreign (audio)
  episode injected into a wiki score context deflects perplexity by **+1989%** *by design* — that is
  the cross-context mismatch the verify gate is built to *reject*, not a quality regression. Equally,
  a *matched*-context replay deflects ~0%, which is parity, **not** a quality improvement. We claim
  neither a regression nor a gain from the inject; we claim it is well-formed, addressable, and
  undoable.

- **The O(1) claim is the inject + verify, not end-to-end.** "O(1)" here means: the **verify** is a
  constant-time Hamming check per candidate, and the **inject/rewind** touch a bounded number of
  bytes (the episode's owner-K/V on inject; zero on the full-cache rewind). It is **not** a claim
  that the whole pipeline — shortlisting from a large store, the Ring-3 retrieve, the Frobenius
  store — is O(1); the shortlist/retrieve cost is separate and not characterized here.

- **Scale is small.** The superposition loop is gated at **N ≤ 64 episodes**. This is
  proof-of-mechanism, not a scaling study; capacity, interference, and recall-accuracy curves at
  large N are not measured here.

- **One model, one host, one audio front-end.** Gemma-4-12B (B1 / OK_Q4B), RTX 2060 12 GB, the EAR
  audio line. Not multi-model, not scale-validated, not independently reproduced.

- **A noted correctness item, recorded honestly.** The signature pipeline originally hashed a
  period-8 layer subset; the model's true global-layer period is 6. Separation is robust to the
  subset choice (any consistent subset distinguishes episodes — see §4.2), so the prior gates stand;
  the period-6 rebase (`d2d7ceb`) is a correctness tidy-up that preserves the result, not a number
  that changes it.

## 6 Conclusion

Agentic memory does not have to pay a prefill on every recall. The reason it usually does is a design
choice — store memories as token streams and re-feed them — not a necessity. We stored the **KV
tensors** the model originally produced and **injected them directly** into the resident cache on
recall, gating retrieval with a **256-bit content signature** whose verify is an **O(1) Hamming
check**, and we closed a **cross-modal** loop on a real Gemma-4-12B in which the verdict is rendered
entirely in discrete Hamming space — accept audio, reject text — precisely because a continuous-audio
cue cannot be scored by perplexity. The closest prior art, *Hippocampus*, shares the signature/Hamming
addressing and differs exactly where it matters: it reconstructs by re-tokenizing and re-computing;
we reconstruct by injecting tensors. What remains, and what we state plainly, is the downstream-task
demonstration: the inject is proven well-formed, load-bearing, and reversible, but not yet shown to
*improve* an answer. Closing that — a matched-modality recall that measurably helps a held-out task,
at N well past 64 — is the clear next step.

---

## Appendix: Reproduction

**Commits.** Loop: engine **`15e7051`** (G-XBAR-ORGANISM-FULL). Upstream organism write/signature:
engine `6600cf4`. Period-6 rebase: `d2d7ceb`. The replay/rewind primitives this loop reuses: engine
`b4b037a` (`gemma4_kv_replay` + O(1) byte-exact rewind, G-222) and `24071bc` (SWA-ring journal-backed
rewind, G-222-WRAP). Build host: CUDA, `build-cuda/`, ninja, sm_75 (RTX 2060). Model:
`gemma4-12b-b1.sp-model` (+ `.sp-tokenizer`), the B1 / OK_Q4B artifact.

**The loop (G-XBAR-ORGANISM-FULL).** The seams are in the engine: the audio→episode write over the
proven KAI-3 `gemma4_kv_inject_seq` path; the C2 256-bit signature + integer Ring-3 superposition +
Frobenius store on the project's exact-integer dual-prime NTT primitives (`tools/ring3/` +
`tools/curator/frob_episode.py`); the SP_REPLAY inject seam `gemma4_kv_replay` in
`src/backends/cuda/cuda_forward.cu` (the one-shot decoder `gemma4_decode_cuda` left byte-untouched).
Expected: audio-cue top-1 retrieve, C2 Hamming **accept audio / reject text**, SP_REPLAY
**checks = 5, fails = 0**. Receipts: engine `tests/fixtures/xbar_organism/` and
`tests/fixtures/xbar_r3/`.

**The signature separation (precondition).** The organism write/signature gate
(`_run_organism_write.bat`): audio self **211/256**, vs text **118–131/256**, margin **+79**; text
margins unchanged. Receipt: `tests/fixtures/xbar_organism/G-XBAR-ORGANISM-write.log`.

**The replay is load-bearing + the rewind is byte-exact (the reconstruction primitive).**
`_run_g222.bat`: a zeroed episode's injected slots read back all-zero (**0 / 688,128** nonzero on the
12B); after `gemma4_kv_rewind(npos)` the prefix `[0, anchor)` is **layer-diffs = 0**.
`_run_g222_wrap.bat`: the SWA-ring journal-backed rewind across a forced wrap is again
layer-diffs = 0. Receipts: `tests/fixtures/xbar_c2/G-222-REWIND-NULL.log`,
`tests/fixtures/xbar_c2/G-222-WRAP.log`.

**Related work referenced.** *Hippocampus: An Efficient and Scalable Memory Module for Agentic AI*,
arXiv:2602.13594 (binary signatures + Hamming-ball search via a Dynamic Wavelet Matrix; lossless
token-ID-stream reconstruction). Standard prefix / KV caching as deployed in production inference
engines (shared-prefix KV reuse). The companion Shannon-Prime work this builds on: the auditable
latent crossbar (the KV-write substrate + self-transplant null), the one-shot and resident replay
seams, and the exact-integer dual-prime NTT memory substrate. (Full citation keys TBD at submission.)
