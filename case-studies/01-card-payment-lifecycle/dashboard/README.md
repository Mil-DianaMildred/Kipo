# Dashboard — Card Payment Auth Rate

Looker Studio dashboard built on BigQuery. Visualizes the analysis queries from `sql/03_analysis.sql` across three pages: **Overview**, **Auth Rate**, **Acceptance Rate**.

---

## Expected headline numbers (sanity check)

After loading the v3 dataset, the dashboard should land on these values. If a chart is more than ~1 pp off, recheck the LOAD step before debugging the chart.

| Metric | Expected | Where it shows up |
|---|---|---|
| Overall auth rate (60-day) | **82.7%** | KPI scorecard, OV1 |
| Total auth attempts | **9,419** | KPI scorecard |
| Bancolombia P1 → P2 | 83.1% → 72.6% (**−10.6 pp**) | Q2 + date filter |
| Davivienda P1 → P2 | 82.6% → 66.8% (**−15.8 pp**) | Q2 + date filter |
| Neobanks (Nequi / Nubank CO / Kipo) | flat 85–89% | Q2 |
| Top decline code overall | `91` Card Issuer Unavailable, 24% | Q3 |
| Top decline code in affected cohort | `05` Do Not Honor, ~28% on B+D Phase 2 | Q3 with issuer filter |
| Hard share of B+D Phase 2 declines | ~42% | Q4 |
| Worst card-type × channel cell | credit × e-commerce, **81.1%** | Q5 |
| Retry success on soft (B+D) | ~51–52% | Q6 |
| Auth rate by acquirer | all three within ~1 pp | Q7 |

---

## 1. Connect BigQuery to Looker Studio

