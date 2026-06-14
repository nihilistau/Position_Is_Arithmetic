# KAIROS: a resident 12B daemon that holds NO_OP discipline and cold-evicts at the metal

*Shannon-Prime release series, paper 09. Discipline: [METHODOLOGY.md](../../METHODOLOGY.md).
Every number below is a row in [LEDGER.md](../../LEDGER.md) with a command behind it.*

> **Release status.** The *mechanism* of this paper is measured and gated —
> ledger rows **KAIROS-01**, **KAIROS-02**, and **KAIROS-03** (the §5 wrap-aware
> journaled ring + §6 O(1) telemetry + the `run_kairos_metal` semantic loop), all
> CLOSED. The paper's
> **endurance** claim is a separate, pre-registered gate (`G-KAIROS-1` soak),
> and the **≥24 h unattended run is IN-FLIGHT at the time of writing — no
> verdict.** Per this series' own discipline (no number from a mid-run log),
> the full release of paper 09 is **held on the soak's receipt**. Everything
> below the §7 "Endurance" subsection is the proven mechanism; the soak is
> stated as running and nothing more.

## 1. The missing axis: time

Every other paper in this series is about *space*. The two-ring memory (01) is
where the cache lives; the reducing loader (02) is how small it is; the dp4a
ladder (06) is how fast the bytes move; the latent crossbar (07) is what writes
into it; the O(1) router (08) is how the cache stops growing with context. All
of it answers the question *where does state go*.

A resident agent — a model that runs as a background daemon for days, waking on
each tick of an event stream — needs a second axis the spatial papers do not
supply: *time*. It must be able to **commit** state on a salient event (retain
it, advance) and **rewind** state on an idle one (forget the thought it just
had, return to where it was). And the load-bearing requirement is not the
acting; it is the *not* acting. A useful resident agent must do nothing,
correctly, almost all the time — **disciplined silence**. The cost of a single
wrong intervention in an unattended loop compounds; the cost of doing nothing,
if it is genuinely free, does not.

KAIROS is the time/agency axis built on top of the memory hierarchy of papers
07–08. It is a frozen Gemma-4-12B running as a resident kernel daemon that wakes
each tick, reads one environment event, and replies with exactly `NO_OP` (stay
silent) or `<ACTION>…</ACTION>` (intervene), under a salience policy. The thing
that makes it cheap to run unattended forever is that *forgetting an idle
thought is a single O(1) memory-coordinate operation*: `rewind(Δ)` logically
decrements the decode position, and because each cache slot maps to exactly one
position, the sheared slots are never read again, so the rewind is a **perfect,
byte-exact inverse**. The daemon can "think" on a tick and then perfectly
un-think it.

This paper makes two measured claims and holds one in reserve. The mechanism —
disciplined silence (KAIROS-01) and O(1) byte-exact rewind at the metal
(KAIROS-02) — is gated and CLOSED. The endurance claim — that the loop survives
a ≥24 h unattended soak — is in-flight, and the paper says so plainly.

## 2. The discipline crucible

The gate for silence is a scripted, replayable **event tape** (the §2b fixture
of the KAIROS contract; `tools/sp_daemon/tests/fixtures/kairos/tape_smoke.txt`),
so that "did the daemon hold discipline" is a deterministic diff, not a vibe.
One event per line: `tick_idx  kind  payload  salience  expect`. The smoke tape
is N=3 salient events sparse among M=24 ticks (N≪M) — the regime a real daemon
lives in, mostly idle. `salience` feeds the policy; `expect` (`NOOP` / `ACTION`)
is the gate oracle the false-action and missed-event counters diff against.

The salience policy is deliberately simple and stated in the system contract the
model is prefilled with once: *if salience ≥ 0.5 the event requires
intervention, reply with an `<ACTION>` line; if salience < 0.5, reply `NO_OP`;
follow the rule exactly, do not explain.* The contract and every per-tick event
frame are wrapped in the gemma `<start_of_turn>` chat template and encoded at
runtime through the **parity-validated `.sp-tokenizer`** blob lane
(`sp_tokenizer_load_tokfile` / `encode` / `decode`, the same tokenizer proven
token-for-token in T_G4_TOK_PARITY 5432/5432) — no offline bake, no second
tokenizer to drift against.

**The result (KAIROS-01, `SP_G4_KAIROS`, gemma-4-12B B1, RTX 2060 12 GB).** The
24-tick crucible is *perfect*:

```
DONE ticks=24 noop_ok=21 action_ok=3 false_action=0 missed=0 malformed=0
```

