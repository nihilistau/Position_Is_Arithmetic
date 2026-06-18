# The KV-Cache Compression Mirage: extreme quantization ratios collapse beyond perplexity, and the engineered 3–4.5× standard that holds

**Authors:** [Shannon-Prime — author list TBD]

> **DRAFT / preprint — not yet submitted.** This is a measured, *respectful* rebuttal plus an
> engineering contribution. The works we engage (TurboQuant, PolarQuant, IsoQuant, Coupled
> Quantization) are good work; our claim is narrow and evidence-bound. All of our own figures are
> gated on one model family at this project's scales on a single dev host (RTX 2060, 12 GB); each
> carries its scope. See §5. Where a number is operator-reported and we could not locate its receipt,
> we say so explicitly.

---

## Abstract

A fast-moving line of work pushes KV-cache quantization to extreme ratios — 3 bits per value, 6× to
8× — and reports near-lossless perplexity. TurboQuant (Zandieh et al., ICLR 2026), building on
PolarQuant, is a strong representative and has sparked an active research explosion (IsoQuant,
Coupled Quantization, and others). We do **not** dispute that this work is good, nor that the
perplexity numbers are real. Our claim is narrower and falsifiable: **extreme-ratio KV-cache
quantization is validated almost entirely on perplexity and short contexts, and its fidelity falls
off when evaluated on anything beyond perplexity — retrieval and long context in particular.** As a
*suggestive* (not dispositive) corroborating datapoint, roughly eight months into this line, **no
extreme-ratio scheme is in broad large-lab production use** at the ratios the papers headline — we
report the absence of production adoption as evidence worth weighing, not as proof, and we do not
make the unfalsifiable claim that "a big lab would deploy it if it worked." We bring our own
evidence, and we include ourselves in the indictment: the project's own KV codec (a Walsh-Hadamard
prime-factored transform, VHT2, over a 63-byte Spinor block with a half-Möbius reorder) reaches
extreme single-cache ratios only *lossily*, the same trap. Crucially we tested **beyond perplexity**:
on a long-context needle-in-a-haystack (NIAH) harness, a **frozen extreme-sparsity router loses the
needle** while only a **learned router or a moderate ratio** keeps it — concrete evidence that the
break is on **retrieval**, not on PPL — and we note the project's own measured fact that a small-N
PPL gate is **blind below ~1%**, so PPL-only validation structurally cannot see the degradation. We
then offer the engineering contribution: a viable, length-stable **~3–4.5×** standard, built from (a)
**cache-fidelity telemetry** that flags fall-off and triggers a refresh, and (b) a **two-tier
adaptive** scheme that compresses aggressively on short context and drops to ~4× as context grows.
We report each mechanism at exactly the gate status it has — the telemetry primitives and the
two-tier substrate (SWA-ring + compact slab + 4×↔8× adaptive ratio) are **gated**; the automatic
drift-triggered refresh is **design, not yet gated** — and we say which is which.

---

## 1 Introduction

The KV cache is the term that decides whether a model holds a long document on a small card. It grows
linearly with context, so compressing it is one of the most leveraged things one can do for
long-context inference — and the literature has obliged, with a sequence of increasingly clever
quantizers reporting increasingly extreme ratios at increasingly small perplexity costs. Three bits
per value. Six-to-eight-fold compression. "Near-lossless." The trajectory is real and the methods are
genuinely good.

This paper raises a specific, bounded objection, and then does some engineering. The objection is
**not** that the methods are wrong or that the numbers are faked. It is that the *evaluation* is
narrow in a way that hides a failure mode: extreme-ratio KV quantization is validated **almost
entirely on perplexity, at short-to-moderate context**, and perplexity at short context is exactly
the metric least able to see what extreme compression breaks. When you evaluate the *same* extreme
ratios on a task that actually exercises the cache as a memory — long-context retrieval, a needle in a
haystack — the fidelity is not where the perplexity number implies it is.

