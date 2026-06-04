-- ============================================================
-- Case Study 01 · Kipo Fintech · Card Payment Lifecycle
-- Analysis queries — "Why did Kipo's auth rate drop?"
-- Replace `your-project-id` with your GCP project ID.
-- ============================================================


-- ── Q1 · Daily auth rate trend ─────────────────────────────────────────────────
-- Business question: Did the authorization rate actually drop? When did it start?
-- Chart: Line chart with date on X, auth rate % on Y. Add a reference line at day 30.

SELECT
  DATE(aa.attempted_at)                                    AS attempt_date,
  COUNT(*)                                                 AS total_attempts,
  COUNTIF(aa.response_code = '00')                         AS approved,
  ROUND(COUNTIF(aa.response_code = '00') / COUNT(*), 4)   AS auth_rate
FROM `kipo-case01.kipo_cardpayments.auth_attempt` aa
GROUP BY 1
ORDER BY 1;


-- ── Q2 · Auth rate by issuer ───────────────────────────────────────────────────
-- Business question: Which issuers are dragging the overall rate down?
-- Chart: Horizontal bar chart, sorted by auth_rate ascending.

SELECT
  i.name                                                   AS issuer,
  i.issuer_type,
  COUNT(*)                                                 AS total_attempts,
  COUNTIF(aa.response_code = '00')                         AS approved,
  ROUND(COUNTIF(aa.response_code = '00') / COUNT(*), 4)   AS auth_rate
FROM `kipo-case01.kipo_cardpayments.auth_attempt`  aa
JOIN `kipo-case01.kipo_cardpayments.payment_intent` pi ON aa.payment_intent_id = pi.id
JOIN `kipo-case01.kipo_cardpayments.card`           c  ON pi.card_id = c.id
JOIN `kipo-case01.kipo_cardpayments.bin_range`      br ON c.bin_range_id = br.id
JOIN `kipo-case01.kipo_cardpayments.issuer`         i  ON br.issuer_id = i.id
GROUP BY 1, 2
ORDER BY auth_rate ASC;


-- ── Q3 · Decline code breakdown (top 10) ──────────────────────────────────────
-- Business question: What reasons are being given for the declines?
-- Chart: Bar chart, sorted by total_declines descending.

SELECT
  aa.decline_code,
  dc.description,
  dc.decline_type,
  COUNT(*)                                                 AS total_declines,
  ROUND(COUNT(*) / SUM(COUNT(*)) OVER (), 4)              AS pct_of_all_declines
FROM `kipo-case01.kipo_cardpayments.auth_attempt`    aa
JOIN `kipo-case01.kipo_cardpayments.decline_code_catalog` dc ON aa.decline_code = dc.code
WHERE aa.response_code != '00'
GROUP BY 1, 2, 3
ORDER BY total_declines DESC
LIMIT 10;


-- ── Q4 · Soft vs. hard decline split by issuer ────────────────────────────────
-- Business question: Are the declines recoverable (soft) or final (hard)?
-- Chart: Stacked bar — one bar per issuer, split by soft/hard.

SELECT
  i.name                                                   AS issuer,
  aa.decline_type,
  COUNT(*)                                                 AS decline_count
FROM `kipo-case01.kipo_cardpayments.auth_attempt`   aa
JOIN `kipo-case01.kipo_cardpayments.payment_intent` pi ON aa.payment_intent_id = pi.id
JOIN `kipo-case01.kipo_cardpayments.card`           c  ON pi.card_id = c.id
JOIN `kipo-case01.kipo_cardpayments.bin_range`      br ON c.bin_range_id = br.id
JOIN `kipo-case01.kipo_cardpayments.issuer`         i  ON br.issuer_id = i.id
WHERE aa.decline_type IN ('soft', 'hard')
GROUP BY 1, 2
ORDER BY 1, 2;


-- ── Q5 · Auth rate by card type × channel ─────────────────────────────────────
-- Business question: Is the drop concentrated in a specific card type or channel?
-- Chart: Pivot table or heat map — rows = card_type, columns = channel.