All 21 idle ticks decoded `NO_OP`; all 3 salient ticks decoded a coherent,
context-correct imperative — `start` for a finished build (tick 4, salience
0.80), `clean` for a disk at 95% (tick 12, 0.90), `renew` for an expiring TTL
(tick 20, 0.75); zero false actions on idle, zero missed events, zero malformed
replies. The daemon reads the environment, decides, and — overwhelmingly —
stays silent.

The salience gate is the *policy*; the substrate is what makes the silence
cheap. On the one-shot decoder (`gemma4_decode_cuda`) the silence is realized as
**prefix-grow**: an idle `NO_OP` tick leaves the retained token prefix
unchanged, so the next idle tick re-enters a context byte-identical to the
first; an `ACTION` tick *grows* the prefix (the action is retained as history).
This is what defeats the corruption attractor of §3 — every idle tick starts
from the same clean anchor — but its per-tick cost is O(actions retained),
which §4 replaces with the metal rewind.

## 3. The negative control: capacity, not plumbing

A perfect crucible from a 12B is only meaningful if the *same machinery* can
fail — otherwise the harness might be trivially passing. It can fail, and we
ran it failing on purpose. The KAIROS control plane was first proven on the
cheap, bit-exact qwen3 CPU substrate (Path A, `tools/sp_daemon/src/kairos.rs` +
`kairos_runner.rs`): the loop's nervous system — tape → decide → receipt →
counters, the `SALIENCE≥0.5` mode switch, the cold-evict `NO_OP` prune holding a
flat KV position — is *sound* there. But a **0.6B** model driven through that
identical loop **collapses at the tick-5 crucible**: the first idle tick that
follows a *retained* action false-fires, then degenerates into a deterministic
corruption attractor — the model emitting fixed garbage (`NO_克作`) every tick
thereafter, latency creeping as the poisoned session bloats.

That collapse is the control. It proves the discipline is a property of **model
capacity exercised through correct machinery**, not of the plumbing: same
harness, same tape, same policy, same cold-evict — the 0.6B loses silence and
the 12B holds it perfectly. The tick-5 condition (an idle tick immediately after
a retained action) is the specific thing that breaks the small model and that
the 12B survives 21 times over; it is the reason the crucible tape interleaves
its salient events among idle runs rather than batching them. Both halves are
proven: the mechanism works (0.6B nervous system green), and only the 12B has
the cognitive capacity to ride it.

## 4. Cold-evict at the metal (KAIROS-02)

Prefix-grow holds silence, but its idle-tick cost is **O(actions-so-far)**:
every tick re-absorbs `[system + all retained actions + frame]` through the
forward pass, because the one-shot decoder rebuilds its KV from the token prefix
each call. For a daemon meant to run for days that recompute tax is unbounded.
The true resident kernel must evict at the **tensor-routing layer** — shear the
KV write pointer back on a null tick — so an idle tick costs only `frame +
decode`, independent of how much history has accumulated.

We built that as a separate **persistent-KV ABI** on the gemma-4 CUDA path:

```
sp_g4_kv* gemma4_kv_open(m, Pmax);          /* alloc resident KV (rings+slab), dpos=0 */
int       gemma4_kv_prefill(s, toks, n);    /* append + absorb n; dpos += n */
int       gemma4_kv_decode (s, n_gen, out); /* greedy; appends gen to cache; dpos += k */
int       gemma4_kv_rewind (s, delta);      /* O(1): dpos -= delta; logical truncate */
int       gemma4_kv_commit (s);             /* clear journal, set a new baseline anchor */
int       gemma4_kv_pos    (s);             /* current dpos (the flat-vs-grow witness) */
void      gemma4_kv_snapshot(s, hK, hV);    /* D2H copy for the byte-exact gate */
void      gemma4_kv_close  (s);
```

The discipline that keeps the whole tower standing: **`gemma4_decode_cuda` is
left byte-for-byte untouched.** The persistent-KV ABI is a *twin*, not a
modification of the production decoder. So every previously-closed gate — the
26.1 tok/s @ PPL 5.12 of paper 06 (06-R10), the NIAH retention and O(1) VRAM of
paper 08 (X-R2), the latent-write results of paper 07 (X-R1) — is still valid,
because the path they were measured on was not perturbed. This is the *null
floor*, kernel edition: a new surface added beside the proven one, never on top
of it.