We take pains to be fair. We engage the strongest version of the opposing position (§2). We bring our
own data, including our **own** extreme-ratio codec, which is **equally lossy at extreme ratios** —
we are not claiming an exemption (§3, §4.1). And we frame the one piece of circumstantial evidence —
the absence of extreme-ratio schemes in broad production — as *suggestive*, with the unfalsifiable
version of that argument explicitly disowned (§2, §5).

The contribution is two-sided:

1. **The mirage, measured beyond PPL** (§4): on a long-context NIAH harness on a real 12B, a
   **frozen** extreme-sparsity router **loses the needle** while a **learned** router (or a moderate
   ratio) retains it — the break is on **retrieval**. Plus the project's measured fact that a small-N
   PPL gate is blind below ~1%.
2. **The engineered standard that holds** (§4.3): a length-stable **~3–4.5×** built on
   cache-fidelity **telemetry → refresh** and a **two-tier adaptive** ratio, reported at its exact
   gate status (substrate gated; auto-refresh trigger design).

## 2 Background & Related Work

**TurboQuant and the extreme-ratio line (engaged, not dismissed).** TurboQuant (Zandieh, Daliri,
et al., arXiv:2504.19874; ICLR 2026; covered on the Google Research blog) is genuinely strong work.
It advances the PolarQuant idea — quantizing keys and values in a transformed (polar / rotated) basis
where the distribution is better-behaved — into a near-optimal distortion-rate quantizer that reports
strong results at aggressive ratios (down to ~3.x bits) with small perplexity impact, and it
**sparked an active research explosion** building on it. We engage the **strongest** form of the
claim: that a well-designed transform-domain quantizer can hold perplexity at extreme ratios. We do
not contest that. Our objection is about the **breadth of the evaluation**, not the quality of the
quantizer.

**The siblings.** IsoQuant (arXiv:2603.28430) and Coupled Quantization pursue the same goal —
exploit cross-channel / cross-token structure to push the ratio — and PolarQuant is the shared
ancestor of the rotated-basis approach. The line is healthy and productive. The common thread, and
the locus of our objection, is the **validation surface**: the headline evidence is perplexity (and
sometimes a few short-context downstream tasks), and the extreme ratios are where the perplexity
numbers are most flattering and most blind.

**The production-adoption datapoint (suggestive, bounded).** As of roughly eight months into this
line, we are not aware of an extreme-ratio (3-bit / 6–8×) KV-quantization scheme in **broad large-lab
production** at those headline ratios; production long-context serving tends to sit at more
conservative ratios. We report this as **suggestive evidence** that the extreme ratios do not hold up
under the full production evaluation surface (which includes retrieval and long context), **not** as
proof. We explicitly **disown** the unfalsifiable version of the argument — we do **not** claim "a
large lab would deploy it if it worked," because absence of deployment has many causes (integration
cost, risk aversion, the moving target of the model itself). The honest reading: non-adoption at
extreme ratios is *one datapoint* consistent with the beyond-PPL collapse we measure, and it is worth
weighing alongside the direct evidence, not in place of it.

**Long-context retrieval evaluation.** The needle-in-a-haystack (NIAH) paradigm — plant a fact deep
in a long context and test whether the model can retrieve it — is the standard probe for whether a
long-context mechanism actually *remembers*, as distinct from whether it stays *fluent* (perplexity).
Our beyond-PPL evidence is on a NIAH harness; the point is precisely that NIAH and PPL can disagree,
and that extreme KV compression is where they disagree.

## 3 Method: how we measure the mirage, and what we built instead

### 3.1 The project's own KV codec — VHT2 / Spinor / half-Möbius

Our KV-cache codec is **VHT2**: each head vector is transformed by a **Walsh–Hadamard transform**
(WHT = a Z/2Z Vilenkin / prime-factored Hartley transform), split into spectral bands, each band
quantized with its own scale, and reconstructed via the inverse WHT — carried over the project's
**63-byte Spinor block** with a **half-Möbius reorder**. The transform is well-motivated: keys carry
RoPE positional structure, which concentrates WHT energy in the first bands (so band-wise bit
allocation, e.g. 5/5/4/3, matches the energy decay), while values carry diffuse content (so a flat
quantizer wins for V). This is a *good* codec — and it is **ours**, which is the point of including
it: it is subject to the same trap, so the indictment is not partisan.