SELECT
  c.card_type,
  pi.channel,
  COUNT(*)                                                 AS total_attempts,
  COUNTIF(aa.response_code = '00')                         AS approved,
  ROUND(COUNTIF(aa.response_code = '00') / COUNT(*), 4)   AS auth_rate
FROM `kipo-case01.kipo_cardpayments.auth_attempt`   aa
JOIN `kipo-case01.kipo_cardpayments.payment_intent` pi ON aa.payment_intent_id = pi.id
JOIN `kipo-case01.kipo_cardpayments.card`           c  ON pi.card_id = c.id
GROUP BY 1, 2
ORDER BY 1, 2;


-- ── Q6 · Retry success rate ────────────────────────────────────────────────────
-- Business question: When we retry soft declines, how often do we convert them?
-- Chart: Scorecard (overall retry success rate) + bar by issuer.

WITH first_attempts AS (
  SELECT
    aa.payment_intent_id,
    aa.decline_type,
    aa.retried,
    i.name AS issuer
  FROM `kipo-case01.kipo_cardpayments.auth_attempt`   aa
  JOIN `kipo-case01.kipo_cardpayments.payment_intent` pi ON aa.payment_intent_id = pi.id
  JOIN `kipo-case01.kipo_cardpayments.card`           c  ON pi.card_id = c.id
  JOIN `kipo-case01.kipo_cardpayments.bin_range`      br ON c.bin_range_id = br.id
  JOIN `kipo-case01.kipo_cardpayments.issuer`         i  ON br.issuer_id = i.id
  WHERE aa.attempt_number = 1
    AND aa.decline_type = 'soft'
),
second_attempts AS (
  SELECT
    payment_intent_id,
    MAX(CASE WHEN response_code = '00' THEN 1 ELSE 0 END) AS retry_succeeded
  FROM `kipo-case01.kipo_cardpayments.auth_attempt`
  WHERE attempt_number = 2
  GROUP BY payment_intent_id
)
SELECT
  fa.issuer,
  COUNT(*)                                                       AS soft_declines,
  COUNTIF(fa.retried)                                            AS retried_count,
  COUNTIF(sa.retry_succeeded = 1)                                AS retry_converted,
  ROUND(COUNTIF(sa.retry_succeeded = 1) / NULLIF(COUNTIF(fa.retried), 0), 4) AS retry_success_rate
FROM first_attempts fa
LEFT JOIN second_attempts sa ON fa.payment_intent_id = sa.payment_intent_id
GROUP BY 1
ORDER BY retry_success_rate ASC;


-- ── Q7 · Auth rate by acquirer ─────────────────────────────────────────────────
-- Business question: Is one acquirer performing better? Should we shift routing?
-- Chart: Horizontal bar chart sorted by auth_rate.

SELECT
  aq.name                                                  AS acquirer,
  aq.processor_name,
  COUNT(*)                                                 AS total_attempts,
  COUNTIF(aa.response_code = '00')                         AS approved,
  ROUND(COUNTIF(aa.response_code = '00') / COUNT(*), 4)   AS auth_rate
FROM `kipo-case01.kipo_cardpayments.auth_attempt` aa
JOIN `kipo-case01.kipo_cardpayments.acquirer`     aq ON aa.acquirer_id = aq.id
GROUP BY 1, 2
ORDER BY auth_rate ASC;


-- ============================================================
-- PAGE 2 · Acceptance Rate
-- Acceptance rate = % of payment intents that result in a
-- successful capture, covering all drop-off points:
-- risk blocks, auth declines, and capture failures.
-- ============================================================


-- ── Q8 · Payment funnel (acceptance rate overview) ────────────────────────────
-- Business question: Where in the funnel are we losing payments?
-- Chart: Scorecard row — one tile per funnel stage.

