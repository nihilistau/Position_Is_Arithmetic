# A parameter-free neocortex: VSA/HRR Ring-3 consolidation

*Shannon-Prime release series, paper 14. Discipline: [METHODOLOGY.md](../../METHODOLOGY.md).
Every number below is a row in [LEDGER.md](../../LEDGER.md) with a command behind it.*

> **Front-door receipt (measured + gated 2026-06-17, ledger X-R3VSA).** Ring-2 is
> the verbatim hippocampus — bit-exact recall, O(1) evict/rewind. Ring-3 is the
> neocortical gist tier above it: superpose many episodes into one bounded store and
> recall them by content address — built from **discrete mathematics (NTT circular
> convolution), with zero training**. It honors the convicted P2.b verdict
> (generative gist-fill is dead; top-5 shortlisting is the door) by being a
> **retrieve-and-verify** pipe: Ring-3 produces a lossy *shortlist*, Ring-2's exact
> verify carries the fidelity. Four gates, all GREEN, all no-budget: `G-R3-BIND`
> (superposition recall@1 = 1.0 to N=32 @ D=1024; ±1 substrate carrier ≈ ideal
> unitary), `G-R3-LOSS` (consolidation loss is a **step function** — hit lossless
> +0.000% / miss +8.04%, caught by the 2% gate), `G-R3-DUALROUTE` (the
> cue→shortlist→verify→land pipe survives a decoy scan), and `G-R3-NIGHTSHIFT` (idle
> consolidation: 349.8 MB resident KV → a 16.3 KB Ring-3 index).

## 1. The first lossy tier, so the first irreversible gate

Ring-2 (papers 11–13) is the verbatim hippocampus: every recall is bit-exact, every
evict and rewind is O(1) and reversible. Ring-3 is the neocortical gist — the tier
where many episodes are *superposed* into one bounded store and recalled by content
address with graceful, bounded loss. It is the crossbar's first *lossy* tier, which
makes it the first one whose gate is **irreversible**: once a raw episode is consolidated
and its source evicted, a bad consolidation cannot be rewound. The discipline that
follows is non-negotiable, and it is the spine of this paper.

**The §4 trap.** Consolidation is *consolidation-time only*. A Ring-3 gist is written
during the idle loop and read back as native context. **Recall-time gist *upsampling*
is forbidden** — the model must never hallucinate detail back out of a gist at read
time, because that manufactures confident false history. Ring-3 returns either the
gist as-is (a shortlist address) or a pointer that triggers a Ring-2 *verbatim*
retrieve. It never reconstructs the raw span generatively.

## 2. Retrieve-and-verify, not generate-fill — the P2.b verdict honored

Paper 14 inherits a closed-as-convicted result: span→k=2 *generation* is dead (six
forks all convicted), but *recognition* is real-but-sub-usable — the best fork hit
top-1 0.462 (below a 0.50 pass) yet **top-5 = 0.77**: a shortlister, not a sniper.
That verdict is load-bearing here. Ring-3 is a **two-stage retrieve-and-verify**,
exactly the door the top-5 number opened:

1. **RETRIEVE (Ring-3, lossy):** content-address the gist store with the live cue →
   a *shortlist* of candidate episode-ids (not a single answer, never a reconstructed
   span).
2. **VERIFY (Ring-2, exact):** the curator resolves each shortlisted id to its
   verbatim episode and gates it with the already-closed machinery — replay-inject
   (paper 13) → deflection < 2% (paper 11) → promote, else discard and rewind O(1).

Ring-3 never has to be *right*; it has to be *not-wrong-enough to shortlist*, and
Ring-2's exact verify carries the fidelity. This is the only framing consistent with
the measured P2.b numbers, and it keeps the §1 trap shut: the shortlist is a set of
*pointers*, never a generated span.

## 3. The mechanism: holographic binding on the existing substrate

The store is a single superposition vector `M = Σ_i (addr_i ⊛ id_i)`, where `⊛` is
circular convolution — the engine's NTT-over-`Z_q` algebra. Each episode contributes
an `(address, id)` pair: `addr_i` is a carrier **seeded by episode i's real 256-bit
content signature** (the same signature the paper-12 resolver uses, so a live cue
regenerates the address — Ring-3 is tied to the proven Ring-2 resolver, not a new
namespace), and `id_i` is a clean ±1 label that is a *pointer back to the verbatim
Ring-2 episode* for the exact verify (never a reconstructed span — the §1 trap stays
shut). Recall is an unbind: `id_est = M ⊛ addr_j†` followed by a cleanup argmax over
the id codebook.

The headline property: **this requires no training and no parameters.** It is the
existing discrete NTT/CRT substrate used as a holographic memory — Shannon-Prime fit
exactly: discrete `Z_q`, exact bind, lossy-by-design superposition, auditable. It
tests the *whole* Ring-3 thesis (superpose → content-address → shortlist → verify)
for the cost of compute, so the operator's training-budget decision is deferred until
there is evidence it is needed, not spent up front. The learned-adapter path stays
budget-gated and untouched.

## 4. G-R3-BIND: the superposition holds on real episodes

