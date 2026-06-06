# Case Study 01 — Card Payment Lifecycle · v2

> **Companion to:** [`README.md`](./README.md) — the canonical analysis.
> v2 is the methodology and extended-recommendations layer: how the data was generated, why the magnitudes look the way they look, what to push on next, and what would have to change for this story to be wrong.

---

## What v2 adds

v1 reads as a finished postmortem: "the rate dropped, two banks did it, here is the fix." v2 is the working notebook behind it. It documents:

1. **The data-generation choices** that shape the analysis — and which choices the case study is sensitive to.
2. **A confidence statement** for the root cause: what would have to be true for it to be wrong, and how we would tell.
3. **Extended recommendations** with rough sizing: USD at stake, what each lever moves, what the no-decision cost is.
4. **Open questions** parked for v3 — things this dataset cannot answer.

---

## 1 · Data generation: what is real vs. what is a knob

The dataset is synthetic. The generator is `data/generate_data.py`. Every number in v1 falls out of a small set of explicit parameters; understanding them is the difference between "the case study tells me X" and "the case study tells me X **because we dialled it in**."

### The auth-rate ramp

```python
ISSUER_RAMP = {
    "Bancolombia": {"p1": 0.85, "p2_trough": 0.76, "ramp_start_day": 29, "ramp_days": 4},
    "Davivienda":  {"p1": 0.84, "p2_trough": 0.74, "ramp_start_day": 31, "ramp_days": 4},
    "Nubank CO":   {"p1": 0.88, "p2_trough": 0.88, ...},  # flat
    "Nequi":       {"p1": 0.87, "p2_trough": 0.87, ...},  # flat
    "Kipo":        {"p1": 0.90, "p2_trough": 0.90, ...},  # flat
}
```

Three deliberate design choices live here:

- **Stagger**: Davivienda's ramp starts 2 days after Bancolombia's. Real banks reacting to the same advisory rarely move on the same day; staggering by 1–3 days is the realistic pattern. The case study uses this to argue "independent decisions, same trigger."
- **Ramp duration**: 4 days, not 1. A step function would scream "one event"; a ramp is what a policy rollout actually looks like (region-by-region, BIN-by-BIN, slowly increasing match rate).
- **Magnitude**: −9 pp baseline drop per bank. Compounding with the credit + e-commerce extra pressure (below) lands the affected cohort at ~−11 to −16 pp. This is **crisis-level but plausible** for a card-not-present credit tightening. Magnitudes above ~20 pp would only land in a fraud-ring emergency lockdown — not the most common cause.

### Credit + e-commerce pressure

```python
CREDIT_ECOM_PRESSURE = 0.82  # shave another ~18% off the day's base rate
```

Applied only to **Bancolombia and Davivienda credit cards on e-commerce, in the drop window**. This is the lever that makes Q5 readable: credit + e-commerce becomes the worst cell in the matrix (81.14% overall) without becoming an outlier the analyst trips over.

If this lever were 0.95 (5% extra pressure), Q5 would be inconclusive. If it were 0.65 (35% extra pressure), Q5 would be so obvious it would obscure the rest of the story. 0.82 is tuned to make the diagnosis findable but not free.

### Decline-code mix in the affected cohort

```python
DROP_DECLINE_WEIGHTS = [("05", 50), ("91", 25), ("51", 10), ("96", 8), ("57", 4), ("61", 3)]
```

Tuned for realism over drama. Real tightened-policy postmortems show:
- **`05` (Do Not Honor)** dominant because it is the catch-all hard refusal.
- **`91` (Card Issuer Unavailable)** rising as the new risk rules slow the auth endpoint.
- **`51`** present at month-end (insufficient-funds bumps tend to coincide with tightening).
- **`57`** small — pushing it higher would imply a bulk card-attribute update that issuers rarely do.
- **`61`** small but present — a per-card limit tightening, a realistic secondary effect.

Everything outside the affected cohort draws from a broader mix biased ~75% soft, ~25% hard — that is the steady-state baseline you would see in normal traffic.

### What this means for reading the case study

| Finding in v1 | Driven by which generator parameter | Robust to small parameter changes? |
|---|---|---|
| "The drop is real" | the ramp itself | yes |
| "Two issuers, staggered" | `ramp_start_day` stagger | yes |
| "Credit + e-commerce is the worst cell" | `CREDIT_ECOM_PRESSURE` | sensitive — needs to be ≤ ~0.88 |
| "`05` dominates the affected cohort" | `DROP_DECLINE_WEIGHTS["05"] = 50` | yes |
| "Hard share of B+D Phase 2 = 42%" | the soft/hard distribution of the drop weights | yes |
| "Retry recovers ~50% of soft" | the retry-success multiplier in the generator | yes |
| "Acquirers within 1 pp of each other" | acquirer choice is uniform random | yes (by construction) |

The case study is intentionally not designed to be "solved at a glance" — credit×e-commerce barely wins over debit×in-app, the daily auth rate is noisy at <30 attempts/day per issuer, and the decline-code mix on the affected cohort is only ~42% hard rather than a clean 70%+. This makes the analysis muscle more honest at the cost of some pedagogical clarity.

---

## 2 · Root-cause confidence

> **Claim from v1:** Bancolombia and Davivienda tightened their card-not-present authorization policy on credit traffic, starting 2025-01-30 to 2025-02-02, applied independently to the same external trigger.