`rewind(Δ)` is a logical decode-position decrement. On the full cache each slot
maps to exactly one position (slot == pos), so once `dpos` is rolled back by Δ,
the sheared slots in `[dpos−Δ, dpos)` are never read by attention again and are
overwritten on the next append — which is precisely why the rewind is a *perfect
inverse* and not an approximation.

**G-1b-REWIND-NULL (`SP_G4_KV_REWIND`, gemma-4-12B B1, RTX 2060, bit-exact).**
Prefill a system prefix (anchor = 24), snapshot the cache; run one idle tick
(prefill a 12-token frame + decode 8); `rewind(20)` back to the anchor; snapshot
again. The `[0, anchor)` KV region is **byte-identical across all 48 owner
layers (16.5 MB compared, diffs = 0)**. Plus **EQUIV**: re-running the same idle
tick after the rewind reproduces the *identical* generated tokens — the rewound
cache is a flawless re-entry point, "as if the tick never happened." Receipt:

```
[g4-kvrw] anchor=24 after_tick=44 cmp=16515072B owners=48
[g4-kvrw] REWIND-NULL: GREEN (layer-diffs=0) | EQUIV gen-reproduce: GREEN [507 638 510 258882 ...]
```

For a memory operation that will run tens of thousands of times unattended,
"close enough" is the wrong gate — any non-zero drift compounds over a long run.
Byte-exact is the only standard that cannot silently rot, which is why the gate
is byte-exact and not a tolerance.

## 5. The wrap-aware journaled ring (KAI-1c): uniting O(1)-time with O(1)-space

KAIROS-02's rewind is exact on the *full* cache (slot == pos). But paper 08's
O(1)-**space** win comes from putting the dominant 40-of-48 sliding-window (SWA)
layers on a **W-slot ring** (write slot = `pos % W`). On a ring, `rewind` is
*not* a clean pointer decrement, and the hazard is worth naming precisely: an
idle tick advancing `[anchor, anchor+k)` writes ring slots that previously held
*still-live* window positions; a naive `dpos −= Δ` then leaves those slots
holding **future** K/V. The "sheared slots are never read" invariant that makes
the full-cache rewind exact *fails* on the ring, because the tick's writes alias
onto live-window slots. O(1)-time and O(1)-space were proven separately; the
edge daemon needs them at once.

The fix is an **undo-journal**. Before the ring overwrites a slot, the slot's
current K/V is copied into a per-tick journal keyed by `(L, slot)`; `rewind`
replays the journal in reverse to restore each clobbered slot to its pre-tick
contents; `commit` (on a retained action) clears the journal and sets a new
baseline a rewind may not cross. The journal size is bounded by `min(k, W)` per
SWA owner per tick — `k` is `frame + decode` tokens — so it is **constant per
tick, independent of retained-action count A**, preserving O(1) in *both* time
and space. (The 8 global layers attend all positions, have no window and no
ring, and keep their full-cache rewind from §4.)

**G-1b-WRAP-NULL (`SP_G4_KV_WRAP`, W=16, gemma-4-12B B1, RTX 2060, bit-exact +
non-vacuous).** Prefill 50 tokens to wrap the W=16 ring three times, commit,
snapshot the ring; run an idle tick whose 20-token span crosses a wrap boundary
(`anchor%W = 2`, so the slot index wraps 15→0); issue the wrap-crossing
`rewind(20)`; snapshot again. The tick **clobbered live-window slots in all 40
SWA owners** — the non-vacuity proof that the journal was actually exercised,
not bypassed — and the post-rewind ring is **byte-identical (diffs = 0)** across
all 40 owner rings, reproducing identical tokens:

```
[g4-wrap] W=16 anchor=50 after=70 wraps_crossed=1 (anchor%W=2 tick_span=20) clobbered_owners=40
[g4-wrap] WRAP-NULL: GREEN (swa-ring-diffs=0) | EQUIV gen-reproduce: GREEN [107 236743 107 236743 ...] | non-vacuous: YES
```

The `clobbered_owners=40` line is the load-bearing one: it demonstrates the test
forced the exact aliasing hazard it was built to catch, and the journal was a
perfect inverse across it. With this, the O(1)-time eviction of §4 runs on the
O(1)-space ring of paper 08 — the crossbar substrate is one unified object in
time and space.

## 6. The O(actions) → O(1) telemetry: a slope, not an assertion

The O(1) claim is a *measured curve*, not a word. We sweep the retained-action
count A ∈ {1, 2, 4, 8, 16} and time an idle tick under each, in both modes,
clocks pinned, min-of-3 warm reps (`SP_G4_KV_TELEMETRY`):

