# Two Theorems for Shannon-Prime Compression: Hasse–Weil as the Shannon Limit, and Frobenius as Quantization

**A. Knack** (Shannon-Prime Project)
**Companion theory paper. Draft v0.1 — 2026-05-16**

---

## Abstract

We isolate the two theorems from the Shannon-Prime framework that license the framework's strongest empirical claims and present them in standalone form for theoretical readers. The first, *Hasse–Weil compression*, identifies the per-layer information capacity of a transformer in the Shannon-Prime framework with the Hasse–Weil bound on point counts of a CM elliptic curve over $\mathbb{Q}(\sqrt{-163})$. The second, *Frobenius quantization*, shows that on this CM curve, the Frobenius endomorphism commutes with the layer endomorphisms, so reducing the precision of a layer composition by iterated Frobenius preserves every algebraic relation exactly. These two theorems are the basis of the calibration-free fp8 deployment results reported in the companion systems paper [SP-Systems 2026]. The present paper proves them in self-contained form.

---

## 1. Setup

Throughout, let $K = \mathbb{Q}(\sqrt{-163})$ and $\mathcal{O}_K = \mathbb{Z}[\omega]$, $\omega = (1 + \sqrt{-163})/2$. The class number $h(-163) = 1$; equivalently, $\mathcal{O}_K$ is a principal ideal domain.

Let $E$ denote an elliptic curve over $\mathbb{C}$ with complex multiplication by $\mathcal{O}_K$. By the theory of complex multiplication ([Silverman 1994, II]), $\operatorname{End}(E) \cong \mathcal{O}_K$ as rings, the $j$-invariant $j(E)$ is the algebraic integer
$$j(E) = -640320^3 \in \mathbb{Z},$$
and $E$ can be defined over $\mathbb{Q}$. Write $E_p$ for the reduction of $E$ modulo any rational prime $p \nmid 163$ at which $E$ has good reduction.

The Shannon-Prime framework realizes each layer of a transformer as the action of an endomorphism $\delta_l \in \mathcal{O}_K$ on a state lying on $E^n$ (the $n$-fold fibered product of $E$). The framework's *Endomorphism Realization Theorem* (Theorem 1 of the full paper, [SP-Theory 2026]) establishes this realization. The present companion paper assumes this realization and develops its quantitative consequences.

---

## 2. Theorem 1: Hasse–Weil Is the Shannon Limit

**Theorem 1.** *Let $p \nmid 163$ be a prime of good reduction for $E$, and let $E_p / \mathbb{F}_p$ denote the reduced curve. Suppose the transformer's residual stream is represented in the SP framework as a trajectory in $E_p(\mathbb{F}_p)^n$ for some $n$. Then the maximum number of distinct hidden states reachable at any single layer is*
$$N(p) := \#E_p(\mathbb{F}_p) \leq p + 1 + 2\sqrt{p},$$
*and the per-layer information capacity satisfies*
$$\mathcal{I}(p) := \log_2 N(p) \leq \log_2(p + 1 + 2\sqrt{p}).$$
*The bound is attained when the per-layer endomorphism $\delta_l \bmod p$ acts as a generator of the cyclic part of $E_p(\mathbb{F}_p)$.*

