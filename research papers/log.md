---
type: log
title: "Research papers bundle — change log"
description: Chronological creation and conformance history for the research papers/ SP-OKF bundle (R1–R5 preprints, their provenance notes, and the OKF-conformance pass).
resource: ./index.md
tags: [log, research-paper, history, sp-okf]
timestamp: 2026-06-18T00:00:00Z
sp_status: ACTIVE
sp_gate: G-OKF-CONFORM
sp_repro: git -C Position_Is_Arithmetic log -- "research papers"
---

# Research papers — change log

Chronological history of this bundle. The project-wide canonical `log.md` is `../../LEDGER.md`;
this is the bundle-local history.

| When (commit) | Change |
|---------------|--------|
| `120ae79` | **R1** first draft authored — *Reduction-Order-Immune Inference* (`paper.md`). |
| `caf373b` | **R2** and **R4** first drafts authored — *The Boundary Thesis* and *Exact-Integer Holographic Reduced Representations* (`paper.md` each). |
| `a6858ce` | **R3** and **R5** first drafts authored — *O(1) Episodic Memory by KV-Tensor Replay* and *The KV-Cache Compression Mirage* (`paper.md` each); `README.md` template + planned-drafts table. |
| *(this commit)* | **SP-OKF conformance + provenance bank.** Added `provenance.md` (`type: paper-provenance`) to each of R1–R5 with the genuine-wins assessment, literature positioning, defensibility tier, and honest pre-publication open items. Added SP-OKF YAML frontmatter to each `paper.md` (`type: research-paper`, `sp_status: DRAFT`, per-paper gate/commit/repro). Added this `log.md` (`type: log`) and `index.md` (`type: index`, the bundle map + cross-cutting pre-pub checklist); gave `README.md` `type: index` frontmatter. Validated GREEN under `okf_validate.py` (G-OKF-CONFORM). Papers' technical claims unchanged — frontmatter + provenance only. |