1. Open [Looker Studio](https://lookerstudio.google.com) → **Create** → **Data source**
2. Select **BigQuery** connector
3. Pick your GCP project → dataset `kipo_payments`
4. Add `auth_attempt` as the base table (most charts query it)
5. Repeat for any table a chart needs directly (e.g. `settlement_batch` for fee analysis)

For charts that use JOINs across tables, paste the corresponding SQL query into a **Custom query** data source.

---

## 2. Dashboard layout

```
┌─────────────────────────────────────────────────────────────┐
│  KPI — Overall Auth Rate    │  KPI — Total Transactions      │
├─────────────────────────────┴────────────────────────────────┤
│  Q1 — Daily auth rate trend (line chart, full width)         │
├─────────────────────────────┬────────────────────────────────┤
│  Q2 — Auth rate by issuer   │  Q3 — Decline code breakdown   │
│  (horizontal bar)           │  (bar chart)                    │
├─────────────────────────────┼────────────────────────────────┤
│  Q4 — Soft vs hard by       │  Q5 — Auth rate by card type   │
│  issuer (stacked bar)       │  × channel (pivot table)        │
├─────────────────────────────┴────────────────────────────────┤
│  Q6 — Retry success by issuer (bar)  │  Q7 — By acquirer (bar)│
└─────────────────────────────────────┴──────────────────────-─┘
```

---

## 3. Chart-by-chart build guide

### KPI scorecards (top row)
- Data source: `auth_attempt` custom query
  ```sql
  SELECT
    ROUND(COUNTIF(response_code = '00') / COUNT(*), 4) AS auth_rate,
    COUNT(*) AS total_attempts
  FROM `kipo-case01.kipo_cardpayments.auth_attempt`
  ```
- Add two **Scorecard** charts: one for `auth_rate` (formatted as %), one for `total_attempts`

### Q1 — Daily auth rate trend
- Custom query: Q1 from `03_analysis.sql`
- Chart type: **Time series**
- Dimension: `attempt_date`
- Metric: `auth_rate`
- Add **two reference lines** to mark the staggered policy change:
  - `2025-01-30` — Bancolombia ramp begins
  - `2025-02-01` — Davivienda ramp begins (~2 days lag)
- The daily series is noisy at ~150–200 attempts/day. Enable a **3-day moving average** smoothing in the chart style so the ramp is readable; the raw daily line should stay visible underneath as a lighter trace.

### Q2 — Auth rate by issuer
- Custom query: Q2 from `03_analysis.sql`
- Chart type: **Bar chart** (horizontal)
- Dimension: `issuer`
- Metric: `auth_rate`
- Sort ascending by `auth_rate` to put worst issuers at the top

### Q3 — Decline code breakdown
- Custom query: Q3 from `03_analysis.sql`
- Chart type: **Bar chart**
- Dimension: `description`
- Metric: `total_declines`
- Color by `decline_type` from the **catalog join** in Q3 (soft = orange, hard = red). The catalog is the source of truth.
- The overall top decline is `91` Card Issuer Unavailable (soft, ~24%). The smoking gun lives in the affected cohort: apply an `issuer IN ('Bancolombia','Davivienda')` filter together with a Phase-2 date filter and `05` Do Not Honor jumps to ~28%.

### Q4 — Soft vs. hard declines by issuer
- Custom query: Q4 from `03_analysis.sql`
- Chart type: **Stacked bar chart**
- Dimension: `issuer`
- Breakdown: `decline_type` (sourced from `decline_code_catalog`, not from `auth_attempt.decline_type` — see the [data-source note](#data-source-note) below)
- Metric: `decline_count`
- The reading: Bancolombia and Davivienda in Phase 2 should show ~42% hard share, well above the neobank baseline.

### Q5 — Auth rate by card type × channel
- Custom query: Q5 from `03_analysis.sql`
- Chart type: **Pivot table**
- Row dimension: `card_type`
- Column dimension: `channel`
- Metric: `auth_rate`
- Conditional formatting: red below 0.82, yellow 0.82–0.84, green above 0.84. With the v3 data, credit × e-commerce lands at ~0.81 (the only red cell), debit × in-app at ~0.81 as a noisy second-lowest, and the rest cluster around 0.83–0.85.

### Q6 — Retry success rate by issuer
- Custom query: Q6 from `03_analysis.sql`
- Chart type: **Bar chart**
- Dimension: `issuer`
- Metric: `retry_success_rate`
- Expected values: Bancolombia ~52%, Davivienda ~51%, Nequi ~55%, Nubank CO ~60%, Kipo ~64%. Sort ascending so the worst performer is at top.
- Add a `soft_declines` column as a secondary metric in the tooltip — it reminds the viewer that the retry pool is small (~225–265 first-attempt soft per affected bank), so the recoverable lift is bounded.

### Q7 — Auth rate by acquirer
- Custom query: Q7 from `03_analysis.sql`
- Chart type: **Bar chart** (horizontal)
- Dimension: `acquirer`
- Metric: `auth_rate`
- All three acquirers should land within ~1 pp of each other (~82–83%). The flat distribution is itself the finding: routing is not the cause.

---

<a id="data-source-note"></a>
### Data-source note — use the catalog for `decline_type`

`auth_attempt.decline_type` is a denormalised copy of the catalog value, populated at generation time. The v3 generator keeps it consistent, but the catalog (`decline_code_catalog.decline_type`) is the authoritative source. Any chart that splits or colors by soft/hard should join through the catalog:

```sql
FROM `kipo-case01.kipo_cardpayments.auth_attempt` aa
JOIN `kipo-case01.kipo_cardpayments.decline_code_catalog` dc
  ON aa.decline_code = dc.code
```

Q3 and Q4 in `03_analysis.sql` already do this. If you build a new chart from scratch, do the same.

---

## 4. Filters to add

Add a **date range filter** at the top of the dashboard so viewers can compare phases:
- Control: **Date range control**
- Field: `attempt_date` (Q1 data source)
- Preset shortcuts to add: **Phase 1** (2025-01-01 → 2025-01-29), **Phase 2** (2025-02-02 → 2025-03-01). The 3-day gap (2025-01-30 → 2025-02-01) is the ramp window — exclude it from both presets so the magnitude comparison is clean.

Add a **drop-down filter** for `issuer` so viewers can isolate one bank. The intended drill-down sequence is: open with the issuer filter on **All**, see the Q1 dip, then switch to **Bancolombia** to see the earlier ramp, then **Davivienda** to see the deeper trough.

---

## 5. Page 2 — Acceptance Rate

**Definition:** acceptance rate = % of payment intents that result in a successful capture.
This is broader than auth rate — it captures every drop-off point in the funnel: risk blocks, issuer declines, and post-auth abandonment.

### Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│  KPI — Acceptance Rate  │  KPI — Auth Rate  │  KPI — Risk Block Rate │
├────────────────────────────────────────────────────────────────────-┤
│  Q8 — Funnel breakdown (scorecard row: intents → attempted →        │
│        authorized → captured, with % at each stage)                 │
├─────────────────────────────────────────────────────────────────────┤
│  Q9 — Daily acceptance rate vs auth rate (dual-line, full width)    │
├──────────────────────────────────┬──────────────────────────────────┤
│  Q10 — Acceptance rate by        │  Q11 — Risk block by fraud       │
│  channel (grouped bar)           │  score band (stacked bar)        │
├──────────────────────────────────┼──────────────────────────────────┤
│  Q12 — 3DS impact on capture     │  Q13 — Acceptance by merchant    │
│  rate (table)                    │  category, top 10 (bar)          │
└──────────────────────────────────┴──────────────────────────────────┘
```

### KPI scorecards (top row)
- Data source: Q8 custom query
- Three **Scorecard** charts: `acceptance_rate` (%), `auth_rate` (%), `risk_block_rate` (%)
- Apply conditional formatting: red if `acceptance_rate` < 0.80

### Q8 — Funnel breakdown
- Custom query: Q8 from `03_analysis.sql`
- Chart type: Four **Scorecard** tiles in a horizontal row, one per funnel stage:
  `total_intents` → `attempted` (+ `attempt_rate`) → `authorized` (+ `auth_rate`) → `captured` (+ `acceptance_rate`)
- This shows absolute drop-off at each step

### Q9 — Daily acceptance rate vs auth rate
- Custom query: Q9 from `03_analysis.sql`
- Chart type: **Time series** with two metrics: `auth_rate` (blue) and `acceptance_rate` (green)
- Dimension: `txn_date`
- Add **two reference lines** matching Page 1: `2025-01-30` (Bancolombia ramp) and `2025-02-01` (Davivienda ramp)
- Enable 3-day moving average smoothing — same noise level as Q1
- If the two metrics move together, the drop is upstream of capture (risk + auth). If they diverge with `acceptance_rate` falling further than `auth_rate`, look at risk blocks (Q11) or post-auth abandonment (Q12).

### Q10 — Acceptance rate by channel
- Custom query: Q10 from `03_analysis.sql`
- Chart type: **Grouped bar chart**
- Dimension: `channel`
- Metrics: `auth_rate` and `acceptance_rate` as two bars per channel
- Sort by `acceptance_rate` ascending to surface the worst channel first

### Q11 — Risk block breakdown by fraud score band
- Custom query: Q11 from `03_analysis.sql`
- Chart type: **Stacked bar chart**
- Dimension: `fraud_score_band`
- Breakdown: `decision` (pass = green, block = red)
- Metric: `intents`
- This shows which score bands contain the most blocked payments

### Q12 — 3DS impact on post-auth capture rate
- Custom query: Q12 from `03_analysis.sql`
- Chart type: **Table** with conditional formatting
- Dimensions: `is_3ds`, `three_ds_result`
- Metrics: `authorizations`, `captured`, `capture_to_auth_rate`
- Apply conditional formatting on `capture_to_auth_rate`: red below 0.85, yellow 0.85–0.92, green ≥ 0.92
- This is the chart that **closes out the 3DS hypothesis**. The case study argues that the auth drop is upstream of 3DS (the bank refuses before the cardholder is challenged). If `capture_to_auth_rate` on `three_ds_result = Y` is roughly the same as on non-3DS, the data backs that argument. A red cell here would re-open it.

### Q13 — Acceptance rate by merchant category
- Custom query: Q13 from `03_analysis.sql`
- Chart type: **Bar chart** (horizontal)
- Dimension: `mcc_description`
- Metric: `acceptance_rate`
- Secondary metric: `total_intents` (bubble size or tooltip)
- Sort ascending by `acceptance_rate` to put worst categories at top
- Limit to top 10 by volume (already applied in query)

### Filters for Page 2
- Reuse the same **date range control** from Page 1 (apply to Q9 via `txn_date`)
- Add a **drop-down filter** for `channel` linked to Q10

---

## 6. Page 0 — Overview

**Purpose:** executive view of the six headline KPIs before drilling into any detail page. In Looker Studio, set this as the first page of the report.

### Layout

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ Auth Rate │ Acceptance Rate │ Fraud Rate │ Chargeback Rate │ Cost/Txn │ Days to Sett. │
├────────────────────────────────────────────────────────────────────────────────────────┤
│  OV2 — Auth rate vs. acceptance rate trend (line, full width) — reuse Q9 query        │
├──────────────────────────────────────┬─────────────────────────────────────────────────┤
│  OV3 — Fraud & chargeback rate       │  OV4 — Cost per transaction by acquirer         │
│  by week (dual-line time series)     │  (stacked bar: interchange / scheme / acq.)     │
├──────────────────────────────────────┴─────────────────────────────────────────────────┤
│  OV5 — Time to settlement by acquirer (horizontal bar, full width)                     │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### KPI scorecards (top row)
- Data source: OV1 custom query
- Six **Scorecard** charts, one per metric. Thresholds are calibrated against the v3 baseline (overall 82.7%, B+D pulling the average down), not against an aspirational target:
  - `auth_rate` — label "Auth Rate". Red < 0.80, yellow 0.80–0.84, green ≥ 0.84. (The current 60-day blended rate of 82.7% lands as yellow because Phase 2 weighs it down; Phase 1 alone would be green.)
  - `acceptance_rate` — label "Acceptance Rate". Red < 0.70, yellow 0.70–0.75, green ≥ 0.75.
  - `fraud_rate` — label "Fraud Rate". Red > 0.01, yellow 0.005–0.01, green < 0.005.
  - `chargeback_rate` — label "Chargeback Rate". Red > 0.02, yellow 0.01–0.02, green < 0.01.
  - `cost_per_txn_usd` — label "Cost / Transaction (USD)". No threshold; show with 4 decimals.
  - `avg_days_to_settlement` — label "Avg Days to Settlement". Red > 2, yellow 2, green < 2 (T+2 is the industry standard).

### OV2 — Auth rate vs. acceptance rate trend
- Custom query: **Q9** from `03_analysis.sql` (same query used on Page 2)
- Chart type: **Time series** — `auth_rate` (blue), `acceptance_rate` (green)
- Dimension: `txn_date`
- Add **two reference lines**: `2025-01-30` (Bancolombia ramp) and `2025-02-01` (Davivienda ramp)
- Enable 3-day moving average smoothing

### OV3 — Fraud & chargeback rate by week
- Custom query: OV3 from `03_analysis.sql`
- Chart type: **Time series** — `fraud_rate` (red), `chargeback_rate` (orange)
- Dimension: `week`
- Weekly granularity is intentional: dispute volumes are too low for meaningful daily rates

### OV4 — Cost per transaction by acquirer
- Custom query: OV4 from `03_analysis.sql`
- Chart type: **Stacked bar chart** with combo line
- Dimension: `acquirer`
- Stacked bars: `interchange_fees_usd`, `scheme_fees_usd`, `acquirer_fees_usd`
- Combo line (right axis): `cost_per_txn_usd`
- Sort by `cost_per_txn_usd` descending to surface the most expensive acquirer

### OV5 — Time to settlement by acquirer
- Custom query: OV5 from `03_analysis.sql`
- Chart type: **Bar chart** (horizontal)
- Dimension: `acquirer`
- Metric: `avg_days_to_settlement`
- Add a **reference line at 2** (industry standard T+2 settlement)
- Add `min_days` and `max_days` as tooltip fields to show the range
- Sort by `avg_days_to_settlement` ascending to surface the fastest acquirer

### Filters for Page 0
- Reuse the same **date range control** from Page 1 (apply to OV2 via `txn_date` and OV3 via `week`)
