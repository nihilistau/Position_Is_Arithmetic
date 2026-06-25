---
type: paper-bite
title: "Conversational faithfulness: the chat didn't restart — it confabulated"
description: "Shannon-Prime release series, paper 29."
tags: [paper-bite, faithfulness, grounding, lesson]
timestamp: 2026-06-25T00:00:00Z
resource: ./papers/29-conversational-faithfulness/paper.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# Conversational faithfulness: the chat didn't restart — it confabulated

*Shannon-Prime release series, paper 29. Discipline: [METHODOLOGY.md](../../METHODOLOGY.md).
Every number below is a row in [LEDGER.md](../../LEDGER.md) with a command behind it.*

> **Front-door receipt (2026-06-25, ledger X-FAITHFUL).** The served chat *felt* like it restarted
> each turn. The instinct was a cache bug. It was not: the daemon **does** carry the full
> conversation — it re-prefills every message each turn, and a planted name survives, with
> autonomous recall on *and* off. The real failure was **faithfulness**: the model got the *recent*
> fact right and **confabulated an earlier one** — told a favorite animal was "dog" when the user
> had stated "octopus" — leaning on parametric priors over the in-context thread. The fix is a
> default **system prompt** (identity + capabilities + "use what the user said faithfully; never
> substitute a stated fact"), which makes octopus stay octopus (diagnostic `FAITHFUL=True`, engine
> `88d924e`). The meta-lesson is the one the project keeps re-learning: **served-model misbehavior
> is almost always *ours*** — template / decode / sampler / forward / prompt — *not the weights*;
> verify against llama.cpp + our own PPL before blaming the quant. The *structural* answer to
> faithfulness is the tiered memory of paper 28 (reliable recall); the prompt is the patch.

## 1. The symptom and the wrong instinct

A user talks to the served Gemma-4-12B for a while, then asks it to recall something from earlier in
the same conversation — and it gets it *wrong*. The thread "felt like it restarted each turn." The
natural first hypothesis, and the one we reached for, is mechanical: a KV-cache bug, a context that
is not actually being carried, the conversation silently truncated.

This series exists to stop us from believing the natural hypothesis without a receipt. So we tested
it the only honest way: plant a fact early, ask for it late.

## 2. The chat does not restart — proven

We carried a conversation across many turns with a planted token ("Zog," a name; "jazz," a
preference) stated in an early turn, then asked for it turns later. **It survived.** It survived
with autonomous recall **on**, and it survived with autonomous recall **off** — which rules recall
out as the carrier. The daemon **re-prefills the full message list every turn**: system + every
user turn + every assistant turn, templated with the gemma4 control tokens. The conversation is
genuinely, fully present in the model's context on every single turn.

