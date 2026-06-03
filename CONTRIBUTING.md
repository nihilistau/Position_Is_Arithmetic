# Contributing

This is a one-person, proof-of-mechanism project. It's at the stage where the most valuable contributions are exactly the things one person on one machine can't do — and where every claim is already gated and reproducible, so it's easy to verify whether a change helps or not.

## The discipline (please keep it)

- **Every claim has a gate.** If you add a mechanism, add the measurement that decides whether it works, and the off-state must be a bit-exact no-op (`parity gate`). See `CLAIMS-LEDGER.md`.
- **No number without a command.** If it goes in the README, the paper, or a post, it traces to a runnable repro.
- **Honest scope on everything.** "Proof-of-mechanism on 0.6B" is not a weakness to hide; it's the truth that makes the rest believable.

## Where help is wanted most

1. **Scale.** Does 8× sparsification at <2% perplexity deflection hold past 0.6B? Anyone with a larger model and the compute to run the decode-path PPL harness: run it and post the deflection table. This is the single biggest open question.
2. **Independent reproduction.** Run `repro/run_r9_32k_needle.*` on your own hardware and post the output. The **Linux `O_DIRECT` path is not yet validated end-to-end at 32k** — getting it green is a high-value, self-contained task.
3. **Router-index compression.** The recall index is a ±1 projection stored as floats (~950 MB at 32k — the real RAM floor). A sign-packed `popcount` (Hamming/Jaccard) form should cut it ~32× and speed scoring; it needs a fresh NIAH/PPL fidelity gate to confirm the binarization doesn't cost retrieval.
4. **Kernels / backends.** The recall + offload path is CPU-first; GPU and Hexagon ports welcome, each gated against the CPU reference.

## How

Open an issue describing the claim and its gate before a large PR. Small, gated, reproducible changes merge fastest. Discussion of the algebraic companion theory belongs in its own space — this repo is the measured system.
