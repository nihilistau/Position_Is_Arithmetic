---
type: paper-bite
title: "Parametric steel and the teacher-forced ablation knockout: making episodic dependency measurable"
description: "Shannon-Prime release series, paper 23."
tags: [paper-bite, ablation]
timestamp: 2026-06-20T02:44:00Z
resource: ./papers/23-parametric-steel-ablation-knockout/paper.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# Parametric steel and the teacher-forced ablation knockout: making episodic dependency measurable

*Shannon-Prime release series, paper 23. Discipline: [METHODOLOGY.md](../../METHODOLOGY.md).
Every number below is a row in [LEDGER.md](../../LEDGER.md) with a command behind it.*

> **Front-door receipt (2026-06-19, ledger X-B3-ABLATION).** Paper 22 spent nine signals proving
> hand-designed recall fails open-world, and ended on a diagnosis: the *corpus* was the wall —
> the test facts were **parametric**, so deleting the stored copy stranded nothing for any signal
> to measure. This paper breaks that wall. Replace the corpus with **novel needles** the model
> cannot know, and measure dependency *causally*: teacher-force the secret's tokens,
> `cudaMemset`-ablate **exactly** their source KV rows, and read the collapse in summed
> log-likelihood. **Novel-needle collapse = −33.56 nats; a parametric fact = −0.15** — a
> **~220× separation.** The gate nine signals could not build is one exact-integer causal probe,
> and it is **both** a shippable admission oracle **and** a perfect labeler for the learned head
> of paper 24.

## 1. Parametric steel: why recall was unmeasurable

Paper 22's terminal diagnosis, restated as the premise here:

> You cannot detect episodic dependency on knowledge the model already has.

Concretely: the wiki needle "a species of lobster found in the North Atlantic Ocean" is
**parametric** — the 12B regenerates it from its own weights. Ablate the stored episode's copy
of that fact and the model loses *nothing*: it reconstructs the continuation from parameters.
The roof is **parametric steel**. We confirmed this directly with a causal-ablation probe (v10):
the matcher *worked* — it located and zeroed exactly 12 source KV positions for the lobster
episode, 10 for another, with a clean `O(1)` rewind — but the measured collapse landed in
`[−0.09, +0.04]` on *every* query including true matches. **Pure noise. No collapse, no
separation.** Not because the instrument was broken — because there was nothing to strand.

This is the cause behind all nine of paper 22's failures, stated as a single sentence: a signal
can only measure a dependency that *exists*, and on parametric facts the dependency does not
exist. The fix cannot be a better signal. It has to be a better **corpus**.

## 2. The novel needle

