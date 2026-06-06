# Position Is Arithmetic

> A number-theoretic architecture for transformer inference and long-context memory — where a token's position, index, and routing *are* exact arithmetic, not floating-point metadata about it.

**Live site:** https://nihilistau.github.io/Position_Is_Arithmetic/

**The main project is located at [Shannon-Prime-Lattice](https://github.com/nihilistau/shannon-prime-lattice) — you can join the Discord here: [Shannon-Prime-Lattice-Discord](https://discord.gg/rre9XZmvV).**

---

## What this is

Position Is Arithmetic is the public research home of the **Shannon-Prime** project: a ground-up re-derivation of the transformer forward pass in discrete integer arithmetic, plus a memory architecture (**PPT-ARM**) that attaches to a frozen, pretrained transformer and gives it long context on commodity hardware.

The thesis in one line: a transformer's positions, indices, and routing are arithmetic objects — primes, residues, lattices — so they can be **computed exactly** instead of approximated in floating point. That turns operations that are normally lossy (KV-cache compression, quantization, weight offload) into operations that are *bit-exact when disabled* and *cheap when enabled*.

This repository holds the **receipts-first paper series** and the project's document history. Active code lives in the [linked repositories](#links-to-other-repos); the headline implementation is [Shannon-Prime-Lattice](https://github.com/nihilistau/shannon-prime-lattice).

## Results so far

Receipts-first: every number reproduces from a single command. Proof-of-mechanism on one small model (Qwen3-0.6B) on one host — the unflattering numbers are kept attached on purpose.

| Result | Number | Scope / caveat |
|---|---|---|
| Resident KV-cache shrink @ 32k context | **910×** (7.5 GB → 8.3 MB) | two-ring offload to byte-addressable storage |
| Needle retrieved off a physical NVMe drive | **HIT at 512 positions** (7.57 µs/read) | poison-gated; latency figure is Optane-specific. **At 32k the composed run completed but MISSed** (B=512 = a 64× selection budget, far past the gated 2×–8× regime; under diagnosis) — kept here on purpose |
| KV sparsification quality | **8× at +0.69% perplexity** | one corpus, 2k context (2× and 4× go negative) |
| Reducing loader (transcode) | **model → ~50% smaller, bit-faithful forward** | gemma-3 + Qwen3, closure-gated |
| Bit-exact when disabled | **argmax-identical to the stock model** | the invariant under everything |
| 12B GPU decode vs llama.cpp-CUDA, same RTX 2060 | **34.2 vs 31.29 tok/s (+9.3%)** | measured (ledger 06-R6); **not citable until the wikitext-PPL gate clears the Q6_K→Q4 squeeze** — kept here with its anchor on purpose |

Honest scope: this is a proof-of-mechanism, not a scaling study and not yet independently reproduced. CPU decode is ~1.34× behind a tuned llama.cpp at the same quantization; on GPU the 12B decode measured **ahead** of llama.cpp-CUDA (+9.3%, perplexity verification pending). The memory envelope remains the primary value claim.

## The paper series

A staggered set of short, independently citable, receipts-first papers — each carries its own one-command reproduction.

- **01 — Two-ring memory** — query-directed recall + byte-addressable KV offload (the needle-off-NVMe result above).
- **02 — The reducing loader** — output-preserving transcode + zero-copy load (the ~50%-smaller, bit-faithful result).
- **03 — Frobenius calibration-free quantization** *(staged).*
- **[04 — The Oracle & the Teacher](papers/04-oracle-teacher/)** *(staged)* — oracle-grounded backend verification: a 35-layer variable-geometry GPU port matched to its CPU oracle at KL 2.7e-10, autoregressive decode teacher-forced exact — both live runs first-try.
- **[05 — The Probe Suite](papers/05-probe-suite/)** *(staged)* — bisection, isolation and benchmark hygiene used **as one set**: the suite that busted a 12.65× phantom speedup, a wrong-arithmetic divergence and a mixed-precision 0/256 — then landed the monolith pre-verified.
- **[06 — Computing on the Zip File](papers/06-dp4a-bandwidth-ladder/)** *(staged)* — the dp4a bandwidth ladder: direct compute on packed integer codes, **f32 1× → int8 ~3.8× → Q4 ~7.06×** on a consumer GPU, top-1 lossless.

See [`SERIES.md`](SERIES.md) for the manifest and release cadence, [`LEDGER.md`](LEDGER.md) for the master claims ledger (every number traced to a command), and [`METHODOLOGY.md`](METHODOLOGY.md) for the gate vocabulary and the "no number without a command" discipline.

## Older material

The original document history — theory drafts, Friedman/KSTE notes, results, and tools — has been moved to [`Archived/`](Archived/). It is kept for provenance, not as a starting point. Begin with the paper series above or the live project.

## Links to other repos

**Main project**

- [shannon-prime-lattice](https://github.com/nihilistau/shannon-prime-lattice) — the lattice: discrete Z_q substrate, the headline implementation
- [shannon-prime-system](https://github.com/nihilistau/shannon-prime-system) — math core
- [shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine) — inference engine

**Earlier / supporting**

- [shannon-prime](https://github.com/nihilistau/shannon-prime)
- [shannon-prime-engine](https://github.com/nihilistau/shannon-prime-engine)
- [shannon-prime-llama](https://github.com/nihilistau/shannon-prime-llama)
- [shannon-prime-bernhard](https://github.com/nihilistau/shannon-prime-bernhard)
- [shannon-prime-burnhard](https://github.com/nihilistau/shannon-prime-burnhard)
- [shannon-prime-lmstudio-server](https://github.com/nihilistau/shannon-prime-lmstudio-server)
- [shannon-prime-comfyui](https://github.com/nihilistau/shannon-prime-comfyui)

**Audio / Voxtral**

- [voxtral-tts.c](https://github.com/nihilistau/voxtral-tts.c)
- [voxtral-mini-realtime-rs](https://github.com/nihilistau/voxtral-mini-realtime-rs)
- [ComfyUI-FL-VoxtralTTS](https://github.com/nihilistau/ComfyUI-FL-VoxtralTTS)

## License

[MIT](LICENSE).

---

*Shannon-Prime-Lattice is an open-source research project by KnackAU — contact: raydaniels@gmail.com*

*Attributed to Transformers and 250 years of Mathematicians.*