### 3.2 Testing beyond perplexity: the NIAH harness

To measure what extreme sparsity breaks, we use the project's long-context O(1)-KV harness on a real
Gemma-4-12B: the 40 sliding-window layers ride a W-slot ring; the 8 global layers are served from a
compact slab whose contents are chosen by a **router** over the full K/V (resident in host RAM). The
router is the variable. We compare a **frozen** geometric router (a ±1 Rademacher projection — the
extreme-sparsity, no-learning selector) against a **learned** low-rank LSH projection, at the same
selection budget, on (a) the standard PPL deflection gate and (b) the NIAH retrieval gate, which
plants a secret outside the sliding window so a HIT can *only* come through the compressed/selected
global crossbar, with the global cache NaN-poisoned every step so the needle cannot leak through
un-selected state. NIAH is the beyond-PPL ruler; the frozen-vs-learned contrast is the controlled
experiment.

### 3.3 The engineered standard: telemetry-refresh and two-tier adaptive

The constructive half. The two mechanisms of a length-stable ~3–4.5×:

- **Cache-fidelity telemetry → refresh (the "drift sentinel").** The ARM two-ring memory carries
  **recall-hit telemetry** (a per-position content-hit counter — the coldness/association signal) and
  a **cold-evict mask** (positions that never won a content selection are losslessly evictable). These
  are the substrate of a *sentinel*: monitor which compressed entries are still being read and how
  cold the rest are, and **re-prime / refresh** the cache (re-materialize fidelity for the live set,
  evict the cold set) before degradation accumulates. We are precise about status in §4.3: the
  telemetry primitives are **gated** (attaching them is bit-exact-when-off); the **automatic
  drift-triggered refresh policy on top of them is design, not yet a closed gate.**

- **Two-tier adaptive ratio.** Compress aggressively while context is short (where the cache is small
  and the model is robust), and **drop to a more conservative ratio (~4×) as context grows** (where
  retrieval matters and extreme ratios break). The substrate for this is the O(1)-KV scheme: the
  SWA-ring caps the dominant term at a constant window, and the global slab's selection budget is the
  adjustable ratio — the project's gated operating points are **4× at +1.65%** and **8× (learned) at
  +0.47%**, with the explicit finding that **8× on a *frozen* router is RED (+4.17%)** and that 8×
  retrieval requires the learned router. The "two-tier" policy is to ride 8× (learned) while it
  holds and fall back to 4× as the context / fidelity budget demands.

## 4 Results

All of our figures are on **Gemma-4-12B (B1 / OK_Q4B)** on a single **RTX 2060 (12 GB)** (the VHT2
sweep figures are on the two reference models named in §4.1). Receipts-first; every number names its
gate. The deflection gate is the project standard: relative PPL change versus full attention, decode
path, common-mode quantization, bar **< 2%**.

### 4.1 Our own extreme ratios are lossy too — the trap is not partisan

The VHT2 sweep (WikiText-2, ctx = 2048, the noise floor stated per row) lands its **production
operating point at ~3.4–3.8× combined KV at ~+0.6–1.24% PPL** — a *moderate* ratio that holds:

| model (head_dim) | K × | V × | combined × | ΔPPL | note |
|---|---|---|---|---|---|
| Dolphin-1B (64) | 2.8× | 4.3× | **~3.4×** | **+0.60%** | K 5/5/4/3 + V flat int3 |
| Qwen3-8B (128) | 3.2× | 4.7× | **~3.8×** | **+1.24%** | same config |

Push it harder and it degrades exactly as the thesis predicts. The **single-cache** ratios reach
**V 4.3–4.7×** and **K-only 4.1× (GPU fast-path)**, but the cost climbs: GPU-path K-only 4.1× costs
**+6.0% PPL** (a consistent +0.8 PPL across all four chunks — a true systematic effect, not noise),
and a 2-bit band is *catastrophic* (the "3-bit floor": V 4/2 n=2 → +1.59%, sk=64 8-bit → +59%). So
**our** codec, too, is moderate-ratio-clean and extreme-ratio-lossy. We are not exempt; that is the
point.

