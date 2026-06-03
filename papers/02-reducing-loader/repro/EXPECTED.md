# Paper 02 — expected output (captured green)

Captured 2026-06-03 on the reference host (Qwen3-0.6B-f16, MinGW gcc 15.2 build).
Your byte counts will match if you use the same source GGUF; the *reducing* and
*bit-faithful* properties hold for any supported source.

## L1 — reducing (output-preserving size cut)

```
== transcode (GGUF -> .sp-model, --verify) ==
transcode codec: matmul weights -> OK_Q8
[sp_transcode] Qwen3-0.6B-f16.gguf -> out.sp-model (509 tensors, 754551808 bytes) + out.sp-tokenizer
[verify] load OK, 509 tensors
== L1 == GGUF 1,509,347,424 B -> .sp-model 754,551,808 B   reducing=True  (50.0% smaller)
         GGUF 1,439.4 MB -> .sp-model 719.6 MB
```

The cut is exactly ~50% because the dominant matmul weights go from f16 (2 B) to the
OK_Q8 codec (1 B) on an f16 source. A Q4-source model takes the OK_Q4 path instead;
the invariant is that the `.sp-model` is **smaller than the source**, never larger.

## L4 — bit-faithful forward (the engine's closure gate)

`ctest --test-dir build -R E_FMT` runs the full format family. The two `E_FMT_4`
gates are the closure gates: they transcode the GGUF, then assert the full forward
pass on the `.sp-model` path is identical to the forward pass on the GGUF.

```
1/6 Test #18: E_FMT_0 ..........................   Passed    0.03 sec
2/6 Test #22: E_FMT_1 ..........................   Passed   28.19 sec   (header CRC, magic/version, tokenizer SHA-256)
3/6 Test #23: E_FMT_2 ..........................   Passed   21.48 sec   (in-RAM Frobenius packer, precision=8)
4/6 Test #24: E_FMT_3 ..........................   Passed   17.00 sec   (arena layout format)
5/6 Test #25: E_FMT_4 ..........................   Passed   47.20 sec   (CLOSURE: forward(.sp-model)==forward(GGUF), gemma-3-1b)
6/6 Test #26: E_FMT_4_QWEN3 ....................   Passed   32.49 sec   (CLOSURE: forward(.sp-model)==forward(GGUF), Qwen3-0.6B)
100% tests passed, 0 tests failed out of 6
```

## What this proves

The reducing loader cuts the on-disk model in half **and** preserves the model's
output bit-for-bit on the forward pass — on two different architectures (gemma-3,
Qwen3). The size win is not an approximation traded against quality; the closure
gate is exact. L2 (no fp16 inflation on load — the quantized weights are never
expanded back to fp16 in RAM) is asserted in the engine's arena/load path.
