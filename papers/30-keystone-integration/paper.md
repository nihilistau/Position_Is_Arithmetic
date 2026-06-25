---
type: paper-bite
title: "KEYSTONE: the night the arches locked into one organism"
description: "Shannon-Prime release series, paper 30 — the capstone."
tags: [paper-bite, keystone, integration, capstone, organism]
timestamp: 2026-06-25T00:00:00Z
resource: ./papers/30-keystone-integration/paper.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# KEYSTONE: the night the arches locked into one organism

*Shannon-Prime release series, paper 30 — the capstone. Discipline: [METHODOLOGY.md](../../METHODOLOGY.md).
Every number below is a row in [LEDGER.md](../../LEDGER.md) with a command behind it.*

> **Front-door receipt (2026-06-25, ledger X-KEYSTONE, milestone keystone-1).** For months the
> pieces were proven in **isolation** — a byte-exact 12B forward (papers 19–21), a two-ring /
> integer memory (papers 13–18), a learned librarian (paper 24), a diffusion judge. KEYSTONE is the
> **integration**: the night they locked into one self-supporting organism. The served Gemma-4-12B
> now holds a conversation **faithfully** (paper 29), **learns / forgets / decides / merges** facts
> on its own verdict (paper 27), **calls tools and runs Python** through the re-hosted harness,
> beats on an **agency heartbeat** that consolidates and curates its own memory between turns, keeps
> conversations in **tiers** — short / mid / long on the content-addressed store (paper 28) — and
> knows **what it is and how to use itself** — *all on the byte-exact `O_K` substrate, all default-off
> = null floor, all receipted.* The loop closes with **zero manual steps**: the daemon writes each
> turn to disk; the scheduler consolidates it on its tick. ~**90%** of the envisioned organism, with
> the open edges stated honestly. **This is the foundation we build forward on.**

## 1. The keystone

A keystone is the wedge-shaped stone at the apex of an arch. It is the **last** stone placed, and it
is the one that, once set, makes every other stone load-bearing: until the keystone is in, the arch
is a pile of stones held up by scaffolding; the moment it drops into place, the scaffolding comes
out and the arch stands on its own, each stone now pressing into its neighbors. That is the exact
shape of this milestone. Every subsystem in this series was, for months, a stone held up by its own
scaffolding — a gate harness, a default-off flag, a test fixture. KEYSTONE is the night the
**integration stone** dropped in and they started holding each other up.

The series until now has been, deliberately, a sequence of **isolated proofs**:

- the **container** made exact — a 12B forward carried onto exact-integer `O_K` arithmetic (papers
  19–21: the four nonlinear islands, the CRT-NTT attention, the de-conflation that it buys
  *auditability, not compression*),
- the **memory** made discrete and reversible — bounded O(1) replay and rewind, a parameter-free
  VSA tier, a Frobenius integer episode store, the whole loop re-carried onto the same integer
  substrate (papers 13–18),
- the **recall** made autonomous — a learned `W_c` head doing instance-level recall with clean
  foreign-reject, after nine hand-designed signals failed and a causal oracle relabeled the problem
  (papers 22–24),
- the **judge** made cheap — a deterministic token-overlap verifier that beats a 26B MoE cascade on
  a CPU string op.

Each was real, each was gated, each ran alone. None of them, until this night, ran **together**, on
the same substrate, in the same served loop. That is what KEYSTONE is.

## 2. What locked together

The integration is the result. Here is the arch, stone by stone, and how each now presses into its
neighbors:

```
                          ┌───────────────────────────────┐
                          │   KEYSTONE: the served chat    │  ← the apex stone
                          │   one self-supporting organism │
                          └───────────────────────────────┘
       ┌──────────────┬──────────────┬──────────────┬──────────────┬──────────────┐
   faithful        learned/        tool calling   agency         tiered          all on the
 conversation   forgotten/        + Python       heartbeat      conversation     byte-exact
  (paper 29)     decided/         (harness)      (KAIROS)        memory           O_K substrate
                 merged memory                   consolidates    (paper 28)       (papers 19-21)
                 (paper 27)                       between turns
       └──────────────┴──────────────┴──────────────┴──────────────┴──────────────┘
            every stone a default-off flag — null floor when unset — and a gate
```