WITH funnel AS (
  SELECT
    pi.id                AS intent_id,
    re.decision          AS risk_decision,
    aa.any_attempted,
    auth.authorized,
    cap.captured
  FROM `kipo-case01.kipo_cardpayments.payment_intent` pi
  LEFT JOIN `kipo-case01.kipo_cardpayments.risk_evaluation` re
    ON re.payment_intent_id = pi.id
  LEFT JOIN (
    SELECT DISTINCT payment_intent_id, TRUE AS any_attempted
    FROM `kipo-case01.kipo_cardpayments.auth_attempt`
  ) aa ON aa.payment_intent_id = pi.id
  LEFT JOIN (
    SELECT DISTINCT payment_intent_id, TRUE AS authorized
    FROM `kipo-case01.kipo_cardpayments.authorization`
    WHERE response_code = '00'
  ) auth ON auth.payment_intent_id = pi.id
  LEFT JOIN (
    SELECT DISTINCT au.payment_intent_id, TRUE AS captured
    FROM `kipo-case01.kipo_cardpayments.capture` cap
    JOIN `kipo-case01.kipo_cardpayments.authorization` au ON cap.authorization_id = au.id
  ) cap ON cap.payment_intent_id = pi.id
)
SELECT
  COUNT(*)                                               AS total_intents,
  COUNTIF(risk_decision = 'block')                       AS risk_blocked,
  ROUND(COUNTIF(risk_decision = 'block') / COUNT(*), 4)  AS risk_block_rate,
  COUNTIF(any_attempted)                                 AS attempted,
  ROUND(COUNTIF(any_attempted) / COUNT(*), 4)            AS attempt_rate,
  COUNTIF(authorized)                                    AS authorized,
  ROUND(COUNTIF(authorized) / COUNT(*), 4)               AS auth_rate,
  COUNTIF(captured)                                      AS captured,
  ROUND(COUNTIF(captured) / COUNT(*), 4)                 AS acceptance_rate
FROM funnel;


-- ── Q9 · Daily acceptance rate vs auth rate trend ─────────────────────────────
-- Business question: Do acceptance rate and auth rate move together, or diverge?
-- Chart: Dual-line time series — acceptance_rate and auth_rate on the same axis.

WITH daily_outcomes AS (
  SELECT
    DATE(pi.created_at) AS txn_date,
    pi.id               AS intent_id,
    auth.authorized,
    cap.captured
  FROM `kipo-case01.kipo_cardpayments.payment_intent` pi
  LEFT JOIN (
    SELECT DISTINCT payment_intent_id, TRUE AS authorized
    FROM `kipo-case01.kipo_cardpayments.authorization`
    WHERE response_code = '00'
  ) auth ON auth.payment_intent_id = pi.id
  LEFT JOIN (
    SELECT DISTINCT au.payment_intent_id, TRUE AS captured
    FROM `kipo-case01.kipo_cardpayments.capture` cap
    JOIN `kipo-case01.kipo_cardpayments.authorization` au ON cap.authorization_id = au.id
  ) cap ON cap.payment_intent_id = pi.id
)
SELECT
  txn_date,
  COUNT(*)                                       AS total_intents,
  COUNTIF(authorized)                            AS authorized_count,
  COUNTIF(captured)                              AS captured_count,
  ROUND(COUNTIF(authorized) / COUNT(*), 4)       AS auth_rate,
  ROUND(COUNTIF(captured) / COUNT(*), 4)         AS acceptance_rate
FROM daily_outcomes
GROUP BY 1
ORDER BY 1;


-- ── Q10 · Acceptance rate by channel ──────────────────────────────────────────
-- Business question: Which channel (in-store / online / mobile) has the lowest acceptance?
-- Chart: Grouped bar — auth_rate vs acceptance_rate per channel.

WITH intent_outcome AS (
  SELECT
    pi.channel,
    pi.id AS intent_id,
    auth.authorized,
    cap.captured
  FROM `kipo-case01.kipo_cardpayments.payment_intent` pi
  LEFT JOIN (
    SELECT DISTINCT payment_intent_id, TRUE AS authorized
    FROM `kipo-case01.kipo_cardpayments.authorization`
    WHERE response_code = '00'
  ) auth ON auth.payment_intent_id = pi.id
  LEFT JOIN (
    SELECT DISTINCT au.payment_intent_id, TRUE AS captured
    FROM `kipo-case01.kipo_cardpayments.capture` cap
    JOIN `kipo-case01.kipo_cardpayments.authorization` au ON cap.authorization_id = au.id
  ) cap ON cap.payment_intent_id = pi.id
)
SELECT
  channel,
  COUNT(*)                                       AS total_intents,
  COUNTIF(authorized)                            AS authorized,
  COUNTIF(captured)                              AS captured,
  ROUND(COUNTIF(authorized) / COUNT(*), 4)       AS auth_rate,
  ROUND(COUNTIF(captured) / COUNT(*), 4)         AS acceptance_rate