So the cache was never the bug. The "restart" feeling was real, but it was pointing at the wrong
organ. Short-term memory (paper 28's SHORT tier) was working exactly as designed.

## 3. The real failure: confabulation over grounding

The actual failure surfaced when we stopped trusting the feeling and read the transcript. The model
answered a **recent** question correctly — and then, asked about an **earlier** stated fact,
*confabulated it*. The user had said their favorite animal was an **octopus**; the model, several
turns on, said **dog**. The fact was right there in the re-prefilled context. The model did not
fail to *have* it — it failed to *use* it, substituting a high-prior parametric answer ("dog" is a
far likelier "favorite animal" in the weights) for the low-prior thing the user actually said.

This is the recurring grounding problem in its purest, cheapest-to-reproduce form: **the model was
unfaithful to its own in-context conversation.** Recent facts survived; older, lower-salience,
higher-surprise facts got overwritten by the parametric prior. It is the same disease that defeated
nine hand-designed recall signals (paper 22) and the same one the learned librarian (paper 24) and
the causal-ablation oracle (paper 23) were built to measure — *episodic dependency vs parametric
recall* — now showing up inside a single conversation instead of across a registry.

## 4. The fix: a system prompt that demands faithfulness

The patch is small and exactly targeted. We added a **default system prompt** to the served console
(`index.html`), prepended to every conversation:

- **identity** — what the organism is,
- **capabilities** — what it can do (remember, recall, run tools and Python; the seed of paper 28's
  capabilities corpus),
- the **faithfulness rule** — *use the facts the user has stated in this conversation; an octopus is
  an octopus; never substitute a stated fact with a more likely one.*
- a **reply-style** ask — concise, grounded.

With the prompt in place, the diagnostic flips: the octopus stays an octopus
(`FAITHFUL=True`). The change is engine `88d924e`; the user hard-refreshes to pick up the new
console default. It also folds in the operator's two standing asks — seed the model's
self-knowledge of its capabilities, and shape the reply style — in the same prompt.

## 5. The meta-lesson: it is almost always us

This is the second time in the campaign the same lesson landed, and it is worth naming as a finding
in its own right, because it is the discipline that makes the rest of the receipts believable.

> **Served-model misbehavior is almost always *ours* — template, decode, sampler, forward, or
> prompt — not the weights.** Verify against llama.cpp and our own PPL *before* blaming the quant.

The companion case (banked the same week) was the end-of-turn coherence bug: the served chat
rambled and confabulated fake user/model turns, and the quant got the blame — *twice*, wrongly. The
operator (correctly) called it bullshit. Instrumented, the truth was ours: the end-of-turn token
reaches **rank 1** at the boundary in our forward but loses by a hair, so the model never stops; a
small logit bias on the stop tokens (`SP_EOT_BIAS ≈ 4`) fixes it and the model ends cleanly. Same
shape as this paper: the weights were fine, the *harness around them* was the bug. When a served
model misbehaves, the prior should be "we broke it," and the verification is the gold PPL and the
reference engine, never a hunch about the quantizer.

## 6. The structural answer is memory, not prompts

The system prompt is a **patch**, and we say so. It nudges the sampler's prior toward the grounding;
it does not *guarantee* it. The real, durable answer to faithfulness is the **tiered memory** of
paper 28: when a stated fact ("octopus") is *extracted into the mid tier* and *reliably recalled*,
the model is not relying on its attention over a long re-prefilled context to out-vote a strong
parametric prior — the fact is *surfaced* to it as memory. Reliable recall makes faithfulness a
retrieval property instead of an attention-competition property. The prompt buys us correct behavior
today; the tiered store + the learned librarian + the agency that curates it (papers 28, 24, 27) is
the architecture that makes it *hold*.

That is the honest framing: a cheap, correct, shipped patch — and a clear statement that the patch
is not the architecture, the memory is.

## 7. Honest scope

- **One diagnostic, not a benchmark.** "Octopus stays octopus" (`FAITHFUL=True`) is a targeted
  reproduction, not a faithfulness *score* over a corpus. It shows the failure and that the prompt
  fixes *this* case; it does not measure the residual rate.
- **The prompt is a patch.** It biases the prior toward grounding; it does not eliminate parametric
  override. Deeper faithfulness is an explicit open edge of KEYSTONE.
- **Proof-of-mechanism.** One model (Gemma-4-12B B1 / `OK_Q4B`, paper 06), one host (RTX 2060 12 GB),
  the served chat. Not multi-model, not a scaling study.
- **Negative-as-finding.** The headline of this paper is a *misdiagnosis corrected* — "it restarts"
  was wrong. That is the contribution as much as the fix: the cache was never the bug, and proving
  so is what let us build the right thing.
- **Host-side, no frozen change.** The system prompt is a served-console default; no forward, no
  ABI, no `.sp-model` change. Default (an empty system prompt) is the prior behavior.

## 8. Reproduction

Every number above is a row in [`LEDGER.md`](../../LEDGER.md) (`X-FAITHFUL`) with model, fixture,
flags, and commit attached. The carry-the-conversation proof and the faithfulness diagnostic run
against the served daemon
([shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)); the
system prompt is the served console default (`index.html`).

| Check | Driver | Expected | Receipt |
|---|---|---|---|
| Conversation is carried | plant a name early → ask many turns later (recall on **and** off) | the planted name **survives** both ways → the daemon re-prefills the full thread; *not* a cache bug | (faithfulness diag log) |
| The confabulation | ask for an earlier stated fact ("favorite animal") | model says **"dog"** over the stated **"octopus"** → parametric override of in-context grounding | (faithfulness diag log) |
| The fix | default system prompt (identity + capabilities + "never substitute a stated fact"), engine `88d924e` | octopus stays octopus → **`FAITHFUL=True`** | (faithfulness diag log) |
| The companion lesson | EOT coherence bug: stop token rank-1-but-loses → `SP_EOT_BIAS ≈ 4` | the model ends cleanly; the quant was wrongly blamed *twice* — the bug was ours | engine `9e4b40f` (`SP_EOT_DEBUG`) |

**Commit hashes.** The faithfulness system prompt is engine `88d924e` (served console `index.html`);
the companion EOT fix is engine `9e4b40f` (`SP_EOT_BIAS` / `SP_EOT_DEBUG`). No frozen-ABI or
`.sp-model` change. Architecture: lattice `papers/PPT-LAT-KEYSTONE.md` §12 (the recurring lesson,
banked).

## Receipts

| Row | Receipt |
|---|---|
| X-FAITHFUL | The served chat's "it restarts each turn" was a **misdiagnosis**. The daemon **does** carry the full conversation — it re-prefills every message each turn; a planted name **survives** with autonomous recall **on and off** (cache ruled out). The real failure was **faithfulness**: the model answered a *recent* fact right and **confabulated an earlier one** — said a favorite animal was **"dog"** when the user stated **"octopus"** — leaning on a parametric prior over the in-context thread (the grounding problem inside one conversation). **Fix:** a default **system prompt** (identity + capabilities + "use what the user said faithfully; never substitute a stated fact") → **`FAITHFUL=True`**, octopus stays octopus (engine `88d924e`, served console `index.html`). **Meta-lesson** (banked): served-model misbehavior is almost always *ours* — template / decode / sampler / forward / prompt — *not the weights*; verify vs llama.cpp + our PPL first (companion: the EOT coherence bug blamed the quant *twice* wrongly — the real cause was a stop token reaching rank 1 but losing by a hair, fixed by `SP_EOT_BIAS ≈ 4`, engine `9e4b40f`). **The prompt is the patch; the structural answer is the tiered memory of paper 28** (reliable recall). Gemma-4-12B B1, RTX 2060; host-side, no frozen-ABI / `.sp-model` change. **Measured — negative-corrected + patch shipped.** |

Companions: paper 28 / X-CONVMEM (the tiered memory that is the *structural* answer to
faithfulness — reliable recall, not a prompt), paper 24 / X-B3-WC (the learned librarian whose
recall surfaces stated facts), paper 23 / X-B3-ABLATION (the same parametric-vs-episodic boundary,
measured as a causal oracle), paper 22 / X-B3-NEGATIVES (the grounding problem that defeated nine
hand-designed signals), paper 10 / X-RECEIPTS (the discipline — verify before you blame — this
paper instantiates), paper 30 / X-KEYSTONE (the integration this lesson is one stone of).