- **Faithful conversation** (paper 29). The served chat carries the full thread and stays grounded
  to it — the "restart" was a faithfulness bug, not a cache miss, and the system prompt patches it.
  This is the stone the *user actually touches*; without it the rest is invisible.
- **Memory agency** (paper 27). The model owns its memory: it **stores** (NIGHTSHIFT capture),
  **forgets** ("forget X" → drop from the live set + rewrite the registry), and **decides** — on a
  capturing turn that conflicts with an existing memory, a side model-call asks the model itself to
  **supersede** ("CHANGED=n," the *cannot-both-be-true* test) or **merge** ("MERGE:: combined," drop
  both and capture the synthesis). The three-layer stack — STORE / FORGET / DECIDE+MERGE — is live;
  gates `G-FORGET`, `G-DECIDE`, `G-MERGE`.
- **Tool calling + Python** (the harness). The CosySim agent runtime re-hosted on the sp-daemon
  (lmstudio stripped); **ephemeral text-protocol** tool calling — the model emits
  `<tool name="…">{json}</tool>` in plain text, the harness parses, executes, and feeds the result
  back (a ReAct loop, no native tool channel needed). It calls a calculator, runs Python, and reads
  and writes its own memory *as tools*. Gates `G-HARNESS-TOOLCALL-E2E`, `G-HARNESS-MEMTOOLS-E2E`.
- **The agency heartbeat** (KAIROS). Between turns, idle-gated, the organism *does things instead of
  only stopping*: a scheduler tick consolidates the just-written conversation (facts → mid tier,
  transcript → long tier) and runs a **maintenance round** where the model curates its own memory.
  Gates `G-HARNESS-AGENCY-E2E`, `G-HARNESS-KAIROS-TICK`.
- **Tiered conversation memory** (paper 28). Short (the live thread, re-prefilled) → mid (durable
  facts extracted into the registry) → long (the whole conversation, complete *and* summarized,
  under one sha256 address; gist by default, verbatim on demand). Plus the init priming that teaches
  the organism what it is. Gates `G-HARNESS-CONVMEM-E2E`, `G-HARNESS-CONSOLIDATE`,
  `G-HARNESS-HOOK-E2E`.
- **The byte-exact `O_K` substrate** (papers 19–21). All of it rides the exact-integer arithmetic
  container — dual-prime negacyclic CRT-NTT, the four nonlinear islands as exact-integer references,
  cross-machine-deterministic, auditable. Gate `G-BYTEEXACT-FORWARD-12B`. The container is exact; the
  intelligence rides on top.

## 3. The loop closes with zero manual steps

The detail that makes this an *organism* and not a toolbox is that **the loop closes by itself.** A
turn flows end to end like this:

1. The console POSTs the **full** conversation; the daemon templates it, prefills, and — with the
   consolidation hook set — **writes the turn to disk**.
2. If autonomous recall is on, the learned head scores the stored episodes, recites a confident
   match via text-in-context, or abstains (the deterministic token-overlap verifier @0.6 guards
   false fires).
3. Decode streams, EOT-biased so it stops cleanly.
4. Post-response, NIGHTSHIFT **captures** the user statement; the DECIDE layer may **supersede or
   merge** a related memory.
5. Out of band, on the **KAIROS tick**, the scheduler **consolidates** the written conversation
   (facts → mid, transcript → long) and runs a **maintenance round** where the model tidies its own
   memory.

No human runs the consolidation. No human curates the registry. The daemon writes; the heartbeat
reads and consolidates. That self-closing loop — write-on-turn, consolidate-on-tick — is the wedge
that makes the whole arch self-supporting.

## 4. The thread that runs through every stone

Three principles run through all of it, and they are why the integration is *believable* rather than
a demo:

- **Default-off is the null floor.** Every mechanism — `SP_BYTEEXACT`, `SP_EOT_BIAS`,
  `SP_AUTO_RECALL`, `SP_FORGET`, `SP_DECIDE`, `SP_B4_NIGHTSHIFT`, `SP_CURRENT_CONVO`, every harness
  flag — is a **strict no-op when unset**. The baseline is provably the unmodified network; every
  on-state result is a controlled delta, never a confound. The whole organism, switched off, is
  byte-identical to a plain served 12B.
- **No number without a command.** Every claim in this paper is a gate with a receipt log and a
  commit. The proof map (§8) is the index. A capability you cannot run is not in the paper.
