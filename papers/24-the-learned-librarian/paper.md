---
type: paper-bite
title: "The learned librarian: diversity, logsumexp-mean, and int16-exact autonomous recall on a 12B"
description: "Shannon-Prime release series, paper 24."
tags: [paper-bite, librarian]
timestamp: 2026-06-20T02:44:00Z
resource: ./papers/24-the-learned-librarian/paper.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# The learned librarian: diversity, logsumexp-mean, and int16-exact autonomous recall on a 12B

*Shannon-Prime release series, paper 24. Discipline: [METHODOLOGY.md](../../METHODOLOGY.md).
Every number below is a row in [LEDGER.md](../../LEDGER.md) with a command behind it.*

> **Front-door receipt (2026-06-20, ledger X-B3-WC / X-B3-WC-DEPLOY).** Nine hand-designed signals
> failed (paper 22). A causal oracle on novel needles removed the corpus constraint and produced
> perfect labels (paper 23). This paper trains the head those negatives justified — a small
> learned **W_c** selector — and **deploys it live** on the served Gemma-4-12B. **360/361 recall +
> 50/50 foreign-reject, int16 == f32 lossless, s0 = +0.102** (`G-CHAT-B3-WC-DIV2`); a matched query
> recalls its needle (score 9.858), "what is the capital of France?" drives the whole population
> negative → NULL → clean "Paris" (`G-CHAT-B3-WC-DEPLOY`, LIVE). The binding constraint turned out
> to be **corpus diversity**, not the machinery — and the right scoring reduction makes the int16
> head **bit-for-bit identical** to float.

## 1. The head

The learned selector is deliberately small — the boundary thesis says the win is a *learned head
on a diverse corpus*, not a clever architecture. The **W_c** head projects `HD = 512 → r = 32`
and scores relevance by **logsumexp over positions, then mean over heads**. It trains by InfoNCE
over `[episodes + a NULL/s0 slot]` with a reject-margin hinge, on the ablation-oracle labels of
paper 23. At runtime it scores every registry episode plus the NULL slot, takes the
**`(E+1)`-way argmax**, and recalls the winning episode iff the winner is not NULL — replaying it
at a bounded `M = 42` mass (paper 13's seam), or rejecting to a clean prompt. Default-off (env
unset) is the byte-identical null floor.

Two findings carry the result, and both were *discoveries*, not design choices.

## 2. Diversity was the wall

The first head, trained on the 200-needle corpus paper 23 admitted, **rejected foreign queries
cleanly but could not resolve *which* needle** — instance top-1 was only **34%** (270/801
argmax-correct). The diagnosis is the same binding constraint that defeated all nine hand-designed
signals, now at instance granularity: the corpus was **templated**. All 67 code needles shared the
carrier sentence "The primary access code for the {vault} is …"; the query-`Q` vectors *collide*
intra-archetype, so the head routes the right archetype and rejects foreign, but the true needle
is rarely the argmax among its same-shaped siblings.

The fix was the corpus, not the head. `mint_corpus_v2` minted **90 needles** (30/30/30 across the
three archetypes) with **every needle a unique subject** (entity/fact/protocol sampled without
replacement) and **4–5 varied carrier structures per archetype** (all 30 queries fully distinct
within an archetype; the secret still sentence-final). On the diverse corpus the float head's
diagonal argmax-correct went to **361/361 = 100%** (CE 1.97 → 0.086). That single change —
de-duplicating subjects and phrasings — is the entire instance-recall unlock:

> Corpus **diversity** was the binding constraint at every granularity. Query-`Q` intra-archetype
> collision was the whole instance-recall bottleneck; the machinery was never the problem.

## 3. The reduction: int16 == f32, losslessly

A scoring head has to survive int16 quantization to deploy. The first read said it didn't — some
paraphrase queries argmax'd a neighbor after quantization. That read was **wrong**, and chasing it
the wrong direction (aligning the trainer to a `max`/top-m runtime) made it worse (138/361). Direct
measurement found the truth: the "int16 degradation" was a **runtime-reduction bug, not
quantization.** Under the diverse corpus, with int16 weights:

| Reduction | Diagonal top-1 | int16 vs f32 |
|---|---|---|
| `max` over positions | 12/361 | identical |
| top-8-mean | 16/361 | identical |
| **logsumexp-mean** (logsumexp over positions, mean over heads) | **361/361** | **identical** |

So the reduction that the trainer already used — **logsumexp-mean** — is the *only* one that both
**discriminates** (361/361) and **quantizes losslessly** (int16 == f32 for all three reductions;
the quantization was never the problem). The fix was to make `recall.rs` *score* with logsumexp-mean,
not `max`/top-m. "Train as you serve" was the right instinct pointed at the **wrong manifold** —
the receipt flipped it: serve as you *train*.

