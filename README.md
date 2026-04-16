# Shannon-Prime

**KV cache compression library for transformer inference.**

---
Attributed to Transformers and 250 years of Mathematicians.
---

## What this is

Shannon-Prime is a **clean-room** implementation of Vilenkin-Hartley Transform, KV cache compression packaged as a portable library. It targets long-context inference on memory-constrained GPUs (consumer desktop CUDA, mobile Adreno/Vulkan).

"This is an independent implementation of VHT2/Mask-partitioned KV compression. No external GPL-licensed code was used in the kernels."

This repository contains **only** Shannon-Prime-authored code. There is no upstream framework code in-tree. The library attaches to any transformer-inference runtime that exposes a KV-cache abstraction

https://github.com/nihilistau/shannon-prime and https://github.com/nihilistau/shannon-prime-comfyui and https://github.com/nihilistau/shannon-prime-llama



