# Paper 01 — Two-ring memory

**A needle retrieved from 32,000 tokens of context, with the cold KV cache served off an NVMe drive, in ~1.8 GB RAM. 8× KV sparsification at +0.69% perplexity (2× and 4× go negative).**

- Read it: [`paper.md`](paper.md)
- Run the headline: [`repro/run_r9_32k_needle.ps1`](repro/) — expected output in [`repro/EXPECTED.md`](repro/EXPECTED.md)
- Receipts (this paper's ledger slice): [`receipts.md`](receipts.md) · full master ledger: [`../../LEDGER.md`](../../LEDGER.md)
- Discipline: [`../../METHODOLOGY.md`](../../METHODOLOGY.md)

A memory architecture that attaches to a frozen pretrained transformer and preserves its outputs, knocking down the three walls of long-context inference — memory (a two-ring offload to byte-addressable storage), compute (a ±1 projection router + O(N) selection), and quality (attention-sink pinning). Every mechanism is bit-exact when disabled.

Proof-of-mechanism on Qwen3-0.6B; scope and honest negatives are in the paper.
