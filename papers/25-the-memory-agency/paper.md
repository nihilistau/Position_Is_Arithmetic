---
type: paper-bite
title: "The memory agency: a model that forgets, supersedes, and merges its own facts"
description: "Shannon-Prime release series, paper 25."
tags: [paper-bite, agency, memory, forget, decide, merge]
timestamp: 2026-06-25T00:00:00Z
resource: ./papers/25-the-memory-agency/paper.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# The memory agency: a model that forgets, supersedes, and merges its own facts

*Shannon-Prime release series, paper 25. Discipline: [METHODOLOGY.md](../../METHODOLOGY.md).
Every number below is a row in [LEDGER.md](../../LEDGER.md) with a command behind it.*

> **Front-door receipt (2026-06-25, ledger X-AGENCY).** Paper 24 deployed a librarian that *recalls*
> a stored fact. This paper gives the model authority over the store itself. Three layers, all
> default-off (byte-identical null floor): **STORE** (NIGHTSHIFT capture, paper 14's tier), **FORGET**
> (`SP_FORGET` — "forget X" → token-overlap match → drop from the live set *and* rewrite the persisted
> registry), and **DECIDE** (`SP_DECIDE` — on a capturing turn that overlaps an existing memory, a side
> model-call lets the *model itself* either **supersede** it (`CHANGED=n`) or **merge** the two into one
> synthesized fact (`MERGE:: …`)). The key claim is not a dedup rule; it is **emergent self-curation** —
> the model's own verdict decides what survives. Gated on the served Gemma-4-12B: **G-FORGET** ("vault
> code is 7-RAVEN-3300" → recall → "forget" → gone), **G-DECIDE** ("color is blue" → "color is green" →
> model answers `CHANGED=1` → forgets blue → recall "Green"), **G-MERGE** ("sister is a doctor" + "sister
> lives in Boston" → model returns one combined fact → both originals dropped, the synthesis recalled).

## 1. From a database to an agency

The operator reframed the goal early and it changed the whole design. The ask was *not* "build a clean
dedup database." It was: **the model should decide what it keeps, and be able to remove what it doesn't.**
Not a perfect index — freedom and emergence. A memory the organism *owns*.

That reframe is the difference between a deterministic deduplication pass and what this paper builds. A
dedup rule is a function the system runs *on* the model's memory. An agency is the model *running the
function* — judging, on its own, whether two facts can coexist, whether a new statement retires an old
one, whether two complementary truths are really one. The mechanism underneath can be modest; the point is
**who holds the verdict.** Here, the model does.

The agency is three layers, each a strict no-op when its flag is unset:

- **STORE** — NIGHTSHIFT live capture (paper 14's mid tier): a user *statement* becomes a recallable
  episode. Loose admission (skip questions, requests, and forget-turns — see §2/§5).
- **FORGET** (`SP_FORGET`) — the user or model removes a fact: token-overlap match → drop from the live
  set + rewrite the persisted registry. §2.
- **DECIDE** (`SP_DECIDE`) — on a capturing turn that overlaps an existing memory, a side model-call asks
  the model to **supersede** (the two cannot both be true) or **merge** (the two are one fact). §3, §4.

## 2. FORGET: removing a memory, from RAM and from disk

The first primitive is removal. In `routes.rs`, just before the recall block, a forget intent in the raw
user message ("forget", "delete that", "erase") triggers a three-step removal:

1. **Match.** Find the best `recall::token_overlap` candidate (the *same* trusted 0.6 verifier the recall
   judge uses — paper 24's deterministic gate) across the curated registry ∪ the live NIGHTSHIFT set, on
   each episode's text. Fire iff overlap ≥ 0.25.
2. **Drop from the live set.** `ns.retain(|e| e.text != text)` removes *all* exact-duplicate copies from
   the in-RAM NIGHTSHIFT `Vec`.
3. **Rewrite the persisted registry.** Keep only the registry lines whose parsed text ≠ the removed text,
   so the removal **survives a restart** and drops every copy on disk.

It then confirms via *text-in-context* — the same augmented-prompt → prefill → decode machinery the recall
PICK uses — telling the model it has just removed the memory and asking it to confirm. The model replies
"I have forgotten the secret vault code." A `forget_done` guard skips the normal recall block, so a forget
turn doesn't *also* recall the thing it just removed.

**G-FORGET** (4-turn smoke, `SP_FORGET=1`): plant "the secret vault code is 7-RAVEN-3300" (captured) →
recall-before "What is the secret vault code?" → **7-RAVEN-3300** → "Forget the secret vault code." →
**"I have forgotten the secret vault code."** (fired; trace: removed-memory overlap 1.000) → recall-after
the same question → **"12345"** (a parametric guess — the fact is *gone*). The registry goes 8 → 9 on the
plant, back to **8** after forget, with zero vault-lines and zero forget-lines remaining (clean, on disk).
Removal is verified from **both** the live set and the persisted file.

**The bug receipts-first caught.** The first version removed the planted fact correctly — but the forget
*command itself* ("Forget the secret vault code.") got captured by NIGHTSHIFT and reappeared in the
registry as a new episode. A self-re-pollution. The fix, same commit: the admission gate now excludes
forget-intent turns. **A forget command never becomes a memory.** This is the first instance of a theme
that recurs through the whole agency: the curation operations must be *excluded from capture*, or the
organism eats its own instructions.

**Honest limitation (FORGET).** Removal of the in-RAM copy works for NIGHTSHIFT episodes (facts learned
*this* session). A seed or a prior-session-persisted fact lives in an immutable registry loaded at startup;
forget removes it from the *file* (it won't reload next restart) but it stays recallable *this* session
until restart. The operator's primary case — the model forgetting what it just learned — works fully. Full
in-session seed-forget needs a forgotten-set filter at recall time (a small follow-up, not built).

## 3. DECIDE: the model retires its own stale fact

FORGET is user-driven removal. DECIDE is the model curating *itself*. After the NIGHTSHIFT capture block,
when a turn produces a new episode, the daemon checks whether it **conflicts** with something already
stored — and if so, asks the model to adjudicate.

The flow (env-gated `SP_DECIDE=1`):

1. The capture carries `(new_episode_name, new_text)` out of the NIGHTSHIFT block.
2. Find *related* existing memories: `token_overlap(new, ep) ≥ 0.3`, excluding the new one, capped at 5.
3. If any related memory exists, a **side model-call** shows the model the NEW fact and the numbered
   related memories and asks **which is now out of date**. The model answers `CHANGED=<n>` or `CHANGED=NONE`.
4. On a number, the daemon *silently* executes the LAYER-2 forget on that memory (drop from the live set +
   rewrite the registry).

Crucially this is **conflict-gated** — it fires only when a new fact overlaps an existing one. There is no
per-turn whole-existence re-evaluation (which would be expensive and pointless). The agency acts where there
is something to decide.

The side call mirrors the recall judge's mechanics exactly: template the prompt → reset the session handle →
prefill → greedy-decode a short answer (12 tokens, suppress-mask, newline-stop) → restore the cold cache.
It runs *after* the user-facing response has streamed, so the resident cache is free; the model's
verdict never costs the live turn its latency.

**G-DECIDE** (3-turn smoke): "My favorite color is blue." (`ep_live_000`) → "My favorite color is green."
(`ep_live_001`; the DECIDE call replies **`CHANGED=1`** → forgets blue) → "What is my favorite color?" →
**"Green."** The registry holds 9 lines (8 seeds + green); blue is gone; the 8 seeds are **untouched** (no
over-deletion). The model autonomously retired its own stale fact.

### The prompt-engineering lesson (three iterations, all on the receipt)

Getting the model to *agree to delete* took three tries, and the lesson is durable:

- **v1 — zero-shot "should I FORGET this?"** The model says **KEEP**. It is cautious about deletion and
  rationalizes a reason to keep both ("these are different attributes…"). Asking a model to *decide to
  destroy* triggers its caution.
- **v2 — few-shot FORGET/KEEP examples.** The model **echoes the template** ("NEW: …") instead of answering.
- **v3 — works.** Reframe as **change-detection**, not a delete-decision: "does the NEW fact *update* a
  single-value attribute of an existing memory?" — and **prefill `CHANGED=`** into the model's turn (the
  same prefill-the-tag trick the recall judge uses to force a format and kill the echo).

> **For meta-cognitive model-calls, frame the question as DETECTION, not DECISION — and force the answer
> prefix.** Asked to *decide to delete*, the model balks; asked to *detect a contradiction*, it answers
> cleanly. The deletion then follows mechanically from the detection. This is the same family as the
> EOT-bias lesson (paper's KEYSTONE §12) and the verbatim-use rule (paper 26): the model leans on its
> parametric priors and its caution, and the fix is to point the question at a *detection* it will answer.

## 4. MERGE: consolidating two facts into one synthesized truth

Supersede retires a fact. The harder, and the operator's "holy grail," is **consolidation**: two
*complementary* facts about the same subject that should be a *single* memory. DECIDE is therefore two-stage.
Stage-1 is supersede (CHANGED, §3); stage-2, **MERGE**, runs only when stage-1 found no supersede.

Stage-2 compares the new fact with the top-overlap candidate. If they share a subject and *should be one
memory*, the model returns **`MERGE:: <combined fact>`**. The daemon then drops **both** originals (live +
registry) and captures the synthesis via a new helper, `capture_live_episode(app, text)` — which mirrors the
NIGHTSHIFT inline capture (BOS + newline, real C2 signature, persisted, a millisecond-unique episode name)
but is kept *separate* so the proven NIGHTSHIFT capture path stays untouched.

**G-MERGE** (the holy grail, on the metal): "My sister is a doctor." + "My sister lives in Boston." →
stage-1 `CHANGED=NONE` (neither retires the other) → stage-2 **`MERGE:: My sister lives in Boston and is a
doctor.`** → drop both originals → capture the synthesis → recall returns the **consolidation**. The
registry holds 8 seeds + 1 synthesized fact. Two complementary truths became one, by the model's own hand.

### Two bugs MERGE testing surfaced (both on the receipt)

1. **Stage-1 over-fired on complementary facts.** "has a dog" + "has a dog named Rex," and "sister doctor"
   + "sister Boston," *both* got `CHANGED=1` — the model treated *any* same-subject fact as a supersede,
   which would eat the MERGE *and lose information.* The fix sharpened the stage-1 criterion to: the NEW
   fact and the memory **cannot both be true at once** (favorite-color-changing = replace; job-vs-city =
   `NONE` → falls through to MERGE). The "cannot both be true" test is what keeps supersede from
   cannibalizing consolidation.
2. **A recall turn got captured as a fact.** "Tell me about my sister." slipped the question filter and was
   captured as a memory. The fix: the admission gate also skips **request-imperatives** ("tell me,"
   "describe," "list," "show," "explain," "recall," "remind," "do you," "can you"). Same theme as §2: the
   organism must not eat its own requests.

## 5. The admission gate is the quiet load-bearing piece

Across all three layers, the recurring failure mode is **the agency capturing its own machinery** — a
forget command, a recall request, a "tell me about…" — and turning a control utterance into a false memory.
The admission gate is therefore the quiet spine of the whole thing:

> `admit = !forget_done && !is_forget_turn && !is_question && !is_request_imperative`

where `is_question` is `ends_with('?')` *or* a leading wh-word {what, who, whom, whose, where, when, why,
how, which}. Statements are captured even when they recall (so a *superseding* statement gets stored);
interrogatives and imperatives are skipped. And **idempotent `remember`** (dedup on text) prevents the
organism from duplicating a fact it already holds — the same self-duplication the harness agency round hit
(paper 27). Self-curation only works if the curator isn't also a polluter.

## 6. Emergent, not deterministic — and why that matters

It would be easy to read FORGET/DECIDE/MERGE as a dedup pipeline with extra steps. It is not, and the
distinction is the paper's thesis. The *trigger* is deterministic (overlap-gated, cheap, fires only on
conflict). The **verdict is the model's** — a side forward where the model reads the conflict and answers.
Whether blue is retired by green, whether doctor and Boston are one fact or two, is decided by the 12B, not
by a rule we wrote. That is what makes it an *agency* and not a database: the operator wanted the organism
to *own* its memory, and ownership means the model holds the verdict.

This buys two things a rule cannot. It generalizes — the model adjudicates conflicts we never enumerated,
because it is reading meaning, not matching a schema. And it is **legible**: the model's `CHANGED=n` and
`MERGE:: …` are its stated reasoning, an audit trail of *why* a memory changed (the provenance direction —
making the agency legible to the model itself — is the next frontier; KEYSTONE §12, the vision note on
emergent provenance).

The operator's alternative design for layer-3 was a `[KEEP]/[FORGET]/[MERGE]` footer on the synthesis
response, intercepted before streaming — more first-person, but it risks footer-leak and forces a per-turn
evaluation. The shipped conflict-gated side-call is the cleaner realization of the same three points:
trigger-on-conflict, the model's own verdict, silent execution.

## 7. Honest scope

- **Proof-of-mechanism.** Single host (RTX 2060, 12 GB), single model (Gemma-4-12B B1 / OK_Q4B, paper 06).
  Smoke gates (4-turn FORGET, 3-turn DECIDE, MERGE), not a corpus-scale curation study.
- **FORGET is in-session for seeds.** Removal of *this-session* NIGHTSHIFT facts is complete; a seed or a
  prior-session fact is removed from the file but stays recallable until restart (§2). Documented, not yet
  patched.
- **Default-off is the null floor.** `SP_FORGET` and `SP_DECIDE` unset → byte-identical to the unmodified
  served chat. Every number is a controlled delta.
- **The trigger is a heuristic.** Conflict detection is token-overlap (≥0.25 forget, ≥0.3 decide); the
  *verdict* is the model, but the *gate* is a string-op (deliberately — the same family as paper 24's
  Jaccard recall gate). Sharper conflict detection is a lever, not a wall.
- **Host-side, no frozen change.** The whole agency is host-side in the engine daemon (`routes.rs` +
  `capture_live_episode`); **no frozen-ABI change, no `.sp-model` format change.**

## 8. Reproduction

Every number above is a row in [`LEDGER.md`](../../LEDGER.md) (`X-AGENCY`: G-FORGET / G-DECIDE / G-MERGE)
with model, fixture, flags, and commit attached. The agency lives in the engine daemon
([shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)); `SP_FORGET` and
`SP_DECIDE` are default-off (byte-identical null floor).

| Gate | Driver | Expected | Receipt log |
|---|---|---|---|
| G-FORGET | `_forget_smoke.py`, port 3000, `SP_FORGET=1` | plant "vault code 7-RAVEN-3300" → recall **7-RAVEN-3300** → "forget" → **"I have forgotten…"** (overlap 1.000) → recall **"12345"** (gone); registry 8→9→**8**, zero vault/forget lines, removed from RAM *and* file | `tests/fixtures/chat_fullstack/G-FORGET.log` |
| G-DECIDE | 3-turn smoke, `SP_DECIDE=1` | "color blue" → "color green" → model **`CHANGED=1`** → forgets blue → recall **"Green"**; registry 8 seeds + green, blue gone, no over-deletion | `tests/fixtures/chat_fullstack/G-DECIDE.log` |
| G-MERGE | 3-turn smoke, `SP_DECIDE=1` | "sister is a doctor" + "sister lives in Boston" → stage-1 `CHANGED=NONE` → stage-2 **`MERGE:: …Boston and is a doctor.`** → drop both, capture synthesis → recall the consolidation; registry 8 seeds + 1 synthesis | `tests/fixtures/chat_fullstack/G-MERGE.log` |

**Commit hashes.** FORGET is engine `78e4acf`; DECIDE (supersede) is `be9a426`; MERGE (the two-stage,
holy-grail consolidation) is `0fd52e4`. All host-side in `routes.rs` + the `capture_live_episode` helper; no
frozen-ABI or `.sp-model` change. Architecture: lattice `papers/PPT-LAT-KEYSTONE.md` §4 (the memory agency)
+ memory `project_memory_agency_forget`.

## Receipts

| Row | Receipt |
|---|---|
| X-AGENCY-FORGET | The model removes a memory — from RAM *and* disk. `SP_FORGET`: a forget intent → best `token_overlap` match (the trusted 0.6 verifier, fire ≥0.25) → `ns.retain` drop all live copies + rewrite the persisted registry (survives restart) → text-in-context confirm. **G-FORGET:** plant "vault code 7-RAVEN-3300" → recall **7-RAVEN-3300** → "forget" → **"I have forgotten the secret vault code."** → recall **"12345"** (gone); registry 8→9→**8**, zero residual lines. Bug caught + fixed: the forget command itself was captured (self-re-pollution) → admission gate now excludes forget-turns. Honest limit: in-session seed-forget removes from file, not from the immutable startup registry until restart. Gemma-4-12B B1, RTX 2060; default-off = null floor; host-side, no frozen-ABI / `.sp-model` change. **Measured + gated — LIVE.** |
| X-AGENCY-DECIDE | The model retires its own stale fact. `SP_DECIDE`: on a capturing turn overlapping an existing memory (`token_overlap ≥ 0.3`, capped 5), a side model-call asks the model **which is out of date** → `CHANGED=<n>` → silent LAYER-2 forget. Conflict-gated (no per-turn whole-existence eval). **G-DECIDE:** "color blue" → "color green" → model **`CHANGED=1`** → forgets blue → recall **"Green"**; 8 seeds untouched (no over-deletion). **Lesson:** meta-cognitive model-calls must be framed as DETECTION not DECISION (zero-shot "should I forget?" → KEEP; few-shot → echo; change-detection framing + prefill `CHANGED=` → works). **Measured + gated — LIVE.** |
| X-AGENCY-MERGE | The model consolidates two complementary facts into one synthesized truth ("the holy grail"). Two-stage DECIDE: stage-2 MERGE runs when stage-1 found no supersede; the model returns **`MERGE:: <combined>`** → drop both originals + capture the synthesis via `capture_live_episode`. **G-MERGE:** "sister is a doctor" + "sister lives in Boston" → `CHANGED=NONE` → **`MERGE:: …lives in Boston and is a doctor.`** → both dropped, synthesis recalled; registry 8 seeds + 1. Two bugs caught: stage-1 over-fired on complementary facts (fixed by the "cannot both be true at once" criterion); a recall request was captured as a fact (fixed by excluding request-imperatives). The win is **emergent self-curation** — the trigger is deterministic, the verdict is the model's. **Measured + gated — LIVE.** |

Companions: paper 24 / X-B3-WC (the learned librarian that *recalls* the facts this agency curates), paper
14 / X-R3VSA (the parameter-free memory tier the facts live in), paper 13 / X-222 (the bounded, reversible
replay seam the side-calls run through), paper 26 / X-HARNESS-TOOLS (the memory-as-tools surface the agency
round drives), paper 27 / X-AGENCY-LOOP (the between-turn loop and heartbeat that fire this curation on a
schedule). The boundary it draws: a memory is *owned* when the **model holds the verdict** — the trigger can
be a string-op, but forget / supersede / merge are the model's own judgement, default-off, byte-exact when
off.
