---
type: index
title: "AGENTS.md — how to navigate the Position_Is_Arithmetic paper series"
description: "Entry guide for an agent or reader landing on the public Shannon-Prime paper repo. The LEDGER is the master claims index; this file gives the read order, the honest-status convention, and the receipts-first discipline so a claim can always be traced to a command + a commit."
tags: [agents, navigation, ledger, receipts-first, honest-status, sp-okf]
timestamp: 2026-06-21T00:00:00Z
resource: LEDGER.md
sp_status: ACTIVE
sp_gate: none
sp_commit: c74afe8
sp_repro: "read LEDGER.md (the master claims index); follow each row to its commit/gate"
---

# AGENTS.md — navigating this repo

This is the **public, receipts-first paper series** of the Shannon-Prime project. It holds the
narrative, the papers, and the master claims ledger. The implementation lives in the
[linked repositories](README.md#related-repositories); this repo is the *story and the receipts*.

If you are an agent or a careful reader, **enter here**, in this order.

## 1. Read order

1. **[`README.md`](README.md)** — the public story: what "position is arithmetic" means, the
   PROVEN headline results *with their caveats*, the discipline, and the PROVEN-vs-WIRED-vs-DESIGN
   honesty section. Start here.
2. **[`LEDGER.md`](LEDGER.md)** — **the master claims index.** This is the single source of truth.
   Rule: *nothing appears in any paper, the README, a post, or a talk unless it is a row here, with
   its scope attached.* Every headline number traces to a ledger row, and every row carries its
   number, config, gate, caveat, status, and the commit chain that produced it. If a claim is not a
   ledger row with a command, it is not a claim.
3. **[`METHODOLOGY.md`](METHODOLOGY.md)** — the three rules (bit-exact when off; no number without a
   command; scope travels with the number) and the three gates (parity / deflection <2% / poison).
   This is *why* the numbers are believable; every paper cites it instead of re-deriving it.
4. **[`SERIES.md`](SERIES.md)** — the manifest and release cadence: the paper order, each paper's
   front-door receipt, and the rule for slotting a new release in.
5. **[`HISTORY.md`](HISTORY.md)** — a hashed, tiered commit log (MEM-OKF style). Tier-0 is a LUT of
   milestones; the git short-hash **is** the content address — follow any row with `git show <hash>`
   for the full commit. Regenerate with `python tools/okf_history.py gen --repo . --out HISTORY.md`
   (the tool lives in the lattice repo).
6. The papers themselves, under [`papers/`](papers/) — each is a self-contained module
   (`README.md` + `paper.md` + `receipts.md` + `repro/`), independently citable, carrying its own
   one-command reproduction. **[`research papers/`](research%20papers/)** holds the longer-form
   preprint drafts.

## 2. The honest-status convention (binding)

Every claim in this repo is tagged. **Read the tag before you trust the number.**

| Tag | Meaning |
|---|---|
| **[PROVEN]** | Measured and gated; the number has a ledger row and a reproducing command. Citable. |
| **[WIRED]** | Implemented and gated in-engine/in-core, running behind a flag — *not* a public citable headline, *not* "live by default." |
| **[DESIGN]** | Specified, with its falsification gates pre-stated; not built. |
| **honest negative** | Measured and *refuted*, kept on the record (e.g. the 32k NIAH MISS, the nine refuted recall signals, the inert content-side number-theory levers). |

Do not inflate a tag. In particular, on this public repo:
- The **32k NIAH MISS** (ledger `01-R9`) stays visible — it is the honest anchor for the recall budget.
- The **NIGHTSHIFT curator** is gated-GREEN on a *synthetic* gate (criteria 1–4); its live
  in-distribution criterion is **PENDING** — do not call it "live."
- The **byte-exact forward** buys *auditability* (exact arithmetic / cross-machine determinism),
  **not** compression, speed, or size; it is default-off (gated-GREEN), with the OFF state
  byte-identical to the bf16 gold.
- The **diffusion judge** is **not claimed here** — it is unproven and held in the drawer; any
  95.6% figure that appears in upstream notes is the *external llama.cpp oracle's* number, not ours.
- When in doubt, **under-claim**.

## 3. The receipts-first discipline (the project's whole posture)

- **Bit-exact when off.** Every mechanism is a strict no-op in its default state — the baseline is
  provably the original network, so any on-state result is a controlled delta.
- **No number without a command.** Every figure is reproducible from a ledger row.
- **Scope travels with the number.** Model, context, corpus, and what it does *not* generalize to
  ride along with every figure. This is *proof-of-mechanism on one dev host (RTX 2060, 12 GB)* — not
  a scaling study, not multi-model, not independently reproduced. Say exactly that.
- **No silent gate revision.** A gate that can't be met surfaces upstream; gates are never quietly
  retuned until a number passes.
- **Honest negatives stay attached.** A result with its caveats is one a reader can trust without
  re-deriving the authors' incentives.

## 4. The knowledge system (auditability discipline)

Shannon-Prime records its knowledge under **SP-OKF** — its profile of Google's Open Knowledge
Format v0.1: every knowledge `.md` carries `type` + receipts-first frontmatter
(`title/description/tags/timestamp/resource` + `sp_status/sp_gate/sp_commit/sp_repro`), validated by
`okf_validate.py`. The commit history is itself a tiered, content-addressed store
([`HISTORY.md`](HISTORY.md) via `okf_history.py`). The same discipline that gates the code gates the
docs: a claim you cannot trace to a command does not ship. The tooling and the full
**MEM-OKF** anti-rebuild store live in the lattice repo
(`shannon-prime-lattice`, `tools/`, `papers/SP-OKF-PROFILE.md` + `papers/MEMORY-OKF-PROFILE.md`).

## 5. Where the code is

This repo is the public face. The implementation is in the
[main project](README.md#related-repositories):
**[shannon-prime-lattice](https://github.com/nihilistau/shannon-prime-lattice)** (umbrella +
STATE + contracts + the OKF tooling), **[shannon-prime-system](https://github.com/nihilistau/shannon-prime-system)**
(the math core), and **[shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine)**
(the inference engine: the served chat, the recall head, the gates). The architecture ground truth
is the lattice repo's `papers/RFC-XBAR-auditable-latent-crossbar.md`.
