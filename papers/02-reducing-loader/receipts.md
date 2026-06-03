# Paper 02 — receipts (ledger slice) *(staged — re-gate before release)*

Extract of the [master ledger](../../LEDGER.md) rows tagged `02`. From prior measured work; re-gated with a published repro before release per [`../../SERIES.md`](../../SERIES.md) rule 4.

| # | Claim | Number | Gate | Caveat |
|---|---|---|---|---|
| L1 | Reducing transcode, output-preserving | .sp-model 16.3 GB < 19.7 GB GGUF, top-1 identical | argmax parity | one 35B-MoE; reduction source-dependent (~17% here) |
| L2 | Zero-copy swivel load | no fp16 inflation of quants (avoids ~4× bw/footprint) | arena-alias verified | load-path invariant |
| L3 | Codec-by-source, no added loss | Q4→packed-Q4, Q8/F16→packed-Q8 | gate-off bit-faithful | not a new quant scheme |
| L4 | Bit-faithful on a second architecture | Gemma-class within f32-vs-Q8 floor (PPL 86.2 vs 90.7) | PPL gate + argmax | **86.2 vs 90.7 is the floor direction, NOT "5% worse" — say so** |

The exactness gate is top-1/argmax identity (not bit-identical logits). "Reducing" is source-dependent: the artifact shrinks when the source carries quantized weights SP packs tighter plus container overhead.