FROM intent_outcome
GROUP BY 1
ORDER BY acceptance_rate ASC;


-- ── Q11 · Risk block breakdown by fraud score band ────────────────────────────
-- Business question: What fraud score thresholds are killing acceptance?
-- Chart: Stacked bar — intents per score band, split by risk decision (pass/block).

SELECT
  CASE
    WHEN re.fraud_score < 30 THEN '1 · Low (0–29)'
    WHEN re.fraud_score < 60 THEN '2 · Medium (30–59)'
    WHEN re.fraud_score < 80 THEN '3 · High (60–79)'
    ELSE                          '4 · Very High (80+)'
  END                                            AS fraud_score_band,
  re.decision,
  COUNT(*)                                       AS intents,
  ROUND(COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY re.decision), 4) AS pct_within_decision
FROM `kipo-case01.kipo_cardpayments.risk_evaluation` re
GROUP BY 1, 2
ORDER BY 1, 2;


-- ── Q12 · 3DS impact on post-auth capture rate ────────────────────────────────
-- Business question: Does 3DS friction cause customers to abandon after auth?
-- Chart: Table — rows = 3DS result, columns = authorizations / captured / capture rate.

WITH auth_with_capture AS (
  SELECT
    au.is_3ds,
    au.three_ds_result,
    au.payment_intent_id,
    cap.captured
  FROM `kipo-case01.kipo_cardpayments.authorization` au
  LEFT JOIN (
    SELECT DISTINCT au2.payment_intent_id, TRUE AS captured
    FROM `kipo-case01.kipo_cardpayments.capture` cap2
    JOIN `kipo-case01.kipo_cardpayments.authorization` au2 ON cap2.authorization_id = au2.id
  ) cap ON cap.payment_intent_id = au.payment_intent_id
)
SELECT
  is_3ds,
  COALESCE(three_ds_result, 'N/A')               AS three_ds_result,
  COUNT(*)                                       AS authorizations,
  COUNTIF(captured)                              AS captured,
  ROUND(COUNTIF(captured) / COUNT(*), 4)         AS capture_to_auth_rate
FROM auth_with_capture
GROUP BY 1, 2
ORDER BY 1, 2;


-- ── Q13 · Acceptance rate by merchant category (top 10 by volume) ─────────────
-- Business question: Are certain merchant categories dragging acceptance down?
-- Chart: Horizontal bar chart sorted by acceptance_rate ascending.

WITH intent_outcome AS (
  SELECT
    m.mcc_description,
    pi.id AS intent_id,
    auth.authorized,
    cap.captured
  FROM `kipo-case01.kipo_cardpayments.payment_intent` pi
  JOIN `kipo-case01.kipo_cardpayments.merchant` m ON pi.merchant_id = m.id
  LEFT JOIN (
    SELECT DISTINCT payment_intent_id, TRUE AS authorized
    FROM `kipo-case01.kipo_cardpayments.authorization`
    WHERE response_code = '00'
  ) auth ON auth.payment_intent_id = pi.id
  LEFT JOIN (
    SELECT DISTINCT au.payment_intent_id, TRUE AS captured
    FROM `kipo-case01.kipo_cardpayments.capture` cap
    JOIN `kipo-case01.kipo_cardpayments.authorization` au ON cap.authorization_id = au.id
  ) cap ON cap.payment_intent_id = pi.id
)
SELECT
  mcc_description,
  COUNT(*)                                       AS total_intents,
  COUNTIF(authorized)                            AS authorized,
  COUNTIF(captured)                              AS captured,
  ROUND(COUNTIF(authorized) / COUNT(*), 4)       AS auth_rate,
  ROUND(COUNTIF(captured) / COUNT(*), 4)         AS acceptance_rate
FROM intent_outcome
GROUP BY 1
ORDER BY total_intents DESC
LIMIT 10;