- **The container is exact; the structure is learned.** The boundary thesis the whole series drew —
  `O_K` wins on *exact arithmetic* (the container), never on structuring *content* — holds across
  the integration. The byte-exact forward, the integer memory ring, the bounded replay seam: all
  exact arithmetic. The recall relevance, the merge judgement, the faithfulness: all **learned** or
  **model-decided**, riding the exact container. Every hand-designed structure-on-content lever in
  the series stayed a measured negative (papers 16–17, 21, 22) — kept attached, never quietly
  dropped.

## 5. What is done, and what is open (honest)

KEYSTONE is **~90%** of the envisioned organism. The honest ledger of done-vs-open:

**Done (GREEN-LIVE):** byte-exact 12B forward; coherent, faithful served chat; autonomous recall +
clean reject; the full memory agency (store / forget / decide / merge); the harness end-to-end
(daemon, tool calling, Python exec, memory-as-tools, the agency loop + heartbeat tick); tiered
conversation memory + the capabilities corpus; the live, zero-step consolidation hook.

**Open edges (the next stones):**

1. **Persistent O(1) conversation KV.** The daemon re-prefills the whole conversation each turn —
   *correct but O(n)*. The L1 stateful kvdecode verb (§6b) can make "continue the cache" a true O(1)
   append. This is the single biggest performance lever left, and it is an ABI hook already built,
   not yet the served path.
2. **The two-physical-GPU check.** Byte-exact's cross-machine determinism is proven *on-machine*
   (run-to-run bit-identity + reduction-order immunity as the proxy); the genuinely-external step —
   a bit-identical logit check across two *different physical* GPUs — needs a second machine and is
   still open.
3. **Deeper faithfulness.** The system prompt (paper 29) is a patch; the model still leans on
   parametric priors over grounding in the hard cases. The *structural* answer is the tiered memory
   (reliable recall surfacing stated facts), and pushing that from "works on the diagnostic" to
   "holds at length" is open.
4. **Native-C XBAR port + T4 weights.** The XBAR memory tooling is still host-Python on the integer
   primitives; a native-C, `core/`-resident port is scoped. And the T4 Frobenius π^k of the model
   *weights* — a validated lever — remains untouched.

We say ~90% and name the missing 10% on purpose. The receipts discipline (paper 10) is the same one
that kept the 32k MISS on the front page and retired the first speed headline: the open edges go in
the front door, not a footnote.

## 6. Why this is the capstone

Papers 01–06 built the **container** — a 12B served byte-faithfully on a 2060, computing on its own
packed codes. Papers 07–15 built the **crossbar and the orchestration** — latent KV steering,
O(1) cache, the resident daemon, the discrete recall loop, the parameter-free neocortex, the first
breath of a cross-modal organism. Papers 16–21 carried the whole thing onto the **exact-integer
`O_K` substrate** and proved what that does (auditability) and does not (compression) buy. Papers
22–24 won **autonomous recall** the hard, honest way — nine negatives, a causal oracle, a learned
head. Papers 27–29 gave the organism **agency over its own memory** and **faithfulness to its own
conversation**.

KEYSTONE (paper 30) is where those locked into **one running thing**. Not a new mechanism — the
*integration as the result*. The arch was a sequence of beautiful, isolated stones; tonight the
keystone went in and it stands on its own. Everything in this series so far is the foundation. From
here, we build *up*.

## 7. Honest scope

- **Integration paper.** The headline is that the pieces run **together**, on one substrate, in one
  loop, default-off-is-null-floor — not a single new performance number. Each subsystem's measured
  result is its own paper; this paper's contribution is that they compose.
- **Proof-of-mechanism, still.** One model (Gemma-4-12B B1 / `OK_Q4B`, paper 06), one host (RTX 2060
  12 GB), one operator's machine. Not multi-model, not multi-user, not a scaling study, not
  independently reproduced. ~90% built, with the four open edges of §5 named.
- **The flags are off by default.** The whole organism, switched off, is the byte-identical null
  floor. Every on-state capability is a controlled delta with a gate.
- **No frozen change for the agency/memory tiers.** The recall head, the agency, and the tiered
  memory are host-side (engine daemon + harness); the byte-exact forward touches the math core
  (`core/exact_islands`) and the additive L1 §6b verb, but renumbers no frozen surface and changes
  no `.sp-model` format.

