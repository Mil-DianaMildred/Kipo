# Case Study 01 — Card Payment Lifecycle

> **Role:** Product Manager at Kipo, a Colombian fintech with a Sedpe license and Mastercard/Visa card programs.
> **Stack:** BigQuery · Looker Studio · Claude
> **Dataset:** 10,000 synthetic payment intents → 9,419 authorization attempts, 60 days (January–March 2025)

---

## Business Context

Kipo issues debit and credit cards under Mastercard and Visa to ~4.2 million users in Colombia's informal economy. Every card transaction travels a path: risk evaluation → authorization attempt → capture → settlement. If a transaction is declined before authorization, Kipo loses revenue and the user loses trust.

**Authorization rate** is the single most-watched metric in card payments: the percentage of authorization attempts that result in an approval. An auth rate of 85% means 15 out of every 100 attempts are declined by the issuing bank. A drop of even 5 percentage points has a direct and immediate impact on revenue.

---

## The Problem

In early February 2025, Kipo's Head of Payments flagged that the overall authorization rate had drifted down by several points over the previous two weeks. The question passed to the product manager:

> "What's causing the drop — and what do we fix first?"

---

## Data Model

The schema for this case study covers the full card payment lifecycle across 15 tables. See [`../../ERD.md`](../../ERD.md) for the complete entity-relationship diagram.

Key tables used in this analysis:

| Table | What it captures |
|---|---|
| `payment_intent` | Every payment attempt, approved or not |
| `auth_attempt` | Each individual authorization request sent to an acquirer |
| `authorization` | The final authorization result (auth code or decline code) |
| `risk_evaluation` | Kipo's internal fraud score and block decision, before the bank is asked |
| `card` + `bin_range` + `issuer` | Card metadata — which bank issued the card, card type, brand |
| `decline_code_catalog` | Mastercard/Visa decline codes classified as soft or hard |

---

## Analysis

### Q1 — Did the drop actually happen? When?

Overall auth rate over the 60-day window is **82.74%** (7,793 approved / 9,419 attempts). Splitting on `2025-01-31`:

| Phase | Window | Overall auth rate |
|---|---|---|
| Phase 1 | 2025-01-01 → 2025-01-30 | ~85% |
| Phase 2 | 2025-01-31 → 2025-03-01 | ~80% |

The drop is real and it is not a single bad day. Looking at a 3-day rolling auth rate for the affected issuers:

| Date | Bancolombia (3d roll) | Davivienda (3d roll) |
|---|---|---|
| 2025-01-29 | 85.0% | 85.6% |
| 2025-01-30 | 76.9% | 84.4% |
| 2025-01-31 | 71.8% | 82.4% |
| 2025-02-01 | 73.1% | 80.2% |
| 2025-02-02 | 81.2% | 75.9% |
| 2025-02-03 | 84.6% | 65.2% |
| 2025-02-04 | 75.0% | 61.6% |
| 2025-02-05 | 69.8% | 65.7% |

Two observations:
1. Bancolombia degrades first, around **2025-01-30**, settling roughly 10 pp below baseline within ~4 days.
2. Davivienda lags by **~2 days** and settles even lower, ~16 pp below baseline.

The lag between the two banks is the first piece of evidence that this is an issuer-side decision applied independently, not a Kipo-side event or a network outage.

### Q2 — Which issuers are responsible?

| Issuer | Phase 1 | Phase 2 | Δ | Phase 2 volume |
|---|---|---|---|---|
| **Davivienda** | 82.55% | **66.80%** | **−15.8 pp** | 970 |
| **Bancolombia** | 83.13% | **72.57%** | **−10.6 pp** | 915 |
| Nequi | 83.40% | 85.55% | +2.1 pp | 1,038 |
| Nubank CO | 85.65% | 88.63% | +3.0 pp | 853 |
| Kipo (self-issued) | 89.67% | 89.21% | −0.5 pp | 1,038 |