The unlock is a curator that mints **novel needles** — secrets the model could not have
memorized, stated **once** — so that the only place the fact lives is the stored episode. The
needle-authoring rule is itself a lesson paid in receipts (v11): a needle that states its secret
*twice* is self-redundant, and the model recovers the secret from the duplicate, blunting the
collapse. **State the secret exactly once; make it the tail of the episode.** The curator path
reuses existing parts end-to-end — `_b3_capture_ep` mints token-aligned `ep.k` / `ep.v` / `ep.mf`
through the existing `SP_XBAR_RECALL_WRITE` manifest serializer, and `ep.tok` *is* the exact
input token file, so alignment is guaranteed by construction (the "213-vs-84 lost-provenance
ghost" of the parametric corpus is gone). No new metal, no `.sp-model` format change, no
frozen-ABI change.

## 3. The teacher-forced knockout

With a novel needle in the registry, the probe is exact and causal. For a query whose answer key
is the secret string:

1. **Inject** the candidate episode at a bounded replay mass (`M_target`), through the
   speculate-and-undo seam of paper 13.
2. **Teacher-force** the *known* secret tokens (not the model's greedy continuation — the actual
   secret), so the score window covers the *whole* secret, not a partial [2,8) overlap (the
   instrument-sensitivity limiter diagnosed at v11).
3. **Ablate** exactly the secret's **source KV rows** with `gemma4_kv_ablate_rows`
   (`cudaMemset`-zero, restored by rewind).
4. **Score** the collapse: `ΣΔLL = Σ (NLL_with − NLL_without)` over the secret window — the
   secret's *causal* dependence on the stored memory.
5. **Rewind** `O(1)` — the cache returns byte-identical (paper 13's guarantee).

The earlier versions (v10 greedy-window, v11 single-needle) were *directionally* right but
magnitude-weak: greedy decode at temperature 0 may not strongly recite the secret, and the fixed
[2,8) window only partially overlapped the code tokens. Both axes that defeated all nine prior
signals — **corpus** (parametric → collapse 0) and **scoring** (greedy window missed the payload)
— are fixed *together* here: a novel needle + the teacher-forced exact-secret window.

## 4. The matrix and the pin

With both axes fixed, the roof collapsed. On the metal (prompt "…the vault is", secret
" 8-FALCON-7729"):

- `ep_needle2` (NOVEL) collapse = **−33.56 nats** — 12 source positions ablated — **catastrophic.**
- `ep_homarus` (PARAMETRIC control) = **−0.15** — **flat.**

A **~220× separation**, with a clean gate. We then ran the full **3-archetype matrix** against the
parametric control, to check the result was not an artifact of one needle shape:

| Archetype | Collapse (nats) | Note |
|---|---|---|
| high-entropy code | **−33.56** | a CSPRNG-style access code |
| parametric contradiction | **−18.58** | a fact that *overrides* a parametric prior (France → Oricon-Prime) |
| relational / multi-hop | **−16.10** | predicted-hard; collapses anyway |
| parametric control band | **[−0.15, +1.45]** | the lobster + other knowns |

The novel archetypes sit at `[−33.56, −16.10]`; the parametric band sits at `[−0.15, +1.45]`.
**No overlap, ~16 nats of gap.** We pinned **TAU = −8.0** — it fires all three needles and rejects
every parametric fact, with ~8 nats of margin on each side. Even the predicted-hard relational
case clears it.

## 5. The oracle is also the labeler

The probe needs the answer key (the secret), so it is an **offline** oracle — it cannot run
*live* as the selector (paper 24's job). But an offline oracle that produces a clean, separable
label is exactly what paper 22 never had: a **perfect labeler**. The cross-matrix — 3
needle-queries × {3 needles + parametric control} — is a **perfect diagonal**: matched cells at
`[−33.56, −18.58, −16.10]`, *every* off-diagonal cell (including the *other* novel needles and the
control) at `[−0.71, +1.45]`. ~15 nats of margin in every cell. These are the fully-separable
ground-truth labels the `N=3` wiki corpus could never provide — the binding constraint paper 22
diagnosed, now removed.

The lifecycle is then mechanical and reuses the whole prior stack:

- **Ingestion** — `_b3_capture_ep` mints token-aligned `ep.k/v/mf/tok` on command.
- **Safety** — bounded replay mass `M_target` caps any false-positive attention mass (paper 13).
- **Gate** — `O(1)` speculative teacher-forced knockout: `collapse < TAU` fires, else `O(1)` rewind.
- **Admission at scale** — one model load self-ablates the whole registry with each episode's own
  secret: **200/200 novel needles ACCEPT** (collapse `[−46.82, −9.42]`), the parametric control
  `ctrl_paris` REJECTS (−0.23), zero fails, ≥9.4 nats of margin. The oracle *scales*.

## 6. Honest scope

- **Offline, by construction.** The gate needs the secret as its answer key, so it admits and
  labels episodes *offline*; it is not the live selector — that is paper 24. What it ships is a
  relevance **gate** and a **training signal**, not a runtime head.
- **Novel needles required.** The result depends on the corpus being non-parametric. On facts the
  model already knows, the collapse is ≈0 *by design* — "parametric steel" is a property of the
  corpus, not a failure of the probe (paper 22's lobster lands at −0.15 here, correctly rejected).
- **One model, one host.** Gemma-4-12B (B1 / `OK_Q4B`, paper 06), RTX 2060 12 GB. Proof-of-mechanism
  on a curated novel-needle corpus, not a scaling study, not multi-model, not independently
  reproduced.
- **The win is real and shippable.** Unlike paper 22's nine measured-then-discarded signals, this
  one *passed a gate* and shipped as the admission oracle + labeler for paper 24.

## 7. Reproduction

Every number above is a row in [`LEDGER.md`](../../LEDGER.md) (`X-B3-ABLATION`) with model,
fixture, flags, and commit attached. The probe runs from the engine repo
([shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine));
`SP_B3_DISPOSER=2` + `SP_B3_SECRET` (or the per-episode `ep.secret` sidecar) drives the
teacher-forced knockout; default-off is the byte-identical null floor.

| Gate | Driver | Expected | Receipt log |
|---|---|---|---|
| G-CHAT-B3-NEEDLE-v12 (knockout) | `SP_B3_DISPOSER=2` + `SP_B3_SECRET` | novel `ep_needle2` **−33.56** (12 source rows ablated) vs parametric `ep_homarus` **−0.15** — ~220× | `tests/fixtures/chat_fullstack/G-CHAT-B3-NEEDLE-v12.log` |
| G-CHAT-B3-NEEDLE-v13-MATRIX (pin) | same, 3-archetype matrix + control | **−33.56 / −18.58 / −16.10** vs control band **[−0.15, +1.45]**; **TAU pinned −8.0**, ~16-nat gap, no overlap | `tests/fixtures/chat_fullstack/G-CHAT-B3-NEEDLE-v13-MATRIX.log` |
| G-CHAT-B3-LABELER (oracle = labeler) | cross-matrix 3 queries × {3 needles + control} | **perfect diagonal**: matched [−33.56,−18.58,−16.10], all off-diagonal [−0.71,+1.45]; ~15-nat margin every cell | `tests/fixtures/chat_fullstack/G-CHAT-B3-LABELER.log` |
| G-CHAT-B3-ADMISSION-200 (scale) | one daemon boot, `auto_recall` self-ablation sweep | **200/200 ACCEPT** collapse [−46.82,−9.42]; `ctrl_paris` **−0.23 REJECT**; 0 fails, ≥9.4-nat margin | `tests/fixtures/chat_fullstack/G-CHAT-B3-ADMISSION-200.log` |

**Commit hashes.** The teacher-forced knockout is engine `15738c1` (v12); the 3-archetype matrix
with TAU pinned is `b6470cc` (v13); the labeler cross-matrix is `7556d04`; the 200/200 admission
sweep is `f4166c7` (lineage through the corpus minter `52ec468` / `adfcb06` / `421627d`). The
ablation kernel is `gemma4_kv_ablate_rows`; the speculate-and-undo seam it rides is paper 13's
(`X-222`); no frozen-ABI or `.sp-model` change. Architecture: lattice
`papers/CONTRACT-CHAT-FULLSTACK.md` + `SESSION-HANDOFF.md §0d` + the corpus runbook
`tools/xbar_lsh/CORPUS_PIPELINE.md`.

## Receipts

| Row | Receipt |
|---|---|
| X-B3-ABLATION | A teacher-forced ablation knockout makes episodic dependency measurable on novel needles. **Parametric steel:** on facts the model already knows, causal ablation collapses ≈0 (lobster −0.15; the v10 probe landed in [−0.09,+0.04] on every query — pure noise, *nothing to strand*). **The unlock:** novel needles (secrets stated **once**, tail-positioned, token-aligned by construction) + a teacher-forced exact-secret window — fixing *both* axes that defeated paper 22's nine signals (corpus **and** scoring). **The knockout:** inject @M_target → teacher-force the known secret → `cudaMemset`-ablate exactly its source KV rows (`gemma4_kv_ablate_rows`) → score ΣΔLL with/without → `O(1)` rewind. **Novel collapse −33.56 vs parametric −0.15 (~220×).** 3-archetype matrix **−33.56 / −18.58 / −16.10** vs control band **[−0.15,+1.45]**; **TAU pinned −8.0** (~8-nat margin each side; even the predicted-hard multi-hop case collapses). **Oracle = perfect labeler:** the 3×4 cross-matrix is a perfect diagonal (off-diagonal [−0.71,+1.45], ~15-nat margin every cell) — the separable ground-truth labels the N=3 wiki corpus never could give. **Scales:** 200/200 admission in one model load (collapse [−46.82,−9.42], control −0.23 reject). Offline (needs the answer key); 1 model / 1 card; no frozen-ABI / `.sp-model` change. **Measured + gated — CLOSED.** |

Companions: paper 22 / X-B3-NEGATIVES (the nine hand-designed negatives this causal probe breaks
— "parametric steel" is the cause behind all nine), paper 24 / X-B3-WC (the learned head this
oracle labels and admits the corpus for), paper 14 / X-R3VSA (the parameter-free memory tier the
needles ride on), paper 13 / X-222 (the `O(1)` speculate-and-undo seam that makes the knockout a
free, reversible measurement), papers 16–17 + 21 (the boundary thesis — the win is exact causal
arithmetic on a curated corpus, not a number-theoretic content signal).
