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
    07-auditable-latent-crossbar/  (written 2026-06-14 — paper.md complete; latent KV write, X-R1)
    08-o1-kv-learned-router/       (written 2026-06-14 — paper.md + repro/ complete; O(1) KV + learned router, X-R2)
    09-kairos-resident-daemon/     (written 2026-06-14 — paper.md complete for the mechanism; resident daemon + rewind; release held on the in-flight soak)
    10-receipts-or-it-didnt-happen/ (written 2026-06-14 — paper.md complete; the methodology as the contribution)
    12-memo-curator/               (written 2026-06-17 — paper.md + README complete; autonomous discrete recall, X-C2)
    13-speculate-and-undo/         (written 2026-06-17 — paper.md + README complete; O(1) bit-exact rewind, X-222)
    14-parameter-free-neocortex/   (written 2026-06-17 — paper.md + README complete; VSA/HRR Ring-3 consolidation, X-R3VSA)
    15-the-organism-breathes/      (written 2026-06-17 — paper.md + README complete; real audio → episodic memory, X-ORG)
    16-the-unification/            (written 2026-06-18 — paper.md + README complete; the bind re-carried onto exact-integer O_K, X-OK-BIND)
    17-frobenius-integer-store/    (written 2026-06-18 — paper.md + README complete; integer episode codec + the boundary of the algebra, X-OK-FROB)
    18-organism-on-silicon/        (written 2026-06-18 — paper.md + README complete; the full cross-modal loop on the integer substrate, X-OK-ORG)
    19-killing-the-float-islands/  (written 2026-06-18 — paper.md + README complete; the four nonlinear fp32 islands → exact-integer on the 12B forward, X-BX-ISLANDS)
    20-one-substrate-every-backend/ (written 2026-06-18 — paper.md + README complete; the universal-crate reference + CRT-NTT attention + the O(1) daemon decode, X-BX-WIRE)
    21-byte-exact-not-compression/  (written 2026-06-18 — paper.md + README complete; the de-conflation, the boundary thesis, the re-derivation lesson, X-BX-BOUNDARY)
