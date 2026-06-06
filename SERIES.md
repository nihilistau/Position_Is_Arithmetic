# Shannon-Prime — release series (the staggering frame)

The campaign is a **series of short, receipts-first papers**, each independently citable, each sharing one ledger and one discipline. This file is the control surface: the layout, the manifest, and the rule for slotting a new release in.

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
```

**To slot a release in:** drop its `papers/NN-*/` folder (self-contained — paper, its receipts, its repro), flip its row in the manifest below to `released`, surface it on the landing index, tag the repo. Nothing else moves. That's the whole point of the module shape.

## Manifest (the staggering control)

| # | Paper | Front-door receipt | Status | Target |
|---|---|---|---|---|
| 01 | Two-ring memory: query-directed recall + byte-addressable KV offload | 32k needle off NVMe, 910× resident-cache shrink, 8× sparsification at +0.69% PPL | **draft complete** (pending R9 figures) | release first |
| 02 | The reducing loader: output-preserving transcode + zero-copy swivel | a model transcoded to a *smaller* artifact that loads zero-copy and runs bit-faithfully | **staged, repro green** (6/6 E_FMT gates; 1,439→720 MB @50%, bit-faithful on gemma-3 + qwen3 — see [EXPECTED.md](papers/02-reducing-loader/repro/EXPECTED.md)) | +2–4 wks after 01 |
| 03 | Frobenius calibration-free quantization | fp8 without QAT, ~zero PPL delta (verify numbers first) | candidate | after 02, if it re-gates clean |
| 04 | The Oracle & the Teacher: oracle-grounded backend verification | 35-layer variable-geometry GPU port matched at **KL 2.663e-10** (argmax 12/12); decode teacher-forced exact; both live runs first-try, 38/38 | **staged** (gated in engine; repro pending) | after 03; pairs with 05 |
| 05 | The Probe Suite: bisection, isolation & benchmark hygiene as one set | the suite caught a 12.65× phantom, a 2.8e-3 wrong-arithmetic, a 0/256 K-quant-mix bug, a ×25 norm amplification — then landed the port first-try | **staged** (every tool live in engine; repro pending) | with/just after 04 (methodology pair) |
| 06 | Computing on the Zip File: the dp4a bandwidth ladder | isolated, clocks pinned: **f32 1× (290 GB/s bus-saturated) → int8 ~3.8× → Q4 ~7.06×**, top-1 lossless | **staged** (gated in engine; headline = the 12B tok/s from ETA.5b before release) | after the ETA.5b shootout |
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
