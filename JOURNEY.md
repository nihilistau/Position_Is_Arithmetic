# JOURNEY.md — agent map of the zoo

**Date:** 2026-08-29  
**Owner:** nihilistau / KnackAU  
**Audience:** the next agent that lands on any public tree and needs to know *which epoch this is*.

This file is the central map. Tombstones live as `STATUS.md` in each repo. **Read `STATUS.md` in a repo before treating its README as current.**

Companion / durable-memory daemon work (`Kairos`, `shannon-prime-kairos`) is **out of scope for this document**. Those trees are left alone. This map covers the Shannon-Prime arithmetic organism, the historical Shannon-Prime siblings, CosySim, Archives of Anubis, and the related game / media experiments.

---

## Agent rule (read this first)

1. Read this file, then the target repo's `STATUS.md`.
2. Do **not** collapse the lattice family into a companion harness.
3. Do **not** treat a `HISTORICAL` README as the live product.
4. Raw commits, gates, OKF receipts, Hindsight notes, and `AGENTS.md` files stay. That is the point of the archive.
5. Circular returns are expected. Threads exist so another agent can pick them up without a rebuild.

**Class vocabulary**

| Class | Meaning |
|---|---|
| `STANDING` | Living work. Unique substrate. Not absorbed elsewhere. |
| `HISTORICAL` / `PROVED` | Epoch closed. Mine it; do not clone it as a starting app. |
| `LIVE` (mentioned only) | Companion thread exists elsewhere. Not mapped here. |

---

## Why this is left raw

The public zoo is a live-committed field notebook of a journey with AI agents. The sprawl is the experiment: future-proof the archive so an agent can reconstruct the progression (including ADHD circular-return) without a human walking them through it. Cleaning the history would destroy the receipts. The map is the navigation layer; the commits stay the evidence.

---

## Epoch map (six clusters)

### 1. Shannon-Prime arithmetic organism — `STANDING`

**This is the living math / systems core. It does not move to a companion daemon.**