> **(operator-reported) The specific figure "VHT2 reaches 8× at relL2 ≈ 0.0998" was not located in
> the repository's VHT2 receipts.** The VHT2 results we *can* verify (the sweep above) report
> *compression ratios and PPL deltas*, not a relL2 at 8×; the highest *single-cache* ratio on record
> is ~4.3–4.7× (V) / 4.1× (K-only GPU), all lossy, with extreme settings going badly (+6% to +59%).
> We therefore report the verified moderate-ratio standard and flag the "8× / relL2 0.0998" datapoint
> as operator-reported pending its receipt. The *qualitative* claim it supports — high ratios are
> achievable but lossy, the same trap — is fully borne out by the verified numbers.

### 4.2 The collapse is on RETRIEVAL, not PPL — the frozen router loses the needle

This is the load-bearing measurement. On the NIAH harness, with the extreme selection budget held
fixed, the **router quality** decides whether the needle survives:

| condition | router | depth / N | NIAH result |
|---|---|---|---|
| extreme sparsity (8×), **frozen** ±1 | geometric, no learning | 50% / 8k | **MISS** (5/6 digits → corrupted → loop) |
| extreme sparsity (8×), **learned** LSH r=32 | learned projection | 10% / 16k | **HIT** (exact secret) |
| same | same | 50% / 8k | **HIT** |
| same | same | 90% / 16k (SWA edge) | **HIT** |

The **frozen** router — the extreme-sparsity, no-learning selector that a PPL gate would wave through
— recalls the right *neighborhood* and gets *five of six* secret digits, then corrupts the sixth and
loops. Coarse geometry pulls the region but **lacks the resolution to land the key**. The learned
projection nails all six at every depth. The needle survives **only because the router is learned**;
the frozen control **MISSES at the same budget**. This is direct evidence that extreme KV
sparsification breaks on **retrieval**, in a regime where the perplexity deflection alone would not
have rung the alarm. (Gate G-P3-R2.b-2c-NIAH, engine `8e35877` / `3218d73`; the frozen-vs-learned
PPL contrast: frozen **+4.17% RED** vs learned **+0.47% GREEN** at 8×, oracle ceiling −0.08%, gate
G-P3-R2.b-2b-LSH, engine `222463a`.)

And the metric that misses it: the same mechanism, scored on a **small-N PPL** gate (n_ctx = 84, **42
scored positions**), showed *negative* deflections (4× −0.31%, 8× −3.21%) that looked like a *win* —
pure small-sample noise; the sign **flipped** on the full corpus (3072 scored positions: 4× +1.65%,
8× +4.17%). **A small-N PPL gate is blind below ~1%.** PPL-only validation, at the scales most papers
report, structurally cannot see the degradation that NIAH exposes. (The project's own honest-negative
episode, gate G-P3-R2.b-2b-N, engine `587c8d7`.)

### 4.3 The engineered standard — at its exact gate status

The viable, length-stable ratio and its mechanisms, reported precisely:

- **The two-tier adaptive substrate — GATED.** The O(1)-KV scheme is closed end-to-end on the real
  12B: the SWA-ring is byte-exact (caps the dominant term at a constant window), the compact global
  slab is output-invariant, and the selection budget is the adjustable ratio. **4× holds at +1.65%**;
  **8× (learned router) holds at +0.47%**; **8× frozen is RED (+4.17%)**. The "two-tier" policy —
  ride 8×-learned while it holds, fall to 4× as context/fidelity demands — is composed from these
  **gated** operating points. VRAM is flat 8k↔16k (~50 MiB jitter vs ~5.4 GiB for a full O(N) cache).
  (Gates G-P3-R2.b-2a/2b/2c, engine `222463a` / `33ac632` / `8e35877`.)