**G-R3-BIND** (`tools/ring3/g_r3_bind.py`, Path A, offline, parameter-free). Bind the
real Ring-2 episode tensors into one store and unbind each.

| metric | result |
|---|---|
| **N=2 (the two real proven episodes)** | recall@1 = 1.0; margins **+0.586 / +0.568** (correct id strictly above crosstalk) |
| capacity sweep (±1 carrier, D=1024) | recall@5 ≥ 0.90 to **N=64**; graceful degrade past ~D (N=128 → 0.87, N=256 → 0.45) |
| substrate cost | the ±1 Rademacher carrier tracks the ideal unitary carrier closely — recall curves ≈ identical |

That last row matters: the cheap discrete ±1 carrier (native to the substrate) is
*not* paying a quality tax versus the textbook unitary HRR carrier.

**A metric bug caught, not a math failure.** The first cut defined `SNR =
cos(correct)/max cos(wrong)`, which at N=2 divides by a near-zero/negative wrong-id
cosine (random ids are near-orthogonal) → a sign-flipped artifact (−91) *despite*
recall@1 being perfect. We replaced it with the cleanup-standard **margin**
(`correct − max wrong > 0`) plus a z-score; recall was always correct. The math never
failed — the metric did — and it is recorded because the gate caught it.

## 5. G-R3-LOSS: consolidation loss is a step function

The pre-registered consolidation gate (`G-R3-LOSS`) had to be re-derived before
running, because the locked retrieve-and-verify design stores a *pointer*, not a lossy
gist — a correct recall fetches the **verbatim** Ring-2 tensor, so hit fidelity is 0
*by construction*. The directive's naive "gist-PPL vs verbatim-PPL" delta would read ~0
(trivial) or require the convicted lossy-gist path. So the gate decomposes into real
axes, all measured (12B-b1):

| axis | result |
|---|---|
| **hit fidelity** (correct id → verbatim episode) | PPL 4.6665 == baseline → **+0.000% — lossless verify** |
| **capacity miss** (wrong id → foreign episode) | PPL 5.0417 → **+8.04%** — i.e. **>> the 2% gate ⇒ flagged + O(1)-rewound, never silent corruption** |
| **promotion budget** (from the bind curve @ D=1024) | recall@1 = 1.0 to **N=32** → **consolidate ≤ 32 episodes per Ring-3 vector** for lossless recall; beyond, misses are gate-caught |
| **latency shear** | unbind + cleanup **71 µs** (negligible) + one Optane read (the existing Ring-2 backend); inject/score unchanged |

The thermodynamic answer: recoverable-information loss is **binary** — a correct unbind
costs *zero* fidelity (the verify re-injects exact bytes), a wrong unbind (capacity
overflow) loses the fact but is *caught by the deflection gate*. The loss is
degrade-safe, not corrupting; the governing quantity is `recall@1(N)`, and the budget
is the math.

## 6. G-R3-DUALROUTE and G-R3-NIGHTSHIFT: the loop, and the GC

**G-R3-DUALROUTE** (`tools/ring3/g_r3_dualroute.py`). The full continuous pipe, composed
from individually-metal-proven stages — RETRIEVE = VSA unbind → top-K shortlist;
VERIFY = the paper-13 / G-R3-LOSS gate; LAND/UNDO = replay + O(1) rewind:

| pipe | trace | verdict |
|---|---|---|
| **(a) clean hit** | cue → shortlist top-1 = correct → verify +0.000% → ACCEPT | scan_len=1, PASS |
| **(b) decoy scan** | adversarial shortlist [foreign, correct] → rank-1 +8.04% REJECT+rewind → rank-2 +0.000% ACCEPT | scan_len=2, PASS — the top-K door: survives a wrong candidate, still lands the fact |
| **(c) null parity** | empty Ring-3 → empty shortlist → NULL → no inject → baseline byte-exact | PASS, scan O(1) |

The pipe takes a raw cue, survives the VSA unbind, scans the shortlist (rejecting and
O(1)-rewinding foreign candidates), and lands the correct *verbatim* memory —
degrade-safe throughout.

**G-R3-NIGHTSHIFT** (`tools/ring3/g_r3_nightshift.py`). The idle-loop consolidation
state machine: SELECT a resident Ring-2 episode → BIND it into the active vector (in a
shadow copy) → SHADOW-GATE (re-verify that *every* bound episode still recalls@1 above
margin — crosstalk-safe, not just the new one) → PROMOTE + EVICT (free the resident
slot; the verbatim tensor *stays on Optane* — a tier-demotion, not a delete) →
SATURATE & SEAL (gate-driven; the budget as a safety cap) → start a fresh vector.

| run | result |
|---|---|
| **D=1024, CAP=32 (production)** | 40 episodes → vector #1 seals at the cap (32), vector #2 carries 8; all recall@1 GREEN; resident pool 40→0; **349.8 MB resident KV demoted to Optane, Ring-3 resident index 16.3 KB** |
| **D=128 (small)** | the shadow-gate fires *before* the cap — seals at max-15 < 32, **proving the seal is the capacity math, not a hardcoded constant**; all recall@1 GREEN |