| A | prefix-grow (s) | metal (s) | grow / metal |
|---|---|---|---|
| 1 | 2.72 | 0.88 | 3.08× |
| 2 | 3.59 | 0.89 | 4.03× |
| 4 | 5.35 | 0.91 | 5.89× |
| 8 | 8.96 | 0.93 | 9.60× |
| 16 | 16.58 | 0.99 | 16.70× |

The slopes: prefix-grow **0.924 s/action** (the linear recompute tax — each idle
tick re-prefills `system + A·action + frame`); metal **0.0073 s/action — a 127×
shallower slope**, 16.7× faster at A=16. That flatline *is* the O(1) claim. The
recompute tax the crossbar deletes is exactly the area between the two curves.

The journaled ring of §5 preserves it. Re-running the sweep through the
undo-journal path with commit-per-action (`SP_G4_KV_RING_TEL`, A ∈ {8…96}) gives
ring slope **0.00365 s/action ≈ full-cache 0.00371** — both flat, ~270× under
the prefix-grow tax; the journal adds **no asymptotic cost** in retained-action
count.

**The honest measurement caveat.** We wanted the *fine-grained* per-tick journal
overhead (the extra device-to-device save-before-store copies — structurally
`min(k,W)·40·2` per tick, ~1–3% of a ~1 s tick). We could not isolate it on this
card. The RTX 2060 **cannot lock its memory clock** (`nvidia-smi`: "not
supported"), and bandwidth-bound decode jitters ±~12% — which swamps a 1–3%
delta and even produced *physically impossible* negative "taxes" (−137 ms) with
210% coefficient of variation when two sequential wall-clock series were
differenced. The within-leg *slope* (the O(1) claim) survives because it is
computed inside a single leg; the absolute journal tax does not, and we report
it as below the instrument's noise floor rather than report a number we cannot
defend. The exact figure is deferred to CUDA-event instrumentation. The standing
rule this banked: never difference two sequential wall-clock series for sub-10%
deltas on this card.

**The operational unification** (`SP_G4_KAIROS_METAL`). The semantic decision
loop of §2 runs on the journaled-ring ABI directly: open the ring, prefill the
system contract, commit (anchor); per tick prefill the event frame and decode;
**`NO_OP` → `gemma4_kv_rewind(pos−anchor)`** (journaled cold-evict to the
anchor), **`ACTION` → `gemma4_kv_commit`** (retain, advance the anchor).
Position-discipline is itself a gate — an idle tick *must* return `pos` exactly
to the anchor, an action tick *must* advance it, so an off-by-one in the
rewind/commit math fails loudly. The 24-tick crucible on the metal ring is again
perfect:

```
DONE ticks=24 noop_ok=21 action_ok=3 false_action=0 missed=0 malformed=0 pos_violations=0
CRUCIBLE: GREEN (semantic clean + O(1) metal pos-discipline)
```

The three salient ticks committed (anchor 135 → 195 → 258 → 318); every
post-action idle tick reverted cleanly to `NO_OP` via rewind to the new anchor,
`pos` flat, zero drift — the tick-5 condition that broke the 0.6B, now defeated
on the metal ring with the semantic and the byte-exact correctness checked in
one pass.

## 7. Honest scope

- **A scripted tape, not live sensors.** The crucible runs the deterministic
  §2b event tape; wiring real sensors and a real actuator is a follow-on
  (KAI-4), and the actuator here only logs — no real side effects.
- **The idle tick still carries the O(context) attention-read term.** The O(1)
  result is in the *step count*: the metal idle tick is a constant number of
  forward steps (`frame + decode`) regardless of A, where prefix-grow is
  `system + A·action + frame` steps. The per-step attention *read* over the
  resident context is unchanged (a mild rise, 0.88→0.99 s as the resident
  context grew 44→344 in the §6 sweep) — that is the attention term, not
  re-prefill. The elimination is of the *recompute*, measured as the step-count
  slope.
- **One model, one host.** Gemma-4-12B (the B1 / OK_Q4B artifact of paper 06),
  RTX 2060 12 GB, ~8–17 s/tick on the prefix-grow path / ~2.3 s/tick on the
  metal ring, ~10.4 GB resident. Proof-of-mechanism, not a scaling study, not
  multi-model, not independently reproduced.
- **The journaled-ring scope.** The dominant 40 SWA owners move to the journaled
  ring; the 8 globals stay full-cache. A 24-tick faithful run at W=1024 (the
  true SWA window) does not itself wrap the ring (a wrap needs >~50 retained
  actions); wrap-correctness is proven *in isolation* by G-1b-WRAP-NULL (§5,
  clobbered_owners=40, diffs=0) and semantic correctness on the faithful ring
  (§6) — the two are orthogonal and each tested cleanly. Compact-slab globals
  wrap-rewind is a named follow-on.

### Endurance (in progress — no verdict)

The remaining gate is `G-KAIROS-1`'s **soak**: ≥24 h unattended, flat RSS,
complete per-tick receipts. The harness (`SP_G4_KAIROS_SOAK`,
`run_kairos_soak`) loops the deterministic tape with a per-loop re-anchor
(close + reopen ⇒ bounded state), streams two-tier flushed telemetry, and arms
in-process **hard tripwires**: any CUDA error, any false-action or missed event,
any pos-discipline violation, three consecutive malformed replies, a latency
spike (five *consecutive* ticks > 3× the warm median — consecutive precisely to
tolerate the unlockable memory clock's jitter), a VRAM leak (>256 MiB over
baseline), and a thermal limit (>87 °C). A **3-loop smoke passed clean** (72
ticks, `noop_ok=63 action_ok=9 false=0 missed=0 malformed=0 pos_violations=0`,
VERDICT GREEN), which validates the soak machinery itself.

The full **≥24 h run (~36,700 ticks) is executing as this paper is written.**
Per this series' discipline we **do not call a verdict from a mid-run log.**
Three outcomes are all informative: a clean 24 h GREEN, a tripwire abort that
*found* an endurance bug (the tripwires exist to make that loud, not to be
avoided), or a semantic surprise. **This paper's endurance claim — and its full
release — wait on the soak's receipt, not on the in-flight log.** What is
already citable is the mechanism: KAIROS-01 and KAIROS-02, both closed.

## 8. Continuity

KAIROS sits *above* the rings. It composes paper 08's O(1)-**space** SWA ring
(the window that makes the cache flat in context) with an O(1)-**time** rewind
(the pointer shear that makes forgetting free), and runs paper 07's latent
crossbar as the memory it curates. It reuses paper 06's 12B instrument (the only
mathematically-intact 4-bit Gemma-4-12B) and paper 05's bit-exact / null-floor
discipline (the production decoder left untouched, every "on" result a
controlled delta against a byte-identical baseline). Space ⊗ time ⊗ cognition,
on one 12 GB card — with the endurance corner of that claim still under the
soak.

