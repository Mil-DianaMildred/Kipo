# Dashboard — Card Payment Auth Rate

Looker Studio dashboard built on BigQuery. Visualizes the 7 analysis queries from `sql/03_analysis.sql`.

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
- Add a **reference line** at the date where the drop starts (day 30 = 2025-01-31)

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
- Color by `decline_type` (soft = orange, hard = red)

### Q4 — Soft vs. hard declines by issuer
- Custom query: Q4 from `03_analysis.sql`
- Chart type: **Stacked bar chart**
- Dimension: `issuer`
- Breakdown: `decline_type`
- Metric: `decline_count`

### Q5 — Auth rate by card type × channel
- Custom query: Q5 from `03_analysis.sql`
- Chart type: **Pivot table**
- Row dimension: `card_type`
- Column dimension: `channel`
- Metric: `auth_rate`
- Apply conditional formatting: red for rates below 0.80

### Q6 — Retry success rate by issuer
- Custom query: Q6 from `03_analysis.sql`
- Chart type: **Bar chart**
- Dimension: `issuer`
- Metric: `retry_success_rate`

### Q7 — Auth rate by acquirer
- Custom query: Q7 from `03_analysis.sql`
- Chart type: **Bar chart** (horizontal)
- Dimension: `acquirer`
- Metric: `auth_rate`

---

## 4. Filters to add

Add a **date range filter** at the top of the dashboard so viewers can compare Phase 1 (Jan 1–30) vs Phase 2 (Jan 31–Mar 1):
- Control: **Date range control**
- Field: `attempt_date` (Q1 data source)

Add a **drop-down filter** for `issuer` so viewers can isolate one bank.

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
- Add a **reference line** at 2025-01-31 (same as Page 1) to mark the rate drop
- If the lines diverge, it signals a problem outside the issuer (e.g. risk blocks or capture failures)

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
- Apply conditional formatting on `capture_to_auth_rate`: red below 0.90
- Signals whether 3DS friction causes customers to drop off after a successful auth

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
