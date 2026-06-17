# Re-building a model's memory on exact-integer algebra (field note, 2026-06-18)

**What we did, in one sentence:** we took XBAR — our auditable latent-memory crossbar — and the KAIROS "organism" (an always-listening audio front-end feeding a frozen Gemma-3-12B's KV cache), both of which had been running on ordinary floating-point carriers, and re-built the entire memory tier on our own exact-integer algebra: the ring of integers of Q(√-163) (Heegner number 163, class number 1), carried by a dual-prime negacyclic Number-Theoretic Transform. All on a single RTX 2060, 12GB.

This is the discrete-substrate counterpart to the theory in **Papers 16–18** — moving from "the arithmetic *could* be exact" to "the memory tier *is* exact, on real weights, with receipts." Receipts live in the engine repo under `tests/fixtures/` (origin/main `0019b86`→`d2d7ceb`, pushed).

## What shipped (GREEN)

- **Exact-integer Ring-3 bind.** The holographic memory superposition (bind / unbind) moved off a host floating-point FFT onto the engine's native CRT-NTT. It is **256/256 bit-identical** to the C primitives and **reduction-order immune**: summing memories in any order gives a byte-identical result. The float version drifts ~4e-15 with order — that silent non-determinism is now engineered away, not bounded.
- **Frobenius integer episode store.** KV-cache memories are stored as exact integer O_K coordinates (a 2-coordinate `a + b` lattice with a per-tensor scale that cancels through the model's norm, by Theorem T4). Sub-ULP fidelity (relL2 ~1e-7) at 24 bits; ~2× smaller at an effectively-lossless 16 bits.
- **The organism on silicon, end to end.** A live continuous audio waveform → a 256-bit signature → bound into the discrete integer memory alongside text decoys → recalled by an audio cue (top-1) → verified by a Hamming check (accepts audio, rejects text) → decoded back to floating-point and injected into the live 12B attention heads. Continuous → discrete → continuous, autonomous.

## What didn't (and why that's the result)

The disappointments are load-bearing. We tried four ways to impose number-theoretic *structure on the data itself*, and **measured each one fail**:

- **Curve-aligned (split-prime / Dirichlet-character) addresses** lowered vector coherence beautifully — and in the predicted Heegner order — but did **not** improve recall. A periodic carrier "ghosts itself" on unbind.
- **Möbius square-free compression** of the memory vector sheds memories. A holographic sum has no sparse structure to exploit.
- **Entropy-coding the integer codes:** 1.02×. Quantization residue is noise; nothing to compress.
- **Möbius compression of the model's embedding table** (Theorem T2's own target): reconstruction came out **no better than random.** Trained embeddings have no multiplicative index structure. Said plainly: **T2 was a design proposal in our theory papers, never empirically validated** — unlike T4, which was. We just falsified it on real weights.

## The honesty note that matters

Our small perplexity gate scores only **42 tokens** — it literally cannot resolve sub-1% fidelity differences. A 1e-7 perturbation swung it as much as a 1e-2 one. So we report **"lossless" from reconstruction fidelity, not from a perplexity number we knew was noise.** We did not manufacture a clean +0.000%.

## The boundary thesis (the keystone)

The discrete algebra is an unmatched **container** — exactness, bit-reproducibility, reduction-order immunity. But the high-entropy *content* of a neural network must be allowed to stay unstructured. Intelligence lives at the edge of chaos: unstructured chaos bound inside rigid algebraic order. **Use the algebra for the arithmetic, never for the meaning.** That is what the four failures, taken together, actually prove.

## Next

The one structure-preserving lever we have **not** yet pulled: **T4 Frobenius integer quantization of the 9.4GB model weights themselves** — the *validated* theorem, applied to the model rather than the memory. That's the test that matters next.

---

*Shannon-Prime is a receipts-first project: no number without a reproducing command. Negatives stay attached. See Papers 16–18 and the `LEDGER.md`.*
