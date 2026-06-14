# Shannon-Prime — release series (the staggering frame)

The campaign is a **series of short, receipts-first papers**, each independently citable, each sharing one ledger and one discipline. This file is the control surface: the layout, the manifest, and the rule for slotting a new release in.

**Scope (carried on every number):** proof-of-mechanism on a single dev host (RTX 2060, 12 GB). The **0.6B** model (Qwen3-0.6B) carries the two-ring memory-ladder and control experiments (paper 01); the **12B** (Gemma-3-12B, QAT 4-bit — the B1 artifact) carries the XBAR and KAIROS headline results (papers 06–09). Not scale-validated, not multi-model, not independently reproduced — say exactly that, everywhere.

## Layout (each paper is a self-contained module)

```
shannon-prime/                  public repo / site root
  README.md                     SERIES landing: what SP is + the series index (live + upcoming) + the live paper's front-door receipt
  SERIES.md                     this file — the manifest + release control
  LEDGER.md                     master claims ledger (every paper's receipts, paper-tagged) — single source of truth
  METHODOLOGY.md                shared discipline (gate vocabulary, bit-exact-when-off, "no number without a command") — written once, every paper cites it
  COMPANION-THEORY.md           shared cathedral pointer
  CONTRIBUTING.md  CITATION.cff  LICENSE
  papers/
    01-two-ring-memory/         { README.md  paper.md  receipts.md  repro/ }   <- the module shape
    02-reducing-loader/         { README.md  paper.md  receipts.md  repro/ }
    03-frobenius-quant/         (staged later, same shape)
    04-oracle-teacher/          (staged 2026-06-06 — front-door mapped; verification methodology)
    05-probe-suite/             (staged 2026-06-06 — front-door mapped; the testing-methodology SET)
    06-dp4a-bandwidth-ladder/   (staged 2026-06-06 — front-door mapped; computing on the packed codes)
    07-auditable-latent-crossbar/  (staged 2026-06-14 — front-door mapped; latent KV write, X-R1)
    08-o1-kv-learned-router/       (staged 2026-06-14 — front-door mapped; O(1) KV + learned router, X-R2)
    09-kairos-resident-daemon/     (staged 2026-06-14 — front-door mapped; resident daemon + rewind; release gated on the in-flight soak)
    10-receipts-or-it-didnt-happen/ (staged 2026-06-14 — front-door mapped; the methodology as the contribution)
```

**To slot a release in:** drop its `papers/NN-*/` folder (self-contained — paper, its receipts, its repro), flip its row in the manifest below to `released`, surface it on the landing index, tag the repo. Nothing else moves. That's the whole point of the module shape.

## Manifest (the staggering control)