-- ============================================================
-- PAGE 0 · Overview
-- Six headline KPIs: authorization rate, acceptance rate,
-- fraud rate, chargeback rate, cost per transaction,
-- and average days to settlement.
-- ============================================================


-- ── OV1 · KPI overview scorecard ─────────────────────────────────────────────
-- Business question: How is the business performing across all key metrics?
-- Chart: Six Scorecard tiles in a horizontal row.

WITH
auth_kpi AS (
  SELECT ROUND(COUNTIF(response_code = '00') / COUNT(*), 4) AS auth_rate
  FROM `kipo-case01.kipo_cardpayments.auth_attempt`
),
acceptance_kpi AS (
  SELECT ROUND(COUNTIF(cap.captured) / COUNT(*), 4) AS acceptance_rate
  FROM `kipo-case01.kipo_cardpayments.payment_intent` pi
  LEFT JOIN (
    SELECT DISTINCT au.payment_intent_id, TRUE AS captured
    FROM `kipo-case01.kipo_cardpayments.capture` c
    JOIN `kipo-case01.kipo_cardpayments.authorization` au ON c.authorization_id = au.id
  ) cap ON cap.payment_intent_id = pi.id
),
dispute_kpi AS (
  SELECT
    ROUND(
      COUNT(DISTINCT CASE WHEN d.dispute_type = 'fraud' THEN cap.id END)
      / NULLIF(COUNT(DISTINCT cap.id), 0), 4
    ) AS fraud_rate,
    ROUND(
      COUNT(DISTINCT d.id) / NULLIF(COUNT(DISTINCT cap.id), 0), 4
    ) AS chargeback_rate
  FROM `kipo-case01.kipo_cardpayments.capture` cap
  LEFT JOIN `kipo-case01.kipo_cardpayments.dispute` d ON d.capture_id = cap.id
),
cost_kpi AS (
  SELECT
    ROUND(
      SUM(interchange_fee_usd + scheme_fee_usd + acquirer_fee_usd)
      / NULLIF(SUM(transaction_count), 0), 4
    ) AS cost_per_txn_usd
  FROM `kipo-case01.kipo_cardpayments.settlement_batch`
  WHERE status = 'settled'
),
cap_acq AS (
  SELECT
    cap.id              AS capture_id,
    au.acquirer_id,
    DATE(cap.captured_at) AS capture_date
  FROM `kipo-case01.kipo_cardpayments.capture` cap
  JOIN `kipo-case01.kipo_cardpayments.authorization` au ON cap.authorization_id = au.id
),
cap_settled AS (
  SELECT
    ca.capture_id,
    ca.capture_date,
    MIN(sb.settlement_date) AS settlement_date
  FROM cap_acq ca
  JOIN `kipo-case01.kipo_cardpayments.settlement_batch` sb
    ON sb.acquirer_id = ca.acquirer_id
   AND sb.settlement_date >= ca.capture_date
   AND sb.status = 'settled'
  GROUP BY ca.capture_id, ca.capture_date
),
settlement_kpi AS (
  SELECT ROUND(AVG(DATE_DIFF(settlement_date, capture_date, DAY)), 1) AS avg_days_to_settlement
  FROM cap_settled
)
SELECT
  a.auth_rate,
  b.acceptance_rate,
  c.fraud_rate,
  c.chargeback_rate,
  d.cost_per_txn_usd,
  e.avg_days_to_settlement
FROM auth_kpi       a
CROSS JOIN acceptance_kpi  b
CROSS JOIN dispute_kpi     c
CROSS JOIN cost_kpi        d
CROSS JOIN settlement_kpi  e;


-- ── OV3 · Fraud & chargeback rate by week ─────────────────────────────────────
-- Business question: Are fraud and chargeback rates trending up over time?
-- Chart: Dual-line time series — fraud_rate (red) and chargeback_rate (orange).
-- Note: weekly granularity because dispute volumes are too low for meaningful daily rates.

