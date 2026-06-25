---
type: paper-bite
title: "29 — Conversational faithfulness: the chat didn't restart, it confabulated *(written, citable — X-FAITHFUL)*"
description: "The served chat 'felt like it restarted each turn' — but the daemon carries the full conversation. The real"
tags: [paper-bite, faithfulness, grounding, lesson]
timestamp: 2026-06-25T00:00:00Z
resource: ./papers/29-conversational-faithfulness/README.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# 29 — Conversational faithfulness: the chat didn't restart, it confabulated *(written, citable — X-FAITHFUL)*

> **STATUS: written — front-door complete.** The sharp-lesson paper of the KEYSTONE set (ledger
> **X-FAITHFUL**): a misdiagnosis corrected, a one-line patch shipped, and the meta-lesson the
> project keeps re-learning, banked.

> **Front-door (2026-06-25):** The chat *felt* like it restarted each turn. It does not — the daemon
> re-prefills the full conversation, and a planted name survives (recall on *and* off). The real
> failure was **faithfulness**: the model confabulated an earlier stated fact (said "dog" over the
> user's "octopus"), leaning on parametric priors over the in-context thread. A default system
> prompt ("never substitute a stated fact") makes octopus stay octopus.

## The claim this paper makes

The served chat's "restart" feeling was a **misdiagnosis**, not a cache bug: the daemon **carries**
the full conversation (re-prefills every message each turn; a planted name **survives** with
autonomous recall **on and off**). The real failure was **faithfulness** — the model got the
*recent* fact right and **confabulated an earlier one** (favorite animal: said **"dog"** over the
stated **"octopus"**), leaning on a parametric prior over the in-context thread (the grounding
problem inside one conversation). The fix is a default **system prompt** (identity + capabilities +
"use what the user said faithfully; never substitute a stated fact") → diagnostic **`FAITHFUL=True`**
(engine `88d924e`). The **meta-lesson**: served-model misbehavior is almost always *ours* — template
/ decode / sampler / forward / prompt — *not the weights*; verify vs llama.cpp + our own PPL first
(the companion EOT bug blamed the quant *twice* wrongly; the real cause was a stop token at rank 1
losing by a hair, fixed with `SP_EOT_BIAS ≈ 4`, engine `9e4b40f`). The **prompt is the patch**; the
*structural* answer is the tiered memory of paper 28 (reliable recall).

## What's in it (the map)

1. **The symptom and the wrong instinct** — "it restarts each turn" → the reflex is a cache bug.
2. **The chat does not restart — proven** — plant a name early, ask late; it survives (recall on and off); the daemon re-prefills the full thread.
3. **The real failure** — confabulation over grounding: octopus → "dog," parametric prior beats the in-context fact.
4. **The fix** — a default system prompt (identity + capabilities + the faithfulness rule); `FAITHFUL=True`.
5. **The meta-lesson** — it is almost always us (template / decode / sampler / forward / prompt); verify before blaming the quant; the EOT companion case.
6. **The structural answer is memory** — the prompt is a patch; reliable recall (paper 28) is the architecture.

## Honest scope

One *diagnostic* ("octopus stays octopus"), not a faithfulness *score* over a corpus. The prompt is
a **patch** — it biases the prior toward grounding, it does not eliminate parametric override
(deeper faithfulness is an explicit KEYSTONE open edge). One model (12B-b1), one host (RTX 2060).
The headline is a *negative corrected* (the cache was never the bug). Host-side served-console
default; no forward / ABI / `.sp-model` change.

## Status

**Front-door written/complete** — citable via ledger **X-FAITHFUL**. The faithfulness system prompt
is engine `88d924e` (served console `index.html`); the companion EOT fix is engine `9e4b40f`
(`SP_EOT_BIAS` / `SP_EOT_DEBUG`). Lattice `papers/PPT-LAT-KEYSTONE.md` §12 (the recurring lesson,
banked). Companions: **28** (the tiered memory — the structural answer), **24** (the librarian whose
recall surfaces stated facts), **23** / **22** (the same parametric-vs-episodic boundary), **10**
(the verify-before-you-blame discipline), **30** (the integration this lesson is one stone of).
