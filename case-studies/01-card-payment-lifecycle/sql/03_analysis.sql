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