## 9. Reproduction

Every number above is a row in [`LEDGER.md`](../../LEDGER.md) with model,
fixture, flags, gate, and commit attached. All gates run from the engine repo
([shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)),
harness `tests/test_gemma4_cuda.c`, persistent-KV ABI
`src/backends/cuda/cuda_forward.cu` (`gemma4_kv_open / prefill / decode / rewind
/ commit / pos / snapshot / close`, `struct sp_g4_kv` + the per-tick
undo-journal). Built on the CUDA host (`build-cuda-vs22/`, sm_75); GPU core
clock pinned for timing (`nvidia-smi --lock-gpu-clocks=1680`; the 2060 cannot
pin its memory clock).

**Prerequisite artifact.** The 12B `-b1` artifact and its parity-validated
tokenizer (paper 06's B1 / OK_Q4B), plus the deterministic event tape:

```
SP_GEMMA4_SPMODEL = models/gemma4-12b-b1.sp-model
SP_GEMMA4_SPTOK   = models/gemma4-12b-b1.sp-tokenizer
SP_KAIROS_TAPE    = tools/sp_daemon/tests/fixtures/kairos/tape_smoke.txt   (N=3 salient, M=24)
SP_CUDA_DECODE_INT8 = 1   (tied-head int8 decode, required by the kv-* ABI)
```

**The gates, each by its env knob** (`tests/test_gemma4_cuda.c` dispatches on
the variable; the metal/soak gates also take `SP_G4_KV_RING_W=1024`,
`SP_G4_KV_JMAX=160`):

| Gate | Env knob | Driver | Expected line | Receipt log |
|---|---|---|---|---|
| Bit-exact rewind (KAIROS-02) | `SP_G4_KV_REWIND=1` | — | `REWIND-NULL: GREEN (layer-diffs=0) … EQUIV … GREEN` | `results/kai1b_rewind_null_gate.log` |
| Wrap-aware ring rewind (KAI-1c) | `SP_G4_KV_WRAP=1 SP_G4_KV_RING_W=16 SP_G4_KV_JMAX=64` | `_run_kv_wrap.bat` | `clobbered_owners=40 … WRAP-NULL: GREEN (swa-ring-diffs=0) … non-vacuous: YES` | `results/kai1c_wrap_null_gate.log` |
| O(actions)→O(1) telemetry | `SP_G4_KV_TELEMETRY=1` | — | `slope … prefix-grow=0.924 … metal=0.0073 … O(actions) vs O(1) CONFIRMED` | `results/kai1b_oactions_to_o1_telemetry.log` |
| Journaled-ring O(1) telemetry | `SP_G4_KV_RING_TEL=1` | `_run_kv_ring_tel.bat` | `slope … full=0.00371 … ring=0.00365 … T1 flatline … PASS` | `results/kai1c_ring_telemetry.log` |
| Crucible, prefix-grow (KAIROS-01) | `SP_G4_KAIROS=1` | — | `DONE ticks=24 noop_ok=21 action_ok=3 false_action=0 missed=0 malformed=0` | `results/kairos_12b_pathB_crucible.log` |
| Crucible, metal ring (KAI-1c) | `SP_G4_KAIROS_METAL=1` | `_run_kairos_metal.bat` | `DONE … pos_violations=0` / `CRUCIBLE: GREEN` | `results/kai1c_kairos_metal.log` |
| Endurance soak (`G-KAIROS-1`) | `SP_G4_KAIROS_SOAK=1` (`SP_SOAK_HOURS`, `SP_SOAK_MAXLOOPS`) | `_run_kairos_soak.bat` | smoke: `VERDICT: GREEN`; ≥24 h: **in-flight, no verdict** | `results/kairos_soak_smoke.log`; live `results/kairos_soak.log` |

The 3-loop soak smoke is `_run_kairos_soak.bat 0.05 3` (args = HOURS MAXLOOPS);
the full run is `_run_kairos_soak.bat` (defaults to 24 h, unbounded loops).

**Commit hashes.** KAI-1b (metal rewind + telemetry): engine `e06e3ae`
(`gemma4_kv_*` ABI), `0bb94f1` (G-1b-REWIND-NULL + §5.4 telemetry closure).
KAI-1c (wrap-aware ring + semantic metal loop): engine `d90945f` (undo-journal +
G-1b-WRAP-NULL), `f201bf3` (journaled-ring O(1) telemetry, #219), `d0a6717`
(`run_kairos_metal` semantic crucible, #221), `b0d2bf6` (soak harness +
tripwires). Architecture and pre-registered gates: lattice
`papers/CONTRACT-KAIROS-K0-K1.md` §4 (KAI-1 closure), §5.5 (KAI-1b), §5.6–5.7
(KAI-1c wrap), §5.8 (telemetry + semantic loop). Implementation map:
`tools/sp_daemon/docs/KAIROS-API.md`; control plane `tools/sp_daemon/src/
kairos.rs` + `kairos_runner.rs` (Path A, the 0.6B negative control).

The bit-exact gates run in seconds; the crucibles in minutes; the endurance soak
in ≥24 h — and that one's verdict is the receipt this paper releases on.

## Receipts

All claims trace to these ledger rows ([`LEDGER.md`](../../LEDGER.md)); scope
travels with each.

| Row | Receipt |
|---|---|
| KAIROS-01 | 24-tick crucible PERFECT: 21/21 idle→NO_OP, 3/3 salient→coherent ACTION (`start`/`clean`/`renew`), 0 false / 0 missed / 0 malformed / 0 drift; 0.6B negative control collapses into the `NO_克作` corruption attractor (capacity, not plumbing) |
| KAIROS-02 | G-1b-REWIND-NULL: rewound KV byte-identical to never-visited across all 48 owner layers (16.5 MB, diffs=0) + EQUIV gen-reproduce; idle-tick latency slope metal 0.0073 vs prefix-grow 0.924 s/action (127× shallower; 16.7× @ A=16) |

Pre-registered but **not yet released** (held on its receipt): `G-KAIROS-1`
endurance soak (≥24 h unattended, flat RSS, complete receipts) — **IN-FLIGHT, no
verdict.** The 3-loop smoke is GREEN; the full run is executing.

Companions: paper 08 (the O(1)-space SWA ring this loop runs underneath it),
paper 07 (the latent crossbar the resident daemon curates), paper 06 (the 12B
instrument), paper 05 (the bit-exact / null-floor discipline the soak enforces),
paper 10 (the bit-exact-or-bounded methodology).