| # | Paper | Front-door receipt | Status | Target |
|---|---|---|---|---|
| 01 | Two-ring memory: query-directed recall + byte-addressable KV offload | needle off NVMe (512-position, poison-gated, 7.57 µs/read), 910× resident-cache shrink, 8× sparsification at +0.69% PPL | **draft complete** — R9 (32k) **MISSed** 2026-06-06 at the 64× budget; the 32k headline is WITHDRAWN from the front door (honest-negative row stays in the ledger); release on the 512-proven claims | release first |
| 02 | The reducing loader: output-preserving transcode + zero-copy swivel | a model transcoded to a *smaller* artifact that loads zero-copy and runs bit-faithfully | **staged, repro green** (6/6 E_FMT gates; 1,439→720 MB @50%, bit-faithful on gemma-3 + qwen3 — see [EXPECTED.md](papers/02-reducing-loader/repro/EXPECTED.md)) | +2–4 wks after 01 |
| 03 | Frobenius calibration-free quantization | fp8 without QAT, ~zero PPL delta (verify numbers first) | candidate | after 02, if it re-gates clean |
| 04 | The Oracle & the Teacher: oracle-grounded backend verification | 35-layer GPU port matched at **KL 2.663e-10** (argmax 12/12), decode teacher-forced exact, first-try 38/38 — PLUS the case study: the hand-written oracle that measured gemma-4's TRUE PPL at **4.68** and convicted the GGUF ecosystem (192–506) while exonerating llama.cpp's forward (06-R8) | **written** (`paper.md` 2026-06-08; instruments live in lattice `tests/gemma4_gold/`) | with 05/06 (the gemma-4 triptych) |
| 05 | The Probe Suite: bisection, isolation & benchmark hygiene as one set | the suite's kills (12.65× phantom, 2.8e-3, 0/256, ×25 norm, rank-205596 act-quant) PLUS the suite at ecosystem scale: tensor-class swap bisection, cosine forensics, simulate-before-build matching the built artifact to FOUR decimals (06-R9) | **written** (`paper.md` 2026-06-08; instruments live) | with 04/06 |
| 06 | Computing on the Zip File: the dp4a bandwidth ladder | **Gemma-4-12B at 26.1 tok/s AND wikitext PPL 5.12 on an RTX 2060 12GB** (06-R10, 24/24 gates; llama.cpp: 31.29 tok/s at PPL 192–506; SP engine bandwidth +18%) + the isolated ladder (f32 1× → int8 ~3.8× → Q4 ~7.06×) + OK_Q4B + the sovereign supply chain | **complete — gated, citable** (`paper.md` done; 06-R6's 34.2 RETIRED with its quality-failed artifact) | release-ready |
| — | [GEMMA4-QUANT-FIX.md](GEMMA4-QUANT-FIX.md): community tutorial — verify the GGUF breakage + the fix recipe (post text: [GEMMA4-ISSUE-POST.md](Archived/Documents/Revisions/GEMMA4-ISSUE-POST.md)) | gold 4.68 vs GGUFs 192–506; recipe ladder +45%→+9.6% | **written** | post alongside 06 |
| 07 | [The Auditable Latent Crossbar](papers/07-auditable-latent-crossbar/): steering a frozen 12B through its KV cache, no tokens | 12B steered by direct KV-cache transplant: **15/15 incorporation, 15/15 selectivity** (2×2 double dissociation), 3.69 orders max rank pull, self-transplant null **7/7 bit-identical**, gold-instrument coherence (X-R1) | **staged draft** — front-door receipt measured + gated (X-R1); architecture lattice `RFC-XBAR-auditable-latent-crossbar.md` | re-gate + standalone repro before release |
| 08 | [O(1) KV: a context-decoupled cache via a learned router](papers/08-o1-kv-learned-router/) | learned **512×32 LSH** router selects global top-B at **+0.47% PPL @8×** (oracle −0.08%, frozen +4.17%); compact slab → **O(1) VRAM (8k↔16k flat ~50 MiB)**; **NIAH needle survives 10/50/90%**, frozen-router control MISSES (X-R2) | **staged draft** — front-door receipt measured + gated (X-R2) | re-gate + standalone repro before release |
| 09 | [KAIROS: a resident 12B daemon that stays silent and rewinds at the metal](papers/09-kairos-resident-daemon/) | **24-tick crucible perfect** (21/21 NO_OP, 3/3 ACTION, 0 false/0 missed/0 drift; 0.6B control collapses); **O(1) byte-exact rewind** (48 layers diffs=0; metal 0.0073 vs prefix-grow 0.924 s/action, 127×) (KAIROS-01/02) | **staged draft — release HELD on the ≥24 h endurance soak, which is IN-FLIGHT (no verdict from a mid-run log)** | release on the soak receipt |
| 10 | [Receipts or it didn't happen](papers/10-receipts-or-it-didnt-happen/): bit-exact-or-bounded as the contribution | the four self-corrections (34.2 retired by its own PPL rule; 32k MISS kept on the front page; the small-N noise illusion; oracle-ceiling-before-training) | **staged draft** — evidence is the existing ledger + METHODOLOGY | with 07–09 |
| — | multi-device CRT sharding · MTP rollback | — | not yet (no standalone receipt) | when gated |
| — | the algebraic framework (CM elliptic curve) | — | companion only, never a receipts paper | — |

## Release rules (same discipline, pointed at cadence)

1. **Lead with the strongest, ship it complete.** 01 (memory) is the loudest receipt and it's drafted — it goes first, finished, before 02 starts its release clock. One complete paper beats six started.
2. **Stagger 2–4 weeks.** Each release gets its own moment; cross-link back (to released) and forward (to upcoming) so the series compounds attention instead of splitting it.
3. **Every paper carries its own repro before it releases.** 02's headline (a *smaller* artifact, bit-faithful) needs a one-command repro the way 01 has `run_r9`. No release without it.
4. **Re-gate before claiming.** 02 and 03 rest on prior results (C1 transcode, Frobenius fp8) measured in earlier work; re-run their gates and build the repro *before* the paper goes public — same standard as 01, no grandfathering.
5. **The ledger is shared and append-only.** New paper = new rows tagged to it; no number appears anywhere that isn't a ledger row with a command.

## Mapping from the staging drafts

- `PAPER-DRAFT.md` → `papers/01-two-ring-memory/paper.md`
- `CLAIMS-LEDGER.md` → `LEDGER.md` (paper-tag the rows: R1–R9 = `[01]`)
- `repro/` → `papers/01-two-ring-memory/repro/`
- `repo-skeleton/README.md` → split: the series-level intro becomes root `README.md`; paper-01 front-door becomes `papers/01-two-ring-memory/README.md`