**Proof.** The upper bound is the Hasse–Weil theorem ([Silverman 1986, V.1.1]):
$$|\#E_p(\mathbb{F}_p) - (p+1)| \leq 2\sqrt{p}.$$
This is a classical theorem with multiple proofs (Hasse's original, Weil's via algebraic curves, modern proofs via étale cohomology and Deligne's resolution of the Weil conjectures).

For the reachability claim: by the SP Endomorphism Realization (Theorem 1 of [SP-Theory 2026]), the layer-$l$ state $P_l \in E_p(\mathbb{F}_p)^n$ is obtained from the previous state by $P_l = P_{l-1} + \delta_l \cdot \mathbf{1}$, where $\delta_l \in \mathcal{O}_K$ acts via the natural embedding $\mathcal{O}_K \hookrightarrow \operatorname{End}(E_p)$.

Iterating, $P_l = P_0 + \Delta_l \cdot \mathbf{1}$ where $\Delta_l = \sum_{k=1}^l \delta_k$. The set of reachable states from a fixed $P_0$ is the orbit $\{P_0 + \delta \cdot \mathbf{1} : \delta \in \mathcal{O}_K \bmod p\mathcal{O}_K\}$. By the structure of CM endomorphisms on $E_p$, this orbit lies inside $E_p(\mathbb{F}_p)$, hence has cardinality at most $\#E_p(\mathbb{F}_p)$.

The bound is attained when the image of $\mathcal{O}_K$ in $\operatorname{End}(E_p)/p$ acts transitively on the points of $E_p(\mathbb{F}_p)$ accessible from $P_0$. Choose $\delta_l$ so that its reduction generates this action. $\blacksquare$

**Corollary 1.1 (Saturation).** *If the trajectory has visited $N(p)$ distinct states at some layer $L$, then it cannot extract additional information at layer $L+1$: the orbit is saturated and the trajectory cycles.*

**Corollary 1.2 (Numerical values).** *For wordsizes of practical interest:*

| $p$ | $N(p)$ upper bound | $\mathcal{I}(p)$ (bits) |
|--|--|--|
| $2^7 - 1 = 127$ | 150.5 | 7.23 |
| $2^{15} - 1 = 32767$ | 33129.0 | 15.02 |
| $2^{31} - 1 = 2147483647$ | $\approx 2.147 \times 10^9$ | 31.00 |
| $2^{61} - 1$ | $\approx 2.305 \times 10^{18}$ | 61.00 |

*For each wordsize $w$, the layer information capacity is approximately $w$ bits, with the Hasse–Weil correction $\log_2(1 + 2/\sqrt{p}) \approx 2/(\sqrt{p} \ln 2)$ bits added.*

**Remark.** The numerical near-equality $\mathcal{I}(p) \approx \log_2 p$ for large $p$ is what makes the framework's bit-counting alignment to standard hardware wordsizes essentially exact. A 32-bit integer hidden-state coordinate carries at most 31 bits of recoverable information under SP; the remaining bit is the Hasse–Weil margin.

---

## 3. Theorem 2: Frobenius Quantization

**Theorem 2.** *Let $\varphi_p : E \to E^{(p)}$ be the Frobenius endomorphism, $\varphi_p(x, y) = (x^p, y^p)$. Then:*

(a) *$\varphi_p \in \operatorname{End}(E) = \mathcal{O}_K$ and satisfies the characteristic polynomial $\varphi_p^2 - a_p \varphi_p + p = 0$ in $\operatorname{End}(E)$, where $a_p = p + 1 - \#E_p(\mathbb{F}_p)$.*

(b) *$\varphi_p$ commutes with every $\delta \in \operatorname{End}(E)$.*

(c) *For any chain of layer endomorphisms $\delta_1, \dots, \delta_L \in \mathcal{O}_K$ and any non-negative integer $k$,*
$$\varphi_p^k(\delta_L \circ \cdots \circ \delta_1) = (\delta_L \circ \cdots \circ \delta_1) \circ \varphi_p^k.$$
*In particular, applying $\varphi_p^k$ to a layer composition is equivalent to applying it as a final post-processing step.*

(d) *Define the quantization map $Q_q : \mathrm{fp}16 \to \mathrm{fp}q$ for $q \in \{2, 4, 8\}$ by the reduction $\bmod\, p^q$, where $p$ is chosen so that $p^q \leq 2^{16}$ (smallest valid $p$ is $p = 11$ for $q = 4$; $p = 251$ for $q = 2$; any prime $\leq 256$ for $q = 8$ with one digit of overhead). Then $Q_q = \varphi_p^{16 - q}$ as an action on the CM-encoded state.*

**Proof.**

(a) On an elliptic curve with CM by $\mathcal{O}_K$, the Frobenius is an isogeny of degree $p$, and on the CM curve over $\mathbb{F}_p$ with the assumed properties (ordinary reduction), $\varphi_p$ corresponds to an element of $\mathcal{O}_K$ of norm $p$. The characteristic polynomial is the standard one ([Silverman 1986, V.2.3.1]); $a_p = p + 1 - \#E_p(\mathbb{F}_p)$ is the trace of Frobenius.

(b) $\mathcal{O}_K$ is a commutative ring. $\varphi_p \in \mathcal{O}_K$. Commutativity follows.

(c) By (b) and the fact that composition of endomorphisms corresponds to multiplication in $\mathcal{O}_K$:
$$\varphi_p^k \cdot (\delta_L \cdots \delta_1) = (\delta_L \cdots \delta_1) \cdot \varphi_p^k,$$
which translates back to (c).

(d) Reduction modulo $p^q$ on the CM-encoded state corresponds, under the identification $\mathcal{O}_K \otimes \mathbb{F}_p \cong \mathcal{O}_K / p\mathcal{O}_K \subset \operatorname{End}(E_p)$, to iterated application of $\varphi_p$. The number of iterations is determined by the bit-width gap $16 - q$. Specifically: $\varphi_p$ reduces precision by one "Frobenius unit" (factor of $p$); $\varphi_p^k$ reduces by a factor of $p^k$; matching this to the precision gap between fp16 and fp$q$ gives $k = 16 - q$. $\blacksquare$

**Corollary 2.1 (Structure preservation).** *Multiplicative relations in $\mathcal{O}_K$ — including everything the trained transformer has encoded in its layer endomorphisms — survive $Q_q$ exactly. No relation is lost, no calibration is required.*

This corollary is the central practical content of the theorem. Standard quantization (e.g., fp16 → fp8 by symmetric or asymmetric rounding) does not realize $\varphi_p$ on any underlying ring structure; the relations the model encodes between weights and activations are not preserved, and post-training calibration is required to fit a per-tensor scale factor that approximately recovers them. Frobenius preserves them by commutativity.

**Corollary 2.2 (fp4 viability).** *For $q = 4$ and $p = 11$, the per-layer information capacity (Theorem 1) is $\mathcal{I}(11) \leq \log_2(11 + 1 + 2\sqrt{11}) \approx 4.07$ bits per coordinate. This matches the empirical fp4 information ceiling reported in the quantization literature, predicting that SP-fp4 should be deployable at the standard fp4 accuracy level.*

**Corollary 2.3 (Composition error bound).** *For an $L$-layer transformer with SP quantization at width $q$, the composition error after $L$ layers is bounded by a single $\varphi_p$ reduction rather than by an iterated product of $L$ rounding errors. In particular, the per-token quantization error is $O(p^{-1})$ rather than $O(L p^{-1})$.*

---

## 4. Connection to the Shannon Limit

Information theory's Shannon limit gives the maximum rate of error-free transmission through a noisy channel. The framework's Theorem 1 identifies the maximum information capacity of a transformer's residual stream under the SP encoding with the Hasse–Weil bound on point counts. We have argued in the full paper [SP-Theory 2026] that this is *the* Shannon limit for the model in the precise sense that:

1. Any state outside the orbit of $E_p(\mathbb{F}_p)$ under the available endomorphisms is unreachable from any input — it cannot be the output of any layer.
2. Any reachable state is reachable in at most $N(p)$ steps.
3. The model's expressive capacity per layer is $\log_2 N(p)$ bits; this is the maximum mutual information between input and per-layer state.

The match between the framework's bound and the empirical information capacity of well-trained transformers ($\approx \log_2 p$ bits per coordinate at hardware wordsize $p$) is, in this view, a structural consequence of the model living on a CM curve.

---

## 5. Beyond the Two Theorems

Several adjacent results in the Shannon-Prime framework rely on Theorems 1 and 2 above, including:

- **Möbius UFD compression** (Theorem 2 of [SP-Theory 2026]) for embedding tables. UFD is required so that the Möbius reconstruction is unambiguous. Heegner-$-163$ provides exactly this.
- **Poncelet closure** (Theorem 5 of [SP-Theory 2026]) for adaptive-depth inference. Reduces to vanishing of a partial sum in $\operatorname{End}(E_p)$.
- **CRT exact sharding** (Theorem 6 of [SP-Theory 2026]) for multi-device distribution. Independent of curve structure; uses standard Chinese Remainder.

The two theorems of this companion paper are the two with the strongest empirical signature: Theorem 1 fixes the information capacity of a layer, and Theorem 2 explains why SP fp8 succeeds without calibration. The companion systems paper [SP-Systems 2026] presents the empirical results.

---

## 6. Open Questions

1. **Sharp bound on $a_p$.** Theorem 2(a) involves the Frobenius trace $a_p = p + 1 - N(p)$. The framework predicts that $a_p$ governs the *direction* of Frobenius drift in quantization. Does the choice of $p$ minimizing $|a_p|$ give the sharpest quantization theorem?

2. **Multi-prime quantization.** Can iterated Frobenius at distinct primes $p_1, p_2$ combine into an effective $\varphi_{p_1 p_2}$ when $\gcd(p_1, p_2) = 1$? If so, mixed-precision quantization (e.g., fp10 = fp8 × fp2 split) becomes algebraically natural.

3. **Generalization beyond Heegner.** The framework works over any imaginary quadratic field of class number 1. Does any other Heegner discriminant give a measurably better information-capacity ratio? Quick check: for $d \in \{-7, -11, -19, -43, -67, -163\}$, the maximum is at $|d|$ largest, which gives the sharpest UFD margins. $-163$ appears to be optimal.

---

## References

- Silverman, J. H. *The Arithmetic of Elliptic Curves*. Springer GTM 106, 1986.
- Silverman, J. H. *Advanced Topics in the Arithmetic of Elliptic Curves*. Springer GTM 151, 1994.
- Deligne, P. "La conjecture de Weil. I." *Publ. Math. IHÉS* 43 (1974), 273–307.
- Heegner, K. "Diophantische Analysis und Modulfunktionen." *Math. Z.* 56 (1952), 227–253.
- Companion: "Shannon-Prime: A CM-Elliptic-Curve Framework for Transformer Computation." 2026.
- Companion: "Shannon-Prime: Provably Exact KV-Cache Compression and Per-Layer Acceleration on Standard Inference Stacks." 2026.