## 4. The NULL slot, not a threshold

The foreign-reject margin is the second subtlety. An absolute `s0` threshold **always collapses**:
because instance discrimination is *relative ranking*, `min_target ≈ max_foreign` no matter how you
calibrate the line. The reject is **not** an absolute threshold — it is the **NULL = s0 slot of the
`(E+1)`-way softmax** the cross-entropy trains. `b3_train_wc_fast2` (logsumexp-mean + a reject-margin
hinge, 600 epochs, CE 0.026, diagonal 361/361) gives the deploy gate: **argmax over [episodes,
NULL]** — recall the argmax episode iff it beats every episode *and* the NULL slot.

**`G-CHAT-B3-WC-DIV2`:** **360/361 positives recall** (the true episode beats all others and NULL) +
**50/50 foreign reject** (NULL wins), **f32 == int16 lossless**, `s0 = +0.102`. The autonomous
instance selector works on the 90-diverse corpus.

## 5. The deploy

The head is deployed **live** on the served 12B chat (`G-CHAT-B3-WC-DEPLOY`):

- `recall.rs` carries the `WcHead` (`load_wc` / `wc_score`, logsumexp-mean relevance) reading the
  int16 deploy blob `_b3_wc/wc_deploy.bin` (WCB1, exported by `tools/xbar_lsh/export_wc_deploy.py`).
- `routes.rs` `SP_B3_WC` scores every registry episode, takes the `(E+1)`-way argmax over
  `[episodes, NULL = s0]`, and either replays the winner at `SP_REPLAY_MTARGET = 42` (bounded mass)
  or rejects to a clean prompt.
- Default-off (env unset) is the byte-identical null floor.

