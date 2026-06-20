# The honest-negatives wall: nine hand-designed recall signals, all refuted open-world

*Shannon-Prime release series, paper 22. Discipline: [METHODOLOGY.md](../../METHODOLOGY.md).
Every number below is a row in [LEDGER.md](../../LEDGER.md) with a command behind it.*

> **Front-door receipt (2026-06-19, ledger X-B3-NEGATIVES).** The served Gemma-4-12B has a
> store of episodes (papers 12–18). For a chat turn it should recall the *right* one — or refuse.
> We tried to build that selector **by hand**, exhausting the design space: **nine** relevance
> signals. **Every one failed open-world.** This paper keeps the failures on the record, because
> they are the reason the eventual win — a *learned* head on a *diverse* corpus (paper 24), made
> possible by a causal oracle (paper 23) — is the honest answer and not the first thing we
> reached for. This is the negatives paper: it carries **no winning number.**

## 1. The problem, stated so it can be falsified

The crossbar reads and writes a 12B's KV cache without tokens (paper 07), the cache is O(1) in
context (paper 08), memory replays into it bit-exactly and is reversible (paper 13), and a
curator addresses episodes by a discrete key (paper 12). What was *not* solved was the
**relevance question at the top of the loop**: given a live user turn and a registry of `E`
stored episodes, which episode — if any — does this turn actually depend on?

The failure mode that makes this hard is specific and it is the whole paper:

> A hand-designed relevance signal cannot separate **"the episode this query depends on"** from
> **"an episode that merely shares a fluent attractor,"** at small corpus size, on open-world
> queries.

"Open-world" is the load-bearing qualifier. On a closed set you can tune a threshold per
episode. The moment a foreign query arrives — one that matches *nothing* in the registry and
must be rejected — every per-episode bias the signal silently learned becomes a false fire. The
gate we needed was: fire the *correct* episode on a matched turn, and fire *nothing* on a
foreign turn. We could not build it by hand, and we tried nine ways.

## 2. The nine signals, and why each lost

The design space splits into two families: **pre-inject verifiers** (score the candidate before
touching the cache) and **post-inject "Disposer" signals** (speculatively inject the candidate
at a bounded mass, read the model's reaction, then `O(1)`-rewind — the speculate-and-undo
primitive of paper 13 used as a measurement instrument). Plus two "principled fixes" applied on
top of the best survivor.

| # | Signal | Family | What it measured | Why it lost |
|---|---|---|---|---|
| 1–6 | six verifier prompts | pre-inject | various "is this episode relevant?" promptings of the model | per-episode bias: one episode wins ~6/9 queries regardless of relevance |
| 7 | Yes/No reasoning bridge | post-inject | teacher-force a "Yes/No" after injecting the candidate | margins all negative; matched episode never the argmax; diagonal 0/3 |
| 8 | first-token Δ-continuation | post-inject | does the first generated token change under real-E vs zeroed-E? | better (diagonal 1/3) but per-episode bias remained; first token too early — memory facts surface positions 3–8 downstream |
| 9 | multi-token ΣΔLL | post-inject | sum `log p_real − log p_zero` over the model's own greedy continuation, window [2,8) | best hand-design: **2/3 rank** (diagonal dominance), but foreign queries still throw confident ΔLL spikes |
| — | consensus (q·K ∧ ΔLL) | composite | accept only where cosine-q·K **and** multi-token ΔLL agree | **1/3 consensus**; the two 2/3 diagonals do not overlap; one false fire leaks on a shared attractor |

The honest best across all nine: **raw q·K (Stage-1 ranking) + argmax multi-token-ΔLL** reaches
**2/3 rank, 1/3 consensus** at `N=3`. That is not a gate. It is a signal that is *better than
chance and worse than useful*, and we report it as exactly that.

### The monotonic ladder we did learn

The Disposer sweep was not pure waste — it produced a clean, diagnostic ladder, and the ladder
is itself a result:

- Yes/No bridge — **0/3** diagonal dominance.
- first-token Δ-continuation — **1/3** (the per-episode Yes-bias gone; real query structure
  visible).
- multi-token ΣΔLL over the payload window — **2/3** (the two true episodes self-select).

The direction of the payload-window ΔLL is a *validated* instrument: relevance, when it exists,
lives in the model's continuation at tokens roughly 3–8, not at the first token, and the
multi-token sum sees it. What the ladder never reached is an **absolute** open-world threshold,
because "the memory changed my answer" is **necessary but not sufficient** for "the memory is
relevant" — a foreign query can change the answer too, confidently.