| Repo | Role |
|---|---|
| [shannon-prime-lattice](https://github.com/nihilistau/shannon-prime-lattice) | Umbrella: papers, contracts, KEYSTONE, VERIFIED-SCOREBOARD, ADRs, **SP-OKF + MEM-OKF**, SWARM design |
| [shannon-prime-system](https://github.com/nihilistau/shannon-prime-system) | Exact-integer math core + frozen L1 C ABI |
| [shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine) | Inference engine, backends, `sp-daemon`, `sp_swarm`, memory agency on the 12B |
| [Position_Is_Arithmetic](https://github.com/nihilistau/Position_Is_Arithmetic) | Public papers / LEDGER / this map |

**What stays in the lattice family (unique; not a companion feature):**

- **SP-SWARM / DHT** — L0 QUIC, L1 content addressing, L2 have/want replication, L3 Ed25519 provenance, L4 C2-SimHash discovery. Private signed mesh of MEM-OKF. Call surface: lattice `papers/PPT-LAT-MESH-API.md`. Blueprint: `papers/PPT-LAT-DESIGN-SWARM-MEMORY-MESH.md`.
- **Byte-exact exact-integer forward** — `O_K = Z[(1+√−163)/2]`, dual-prime negacyclic CRT-NTT, four exact islands (RMSNorm / softmax / GELU / CORDIC-RoPE), `SP_BYTEEXACT`. Auditability and cross-machine determinism. Explicitly **not** compression.
- **NTT / CRT / Frobenius / ARM / Ring-3 VSA** kernels and contracts.
- **Frozen L1 C ABI** (`include/sp/sp_l1.h`) that every backend gates to.
- **KEYSTONE papers, SCOREBOARD, FINDINGS-LEDGER, SP-OKF / MEM-OKF** anti-rebuild discipline.
- Served **Gemma-4-12B OK_Q4B** on one RTX 2060 through the project's own engine.

Start inside lattice at `papers/START-HERE.md`. Public receipts: this repo's `LEDGER.md` and `SERIES.md`.

### 2. Historical Shannon-Prime siblings — `HISTORICAL`

Clean rebuild already happened in cluster 1. Do not vendor these into new work (lattice anti-contamination rule).

| Repo | What it was |
|---|---|
| [shannon-prime](https://github.com/nihilistau/shannon-prime) | First public math-core epoch (`O_K`, Friedman sieve, KSTE) |
| [shannon-prime-engine](https://github.com/nihilistau/shannon-prime-engine) | First reference engine |
| [shannon-prime-llama](https://github.com/nihilistau/shannon-prime-llama) | llama.cpp patch bridge |
| [shannon-prime-comfyui](https://github.com/nihilistau/shannon-prime-comfyui) | ComfyUI VHT2 nodes (research dump) |
| [shannon-prime-bernhard](https://github.com/nihilistau/shannon-prime-bernhard) | Prime-harmonic / residue theory sketch |
| [shannon-prime-burnhard](https://github.com/nihilistau/shannon-prime-burnhard) | Burnhard / sp-engine experiment |
| [shannon-prime-harness](https://github.com/nihilistau/shannon-prime-harness) | CosySim runtime re-hosted on `sp-daemon` (July 2026 agency layer) |

`shannon-prime-harness` is the dated receipt of tool-calling + tiered conversation memory on the daemon. The companion *loop* continued elsewhere; the lattice substrate did not follow it.

### 3. Living-world + multi-agent governance

| Repo | Class | Note |
|---|---|---|
| [CosySim](https://github.com/nihilistau/CosySim) | `HISTORICAL` / `PROVED` | Flagship living-world. 35 launch targets, interceptor / skill / MCP control plane, Nexus flywheel, ARGUS, every NPC as a governed local LLM agent. Field notebook, not the current product. |
| [clockwork-dark](https://github.com/nihilistau/clockwork-dark) | living game line | Deterministic hard engine + autonomous LLM agents. CosySim / Anubis thread continues here. |
| [the-clockwork-dark](https://github.com/nihilistau/the-clockwork-dark) | earlier / sibling tree | Related Clockwork Dark epoch. Read `STATUS.md` if present. |
| [the-masters-shadow](https://github.com/nihilistau/the-masters-shadow) | living / sibling | Gothic roguelike; villain is a real agent bound by the same rules. |
| [the_masters_shadow](https://github.com/nihilistau/the_masters_shadow) | sketch / sibling | Earlier naming of the same line. |

### 4. Archives of Anubis — `HISTORICAL` / `PROVED`

| Repo | Note |
|---|---|
| [Achieves-Of-Anubis](https://github.com/nihilistau/Achieves-Of-Anubis) | Scarab-of-Ra reimagining. Hard dungeon engine + local LLM council (Proposer / Critic / Judge / Evaluator) + RAG lore, one RTX 2060. Council + hard-engine receipt. Thread continues in `clockwork-dark`. |

### 5. Neon-City family + satire roguelite

Threads that proved hard-engine + autonomous cast + procedural / baked-TTS pipelines.

- [neoncity](https://github.com/nihilistau/neoncity)
- [Neon-City-Penthouse](https://github.com/nihilistau/Neon-City-Penthouse)
- [neon-city-lock-down](https://github.com/nihilistau/neon-city-lock-down)
- [neon-city-bob-dipples-pickle](https://github.com/nihilistau/neon-city-bob-dipples-pickle)
- [neon-city-bobs-pickle](https://github.com/nihilistau/neon-city-bobs-pickle)
- [big-baby-company](https://github.com/nihilistau/big-baby-company)

### 6. Audio / media / early experiments + infra

- [voxtral-tts.c](https://github.com/nihilistau/voxtral-tts.c)
- [voxtral-mini-realtime-rs](https://github.com/nihilistau/voxtral-mini-realtime-rs)
- [ComfyUI-FL-VoxtralTTS](https://github.com/nihilistau/ComfyUI-FL-VoxtralTTS)
- [shannon-prime-comfyui](https://github.com/nihilistau/shannon-prime-comfyui) (also cluster 2)
- [smarthome-esphome-configs](https://github.com/nihilistau/smarthome-esphome-configs)

---

## Split that must not be averaged

```
                    public front door
                    Position_Is_Arithmetic
                    (papers + LEDGER + THIS MAP)
                              |
          +-------------------+-------------------+
          |                                       |
   STANDING substrate                      companion loop
   lattice + system + engine               (not this document)
   DHT / NTT / byte-exact / OKF
          |
   HISTORICAL siblings
   shannon-prime, -engine, -llama,
   -comfyui, -bernhard, -burnhard, -harness
          |
   proved living-world / council
   CosySim  →  clockwork-dark
   Achieves-Of-Anubis  →  clockwork-dark
```

If you are here for **arithmetic, swarm, byte-exact inference, or the papers**, stay in cluster 1.  
If you are here for **the CosySim / Anubis governance patterns**, read those trees as receipts and continue in `clockwork-dark`.  
If you are here for **a chat companion daemon**, that thread is not this map.

---

## Living entry points (non-companion)

| Need | Go here |
|---|---|
| Epoch map (this file) | [JOURNEY.md](https://github.com/nihilistau/Position_Is_Arithmetic/blob/main/JOURNEY.md) |
| Public receipts / papers | this repo (`LEDGER.md`, `SERIES.md`) |
| Lattice canon / OKF / SWARM | [shannon-prime-lattice](https://github.com/nihilistau/shannon-prime-lattice) → `papers/START-HERE.md` |
| Math core + L1 ABI | [shannon-prime-system](https://github.com/nihilistau/shannon-prime-system) |
| Engine + daemon + swarm crate | [shannon-prime-system-engine](https://github.com/nihilistau/shannon-prime-system-engine) |
| Hard-engine + LLM-agent game line | [clockwork-dark](https://github.com/nihilistau/clockwork-dark) |

Discord (lattice): https://discord.gg/rre9XZmvV

---

*Written as an agent-readable tombstone map. The raw trees stay. The map now exists.*