SELECT
  DATE_TRUNC(DATE(cap.captured_at), WEEK)                                      AS week,
  COUNT(DISTINCT cap.id)                                                       AS total_captures,
  COUNT(DISTINCT CASE WHEN d.dispute_type = 'fraud' THEN cap.id END)           AS fraud_captures,
  COUNT(DISTINCT d.id)                                                         AS total_chargebacks,
  ROUND(
    COUNT(DISTINCT CASE WHEN d.dispute_type = 'fraud' THEN cap.id END)
    / NULLIF(COUNT(DISTINCT cap.id), 0), 4
  )                                                                            AS fraud_rate,
  ROUND(
    COUNT(DISTINCT d.id) / NULLIF(COUNT(DISTINCT cap.id), 0), 4
  )                                                                            AS chargeback_rate
FROM `kipo-case01.kipo_cardpayments.capture` cap
LEFT JOIN `kipo-case01.kipo_cardpayments.dispute` d ON d.capture_id = cap.id
GROUP BY 1
ORDER BY 1;


-- ── OV4 · Cost per transaction by acquirer ────────────────────────────────────
-- Business question: Which acquirer is most expensive? What drives the cost?
-- Chart: Stacked bar (interchange / scheme / acquirer fees) + combo line for cost_per_txn_usd.

SELECT
  aq.name                                                                      AS acquirer,
  SUM(sb.transaction_count)                                                   AS total_transactions,
  ROUND(SUM(sb.interchange_fee_usd), 2)                                      AS interchange_fees_usd,
  ROUND(SUM(sb.scheme_fee_usd), 2)                                           AS scheme_fees_usd,
  ROUND(SUM(sb.acquirer_fee_usd), 2)                                         AS acquirer_fees_usd,
  ROUND(SUM(sb.interchange_fee_usd + sb.scheme_fee_usd + sb.acquirer_fee_usd), 2) AS total_fees_usd,
  ROUND(
    SUM(sb.interchange_fee_usd + sb.scheme_fee_usd + sb.acquirer_fee_usd)
    / NULLIF(SUM(sb.transaction_count), 0), 4
  )                                                                           AS cost_per_txn_usd
FROM `kipo-case01.kipo_cardpayments.settlement_batch` sb
JOIN `kipo-case01.kipo_cardpayments.acquirer` aq ON sb.acquirer_id = aq.id
WHERE sb.status = 'settled'
GROUP BY aq.name
ORDER BY cost_per_txn_usd DESC;


-- ── OV5 · Time to settlement by acquirer ──────────────────────────────────────
-- Business question: How quickly does each acquirer settle funds?
-- Chart: Horizontal bar chart sorted by avg_days_to_settlement ascending.
-- Method: for each capture, find the earliest settlement batch for the same acquirer
--         on or after the capture date — this approximates the actual settlement cycle.

WITH cap_acq AS (
  SELECT
    cap.id              AS capture_id,
    au.acquirer_id,
    DATE(cap.captured_at) AS capture_date
  FROM `kipo-case01.kipo_cardpayments.capture` cap
  JOIN `kipo-case01.kipo_cardpayments.authorization` au ON cap.authorization_id = au.id
),
cap_settled AS (
  SELECT
    ca.capture_id,
    ca.acquirer_id,
    ca.capture_date,
    MIN(sb.settlement_date) AS settlement_date
  FROM cap_acq ca
  JOIN `kipo-case01.kipo_cardpayments.settlement_batch` sb
    ON sb.acquirer_id = ca.acquirer_id
   AND sb.settlement_date >= ca.capture_date
   AND sb.status = 'settled'
  GROUP BY ca.capture_id, ca.acquirer_id, ca.capture_date
)
SELECT
  aq.name                                                                      AS acquirer,
  COUNT(*)                                                                    AS captures_settled,
  ROUND(AVG(DATE_DIFF(cs.settlement_date, cs.capture_date, DAY)), 1)         AS avg_days_to_settlement,
  MIN(DATE_DIFF(cs.settlement_date, cs.capture_date, DAY))                   AS min_days,
  MAX(DATE_DIFF(cs.settlement_date, cs.capture_date, DAY))                   AS max_days
FROM cap_settled cs
JOIN `kipo-case01.kipo_cardpayments.acquirer` aq ON cs.acquirer_id = aq.id
GROUP BY aq.name, cs.acquirer_id
ORDER BY avg_days_to_settlement ASC;