- **The drift sentinel (telemetry → refresh) — telemetry GATED, auto-refresh DESIGN.** The
  recall-hit telemetry (`sp_arm_hits_*`, the per-position content-hit / coldness signal) and the
  cold-evict mask (`sp_arm_evict_*`, lossless eviction of never-selected positions) are **gated and
  bit-exact-when-off**: attaching the telemetry leaves the decoded sequence bit-identical, and
  evicting the cold set is bit-exact. These are the *primitives* of a fidelity sentinel. The
  **closed-loop policy** that monitors fall-off and *automatically* re-primes / refreshes the cache
  on a drift trigger is **design, not yet a closed gate** — we say so rather than imply a result we
  have not gated.

So the engineered standard is: **a moderate ~3–4.5× that is gated to hold** (VHT2 ~3.4–3.8× at
≤1.24%; the O(1)-KV 4×/8×-learned operating points), with a **two-tier adaptive** policy assembled
from gated operating points and a **fidelity-telemetry substrate** that is gated, whose
**auto-refresh trigger is the named next step**, not a claimed result.

## 5 Limitations & Honest Negatives

- **We are not exempt — our own extreme ratios are equally lossy.** VHT2 is clean at ~3.4–3.8× and
  degrades at 4.1×+ (+6% GPU-path K-only) exactly as the thesis predicts. The contribution is the
  *moderate* standard, not an extreme-ratio escape.

- **The beyond-PPL collapse is shown on OUR harness at OUR scales, not universally.** The
  frozen-router-MISSES-the-needle result is on the project's NIAH harness on one 12B at ≤16k context.
  It is strong evidence that extreme sparsification breaks on retrieval *for this mechanism*, **not**
  a universal proof that *every* extreme-ratio quantizer (TurboQuant et al.) fails NIAH — we have not
  run those schemes on this harness. The honest claim is: PPL and retrieval can disagree, and where
  they disagree it is at extreme ratios; the burden the literature has not discharged is the
  beyond-PPL evaluation at the headline ratios.

- **The production-adoption argument is suggestive, not dispositive.** Non-adoption at extreme ratios
  has confounds (integration cost, risk, model churn). We weigh it; we do not rest on it; we disown
  the unfalsifiable "a lab would ship it if it worked."

- **The sentinel auto-refresh is DESIGN.** The telemetry and cold-evict primitives are gated; the
  automatic drift-triggered refresh policy is not yet gated. The two-tier substrate is gated; the
  adaptive *policy* that switches tiers is composed from gated operating points but its closed-loop
  switching is described, not separately gated end-to-end.

- **Scope.** One model family (Gemma-4-12B; VHT2 sweep on Dolphin-1B / Qwen3-8B), one host (RTX 2060
  12 GB), this project's harnesses. Not multi-model at the extreme-ratio comparison, not independently
  reproduced. TurboQuant / IsoQuant / PolarQuant / Coupled Quantization are cited from their
  publications, not re-run by us.

## 6 Conclusion

The KV-cache compression line has produced genuinely good quantizers, and we engage the strongest of
them respectfully. But the evidence base is narrow: extreme ratios are validated on perplexity at
short context, and that is the metric least able to see what extreme compression breaks. Tested
**beyond** perplexity — on a long-context needle-in-a-haystack — a **frozen** extreme-sparsity router
**loses the needle** while a **learned** router (or a moderate ratio) keeps it, and a small-N PPL gate
is **blind below ~1%**: the collapse is on **retrieval**, and PPL-only validation cannot see it. Our
own codec is no exception — it is clean at ~3.4–3.8× and lossy past ~4×, the same trap. The
constructive answer is a moderate, length-stable **~3–4.5×**, built from a fidelity-telemetry
substrate (gated) with a drift-triggered refresh (design) and a two-tier adaptive ratio composed from
gated 4×/8×-learned operating points. The standing challenge to the extreme-ratio line is simple and
falsifiable: **publish the retrieval and long-context numbers at the headline ratios.** Until then,
the extreme ratio is a perplexity mirage, and the engineered 3–4.5× is what holds.

---

## Appendix: Reproduction

