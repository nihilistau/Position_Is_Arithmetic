#!/usr/bin/env bash
# R9 (POSIX) - needle from 32k context, cold KV on a byte-addressable drive.
#
# HONEST STATUS: the engine has a POSIX Ring-2 backend (O_DIRECT + pread, the
# fallback branch of ring2_disk.c) but the 32k end-to-end run has been validated
# on Windows (NO_BUFFERING + IOCP), not yet on Linux. This script is provided so
# the Linux path can be tried and fixed - contributions welcome. Correctness on
# any drive; latency is media-specific.
#
# Usage:
#   SP_R9_MODEL=/path/Qwen3-0.6B-f16.gguf SP_R9_CORPUS=/path/wiki.test.raw \
#   SP_R9_DRIVE=/mnt/optane SP_R9_NIAH=./engine/build/tests/niah  ./run_r9_32k_needle.sh
set -euo pipefail

NIAH="${SP_R9_NIAH:-../../shannon-prime-system-engine/build/tests/niah}"
MODEL="${SP_R9_MODEL:?set SP_R9_MODEL to a Qwen3-0.6B-f16.gguf}"
CORPUS="${SP_R9_CORPUS:?set SP_R9_CORPUS to a long text file}"
DRIVE="${SP_R9_DRIVE:-/mnt/optane/}"

[ -x "$NIAH" ] || { echo "niah not found/executable at $NIAH - build the engine first (see README.md)"; exit 2; }

export SP_ARENA=q8 SP_RECALL_R=32 SP_RECALL_W=32 SP_RECALL_SINK=4 SP_RECALL_B=512
export SP_RING2=1 SP_RING2_DISK=1 SP_RING2_DIR="$DRIVE"
export SP_NIAH_GGUF="$MODEL" SP_NIAH_CORPUS="$CORPUS"
export SP_NIAH_N=32768 SP_NIAH_DEPTH=50 SP_NIAH_GEN=24

echo "R9: N=32768 needle, recall B=512 (4x), sinks=4, Ring-2 on $DRIVE (POSIX O_DIRECT path)"
exec "$NIAH"
