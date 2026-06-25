---
type: paper-bite
title: "Ephemeral tool calling: a text protocol that turns a text-only backend into a tool-using agent"
description: "Shannon-Prime release series, paper 26."
tags: [paper-bite, harness, tools, react, python]
timestamp: 2026-06-25T00:00:00Z
resource: ./papers/26-ephemeral-tool-calling/paper.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# Ephemeral tool calling: a text protocol that turns a text-only backend into a tool-using agent

*Shannon-Prime release series, paper 26. Discipline: [METHODOLOGY.md](../../METHODOLOGY.md).
Every number below is a row in [LEDGER.md](../../LEDGER.md) with a command behind it.*

> **Front-door receipt (2026-06-25, ledger X-HARNESS-TOOLS).** The Shannon-Prime daemon emits **plain
> text** — there is no native tool channel, no function-calling API, no structured-output mode. The harness
> gives the served Gemma-4-12B tools anyway, as a *text protocol*: the model emits `<tool
> name="…">{json}</tool>` in its ordinary output, `run_with_tools` parses it, executes the tool, feeds the
> result back, and loops — a ReAct loop with no special inference path. **G-HARNESS-DAEMON-E2E** (H1): the
> harness streams live tokens off the daemon through one seam ("capital of France" → **"Paris"**).
> **G-HARNESS-TOOLCALL-E2E** (H2): live on the metal, `<tool name="calculate">{"expression":"47 * 89"}</tool>`
> → **4183**; `<tool name="run_python">{"code":"print(sum(range(1,101)))"}</tool>` → **5050**. Honest
> negative: multi-line *indented* code inside a JSON string is unreliable (indentation collapses); one-liners
> are clean — and the model **saw its own stderr and retried**, so the feedback loop works.

## 1. No native channel, so make the protocol the channel

Most tool-calling stacks assume the inference server speaks a structured tool dialect — an OpenAI-style
`tool_calls` array, a constrained-decoding grammar, a JSON-mode flag. The Shannon-Prime daemon (paper's
KEYSTONE §3) speaks none of these. It is a byte-exact decode loop that emits **text** over SSE, one
`{delta}` at a time, and nothing else. That is by design — the whole organism's auditability rests on the
forward being a plain, deterministic text generator, not a special-cased structured sampler.

So the harness does not ask the backend for a tool channel. It makes a **text protocol** the channel:

> The model emits `<tool name="X">{json-args}</tool>` *in its ordinary output*. The harness watches the
> stream for that token shape, parses out the name and JSON arguments, runs the tool, and feeds the result
> back into the conversation as the next turn. Then it generates again. The loop continues until the model
> stops emitting tool calls and produces a final answer. **Tools without a tool API.**

This is "ephemeral" in two senses. The tool *call* is ephemeral — a transient piece of text in the stream,
not a persisted structure. And the binding is ephemeral — a tool is just a Python callable wrapped at call
time; there is no registration handshake with the server, no schema the server has to understand. The
backend stays a pure text generator; all the agency lives in the harness, host-side.

## 2. The harness: CosySim's runtime, re-hosted on the daemon

