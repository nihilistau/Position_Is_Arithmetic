# Reproduce R9 — a needle from 32k context, served off a drive, in ~1.8 GB RAM

This is the campaign's centerpiece: one command, and a stranger watches the system retrieve an out-of-distribution secret from 32,000 tokens of context with the cold KV cache living **on a byte-addressable drive instead of in RAM**.

## What it proves (one run, three receipts)

- **Memory wall (R5):** resident KV cache 8.3 MB vs the dense 7.5 GB at 32k — `911×` on the cache (~8× net process RAM, router-index-dominated).
- **Storage offload (R3):** the needle is retrieved off the physical drive, **poison-gated** so a fake read cannot pass.
- **Latency (R4):** per-block read time, single-digit µs on Optane (media-dependent on other drives).

## Prerequisites

1. **Toolchain (Windows, the validated path):** MinGW gcc (15.2 used here), CMake, Ninja.
2. **Model:** `Qwen3-0.6B-f16.gguf` (any source of the standard GGUF).
3. **Corpus:** a long plain-text file, ≳ 40k tokens (e.g. a WikiText `.raw`). The script injects the needle into it.
4. **A fast drive with free space:** ≈ 7.5 GB for the K+V store. Optane gives the headline latency; any NVMe reproduces the *correctness*.

## Build the engine

```
git clone https://github.com/nihilistau/shannon-prime-system-engine.git shannon-prime-system-engine
cd shannon-prime-system-engine
cmake -S . -B build -G Ninja -DSP_QWEN3_GGUF="/abs/path/Qwen3-0.6B-f16.gguf"
ninja -C build niah
```

## Run it

Windows (validated):

```
cd comms/repro
./run_r9_32k_needle.ps1 -Model "C:\path\Qwen3-0.6B-f16.gguf" -Drive "F:\" -Corpus "C:\path\wiki.test.raw"
```

Linux (POSIX `O_DIRECT` fallback — not yet validated end-to-end at 32k; help wanted):

```
SP_R9_MODEL=/path/Qwen3-0.6B-f16.gguf SP_R9_CORPUS=/path/wiki.test.raw \
SP_R9_DRIVE=/mnt/nvme/ SP_R9_NIAH=../../shannon-prime-system-engine/build/tests/niah \
  ./run_r9_32k_needle.sh
```

Then compare against [`EXPECTED.md`](./EXPECTED.md).

## Honest notes (read these — they're the point)

- **Proof-of-mechanism, one small model.** This reproduces the single headline point, not a scaling claim. The full sweep (depths, budgets, N=512…32k, the PPL deflection) is in the paper.
- **It's slow (~1–2 h+).** Recall runs through the entire prefill here, which is I/O-heavy by design of this test — not the production decode pattern. That's disclosed, not hidden.
- **Latency is media-specific.** Quote the µs/read only with the drive you actually used. Correctness is drive-independent.
- **Gotcha:** if you convert the `.ps1` to a `.bat`, save it with CRLF line endings — `cmd.exe` mis-parses LF-only batch files.

Everything here traces to a row in [`../CLAIMS-LEDGER.md`](../CLAIMS-LEDGER.md). No number appears in the campaign that isn't reproducible from a command like this one.
