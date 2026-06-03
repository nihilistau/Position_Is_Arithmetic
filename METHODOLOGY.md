# Methodology — the discipline every paper in this series shares

Written once; every paper cites it instead of re-deriving it. It is the reason the numbers are believable, and it is as much the contribution as any single mechanism.

## The three rules

1. **Bit-exact when off.** Every mechanism is controlled by a flag and is a *strict no-op* in its default (off) state: the forward pass is then bit-identical to the unmodified reference model. So the baseline is provably the original network, and any on-state result is a controlled delta, never a confound.
2. **No number without a command.** Nothing appears in a paper, the README, a post, or a talk unless it is a row in [`LEDGER.md`](LEDGER.md) reproducible by a specified command (model, corpus, flags, gate, commit). A claim you can't run isn't a claim.
3. **Scope travels with the number.** Every figure carries its caveat — model, context length, corpus, what it does and does not generalize to. "Proof-of-mechanism on one small model" is stated up front, not buried.

## The gates

- **Parity gate** — on-versus-off argmax (token-sequence) identity. Confirms a change is a faithful no-op when disabled. This is what licenses rule 1.
- **Deflection gate** — relative perplexity change versus the full-attention baseline, on the *decode* path (so the mechanism is actually exercised), same engine, tokenizer, and quantization on both sides so the comparison is common-mode. Bar: < 2%.
- **Poison gate** — for the storage-offload path, evicted resident slots are overwritten with NaN. A correct answer is then impossible unless the value was genuinely fetched from storage; a silent-fallback bug fails loudly instead of passing quietly.

## What we deliberately publish

The unflattering results stay in. A falsified hypothesis (a recall signature that didn't survive an adversarial test) is reported, not hidden, because it demonstrates the gates discriminate. A speed number that loses to the state of the art is stated, because honesty about what a system *doesn't* do is what makes the claims about what it *does* credible. A result with its own caveats attached is one a reader can trust without re-deriving your incentives.