This is the most economical explanation that fits the data we have. What would have to be true for it to be wrong:

| Alternative explanation | What we would expect to see | What we actually see |
|---|---|---|
| Mastercard/Visa scheme-wide change | Drop hits all issuers on the same network. Bancolombia = Mastercard, Davivienda = Visa — so a scheme change would only hit one of them, not both. | Both networks are affected → reject |
| Kipo-side risk-engine regression | Drop hits *all* issuers, not just two. Kipo's self-issued rail is the cleanest signal. | Kipo's own rail is flat at ~89% → reject |
| Acquirer routing change | One acquirer underperforms; others are stable. | All three acquirers are within 1 pp of each other and show the same dip → reject |
| 3DS2 challenge-completion drop | Decline codes would be authentication-related (e.g. `1A`, `65`), capture-to-auth rate would crater on `three_ds_result = Y`. | Top codes are `05`, `91`, `61` — none authentication-related. Q12 capture-to-auth on 3DS-Y is stable. → reject |
| Coincidence: two banks happened to tighten in the same week for different reasons | Decline-code mix would diverge between the two banks. | The mix is broadly similar on B+D in Phase 2 → low prior but cannot fully reject from the data alone |

**Confidence level:** high, but contingent on the issuer-relations conversation in Recommendation 1 confirming the policy change in writing. Without that confirmation the case study is "consistent with policy tightening" — not "proven."

---

## 3 · Extended recommendations (with sizing)

### Recovery sizing

| Lever | Mechanism | Expected lift on overall auth rate |
|---|---|---|
| Retry tuning (soft allow-list only) | Recover ~50% of B+D soft declines that are not currently retried | +1.0 to +1.5 pp |
| Issuer-relations TRA exemption on B+D | If <30 USD low-value rule lands, recover ~30–40% of `05` declines on those amounts | +1.5 to +2.5 pp |
| BIN-level alerting | Earlier detection, future incidents only — no lift on this one | 0 (preventive) |
| 3DS2 exemption program | Structural improvement on credit + e-commerce baseline, not for this incident | +0.5 to +1.0 pp over 2–3 months |
| Re-routing PSE (debit-bank) for low-value e-commerce | Bypasses the credit-card auth surface but introduces drop-off at PSE redirect | net +0.5 to +1.5 pp, conditional on redirect drop-off being <5% |

Stack them and the realistic recovery is roughly **+3 to +6 pp** — enough to bring the overall rate back near baseline, but only if Recommendation 1 lands.

### The "do nothing" cost

The dataset has `amount_usd` per intent. A back-of-the-envelope on the lost revenue from the drop:
- Phase 2 has ~5,000 attempts on B+D × ~13 pp drop × ~25 USD average ticket → **~16,000 USD of lost gross authorisations over the 30-day Phase 2**, or roughly **~530 USD/day** of revenue that did not happen because of the tightening.
- This is a lower bound (captures only direct loss, not user churn from repeated bad experiences).

### The recommendation that did not survive v2

v1 hinted at "3DS2 exemption strategy" as the headline fix. v2 demotes it: 3DS2 friction is **not** what is producing `05` and `61` — the bank is refusing the auth before the cardholder is challenged. 3DS2 is still a useful structural lever (Recommendation 4 in `README.md`), but it should not be sold to leadership as the fix for the February drop.

---

## 4 · Open questions parked for v3

These are downstream questions surfaced while writing v2 — none block the recommendations in `README.md`.

1. **Cost of the drop in USD, broken down by recovery path.** The back-of-the-envelope above is one paragraph; a v3 should split the lost revenue into (a) addressable by retry, (b) addressable by issuer relations, (c) structurally lost.
2. **Debit vs. credit economics.** What is the unit cost of pushing low-value e-commerce to PSE instead of credit? PSE has near-zero auth risk but introduces redirect drop-off — needs measurement.
3. **MCC-level effect.** Q13 (acceptance by merchant category) is in the SQL but the merchant-category interaction with the drop is not explored. If `05` declines cluster on certain MCCs (e.g. digital entertainment, marketplaces), issuer relations has a sharper ask.
4. **Capture-to-auth on 3DS2-Y.** Q12 is built but not surfaced. v3 should confirm explicitly that successful auths through 3DS challenge convert to capture at the same rate as frictionless auths — the data is there.
5. **Written confirmation of the policy change.** Recommendation 1 in `README.md` is the path to closing this. Without it, the case study is "consistent with" rather than "proven."

---

## 5 · How to reproduce v2 numbers

```bash
cd case-studies/01-card-payment-lifecycle
python data/generate_data.py
# CSVs land in data/raw/

# Then either:
# (a) run sql/02_load_data.sql in BigQuery and use the dashboard, or
# (b) recompute headline numbers locally with the script embedded in v1's
#     "Q1 — Did the drop actually happen" rolling-window methodology.
```

The generator uses `csv.QUOTE_NONNUMERIC`, so every string field is wrapped in double quotes. This is the defensive choice for BigQuery loads: leading-zero decline codes (`"00"`, `"05"`, `"57"`, `"61"`) and string-but-numeric-looking fields (`"5557"`, `"4853"`) survive as strings, and no downstream tool will silently re-type them as integers.

---

## Files

Same as v1 — v2 is documentation only, no new schema or queries.
