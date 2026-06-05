# Case Study 01 — Card Payment Lifecycle

> **Role:** Product Manager at Kipo, a Colombian fintech with a Sedpe license and Mastercard/Visa card programs.
> **Stack:** BigQuery · Google Data Studio · Claude
> **Dataset:** 10,000 synthetic card transactions, 60 days (January–March 2025)

---

## Business Context

Kipo issues debit and credit cards under Mastercard and Visa to ~4.2 million users in Colombia's informal economy. Every card transaction travels a path: risk evaluation → authorization attempt → capture → settlement. If a transaction is declined before authorization, Kipo loses revenue and the user loses trust.

**Authorization rate** is the single most-watched metric in card payments: the percentage of authorization attempts that result in an approval. An auth rate of 85% means 15 out of every 100 attempts are declined by the issuing bank. A drop of even 5 percentage points has a direct and immediate impact on revenue.

---

## The Problem

In early February 2025, Kipo's Head of Payments flagged that the overall authorization rate had dropped from **~85% to ~77%** over the previous two weeks. The question passed to the product manager:

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

The daily auth rate time series confirms the drop. The rate was stable around 84–86% through January 30, then fell to 75–78% starting January 31 and remained there.

This rules out a one-day data anomaly. Something changed at the boundary.

### Q2 — Which issuers are responsible?

Breaking auth rate by issuer reveals a clear pattern:

Phase 1 (January 1 to 30)
Phase 2 (February 1 to 28)

| Issuer | Auth Rate (Phase 1) | Auth Rate (Phase 2) | Change |
|---|---|---|---|
| Bancolombia | ~84% | ~65% | **−19 pp** |
| Davivienda | ~81% | ~61% | **−20 pp** |
| Nubank CO | ~87% | ~88% | stable |
| Nequi | ~84% | ~85% | stable |
| Kipo (self-issued) | ~89% | ~90% | stable |

The drop is concentrated entirely in **Bancolombia and Davivienda** — Colombia's two largest traditional banks. The neobanks are unaffected.

### Q3 — What decline codes are driving it?

84% of the declines were soft (recoveable)
16% of the declines were hard (not recoverable)

The decline code breakdown shows three soft codes dominating the new declines:
- **`05` — Do Not Honor** (~31% of declines): a generic soft decline from the issuer
- **`57` — Transaction Not Permitted** (~26% of declines): often triggered by 3DS2 friction or missing authentication challenge
- **`91` — Issuer Unavailable** (~20% of declines): the issuing bank's authorization system failed to respond within the network timeout

`05` and `57` the bank is not permanently refusing the card, but rejecting this specific transaction, which is a strong signal that the issue is authentication-related. 
`91` adds an availability dimension: Bancolombia and Davivienda appear to be struggling with response times under the increased 3DS2 challenge load, generating timeouts that register as this code.

### Q4 — Soft vs. hard declines by issuer

Bancolombia and Davivienda's new declines are almost entirely **soft** (recoverable). Hard declines like expired card (`54`) or invalid card (`14`) are flat across both phases.

Soft declines can often be recovered with a retry or an alternative authentication path.

### Q5 — Is the pattern tied to a specific card type or channel?

The pivot table is the clearest finding:

| | e-commerce | POS | in-app |
|---|---|---|---|
| Credit | **78%** | 83% | 83% |
| Debit | 82% | 85% | 80% |

The drop is most concentrated in **e-commerce + credit** combinations — the lowest auth rate in the grid. POS and in-app channels are more stable, though in-app debit (80%) slightly underperforms other debit segments. The e-commerce + credit pattern points squarely at 3DS2: e-commerce is the only channel where interactive challenges are presented to the user. 

REVISAR QUE DE LO QUE NO SE APROVO TENIA 3DS, RELACION CANAL 3DS. QUE CAMBIO EN EL ISSUES? COMO CONFIRMO LA EFECTIVIDAD O NO DEL CAMBIO DE POLITICA EN EL FRAUDE ? ESTA POLITICA ES VERDAD? O PURA HALUCINACION? COMO PUDO PASAR ESTE CAMBIO Y LO PUDIMOS HABER MITIAGADO? NOS BENEFICIA O NOS PERJUDICA?

This is the root cause: Bancolombia and Davivienda tightened their 3DS2 challenge policy on e-commerce credit card transactions starting January 31. Transactions that previously passed a frictionless flow are now being challenged — and a portion of cardholders are abandoning or failing the challenge.

### Q6 — Can retries recover the soft declines?

The retry success rate shows that roughly **45–47% of soft declines from Bancolombia and Davivienda are recovered on a second attempt** (Bancolombia ~47%, Davivienda ~45%) — lower than neobanks, where recovery rates range from ~48% (Nubank CO) to ~61% (Nequi). This means retrying helps but is not enough on its own.

TUVO ALGUN IMPACTO PARA LOS USUARIOS LOS RECOVERY EN LA EXPERIENCIA? COMO SE RECUPERARON? COMO SE PUEDE EVITAR LOS RECHAZOS EN PRIMERA Y LOS RIEGOS QUE CONYEVA?

### Q7 — Is one acquirer performing better?

Auth rates across acquirers (Credibanco, Redeban, Yuno) are broadly similar. The drop appears in all three, confirming the problem is issuer-side, not acquirer routing.

---

## Root Cause ??? NO ESTOY SEGURA DE ESTO? COMO SE MITIGAN ESTOS CAMBIOS?

Bancolombia and Davivienda tightened their 3DS2 authentication requirements on e-commerce credit card transactions starting January 31, 2025. Transactions that previously completed frictionless (no challenge presented to the user) are now triggering an interactive challenge. A meaningful portion of users are failing or abandoning the challenge, resulting in `05` and `57` declines.

The traditional banks are applying this policy. The neobanks have not, which is consistent with their stable rates.

---

## Recommendations

1. **Issuer engagement** — Open a direct line with Bancolombia and Davivienda's issuer relations teams. Request data on how they are applying their 3DS2 challenge policy and whether exemptions (e.g. low-value transaction exemptions under 30 USD) can be negotiated. 

COMO FUNCIONA EL 3DS EN EL FLUJO DEL USUARIO?

2. **Retry logic tuning** — Implement automatic retry for `05`, `57`, and `91` decline codes with a 10-second delay.??? With ~46% retry recovery on Bancolombia and Davivienda soft declines, this alone could recover ~3–4 percentage points of the rate. For `91` (issuer unavailable), a second retry after a longer delay (30s) may further improve conversion.

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

cual es la diferencia de debit y credit card? en este caso se tratan como iguales, se podria optimizar el costo con PSE, PERO SE CORRE EL RIESGO DE DROP OFF