```

*(Numbering: paper 11 is reserved; the orchestration-tier set above the closed P3 substrate is published as 12–15, matching the operator's release plan; the discrete-container set — the crossbar re-carried onto the exact-integer O_K substrate — is 16–18; the byte-exact set — the forward pass itself carried onto the exact-integer substrate — is 19–21.)*

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
| 07 | [The Auditable Latent Crossbar](papers/07-auditable-latent-crossbar/): steering a frozen 12B through its KV cache, no tokens | 12B steered by direct KV-cache transplant: **15/15 incorporation, 15/15 selectivity** (2×2 double dissociation), 3.69 orders max rank pull, self-transplant null **7/7 bit-identical**, gold-instrument coherence (X-R1) | **written** (`paper.md` 2026-06-14; citable via X-R1) — architecture lattice `RFC-XBAR-auditable-latent-crossbar.md` | standalone-repro re-gate (needs GPU; held while soak runs) before full release |
| 08 | [O(1) KV: a context-decoupled cache via a learned router](papers/08-o1-kv-learned-router/) | learned **512×32 LSH** router selects global top-B at **+0.47% PPL @8×** (oracle −0.08%, frozen +4.17%); compact slab → **O(1) VRAM (8k↔16k flat ~50 MiB)**; **NIAH needle survives 10/50/90%**, frozen-router control MISSES (X-R2) | **written** (`paper.md` + `repro/EXPECTED.md` 2026-06-14; citable via X-R2) | standalone-repro re-gate (needs GPU; held while soak runs) before full release |
| 09 | [KAIROS: a resident 12B daemon that stays silent and rewinds at the metal](papers/09-kairos-resident-daemon/) | **24-tick crucible perfect** (21/21 NO_OP, 3/3 ACTION, 0 false/0 missed/0 drift; 0.6B control collapses); **O(1) byte-exact rewind** (48 layers diffs=0; metal 0.0073 vs prefix-grow 0.924 s/action, 127×); **wrap-aware journaled ring byte-exact (KAIROS-03)** uniting O(1)-time with O(1)-space + the semantic metal loop (24 ticks 0-fault) (KAIROS-01/02/03) | **written for the mechanism** (`paper.md` 2026-06-14; citable via KAIROS-01/02) **— full release HELD on the ≥24 h endurance soak, which is IN-FLIGHT (no verdict from a mid-run log)** | release on the soak receipt |
| 10 | [Receipts or it didn't happen](papers/10-receipts-or-it-didnt-happen/): bit-exact-or-bounded as the contribution | the four self-corrections (34.2 retired by its own PPL rule; 32k MISS kept on the front page; the small-N noise illusion; oracle-ceiling-before-training) | **staged draft** — evidence is the existing ledger + METHODOLOGY | with 07–09 |
| 12 | [The Memo Curator](papers/12-memo-curator/): autonomous discrete recall above the crossbar | the loop that drives the closed crossbar on its own — inert when off (G-MEMO-NULL, PPL 4.6665 bit-identical), a 256-bit LSH / integer-Hamming address (reduction-order-immune; sign-binarize collapses at r=32, ship r=256), promote-matched / discard-corrupted (G-MEMO-LOOP, +0.000% / +40106%) | **written, citable — X-C2** (`paper.md` + README 2026-06-17) | with 13–15 |
| 13 | [Speculate and Undo](papers/13-speculate-and-undo/): O(1) bit-exact rewind of latent memory | replay into the resident cache is load-bearing (zeroed reads back all-zero) + rewind resets the prefix byte-identical (G-222, 12B+E2B; G-222-WRAP across an SWA-ring wrap) — the §4-trap guarantee made mechanical | **written, citable — X-222** (`paper.md` + README 2026-06-17) | with 12, 14, 15 |
| 14 | [A parameter-free neocortex](papers/14-parameter-free-neocortex/): VSA/HRR Ring-3 consolidation | the gist tier from discrete NTT, zero training; retrieve-and-verify (P2.b top-5 honored) — G-R3-BIND (recall@1=1.0 to N=32), G-R3-LOSS (step function: hit +0.000% / miss +8.04% caught), G-R3-DUALROUTE (decoy scan), G-R3-NIGHTSHIFT (349.8 MB → 16.3 KB) | **written, citable — X-R3VSA** (`paper.md` + README 2026-06-17) | with 12, 13, 15 |
| 15 | [The organism breathes](papers/15-the-organism-breathes/): real audio to episodic memory | real speech → EAR on physical GNA 2.0 (0.877, KAIROS-04) → 12B pivots 7/8 → audio-conditioned KV serialized as a canonical Ring-2 episode; signature separates (self 211/256, margin +79); round-trip clean (the +1989% is foreign-by-design) | **written, citable (step 1) — X-ORG** (`paper.md` + README 2026-06-17) | with 12–14 |
| 16 | [The Unification](papers/16-the-unification/): the latent crossbar re-carried onto the exact-integer O_K substrate | the Ring-3 bind re-carried onto the engine-native dual-prime negacyclic CRT-NTT: **256/256 bit-identical** to native `sp_pr_mul` + **reduction-order-immune** (int byte-identical / float 4.44e-15); live loop on native `sp_pr_mul` (CAP=32 unregressed); Leg B `χ_d` carrier lowers coherence but is **inert** (the first negative) | **written, citable — X-OK-BIND** (`paper.md` + README 2026-06-18) | with 17, 18 |
| 17 | [The Frobenius integer episode store](papers/17-frobenius-integer-store/): and the boundary of the algebra | rank-2 O_K codec `a·s_a+b·s_b` **sub-ULP at 24 bits** (`a16b8` relL2 1.2e-7, 0.76× store); losslessness = reconstruction fidelity, **not** a fake +0.000% (the n=42 PPL gate is blind below ~1%); three boundary negatives (entropy 1.02×, Möbius sheds memories, T2-on-weights ≈ random) | **written, citable — X-OK-FROB** (`paper.md` + README 2026-06-18) | with 16, 18 |
| 18 | [The organism breathes (full loop)](papers/18-organism-on-silicon/): a cross-modal continuous→discrete→continuous loop on silicon | the full audio-cue loop on the integer substrate — sig (audio 256 / decoys 147,129) → integer bind → retrieve top-1 (cos +0.47) → C2 cross-modal verify (accept audio / reject text) → Frobenius land (relL2 ~9e-8) → metal `SP_REPLAY` clean; + the period-8→6 rebase (separation cleaner, decoy 154→129) | **written, citable — X-OK-ORG** (`paper.md` + README 2026-06-18) | with 16, 17 |
| 19 | [Killing the float islands](papers/19-killing-the-float-islands/): an exact-integer forward pass on a 12B | the four nonlinear fp32 islands (RMSNorm/softmax/GELU/RoPE) → deterministic exact-integer, no `libm` (RoPE by device CORDIC), no `__int128` (`M ≈ 2^60` fits u64); `G-BYTEEXACT-FORWARD-12B` OFF 4.6665 byte-identical to bf16 gold (null floor) / ON 4.6569 parity (−0.21% @ n=42) / ON run-to-run bit-identical | **written, citable — X-BX-ISLANDS** (`paper.md` + README 2026-06-18; the 2-physical-GPU check is the open external step) | with 20, 21 |
| 20 | [One substrate, every backend](papers/20-one-substrate-every-backend/): the universal crate, the CRT-NTT attention, an O(1) daemon decode | the L2 Rust crate is the **bit-exact reference** the C/CUDA/HVX backends gate to; attention `⟨q,k⟩`/`p·V` → exact-integer dual-prime convolution (`p·V` `~2^46 ≪ M` ⇒ no third prime); `G-WIRE-CUDA-DECODE-GEMMA4` 32/32 tokens bit-identical to the oracle, VRAM flat (O(1)) | **written, citable — X-BX-WIRE** (`paper.md` + README 2026-06-18) | with 19, 21 |
| 21 | [Byte-exact, not compression](papers/21-byte-exact-not-compression/): the boundary thesis + the honest negatives | the de-conflation (auditability ≠ compression); compression levers convicted (incoherence 1.37× / column reorder 1.05×, redundant vs `OK_Q4B`); the boundary thesis on the forward (T2-on-real-weights recon ≈ random); the re-derivation kept on the record | **written, citable — X-BX-BOUNDARY** (`paper.md` + README 2026-06-18; the reflective record — no new performance number) | with 19, 20 |
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

## Papers 22–24 — the autonomous librarian (X-B3-*, 2026-06-20)

- **22 — The honest-negatives wall** (`X-B3-NEGATIVES`): nine hand-designed recall signals, all refuted open-world. The negatives that justify the learned head.
- **23 — Parametric steel & the teacher-forced ablation knockout** (`X-B3-ABLATION`): novel-needle causal ablation makes episodic dependency measurable (−33.56 vs −0.15); the oracle that is also the labeler.
- **24 — The learned librarian** (`X-B3-WC`): a W_c head, diversity (34%→100%), logsumexp-mean (int16==f32), 360/361 recall + 50/50 reject, DEPLOYED LIVE on the 12B.