## 3. The N-sweep: more memory made it worse

The natural hypothesis after a `N=3` failure is "the corpus is too small — add memory." We swept
`N = 3 → 4 → 5 → 6`, adding a novel continuous-audio episode and two further distractors. The
result is one of the cleaner negatives in the set:

> **More — and more *novel* — memory amplified the confound instead of curing it.**

The high-energy audio episode became a **universal super-attractor**: it is the argmax of *both*
q·K and ΔLL on all three matched queries. Consensus then fires the audio episode as a wrong
recall on every query; diagonal dominance collapsed from `N=3`'s 2/3 to **0/3** at `N=6`. The
sweep exposed two root causes that no amount of corpus growth fixes:

1. **q·K is K-norm-dominated.** A high-norm global-K episode out-scores every wiki episode on
   *every* query — the score is measuring **magnitude, not direction**.
2. **The ΔLL sign is inverted from intuition.** True matched episodes score **negative** ΣΔLL —
   memory *disrupts* the model's naive greedy trajectory. The super-attractor wins by being
   ~0 / ignored. argmax then picks the *least-disruptive* = *most-irrelevant* episode.

## 4. The two "pristine" fixes that backfired

Sections 2–3 name two confounds (magnitude-not-direction; truth-is-disruptive). The principled
fixes are obvious — and both, measured, made it **worse**. Keeping them on the record is the
point of a negatives paper.

- **Cosine-normalize q·K** (strip the magnitude confound). On the metal this **collapses
  Stage-1**: at `N=3` the top candidates land at `0.140 / 0.141 / 0.140` — *indistinguishable*.
  The question-`Q` vs passage-`K` angle is ~0.14 for **every** episode, so it was the **magnitude
  that carried the relevance**, not the direction. Cosine threw away the only working signal.
  Diagonal `0/3` (vs raw `2/3`). At `N=6` cosine still cannot strip the directional hub.
- **Flip the ΔLL polarity** (argmin instead of argmax — pick the most-disruptive). Worse:
  `N=3` `1/3` vs argmax `2/3`. Matched memory is **mid-disruption, not the extremum** — conflict
  beats coherence but does not beat *maximal* conflict, which a genuinely off-topic episode
  supplies. False fires reappear at `N=6`.

Both refuted. The norm-confound hypothesis and the truth-is-surprising hypothesis are *real
diagnoses* of why the naive signals fail, and *both proposed cures fail too* — because the
binding constraint is neither normalization nor the sign.

## 5. The lesson (named here, paid off in 23–24)

Every hand-designed lever — six verifiers, four Disposer signals, consensus, the N-sweep, the
cosine fix, the polarity flip — fails the open world at small `N`. The two most principled fixes
fail for principled reasons. The conclusion is not "try a tenth signal":

> The binding constraint is **the corpus**, not the signal. At `N=3` with *wiki* episodes, the
> facts are **parametric** — the 12B already knows them — so there is no episodic dependency for
> *any* signal to measure. Autonomous open-world recall is **unsolvable** at this scale with
> hand-designed signals, and the durable assets are the instruments: the `O(1)`
> verify-and-rewind plumbing and the multi-token-ΔLL probe, kept for a future *learned* head on
> a *larger, novel* corpus.

Paper 23 names the wall — "parametric steel" — and breaks it with a causal probe on novel
needles. Paper 24 trains the head the negatives justified. This paper is the boundary that makes
both honest: the win is a *learned* selector on a *diverse* corpus, and we know that because
every hand-designed alternative is a measured negative, attached here.

## 6. Honest scope

- **No winning number.** This is the negatives paper. Every signal was *measured then
  discarded* — nothing reached deployment (receipts-first: the absence of a shipped gate is the
  result).
- **Small-N, curated.** `N ≤ 6`, wiki + one audio episode. The failures are diagnosed (per-episode
  bias / super-attractor / magnitude-not-direction / truth-is-disruptive), not merely observed.
- **One model, one host.** Gemma-4-12B (the B1 / `OK_Q4B` artifact, paper 06), RTX 2060 12 GB.
  Post-inject signals ride the resident-chat decode through the speculate-and-undo seam (paper 13).
- **The negatives are the contribution.** They bound the win in 23–24; they are not a failure of
  the campaign, they are its map.

## 7. Reproduction

Every number above is a row in [`LEDGER.md`](../../LEDGER.md) (`X-B3-NEGATIVES`) with model,
fixture, flags, and commit attached. The signal sweep runs from the engine repo
([shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)) on the
resident chat decode; every Disposer signal is default-off (byte-identical null floor) and only
ever *measured*, never shipped.