On the metal, on a 90-needle diverse registry: a **matched** query → **RECALL** `ep_n_div_000`
(score **9.858**, clear argmax, replayed at `M = 42`); **"what is the capital of France?"** drives
the whole population negative (best **−0.026 < s0**) → **NULL** → a clean **"Paris."** The served
chat (paper's `CONTRACT-CHAT-FULLSTACK` — coherent, byte-exact, `O(1)`-context, single-entry) now
has an autonomous librarian.

## 6. The boundary thesis, on recall

The autonomous-recall arc is, end to end, a boundary-thesis win — the same line papers 16–17 and 21
drew on memory and the forward, now on recall:

> The win is a **learned selector on a diverse corpus** — never a hand-designed number-theoretic or
> geometric signal.

Every hand-designed lever was a measured negative (paper 22's nine). Every "principled" fix
backfired. The corpus was the binding constraint at every granularity — first parametric-vs-novel
(paper 23), then templated-vs-diverse (here, 34% → 100%). And the algebra's role stayed the
*container*: the head rides the exact-integer KV seam (paper 13), the int16 weights are lossless
under the right reduction, and the relevance the head learns lives in the *content* — which is, and
stays, entropy that a *learned* head resolves and a *hand-designed* number-theoretic signal cannot.

## 7. Honest scope

- **Proof-of-mechanism.** A 90-needle curated registry, one model (Gemma-4-12B B1 / `OK_Q4B`, paper
  06), one host (RTX 2060 12 GB). Not a scaling study, not multi-model, not independently reproduced.
- **The reject is relative.** It is the NULL-argmax slot of an `(E+1)`-way softmax, **not** an
  absolute calibrated threshold — no fixed line exists at small `N` (that is the honest finding of
  §4, not a missing feature).
- **The corpus is curated.** Diversity was *engineered* (`mint_corpus_v2`), and the labels came from
  paper 23's offline oracle. The head is autonomous at *recall time*; the corpus is not yet grown
  autonomously.
- **Consolidation is not built.** Between-turn consolidation — the memory that *grows* as you talk —
  is scoped but **not yet built** (B4 NIGHTSHIFT, paper 14's design tier).
- **Host-side, no frozen change.** The whole head is host-side in the engine daemon
  (`recall.rs` / `routes.rs`); **no frozen-ABI change, no `.sp-model` format change.**

## 8. Reproduction

Every number above is a row in [`LEDGER.md`](../../LEDGER.md) (`X-B3-WC` / `X-B3-WC-DEPLOY`) with
model, fixture, flags, and commit attached. The head trains and deploys from the engine repo
([shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)) on the
ablation-oracle labels of paper 23; `SP_B3_WC` is default-off (byte-identical null floor).

| Gate | Driver | Expected | Receipt log |
|---|---|---|---|
| (diversity) | `mint_corpus_v2` → `b3_train_wc_fast` | templated 34% (270/801) → diverse **361/361** float diagonal; CE 1.97 → 0.086 | (in `G-CHAT-B3-WC-DIV.log`) |
| G-CHAT-B3-WC-DIV2 (head finished) | `b3_train_wc_fast2` (logsumexp-mean + reject hinge) | **360/361 recall + 50/50 foreign-reject, int16 == f32 lossless, s0 = +0.102**; reductions max 12 / top-8-mean 16 / logsumexp-mean 361 | `tests/fixtures/chat_fullstack/G-CHAT-B3-WC-DIV2.log` |
| G-CHAT-B3-WC-DEPLOY (LIVE) | `recall.rs` `WcHead` + `routes.rs` `SP_B3_WC` (E+1)-argmax + `SP_REPLAY_MTARGET=42` | matched → RECALL `ep_n_div_000` (9.858, clear argmax); "capital of France?" → best −0.026 < s0 → NULL → clean "Paris" | `tests/fixtures/chat_fullstack/G-CHAT-B3-WC-DEPLOY.log` |

**Commit hashes.** The diversity run (34% → 100%) is engine `f62e6ef`; the finished head
(360/361 + 50/50, the reduction discovery) is `87044d8`; the live deploy is `edc8079`. The deploy
blob is `_b3_wc/wc_deploy.bin` (WCB1) via `tools/xbar_lsh/export_wc_deploy.py`; the launcher is
`run_console_recall.bat`. The labels are paper 23's ablation oracle (`f4166c7`). No frozen-ABI or
`.sp-model` change. Architecture: lattice `papers/CONTRACT-CHAT-FULLSTACK.md` + `SESSION-HANDOFF.md §0d`.

## Receipts

| Row | Receipt |
|---|---|
| X-B3-WC | A learned W_c head does autonomous instance-level recall + clean foreign-reject, int16-exact. **The head:** HD=512→r=32, relevance = **logsumexp over positions then mean over heads**, InfoNCE over `[episodes + NULL/s0]` + a reject hinge, trained on paper 23's ablation-oracle labels. **Diversity was the wall:** a templated corpus gave only **34%** instance top-1 (query-`Q` collides on shared carrier boilerplate); distinct subjects + varied phrasing (`mint_corpus_v2`, 90 needles) → **100%** float diagonal (CE 1.97 → 0.086). **The reduction:** `max` 12/361, top-8-mean 16/361, **logsumexp-mean 361/361**, **int16 == f32 for all three** — the earlier "quantization hurts" read was a wrong-reduction bug, not quantization. **The gate** `G-CHAT-B3-WC-DIV2`: **360/361 recall + 50/50 foreign-reject, int16 == f32 lossless, s0 = +0.102**; the reject is the **NULL slot of an (E+1)-way argmax**, not an absolute threshold (none exists at small N). Gemma-4-12B B1, RTX 2060; 90-needle curated registry; host-side, no frozen-ABI / `.sp-model` change. **Measured + gated — CLOSED.** |
| X-B3-WC-DEPLOY | The learned librarian is **DEPLOYED LIVE** on the served 12B chat. `recall.rs` `WcHead` + `routes.rs` `SP_B3_WC` ((E+1)-argmax over [episodes, NULL=s0] → replay winner @ `SP_REPLAY_MTARGET=42`, else clean prompt; default-off = byte-identical null floor). On the metal, 90-needle diverse registry: **matched query → RECALL `ep_n_div_000` (score 9.858, clear argmax, replay @M=42)**; **"what is the capital of France?" → whole population negative (best −0.026 < s0) → NULL → clean "Paris."** Deploy blob `_b3_wc/wc_deploy.bin` (WCB1) via `export_wc_deploy.py`; launcher `run_console_recall.bat`. Proof-of-mechanism; between-turn consolidation (B4 NIGHTSHIFT) scoped but not built; 1 model / 1 card. **Measured + gated — LIVE.** |

Companions: paper 22 / X-B3-NEGATIVES (the nine hand-designed negatives this learned head
justifies), paper 23 / X-B3-ABLATION (the causal oracle that labels it and admits its corpus),
paper 14 / X-R3VSA (the parameter-free memory tier it recalls from), paper 13 / X-222 (the bounded,
reversible `M=42` replay seam it fires through), papers 16–17 + 21 (the boundary thesis it closes
on recall: a *learned* selector on a *diverse* corpus, never a hand-designed number-theoretic
signal — the container is exact, the relevance is learned).