The thermodynamic garbage-collector works: episodes move from the expensive resident
pool into the dense superposed index (O(1)-per-vector resident footprint) before
capacity runs out, the eviction is degrade-safe (the gate guards reachability *before*
the slot is freed, and the verbatim survives on Optane), and the seal is the math. The
D=128 run is the proof that the cap is derived, not assumed: when the dimensionality
shrinks, the seal moves with it.

## 7. Honest scope

- **The VSA retrieve is host-numpy.** The bind/unbind is proven in the real domain via
  FFT circular convolution (= the NTT algebra); the **`Z_q`/NTT engine port** (exact
  integer, no float drift) is the named deployment follow-on. This paper proves the
  *mechanism and capacity*, not the on-engine integer implementation.
- **Path B stays budget-gated and untouched.** The trained-adapter gist path is opened
  only if a future need shows the parameter-free shortlist insufficient, and only
  behind the operator's explicit budget green. Everything here (R3.0–R3.4) is
  compute-only, zero training budget.
- **One model, one host.** Gemma-4-12B (the B1 / OK_Q4B artifact of paper 06), RTX 2060
  12 GB. Proof-of-mechanism, not a scaling study, not multi-model, not independently
  reproduced.
- **The deflection numbers carry paper 11's caveat** (single-chunk, deterministic; the
  larger-N run is the hardening lever).
- **The provenance tag (`G-R3-PROV`) is deferred** — a post-R3 refinement, never
  bundled into the first run.

## 8. Reproduction

Every number above is a row in [`LEDGER.md`](../../LEDGER.md) with model, fixture, flags,
gate, and commit attached. Gates run from the engine repo
([shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)),
`tools/ring3/{g_r3_bind,g_r3_dualroute,g_r3_nightshift}.py` + `_run_g_r3_loss.bat`;
`gemma4_decode_cuda` is left byte-untouched.

| Gate | Driver | Expected | Receipt log |
|---|---|---|---|
| G-R3-BIND | `tools/ring3/g_r3_bind.py` | recall@1=1.0 N=2 margins +0.586/+0.568; recall@5≥0.90 to N=64 @D=1024 | `tests/fixtures/xbar_r3/G-R3-BIND.log` |
| G-R3-LOSS | `_run_g_r3_loss.bat` | hit +0.000% (4.6665); miss +8.04% (5.0417) caught by 2% gate; budget ≤32/vector; 71 µs unbind | `tests/fixtures/xbar_r3/G-R3-LOSS.log` |
| G-R3-DUALROUTE | `tools/ring3/g_r3_dualroute.py` | (a) clean hit scan_len=1; (b) decoy scan rejects rank-1 +8.04%, accepts rank-2 +0.000%; (c) empty-index null parity | `tests/fixtures/xbar_r3/G-R3-DUALROUTE.log` |
| G-R3-NIGHTSHIFT | `tools/ring3/g_r3_nightshift.py` | (A) D=1024 seals at CAP=32, 349.8 MB→16.3 KB; (B) D=128 seals before cap (seal=math) | `tests/fixtures/xbar_r3/G-R3-NIGHTSHIFT.log` |

**Commit hashes.** Engine: `23539b7` (R3.1 G-R3-BIND), `aae3131` (R3.2 G-R3-LOSS),
`69638cf` (R3.3 G-R3-DUALROUTE), `a64a916` (R3.4 G-R3-NIGHTSHIFT — Ring-3 Path A closed
end-to-end). Architecture and pre-registered gates: lattice
`papers/CONTRACT-XBAR-R3-consolidation.md` (§1 the §4 trap, §3 the Path A/B budget fork,
§4 gates, §5.1 run-records).

## Receipts

| Row | Receipt |
|---|---|
| X-R3VSA | Ring-3 Path A (VSA/HRR, NTT circular convolution, parameter-free, zero training) closed end-to-end. `G-R3-BIND`: superposition recall@1=1.0 to N=32 @ D=1024 (N=2 margins +0.586/+0.568, recall@5≥0.90 to N=64), ±1 carrier ≈ ideal unitary. `G-R3-LOSS`: step-function loss — hit (verbatim verify) +0.000% / miss +8.04% caught by the 2% gate; budget ≤32 episodes/vector; 71 µs unbind + 1 Optane read. `G-R3-DUALROUTE`: cue→shortlist→verify→land survives a decoy scan (reject rank-1 +8.04%/rewind, accept rank-2 +0.000%) + null parity. `G-R3-NIGHTSHIFT`: idle consolidation 349.8 MB resident KV → 16.3 KB Ring-3 index; D=128 gate-driven seal proves the cap is the math. 12B-b1, RTX 2060 12 GB. Scope: VSA host-numpy, the `Z_q`/NTT engine port deferred; Path B (trained adapter) budget-gated, untouched |

Companions: paper 12 / X-C2 (the Ring-2 verbatim curator this gist tier sits above),
paper 13 / X-222 (the replay + O(1) rewind the dual-route verify scans with), paper
11 / X-R3 (the replay-write seam and <2% deflection bound), paper 10 (the
bit-exact-or-bounded methodology and the irreversible-gate discipline).