The harness ([shannon-prime-harness](https://github.com/nihilistau/the-clockwork-dark)) is CosySim's agent
runtime — its MCP framework, skill decorators, interceptor pipeline, and SSE streaming — **re-hosted on the
Shannon-Prime daemon.** The original lmstudio coupling was stripped entirely; the runtime now talks to
sp-daemon's `POST /v1/chat`. The operator's call was *build on* the clean skeleton, not rebuild — and the
"messed-up OKFS" worry that preceded it turned out to be a phantom (a CRLF-churn artifact of editing the
repo through a Linux mount; native Windows git showed a clean tree — a binding lesson banked: **do git ops
on these repos via native PowerShell, never the mount**).

The inference seam is one method: `InferenceConfig.to_sp_chat()` builds the `/v1/chat` request body, and
`SPDaemonClient` (`harness/inference/`) streams it. **G-HARNESS-DAEMON-E2E (H1)** is the seam proven end to
end: the client health-checks the live daemon (:3000), `to_sp_chat` produces the correct body, and a real
generation streams through ("capital of France" → coherent **"Paris"**). One seam, real tokens, no
lmstudio. Everything in this paper rides that seam.

## 3. `run_with_tools`: the ReAct loop in plain text

The ephemeral tool calling lives in `harness/mcp/tools.py`:

- **`_TOOL_RE`** is the parser — a regex that recognizes `<tool name="X">{json}</tool>` in the model's text
  stream and extracts the name and the JSON argument blob.
- **`ToolSpec.from_callable`** derives a tool schema *from a Python function signature* — parameter names,
  types, and the docstring become the schema the model is shown, with no hand-written JSON-Schema. A tool is
  just a callable.
- **`ToolRegistry.load_from_skills`** bridges the harness's `@skill`-decorated functions to tools, so a skill
  and a tool are the same object viewed two ways.
- **`run_with_tools(messages, tools)`** is the loop: generate → parse for a `<tool …>` call → execute it →
  append the result to the conversation → generate again, until the model emits a final answer with no tool
  call. The classic **ReAct** loop, but the "act" is a regex match on plain text and the "observation" is a
  tool result fed back as a turn.

A small but load-bearing piece is the **tool preamble** (`_tool_preamble`), the system text that tells the
model the protocol and the available tools. It had to be strengthened so the model emits the *tool call*
instead of narrating a Markdown code fence — the first version caught the model writing "here's the Python
I'd run: ```…```" instead of emitting `<tool name="run_python">…</tool>`. The preamble now states the
protocol explicitly: emit the tool tag, not prose, not a fenced block.

**G-HARNESS-TOOLCALL-E2E (H2)**, live on the served 12B, with two tools registered via
`ToolSpec.from_callable`:

- `calculate(expr)` — a safe-eval arithmetic tool. The model emits
  `<tool name="calculate">{"expression":"47 * 89"}</tool>` → the harness computes **4183** → the model's
  final answer is **"4183."**
- `run_python(code)` — a sandboxed subprocess (10-second timeout). The model emits
  `<tool name="run_python">{"code":"print(sum(range(1,101)))"}</tool>` → the sandbox runs it → **5050**.

The model *chooses* the tool, *formats* the call, *reads* the result, and *answers*. No native tool API was
involved at any point; it is all text in and text out, with the harness as the interpreter.

## 4. The honest negative: indented code in JSON is unreliable

The unflattering result, kept on the front door because it is exactly the kind the gates exist to surface:

> **Multi-line, *indented* code inside a JSON string is unreliable.** A Fibonacci attempt collapsed its
> indentation passing through the JSON argument and produced an `IndentationError`. One-liners
> (`print(sum(range(1,101)))`) are clean; a multi-line function body with `for`/`if` blocks is not.

The cause is the seam between two formats: Python is whitespace-significant, JSON strings are not
whitespace-preserving the way the model emits them, and the model's own formatting of nested indentation
inside a quoted string is lossy. It is a real limitation of carrying *code* through a *JSON-in-text*
protocol — not a model failure, a protocol mismatch.

But the *loop* held, and that is the finding under the finding:

> **The model saw its own stderr and retried.** When the sandbox returned an `IndentationError`, that error
> was fed back as the tool observation, and the model adjusted on the next turn. The ReAct feedback loop —
> the thing the whole text-protocol design exists to make possible — **worked**: the agent reacted to a real
> execution result, not a hallucinated one.

The follow-up levers (not yet built) are mechanical: pass code as a **line-list** argument (one array
element per source line, so indentation survives the JSON round-trip) or use a **non-JSON delimiter** for the
code body. The negative is the protocol's edge, cleanly characterized, with the fix scoped.

## 5. Why a text protocol is the right call here

It would have been possible to add a native tool channel to the daemon — a structured sampler, a
constrained-decoding grammar. We deliberately did not, and the reasons are the project's:

- **The forward stays auditable.** The daemon remains a plain byte-exact text generator (paper 19–21's
  whole point). A tool call is text the model wrote, visible in the transcript, not a hidden structured
  side-channel. The audit trail is the conversation itself.
- **The agency stays host-side.** Tools are Python callables wrapped at call time (`ToolSpec.from_callable`);
  there is no server-side registration, no `.sp-model` change, no frozen-ABI change. The same property that
  lets the memory agency (paper 25) live host-side lets tools live host-side.
- **It composes.** Because tools are ordinary callables and skills *are* tools, the memory operations
  (`list_memories` / `remember` / `forget`, paper 27's memory-as-tools) drop into the same `run_with_tools`
  loop with no new machinery — which is precisely what the between-turn agency loop (paper 27) then drives.

The recurring lesson the campaign keeps re-learning shows up here too: **the model leans on its parametric
prior over grounding.** In the memory-tools follow-on (H3, paper 27) the model first *confabulated* —
substituting a generic "User/blue/pizza" for the real tool result — until a verbatim-use rule ("base your
answer ONLY on the tool result, quote the EXACT values, never invent or substitute") tamed it. Same family
as the DECIDE detection-not-decision lesson (paper 25) and the EOT-bias fix: when the model has a tool
result *and* a parametric guess, you have to point it explicitly at the grounding.

## 6. Honest scope

- **Proof-of-mechanism.** Single host (RTX 2060), single model (Gemma-4-12B B1 / OK_Q4B, paper 06), two
  tools (`calculate`, `run_python`). Not a tool-breadth study, not multi-model.
- **The protocol has a characterized edge.** Multi-line indented code in a JSON string is unreliable (§4);
  one-liners are clean. The fix (line-list / non-JSON delimiter) is scoped, not built.
- **Grounding needs a prompt patch.** The model confabulates a tool result without a verbatim-use rule
  (§5); the rule is a patch, not a structural guarantee.
- **The sandbox is a subprocess.** `run_python` is a 10-second-timeout subprocess, a pragmatic sandbox, not
  a hardened isolation boundary.
- **Host-side, no frozen change.** All of it is the harness (Python) over the daemon's `POST /v1/chat`; **no
  native tool channel, no frozen-ABI change, no `.sp-model` change.**

## 7. Reproduction

Every number above is a row in [`LEDGER.md`](../../LEDGER.md) (`X-HARNESS-TOOLS`: H1 / H2) with model,
fixture, and commit attached. The harness is
[shannon-prime-harness](https://github.com/nihilistau/the-clockwork-dark); the tests run on the Windows host
(reaching the daemon at :3000), launched detached and polled from a log.

| Gate | Driver | Expected | Receipt log |
|---|---|---|---|
| G-HARNESS-DAEMON-E2E (H1) | `tests/g_daemon_e2e.py` (`SPDaemonClient` → live daemon :3000) | health True; `to_sp_chat` body correct; coherent gen ("capital of France" → **"Paris"**) — the inference seam, real tokens, no lmstudio | (harness `cd4d935`) |
| G-HARNESS-TOOLCALL-E2E (H2) | `tests/g_tool_calling_e2e.py` (two `ToolSpec.from_callable` tools, `run_with_tools`) | `<tool name="calculate">{"expression":"47 * 89"}</tool>` → **4183**; `<tool name="run_python">{"code":"print(sum(range(1,101)))"}</tool>` → **5050**. Honest negative: multi-line indented code → `IndentationError` (model saw stderr + retried = loop works); one-liners clean | `tests/G-HARNESS-TOOLCALL-E2E.log` |

**Commit hashes.** The clean re-hosted skeleton is harness `a292f62` (lmstudio stripped, 10/10 offline
tests); H1 (the daemon seam) is `cd4d935`; H2 (live ephemeral tool calling + the strengthened preamble) is
`438738c`. The ephemeral tool calling lives in `harness/mcp/tools.py` (`run_with_tools`, `_TOOL_RE`,
`ToolSpec.from_callable`, `ToolRegistry.load_from_skills`); the seam is `harness/inference/`
(`InferenceConfig.to_sp_chat`, `SPDaemonClient`). No native tool channel; no frozen-ABI / `.sp-model`
change. Architecture: lattice `papers/PPT-LAT-KEYSTONE.md` §4 (the harness) + memory
`project_harness_toolcalling`.

## Receipts

| Row | Receipt |
|---|---|
| X-HARNESS-DAEMON | The harness drives the served 12B through one inference seam. CosySim's runtime re-hosted on sp-daemon (lmstudio stripped); `InferenceConfig.to_sp_chat()` → `SPDaemonClient` → `POST /v1/chat` (SSE). **G-HARNESS-DAEMON-E2E (H1):** health True, body correct, coherent live gen ("capital of France" → **"Paris"**). Binding lesson: git on these repos via native PowerShell, not the Linux mount (the "messed-up OKFS" was a CRLF-churn phantom). Gemma-4-12B B1, RTX 2060; host-side, no frozen-ABI / `.sp-model` change. **Measured + gated — LIVE.** |
| X-HARNESS-TOOLS | Tool calling + sandboxed Python on a **text-only** backend, via a text protocol. The model emits `<tool name="X">{json}</tool>` in plain output; `run_with_tools` parses (`_TOOL_RE`) + executes + feeds back (ReAct); `ToolSpec.from_callable` derives the schema from a Python signature; `@skill` decorators bridge to tools. **G-HARNESS-TOOLCALL-E2E (H2):** `calculate("47 * 89")` → **4183**; `run_python("print(sum(range(1,101)))")` → **5050**. Strengthened `_tool_preamble` so the model emits the tool tag, not a Markdown fence. **Honest negative:** multi-line *indented* code in a JSON string is unreliable (indentation collapse → `IndentationError`); one-liners clean — and the model **saw its own stderr and retried** (the feedback loop works). No native tool channel needed. **Measured + gated — LIVE.** |

Companions: paper 25 / X-AGENCY (the memory operations that become tools), paper 27 / X-AGENCY-LOOP (the
between-turn loop + heartbeat that drive `run_with_tools` with the memory tools), paper 24 / X-B3-WC (the
recall the model can also reach as a tool), papers 19–21 (the byte-exact text-only forward this protocol
rides — the reason there is no native tool channel to call). The boundary it draws: a plain text generator
becomes a tool-using agent **without** a structured tool API — the protocol *is* the channel, the agency is
host-side, and the forward stays auditable.