| Stage | Driver | Result | Receipt log |
|---|---|---|---|
| Yes/No bridge | `routes.rs` `SP_B3_DISPOSER` (Yes/No) | margins all negative; diagonal 0/3; per-episode bias (homarus ~6/9) | `tests/fixtures/chat_fullstack/G-CHAT-B3-DISPOSER-yesno.log` |
| Δ-continuation (first-token) | `SP_B3_DISPOSER` (real-E vs zeroed-E) | diagonal 1/3; Yes-bias gone; first token too early | `tests/fixtures/chat_fullstack/G-CHAT-B3-DISPOSER-dcont.log` |
| multi-token ΣΔLL | `SP_B3_DISPOSER` (window [2,8)) | **2/3 rank** — best hand-design; foreign spikes leak | `tests/fixtures/chat_fullstack/G-CHAT-B3-DISPOSER-multitok.log` |
| consensus (q·K ∧ ΔLL) | computed from the v9e logs (no rebuild) | **1/3** — the two 2/3 diagonals do not overlap; 1 false fire | `tests/fixtures/chat_fullstack/G-CHAT-B3-DISPOSER-consensus.log` |
| N-sweep 3→6 | `SP_B3_DISPOSER` + reg{4,5,6}.jsonl | more/novel memory worse; audio super-attractor; diagonal 0/3 @N=6 | `tests/fixtures/chat_fullstack/G-CHAT-B3-DISPOSER-nsweep.log` |
| dual-fix (cosine-q·K + ΔLL-polarity) | `SP_B3_QK_COSINE` / `SP_B3_DCONT_SIGN` (default-off) | both refuted: cosine collapses the angle; argmin-ΔLL picks most-irrelevant | `tests/fixtures/chat_fullstack/G-CHAT-B3-DISPOSER-dualfix.log` |

**Commit hashes.** The dual-fix toggles are engine `4dba6c8`; the N-sweep is `2b623ab`; the
consensus computed from logs is `acd7b3a`. The verify-and-rewind plumbing the signals ride on is
paper 13's (`X-222`). Architecture: lattice `papers/CONTRACT-CHAT-FULLSTACK.md` + the
`SESSION-HANDOFF.md §0d` B3 record.

## Receipts

| Row | Receipt |
|---|---|
| X-B3-NEGATIVES | Hand-designed relevance cannot pick the dependent episode open-world. **Nine signals refuted:** 6 verifier prompts + 4 post-inject Disposer signals (Yes/No bridge **0/3**, first-token Δ-continuation **1/3**, multi-token ΣΔLL **2/3**, consensus **1/3**) + cosine-normalized q·K + a ΔLL-polarity flip. Best hand-design = raw q·K + argmax multi-token-ΔLL = **2/3 rank, 1/3 consensus @ N=3.** The **N-sweep 3→6** made it WORSE (a high-energy audio episode is a universal super-attractor; diagonal 0/3 @N=6) — exposing two root confounds: q·K is **K-norm-dominated** (magnitude, not direction) and the ΔLL sign is **inverted** (matched memory is disruptive). The two principled fixes both backfired: **cosine-q·K collapses the angle** (every episode ~0.14 — magnitude was carrying the signal), **argmin-ΔLL picks the least-disruptive = most-irrelevant** episode. The monotonic ladder (Yes/No 0/3 → first-tok 1/3 → multi-tok 2/3) and the payload-window ΔLL *direction* are validated instruments; an **absolute** open-world gate does not exist at N=3 with parametric wiki episodes. The binding constraint is the **corpus** (parametric facts → no episodic dependency to measure), broken in paper 23. Gemma-4-12B B1, RTX 2060 12 GB; all signals measured then discarded, none shipped. **No winning number — the honest-negatives paper.** |

Companions: paper 23 / X-B3-ABLATION (the causal oracle that breaks this wall — novel needles +
teacher-forced knockout), paper 24 / X-B3-WC (the learned head these negatives justify), papers
16–17 + 21 / X-OK-BIND + X-OK-FROB + X-BX-BOUNDARY (the boundary thesis — `O_K` is the container,
never the content — that this extends to recall: the win is a *learned* selector on a *diverse*
corpus, not a hand-designed number-theoretic signal), paper 13 / X-222 (the speculate-and-undo
seam the post-inject signals ride on), paper 10 (the receipts-or-it-didn't-happen discipline that
keeps every one of these negatives attached).