## 8. The proof map (the integration's receipts)

Every capability is a gate with a command and a commit. This is the index; each row's detail is its
own paper or its contract.

| Capability | Gate(s) | Where |
|---|---|---|
| Byte-exact 12B forward | `G-BYTEEXACT-FORWARD-12B` | engine `69c0588` / submodule `d9d96f3`; papers 19–21 |
| Faithful served chat | `FAITHFUL=True` diagnostic; `SP_EOT_BIAS` (clean stop) | engine `88d924e` / `9e4b40f`; paper 29 |
| Autonomous recall + reject | `G-CHAT-B3-WC-DEPLOY` | engine `edc8079`; paper 24 |
| Deterministic recall judge | `G-JUDGE-BATTERY` | engine receipts; KEYSTONE §4 |
| Memory agency (store/forget/decide/merge) | `G-FORGET`, `G-DECIDE`, `G-MERGE` | engine `0fd52e4`; paper 27 |
| Harness end-to-end | `G-HARNESS-DAEMON-E2E` (H1), `G-HARNESS-TOOLCALL-E2E` (H2), `G-HARNESS-MEMTOOLS-E2E` (H3), `G-HARNESS-AGENCY-E2E` (H4), `G-HARNESS-KAIROS-TICK` (H5) | harness `tests/` |
| Tiered conversation memory + priming | `G-HARNESS-CONVMEM-E2E` (H6), `G-HARNESS-CONSOLIDATE`, `G-HARNESS-HOOK-E2E` (H7) | harness `tests/`; paper 28 |

Every row reproduces by a `python tests/<gate>.py` (or the contract's repro). The complete,
current, canonical description of the integrated system is lattice `papers/PPT-LAT-KEYSTONE.md`
(milestone keystone-1); the run-it-from-clean instructions are its §10. **Rule, unchanged: no
number without a command + a row.**

## Receipts

| Row | Receipt |
|---|---|
| X-KEYSTONE | **The integration is the result.** For months the pieces were proven in **isolation** — byte-exact forward (papers 19–21), two-ring / integer memory (papers 13–18), the learned librarian (paper 24), the diffusion judge. KEYSTONE (milestone **keystone-1**, 2026-06-25) is the night they locked into **one self-supporting organism**: the served Gemma-4-12B holds a conversation **faithfully** (paper 29), **learns / forgets / decides / merges** memory on its own verdict (paper 27, `G-FORGET` / `G-DECIDE` / `G-MERGE`), **calls tools and runs Python** (harness, `G-HARNESS-TOOLCALL-E2E` / `-MEMTOOLS-E2E`), runs an **agency heartbeat** that consolidates and curates between turns (`G-HARNESS-AGENCY-E2E` / `-KAIROS-TICK`), keeps conversations in **tiers** (paper 28, `G-HARNESS-CONVMEM-E2E` / `-CONSOLIDATE` / `-HOOK-E2E`), and knows **what it is** (priming) — **all on the byte-exact `O_K` substrate** (`G-BYTEEXACT-FORWARD-12B`), **all default-off = null floor, all receipted**. The loop closes with **zero manual steps** (daemon writes the turn → scheduler consolidates on its tick). ~**90%** of the envisioned organism; **open edges named** — persistent O(1) conversation KV (L1 §6b), the two-physical-GPU byte-exact check, deeper faithfulness, the native-C XBAR port + T4 weights. The boundary thesis holds across the integration: the **container is exact** (byte-exact arithmetic, integer memory ring), the **structure is learned / model-decided** (recall, merge, faithfulness); every hand-designed structure-on-content lever stayed a measured negative. Gemma-4-12B B1, RTX 2060, one machine; host-side memory/agency (no frozen-ABI change) + the additive L1 §6b verb. **This is the foundation — build forward from here. Measured + gated — KEYSTONE-1.** |

Companions: the **whole series** locks under this stone — 01–06 (the container), 07–15 (the
crossbar + orchestration), 16–21 (the exact-integer substrate + the boundary thesis), 22–24 (the
autonomous librarian), 27 (the memory agency), 28 (the tiered memory), 29 (the faithfulness lesson).
The canonical, current map of the integrated system is lattice `papers/PPT-LAT-KEYSTONE.md`.
