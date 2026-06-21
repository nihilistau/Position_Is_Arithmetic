---
type: gate-receipt
title: "Paper 02 — reproduction *(green — see [EXPECTED.md](EXPECTED.md))*"
description: "[run_reducing_transcode.ps1](run_reducing_transcode.ps1) is the one-command repro."
tags: [gate-receipt]
timestamp: 2026-06-03T04:49:02Z
resource: ./papers/02-reducing-loader/repro/README.md
sp_status: ACTIVE
sp_gate: none
sp_commit: TBD
sp_repro: none
---

# Paper 02 — reproduction *(green — see [EXPECTED.md](EXPECTED.md))*

[`run_reducing_transcode.ps1`](run_reducing_transcode.ps1) is the one-command repro. It uses the engine's real transcode CLI (`sp_transcode <in.gguf> <out.sp-model> <out.sp-tokenizer> --verify`) and the engine's existing bit-faithful closure gate:

1. **transcode** the source GGUF → `.sp-model` (`--verify`),
2. **L1 — reducing:** print `GGUF bytes` vs `.sp-model bytes` and assert the `.sp-model` is smaller,
3. **L4 — bit-faithful forward:** run the engine's `E_FMT_4` closure test, which checks `forward(.sp-model) == forward(GGUF)` (logits bit-identical on the Q8 arena path).

Set `-Model`, `-Transcode` (the built `sp_transcode` binary), and `-BuildDir` (engine build, for the `E_FMT_4` gate).

**Status (series rule 4): green.** Re-run for the release on 2026-06-03 — captured in [EXPECTED.md](EXPECTED.md). L1 reducing: Qwen3-0.6B-f16 GGUF 1,439.4 MB → .sp-model 719.6 MB (50.0% smaller, verify-load OK). L4 closure: `E_FMT_4` (gemma-3-1b) and `E_FMT_4_QWEN3` (Qwen3-0.6B) both pass — forward on the `.sp-model` is bit-identical to forward on the GGUF, on two architectures (6/6 gates, 0 failed, 2.4 min). For the public repro, use a small GGUF so a stranger can run it without 20 GB of weights; the 35B headline ratio (16.3 < 19.7 GB) is reported, the *mechanism* is what reproduces here at 0.6B.

L2 (no fp16 inflation on load) is asserted in the engine's arena/load path; a dedicated resident-bytes assertion is a good add before release.