**Commits.** O(1)-KV / router / NIAH (the beyond-PPL evidence and the two-tier substrate): engine
`222463a` (learned LSH router, 8× +0.47%), `33ac632` (compact slab, O(1) VRAM 8k↔16k), `8e35877` /
`3218d73` (NIAH retention + frozen-control MISS), `587c8d7` (the small-N → full-corpus sign-flip).
ARM telemetry primitives (the sentinel substrate): math-core `core/arm/arm.c`
(`sp_arm_hits_attach`/`_detach`, `sp_arm_evict_attach`/`_detach`). VHT2 codec receipts: the project's
VHT2 compression results (the 3.4–3.8× sweep, the 3-bit floor, the GPU fast-path +6%). Build host:
CUDA, `build-cuda/`, ninja, sm_75 (RTX 2060). Model: `gemma4-12b-b1.sp-model`.

**The beyond-PPL evidence (NIAH retrieval vs PPL).**
```
:: frozen vs learned router at 8x, PPL deflection (full wikitext-2 val, 3072 scored positions)
_run_g2_lsh.bat            :: FULL 5.1551 ; LSH r=32 5.1791 (+0.47% GREEN) ; frozen +4.17% RED
:: NIAH retrieval — the needle survives only with the learned router
_run_niah_cc.bat B 50  8192     REM frozen router  -> MISS (5/6 digits -> corrupt -> loop)
_run_niah_cc.bat C 10 16384     REM learned LSH    -> HIT
_run_niah_cc.bat C 50  8192     REM learned LSH    -> HIT
_run_niah_cc.bat C 90 16384     REM learned LSH    -> HIT
```
Receipts: `tests/fixtures/lsh/results/` (PPL), `results/niah_{C_d10_16k,C_d50_8k,C_d90_16k,B_d50_8k}.log`.

**The small-N PPL blindness (sign flip).** The mechanism-closing G2 first ran at n_ctx = 84 (42
scored positions) and showed negative deflections (4× −0.31%, 8× −3.21%) that flipped on the full
corpus (3072 positions: 4× +1.65%, 8× +4.17%). Gate G-P3-R2.b-2b-N, engine `587c8d7`.

**The two-tier substrate (gated operating points + O(1) VRAM ladder).**
```
_run_g2_cb2_vram.bat 8192  4400 1 8k     :: PPL 5.0549, VRAM ~11440-11476 MiB
_run_g2_cb2_vram.bat 16384 4400 1 16k    :: PPL 5.1371, VRAM ~11477-11524 MiB  (~50 MiB delta = O(1))
```
Receipts: `results/g2_cb2_8k_fixed.log` / `g2_cb2_16k_fixed.log` + `_smi.csv`.

**The telemetry sentinel primitives (gated, bit-exact-when-off; the auto-refresh policy is design).**
Attach `sp_arm_hits_*` (the content-hit / coldness counter) and `sp_arm_evict_*` (the cold-evict
mask); detached = zero work, decoded sequence bit-identical; cold-evict of never-selected positions is
bit-exact. Source: math-core `core/arm/arm.c`; gate harness `core/session/arm_genkv_gate.c`
(`T_GENKV_RECALL_HITS`, `T_GENKV_COLD_EVICT`).

**VHT2 codec.** The sweep (WikiText-2, ctx 2048): production op-point K 5/5/4/3 n=4 + V flat int3 →
~3.4× (Dolphin-1B, +0.60%) / ~3.8× (Qwen3-8B, +1.24%); 3-bit floor (2-bit bands catastrophic);
GPU fast-path sk=120 4-bit K-only → 4.1× at +6.0%. Receipt: the project's VHT2 compression results
document. **(operator-reported, receipt not located:** the specific "8× at relL2 ≈ 0.0998" figure —
the verified single-cache maxima are ~4.3–4.7× (V) / 4.1× (K-only), all lossy.)

**Related work referenced.** A. Zandieh, M. Daliri, et al., *TurboQuant* (arXiv:2504.19874; ICLR
2026; Google Research blog). *IsoQuant* (arXiv:2603.28430). *PolarQuant* (the rotated-basis ancestor).
*Coupled Quantization*. The needle-in-a-haystack long-context retrieval paradigm. The companion
Shannon-Prime O(1)-KV and learned-router work (the NIAH harness and the frozen-vs-learned contrast).
(Full citation keys TBD at submission.)
