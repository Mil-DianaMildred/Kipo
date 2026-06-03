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
  FROM `your-project-id.kipo_payments.auth_attempt`
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
