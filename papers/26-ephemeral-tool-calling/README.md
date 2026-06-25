---
type: paper-bite
title: "26 — Ephemeral tool calling: a text protocol that turns a text-only backend into a tool-using agent *(written, citable — X-HARNESS-TOOLS)*"
description: "The model emits <tool name=\"…\">{json}</tool> in plain text; the harness parses, executes, and feeds the result back (ReAct) — tool calling + sandboxed Python with no native tool channel."
tags: [paper-bite, harness, tools, react, python]
timestamp: 2026-06-25T00:00:00Z
resource: ./papers/26-ephemeral-tool-calling/README.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# 26 — Ephemeral tool calling: a text protocol that turns a text-only backend into a tool-using agent *(written, citable — X-HARNESS-TOOLS)*

> **STATUS: written — front-door complete, LIVE on the served 12B.** The agent-harness layer of KEYSTONE
> (ledger **X-HARNESS-TOOLS**): the daemon emits only plain text, yet the served Gemma-4-12B calls tools and
> runs sandboxed Python — because the harness makes a *text protocol* the tool channel.

> **Front-door (2026-06-25):** No native tool API, no constrained decoding, no JSON-mode. The model emits
> `<tool name="…">{json}</tool>` in its ordinary output; the harness parses it, runs the tool, feeds the
> result back, and loops. Tools without a tool API.

## The claim this paper makes

On a **text-only** backend, the harness ([shannon-prime-harness](https://github.com/nihilistau/the-clockwork-dark),
CosySim's runtime re-hosted on sp-daemon, lmstudio stripped) gives the served 12B tools as a text protocol:

- **The seam** — `InferenceConfig.to_sp_chat()` → `SPDaemonClient` → `POST /v1/chat` (SSE).
  **G-HARNESS-DAEMON-E2E (H1):** live tokens off the daemon ("capital of France" → **"Paris"**).
- **The protocol** — the model emits `<tool name="X">{json}</tool>`; `run_with_tools` parses (`_TOOL_RE`) +
  executes + feeds back (ReAct); `ToolSpec.from_callable` derives the schema from a Python signature;
  `@skill` bridges to tools. **G-HARNESS-TOOLCALL-E2E (H2):** `calculate("47 * 89")` → **4183**;
  `run_python("print(sum(range(1,101)))")` → **5050**.
- **The honest negative** — multi-line *indented* code in a JSON string is unreliable (indentation collapse →
  `IndentationError`); one-liners are clean — and the model **saw its own stderr and retried** (the feedback
  loop works).

The thesis: a plain text generator becomes a tool-using agent **without** a structured tool API — the
protocol *is* the channel.

## What's in it (the map)

1. **No native channel, so make the protocol the channel** — why text-in/text-out, and what "ephemeral" means.
2. **The harness** — CosySim's runtime re-hosted on the daemon (lmstudio stripped); the one inference seam.
3. **`run_with_tools`** — the ReAct loop in plain text; `_TOOL_RE`, `ToolSpec.from_callable`, the preamble.
4. **The honest negative** — indented code in JSON is unreliable; the feedback loop held anyway.
5. **Why a text protocol is the right call** — auditable forward, host-side agency, composes with memory tools.

## Honest scope

Proof-of-mechanism: one model (12B-b1), one host (RTX 2060), two tools (`calculate`, `run_python`). The
protocol has a characterized edge (multi-line indented code; fix scoped, not built). Grounding needs a
verbatim-use prompt patch (the model confabulates a tool result otherwise). The sandbox is a 10-s-timeout
subprocess. Host-side; no native tool channel, no frozen-ABI / `.sp-model` change.

## Status

**Front-door written/complete — LIVE** — citable via ledger **X-HARNESS-TOOLS**. Receipts harness
`tests/G-HARNESS-TOOLCALL-E2E.log` (+ H1 `g_daemon_e2e.py`); commits `a292f62` (re-hosted skeleton) /
`cd4d935` (daemon seam, H1) / `438738c` (live tool calling, H2). Lives in `harness/mcp/tools.py` +
`harness/inference/`. Lattice `papers/PPT-LAT-KEYSTONE.md` §4 + memory `project_harness_toolcalling`.
Companions: **25** (the memory operations that become tools), **27** (the between-turn loop + heartbeat that
drive it), 24 (recall as a tool), 19–21 (the byte-exact text-only forward it rides).
