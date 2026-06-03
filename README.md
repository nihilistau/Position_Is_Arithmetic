# Position Is Arithmetic

> A number-theoretic architecture for transformer inference and long-context memory — where a token's position, index, and routing *are* exact arithmetic, not floating-point metadata about it.

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
| Needle retrieved from a 32k-token context | **HIT, served off a physical NVMe drive** | poison-gated; latency figure is Optane-specific |
| KV sparsification quality | **8× at +0.69% perplexity** | one corpus, 2k context (2× and 4× go negative) |
| Reducing loader (transcode) | **model → ~50% smaller, bit-faithful forward** | gemma-3 + Qwen3, closure-gated |
| Bit-exact when disabled | **argmax-identical to the stock model** | the invariant under everything |

Honest scope: this is a proof-of-mechanism, not a scaling study and not yet independently reproduced. CPU decode is ~1.34× behind a tuned llama.cpp at the same quantization — the value here is the **memory envelope, not raw throughput**.

## The paper series

A staggered set of short, independently citable, receipts-first papers — each carries its own one-command reproduction.

- **01 — Two-ring memory** — query-directed recall + byte-addressable KV offload (the 32k-needle result above).
- **02 — The reducing loader** — output-preserving transcode + zero-copy load (the ~50%-smaller, bit-faithful result).
- **03 — Frobenius calibration-free quantization** *(staged).*

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

<<<<<<< HEAD
*Attributed to Transformers and 250 years of Mathematicians.*
=======
https://github.com/nihilistau/shannon-prime-bernhard

https://github.com/nihilistau/shannon-prime-burnhard

---

https://github.com/nihilistau/shannon-prime-lattice

https://github.com/nihilistau/shannon-prime-system

https://github.com/nihilistau/shannon-prime-system-engine

---


https://github.com/nihilistau/shannon-prime-lmstudio-server

https://github.com/nihilistau/shannon-prime-comfyui

---

https://github.com/nihilistau/voxtral-tts.c

https://github.com/nihilistau/voxtral-mini-realtime-rs

https://github.com/nihilistau/ComfyUI-FL-VoxtralTTS

---

*This work was carried out over two days (2026-05-17 to 2026-05-19) on top of the Shannon-Prime project. The system that executes this mathematics is described in Part II.*

*Submitted as preprint, 2026. The theoretical framework is offered as a research program; the implementations are evidence that the program is on the right track. Comments, criticism, replication, and extension are welcome via the Shannon-Prime repositories.*
>>>>>>> 14dc1b206df4155d6d72fcec1a9b82ae7841427b
