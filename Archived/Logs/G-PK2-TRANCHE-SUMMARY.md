# PRODUCT KEYSTONE-2 — harness tranche receipts (2026-07-07)

Contract: `shannon-prime-lattice/papers/CONTRACT-PRODUCT-KEYSTONE-2.md`

## §T2 — coding / agentic + harness expansion

**G-PK2-TOOLROBUST (offline, 10/10 PASS)** — `tests/g_pk2_toolrobust_offline.py`
Proves the new machinery without the daemon (fake scripted client):
- §T2-E3 malformed-tool-fence recovery (re-prompt, never leak a broken fence as the answer)
- §T2-E3 no-progress detector (identical call+result twice → loop self-breaks, honest stop)
- clean single tool call still works (no regression)
- §T2-E2 coding tools: `edit_file` anchored find/replace + ambiguity guard + missing-anchor guard
- §T2-E1 task loop: `post_task` persists, state round-trips (resumable), `list_tasks` filters
- §T2-E1 **verify-gate**: a scripted model that CLAIMS "DONE" without doing the work is REJECTED
  by `run_task(verify=…)` and only accepted once verify() passes (the confabulation fix, below)

**New surfaces:**
- `harness/skills/builtin/coding.py`: added `edit_file`, `run_tests`, `git_status`, `git_diff`
  (+ `CODING_TOOLS` export). Anchored edit > whole-file rewrite; tests + read-only git receipts.
- `harness/control/task_loop.py`: `run_task` (bounded, resumable, receipted multi-step loop),
  `post_task` / `list_tasks` / `advance_pending_task` (the work queue), `TaskState` (atomic JSON
  persistence under `SP_TASK_ROOT`).
- `harness/mcp/tools.py`: malformed-recovery + no-progress guards in `run_with_tools`.
- `harness/control/agency.py`: KAIROS tick drains one pending task/tick under `SP_AGENCY_TASKS=1`.

**G-PK2-TASKLOOP-E2E (live 12B) — HONEST FINDING + FIX.**
First live run (14-tool default): the 12B explored and stalled — confirming the harness's own
"≤6 tools" rule; default corrected to a focused 6-tool coding set.
Second live run (6 tools, no verify): the model declared *"DONE: I've fixed the add() function"*
while `edit_file` had **never landed** — `calc.py` was byte-unchanged. Ground truth caught it
(`fixed=False tests_green=False` → FAIL). **This is a real confabulation gap**: the loop trusted
the model's word. **Fix:** `run_task(verify=…)` — a DONE claim is only accepted if an objective
predicate (here: pytest exit 0) passes; a false claim is fed back and the loop continues. Proven
in the offline gate (verify-gate case). Live convergence of the 12B on *autonomous* multi-tool
code-editing remains at/near this model's capability boundary (honest scope); the harness now
refuses to confabulate a pass regardless. See `G-PK2-TASKLOOP-E2E.log` for the live transcript.

## §T3 — MEM-OKF v2

**G-PK2-MEMOKF-V2 (offline, 6/6 PASS)** — `tests/g_pk2_memokf_v2_offline.py`
- §M1 provenance lane: `remember(fact, source=…)` stamps src+ts; `provenance(fact)` recites
  "learned from <src> at <ts>"
- §M2 near-dup extraction guard: a paraphrase of an existing fact is rejected (registry stays lean);
  a genuinely new fact is still stored
- §M3 hygiene: `verify_registry` flags malformed/dup rows; `compact_registry` removes them
- Consolidator stamps `source="consolidator"`; conflicting facts still go through daemon DECIDE/MERGE

## §T4 — personality + UI

**G-PK2-UI-ENDPOINTS (offline, 5/5 PASS)** — `tests/g_pk2_ui_endpoints_offline.py`
- §U1 gateway surfaces: `/v1/memory` (facts+provenance+health), `/v1/tasks` (work queue)
- §P1 persona editor: `GET/POST /v1/persona` round-trip; an edit records an operator-provenance memory
- persona v2 structured `## Personality state` block still parses (personality system intact)
- New surfaces: `harness/server/app.py` (endpoints, Flask + stdlib), `frontend_mockups/operator.html`
  (memory browser + work queue + persona editor panel), `conversation_memory.CAPABILITIES`
  (§P2 self-knowledge for the new tools).

## WAVE 2 (ADR-006 + speed lever, 2026-07-07)

**ADR-006 Verified Agency** (lattice `PPT-LAT-ADR-006-VERIFIED-AGENCY.md`) — verify-before-accept
as system law, the agentic task loop, typed SSE v2, MEM-OKF v2 as the substrate.

**G-PK2-SSE-V2 (offline, 5/5 PASS)** — `tests/g_pk2_sse_v2_offline.py`. The gateway's `/v1/chat`
stream now carries typed events (`{persona}`, `{tool}`, `{delta}`) so a UI can render tool cards +
personality chips; `typed_events:false` is pure-delta (backward compatible). `harness/server/app.py`.

**G-PK2-UI-ENDPOINTS now 7/7** — added `/v1/persona/state` (personality chip) + the agency-tick
**hygiene** step (verify + compact the registry deterministically on each idle KAIROS tick,
`harness/control/agency.py`). `operator.html` gains a live personality-state chip.

**G-PK2-PREFILL-DP4A (engine, HONEST NEGATIVE, default-off)** — a batched packed-dp4a prefill GEMM
(keep OK_Q4B weights int4, no f32 materialization). Arithmetic CORRECT (coherent "Paris" through
the full 48-layer forward) but NOT a speed win as built (naive + register-tiled both memory/
occupancy-bound on the 2060). Ships default-off (`SP_KV_PREFILL_DP4A` unset = `gemm_w_lift` =
byte-identical null floor). Real levers = cublasGemmEx int8 / SMEM tiling / batched-under-ring
(follow-on). Receipt: engine `tests/perf/G-PK2-PREFILL-DP4A.log`.

## Run
```
python tests/g_pk2_toolrobust_offline.py     # 10/10
python tests/g_pk2_memokf_v2_offline.py       #  6/6
python tests/g_pk2_ui_endpoints_offline.py    #  7/7
python tests/g_pk2_sse_v2_offline.py          #  5/5
python -u tests/g_pk2_taskloop_e2e.py         # live; needs daemon on :3000
```