The drop is **concentrated entirely in Bancolombia and Davivienda**. The three neobanks (Nequi, Nubank CO, Kipo) are flat or slightly up in the same window. This rules out:
- a network outage (Mastercard/Visa would hit everyone),
- a Kipo-side regression (Kipo's own issuing rail is stable at ~89%),
- an acquirer routing issue (see Q7),
- 3DS2 friction at the scheme level (neobanks process e-commerce through the same 3DS rails).

### Q3 — What decline codes are driving it?

**All declines, full 60 days (top codes):**

| Code | Description | Type | Count | % of declines |
|---|---|---|---|---|
| `91` | Card Issuer Unavailable | soft | 394 | 24.2% |
| `51` | Insufficient Funds | soft | 340 | 20.9% |
| `96` | System Error | soft | 321 | 19.7% |
| `05` | Do Not Honor | **hard** | 271 | 16.7% |
| `61` | Exceeds Withdrawal Limit | **hard** | 63 | 3.9% |
| `57` | Transaction Not Permitted | **hard** | 62 | 3.8% |
| `43` | Stolen Card | hard | 46 | 2.8% |
| `41` | Lost Card | hard | 46 | 2.8% |

**Bancolombia + Davivienda, Phase 2 only (n = 573 declines):**

| Code | Type | Count | % of B+D P2 declines |
|---|---|---|---|
| `05` | **hard** | 160 | **27.9%** |
| `91` | soft | 138 | 24.1% |
| `51` | soft | 100 | 17.5% |
| `96` | soft | 93 | 16.2% |
| `61` | **hard** | 21 | 3.7% |
| `57` | **hard** | 19 | 3.3% |
| `41` | hard | 14 | 2.4% |
| `54` | hard | 11 | 1.9% |

Two signals stand out:

- **`05` (Do Not Honor) doubles its share** in the affected cohort — from ~17% of declines globally to ~28% on B+D in Phase 2. `05` is a hard, catch-all "the issuer's risk engine said no" code. There is no cardholder action that recovers it on the same attempt.
- **`91` (Card Issuer Unavailable) holds at ~24%**. This is a soft availability signal — the issuer's auth endpoint timed out. A sustained high `91` share suggests the bank's authorization stack is under load.

Together, `05` + `91` are **52% of all B+D Phase 2 declines**. The remaining mix (`51`, `96`, `57`, `61`, etc.) is broadly consistent with baseline traffic.

### Q4 — Soft vs. hard split by issuer (Phase 2)

| Issuer cohort | Hard | Soft | Hard share |
|---|---|---|---|
| Bancolombia + Davivienda (P2) | 242 | 331 | **42.2%** |
| Neobanks (P2) | small, baseline mix | — | <30% |

For B+D in Phase 2, **~42% of declines are hard** — well above the neobank baseline. The hard share is driven almost entirely by `05`, with `61` and `57` as smaller contributors. Hard declines cannot be recovered with a retry; the cardholder either needs a different payment method or has to call their bank.

### Q5 — Is the pattern tied to a specific card type or channel?

Auth rate by card type × channel, full window:

| | e-commerce | in-app | POS |
|---|---|---|---|
| **Credit** | **81.14%** | 84.12% | 82.73% |
| **Debit** | 83.93% | 80.84% | 84.90% |

The lowest cell on credit is **e-commerce at 81.14%**. Credit cards underperform debit on e-commerce by ~2.8 pp, and credit + e-commerce is also the largest single segment (n = 2,964 attempts, ~31% of all traffic). The debit + in-app cell (80.84%) is also low, but its volume is much smaller and the gap to other debit cells is consistent with statistical noise.

The credit + e-commerce signal aligns with Q3: the new declines from Bancolombia and Davivienda are codes (`05`, `91`, `61`) that are emitted by the issuer's risk engine **before** any cardholder interaction. The 3DS2 challenge layer is not involved in producing them — the bank is refusing the auth request itself, not failing an authentication step.

### Q6 — Can retries recover the soft declines?

Filtering to first-attempt soft declines (the only retryable pool), and computing how often a retry was attempted and how often it succeeded:

| Issuer | 1st-attempt soft | Retried | Recovered | Retry success of retried |
|---|---|---|---|---|
| Bancolombia | 225 | 128 | 67 | **52.3%** |
| Davivienda | 265 | 149 | 76 | **51.0%** |
| Nequi | 186 | 112 | 62 | 55.4% |
| Nubank CO | 137 | 77 | 46 | 59.7% |
| Kipo | 133 | 75 | 48 | 64.0% |

Retry on soft declines is genuinely effective (~51–64% conversion), but the addressable pool is small. For B+D in Phase 2, soft declines are only ~58% of declines; the other ~42% (`05`, `57`, `61`, etc.) cannot be recovered with a retry and **must not** be retried — retrying a hard decline looks to the issuer like a bad-actor pattern and can trigger card-level velocity blocks.

Sizing the retry opportunity: tuning retry to capture every soft B+D decline would recover an additional ~100–120 approvals/month, worth roughly **+1.0 to +1.5 pp** of overall auth rate. Useful, but not a fix for the −11 to −16 pp drop.

### Q7 — Is one acquirer performing better?

| Acquirer | Auth rate | Volume |
|---|---|---|
| Redeban | 83.16% | 3,177 |
| Credibanco | 83.00% | 3,136 |
| Yuno | 82.03% | 3,106 |

Auth rates across the three acquirers are within ~1 pp of each other, and **all three show the same Phase-2 dip on Bancolombia / Davivienda traffic**. This confirms the cause is on the issuer side: changing acquirer routing would not move the rate.

---

## Root Cause

Between 2025-01-30 and 2025-02-02, **Bancolombia and Davivienda tightened their card-not-present authorization policy on credit traffic**. The change is:

- **Where it lives:** the issuer's risk engine, evaluated **before** the cardholder authentication step.
- **What it emits:** `05` (Do Not Honor) jumps to 27.9% of declines in the affected cohort, with `91` (Card Issuer Unavailable) staying high at 24.1% as the issuer's auth endpoint slows under the new rule.
- **Where it lands:** credit cards on the e-commerce channel — the lowest cell in the Q5 matrix at 81.14%.
- **Who is affected:** Bancolombia (−10.6 pp) and Davivienda (−15.8 pp). Neobanks are unaffected, ruling out network, scheme, acquirer, and Kipo-side causes.
- **Timing pattern:** the two banks degrade ~2 days apart and each ramps over ~4 days. This is consistent with two issuers reacting independently to the same external trigger — most plausibly a SFC/UIAF fraud advisory or a Mastercard/Visa fraud bulletin issued in late January.

The 3DS2 hypothesis is **rejected**: `05` and `61` are issuer-side hard stops, not authentication-abandonment signals.

---

## Recommendations

Ordered by impact-per-week-of-effort.

### 1. Open issuer-relations channels with Bancolombia and Davivienda (this week)

This is the only lever that addresses the ~42% of declines in the affected cohort that are hard. Retry tuning and 3DS configuration cannot move `05`, `61`, or `57` — only the issuer can.

Targeted asks:
- Confirm the policy change and get the rule written down.
- Negotiate a TRA (Transaction Risk Analysis) exemption for low-value transactions (<30 USD) and for returning cardholders with successful prior captures on the same merchant.
- Ask for a BIN-level whitelist for Kipo's BaaS B2B traffic.

### 2. Retry policy — hard-coded allow-list

Implement automatic retry **only** for these soft codes:

| Code | Backoff | Notes |
|---|---|---|
| `91` | 30–60s | Issuer endpoint timed out; retry once. |
| `51` | notify, don't blind-retry | Insufficient funds requires cardholder action. |
| `96` | 30–60s | System error; never retry immediately. |

**Hard-block** retry on `05`, `57`, `61`, `14`, `54`, `41`, `43`. Retrying any of these escalates to a velocity-rule block on the card.

Expected lift: **+1.0 to +1.5 pp** of overall auth rate, concentrated on the Bancolombia and Davivienda soft pool.

### 3. BIN-level alerting (one-time build)

Set up a real-time alert on `auth_rate` by BIN prefix, with a 24-hour rolling window and a >5 pp drop threshold. This drop would have been detected on day 30 with a BIN alert rather than after two weeks of bleeding. Looker Studio can serve as a v1 of this; the long-term version belongs in the observability stack.

### 4. 3DS2 exemption strategy (medium-term)

Even though 3DS2 friction is **not** the root cause of the Phase-2 drop, the credit + e-commerce cell is structurally weak. A TRA-exemption program with the issuers would lift the headline rate independently of this incident. This is a 2–3 month integration; do not block on it for the current event.

### 5. Add the playbook to the runbook

Capture this category of incident with a decision tree:
- Drop concentrated in 1–2 issuers? → call issuer relations.
- Drop across all issuers? → check network / scheme status, then acquirer status.
- Drop on a single channel only? → check Kipo's own risk-engine deploy history.
- Hard share of new declines >40%? → retry tuning will not help; the lever is issuer-side.

---

## How to Run This Case Study

```bash
# 1. Install dependencies
pip install faker

# 2. Generate the synthetic dataset
cd case-studies/01-card-payment-lifecycle
python data/generate_data.py
# → 15 CSV files written to data/raw/

# 3. Create BigQuery tables
# Open sql/01_ddl.sql in BigQuery, replace project IDs if needed, and run.

# 4. Upload CSVs to GCS and load into BigQuery
gsutil -m cp data/raw/*.csv gs://your-bucket/kipo/raw/
# Then run sql/02_load_data.sql in BigQuery (replace project and bucket).

# 5. Run analysis queries
# Open sql/03_analysis.sql in BigQuery, run Q1–Q7 (page 1),
# Q8–Q13 (acceptance-rate page 2), and OV1–OV5 (overview page).

# 6. Build the dashboard
# Follow dashboard/README.md — each chart maps to one of the queries.
```

---

## Files

```
01-card-payment-lifecycle/
├── README.md                 ← this file (canonical analysis)
├── README_v2.md              ← methodology notes + extended recommendations
├── data/
│   ├── generate_data.py      ← synthetic data generator (staggered ramp, QUOTE_NONNUMERIC for BigQuery)
│   └── raw/                  ← generated CSVs (committed)
├── sql/
│   ├── 01_ddl.sql            ← BigQuery CREATE TABLE statements
│   ├── 02_load_data.sql      ← loads CSVs from GCS into BigQuery
│   └── 03_analysis.sql       ← Q1–Q13 + OV1–OV5
└── dashboard/
    └── README.md             ← Looker Studio build guide
```
