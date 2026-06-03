# Case Study 01 — Card Payment Lifecycle

> **Role:** Data Analyst at Kipo, a Colombian fintech with a Sedpe license and Mastercard/Visa card programs.
> **Stack:** BigQuery · Looker Studio
> **Dataset:** 10,000 synthetic card transactions, 60 days (January–March 2025)

---

## Business Context

Kipo issues debit and credit cards under Mastercard and Visa to ~4.2 million users in Colombia's informal economy. Every card transaction travels a path: risk evaluation → authorization attempt → capture → settlement. If a transaction is declined before authorization, Kipo loses revenue and the user loses trust.

**Authorization rate** is the single most-watched metric in card payments: the percentage of authorization attempts that result in an approval. An auth rate of 85% means 15 out of every 100 attempts are declined by the issuing bank. A drop of even 5 percentage points has a direct and immediate impact on revenue.

---

## The Problem

In early February 2025, Kipo's Head of Payments flagged that the overall authorization rate had dropped from **~85% to ~77%** over the previous two weeks. The question passed to the data team:

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

The daily auth rate time series confirms the drop. The rate was stable around 84–86% through January 30, then fell to 76–78% starting January 31 and remained there.

This rules out a one-day data anomaly. Something changed at the boundary.

### Q2 — Which issuers are responsible?

Breaking auth rate by issuer reveals a clear pattern:

| Issuer | Auth Rate (Phase 1) | Auth Rate (Phase 2) | Change |
|---|---|---|---|
| Bancolombia | ~84% | ~70% | −14 pp |
| Davivienda | ~83% | ~69% | −14 pp |
| Nubank CO | ~88% | ~88% | stable |
| Nequi | ~87% | ~87% | stable |
| Kipo (self-issued) | ~90% | ~90% | stable |

The drop is concentrated entirely in **Bancolombia and Davivienda** — Colombia's two largest traditional banks. The neobanks are unaffected.

### Q3 — What decline codes are driving it?

The decline code breakdown shows two codes dominating the new declines:
- **`05` — Do Not Honor** (~45% of declines): a generic soft decline from the issuer
- **`57` — Transaction Not Permitted** (~30% of declines): often triggered by 3DS2 friction or missing authentication challenge

Both are soft declines — meaning the bank is not permanently refusing the card, but rejecting this specific transaction. This is a strong signal that the issue is authentication-related, not a cardholder funds problem.

### Q4 — Soft vs. hard declines by issuer

The stacked bar confirms: Bancolombia and Davivienda's new declines are almost entirely **soft** (recoverable). Hard declines like expired card (`54`) or invalid card (`14`) are flat across both phases.

Soft declines can often be recovered with a retry or an alternative authentication path. This is important for the recommendation.

### Q5 — Is the pattern tied to a specific card type or channel?

The pivot table is the clearest finding:

| | e-commerce | POS | in-app |
|---|---|---|---|
| Credit | **71%** | 84% | 86% |
| Debit | 83% | 85% | 87% |

The drop is almost entirely in **e-commerce + credit** combinations. POS and in-app channels, and debit cards across all channels, are unaffected.

This is the root cause: Bancolombia and Davivienda tightened their 3DS2 challenge policy on e-commerce credit card transactions starting January 31. Transactions that previously passed a frictionless flow are now being challenged — and a portion of cardholders are abandoning or failing the challenge.

### Q6 — Can retries recover the soft declines?

The retry success rate shows that roughly **42–48% of soft declines from Bancolombia and Davivienda are recovered on a second attempt** — lower than the ~65% rate from neobanks. This means retrying helps but is not enough on its own.

### Q7 — Is one acquirer performing better?

Auth rates across acquirers (Credibanco, Redeban, Yuno) are broadly similar. The drop appears in all three, confirming the problem is issuer-side, not acquirer routing.

---

## Root Cause

Bancolombia and Davivienda tightened their 3DS2 authentication requirements on e-commerce credit card transactions starting January 31, 2025. Transactions that previously completed frictionless (no challenge presented to the user) are now triggering an interactive challenge. A meaningful portion of users are failing or abandoning the challenge, resulting in `05` and `57` declines.

The traditional banks are applying this policy. The neobanks have not, which is consistent with their stable rates.

---

## Recommendations

1. **Issuer engagement** — Open a direct line with Bancolombia and Davivienda's issuer relations teams. Request data on how they are applying their 3DS2 challenge policy and whether exemptions (e.g. low-value transaction exemptions under 30 USD) can be negotiated.

2. **Retry logic tuning** — Implement automatic retry for `05` and `57` decline codes with a 10-second delay. With ~45% retry recovery, this alone could recover ~3–4 percentage points of the rate.

3. **3DS2 exemption strategy** — For low-risk transactions (fraud score < 30, returning cardholder, small amount), request Transaction Risk Analysis (TRA) exemptions from the issuer to avoid triggering the challenge flow.

4. **Monitoring by BIN** — Set up a real-time alert on auth rate by BIN prefix. A BIN-level alert would have detected this drop within hours on day 30 rather than after 2 weeks.

---

## How to Run This Case Study

```bash
# 1. Install dependencies
pip install faker

# 2. Generate the synthetic dataset
cd case-studies/01-card-payment-lifecycle
python data/generate_data.py
# → 15 CSV files are written to data/raw/

# 3. Create BigQuery tables
# Open sql/01_ddl.sql in BigQuery, replace `your-project-id`, and run.

# 4. Upload CSVs to GCS and load into BigQuery
gsutil cp data/raw/*.csv gs://your-bucket/kipo/raw/
# Then run sql/02_load_data.sql in BigQuery (replace project and bucket).

# 5. Run analysis queries
# Open sql/03_analysis.sql in BigQuery, run Q1–Q7.

# 6. Build the dashboard
# Follow dashboard/README.md — each chart maps to one of the 7 queries.
```

---

## Files

```
01-card-payment-lifecycle/
├── README.md                 ← this file
├── data/
│   ├── generate_data.py      ← generates all 15 CSV files
│   └── raw/                  ← generated CSVs (committed)
├── sql/
│   ├── 01_ddl.sql            ← BigQuery CREATE TABLE statements
│   ├── 02_load_data.sql      ← loads CSVs from GCS into BigQuery
│   └── 03_analysis.sql       ← 7 analysis queries
└── dashboard/
    └── README.md             ← Looker Studio build guide
```
