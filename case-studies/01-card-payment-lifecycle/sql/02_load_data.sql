-- ============================================================
-- Case Study 01 · Kipo Fintech · Card Payment Lifecycle
-- Load CSV data from Google Cloud Storage into BigQuery
-- ============================================================
--
-- Prerequisites:
--   1. Run 01_ddl.sql to create all tables.
--   2. Upload the contents of data/raw/ to a GCS bucket:
--        gsutil cp data/raw/*.csv gs://your-bucket/kipo/raw/
--   3. Replace `your-project-id` and `your-bucket` below.
--   4. Run each LOAD DATA statement in BigQuery (UI or bq CLI).
--
-- Alternative (bq CLI):
--   bq load --source_format=CSV --skip_leading_rows=1 \
--     your-project-id:kipo_payments.issuer \
--     gs://your-bucket/kipo/raw/issuers.csv
-- ============================================================

LOAD DATA INTO `kipo-case01.kipo_cardpayments.issuer`
  (id, name, short_name, country, network, issuer_type,
   avg_auth_rate, avg_soft_decline_rate, created_at)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://your-bucket/kipo/raw/issuers.csv']
);

LOAD DATA INTO `kipo-case01.kipo_cardpayments.bin_range`
  (id, issuer_id, bin_prefix, bin_length, card_type, card_brand,
   card_level, is_active, created_at)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://your-bucket/kipo/raw/bin_ranges.csv']
);

LOAD DATA INTO `kipo-case01.kipo_cardpayments.card`
  (id, user_id, bin_range_id, last_four, network_token, card_type,
   status, created_at, expires_at)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://your-bucket/kipo/raw/cards.csv']
);

LOAD DATA INTO `kipo-case01.kipo_cardpayments.merchant`
  (id, name, legal_name, mcc, mcc_description, country, city,
   channel, status, onboarded_at)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://your-bucket/kipo/raw/merchants.csv']
);

LOAD DATA INTO `kipo-case01.kipo_cardpayments.acquirer`
  (id, name, processor_name, network, country, historical_auth_rate, status)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://your-bucket/kipo/raw/acquirers.csv']
);

LOAD DATA INTO `kipo-case01.kipo_cardpayments.decline_code_catalog`
  (code, description, decline_type, recommended_action, source)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://your-bucket/kipo/raw/decline_code_catalog.csv']
);

LOAD DATA INTO `kipo-case01.kipo_cardpayments.payment_intent`
  (id, card_id, network_token, user_id, merchant_id, order_id,
   customer_type, amount_usd, currency, channel, entry_mode,
   idempotency_key, status, created_at)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://your-bucket/kipo/raw/payment_intents.csv']
);

LOAD DATA INTO `kipo-case01.kipo_cardpayments.risk_evaluation`
  (id, payment_intent_id, fraud_score, decision, block_reason,
   device_id, ip_address, geolocation, velocity_flag, bin_flag,
   blacklist_hit, evaluated_at)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://your-bucket/kipo/raw/risk_evaluations.csv']
);

LOAD DATA INTO `kipo-case01.kipo_cardpayments.auth_attempt`
  (id, payment_intent_id, acquirer_id, attempt_number, routing_reason,
   response_code, decline_code, decline_type, retried, attempted_at)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://your-bucket/kipo/raw/auth_attempts.csv']
);

LOAD DATA INTO `kipo-case01.kipo_cardpayments.authorization`
  (id, payment_intent_id, acquirer_id, processor_id, network, auth_code,
   response_code, decline_code, decline_type, is_3ds, three_ds_result,
   authorized_amount_usd, authorized_at, expires_at)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://your-bucket/kipo/raw/authorizations.csv']
);

LOAD DATA INTO `kipo-case01.kipo_cardpayments.capture`
  (id, authorization_id, captured_amount_usd, is_partial,
   captured_at, late_capture_at)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://your-bucket/kipo/raw/captures.csv']
);

LOAD DATA INTO `kipo-case01.kipo_cardpayments.void_reversal`
  (id, authorization_id, reason, initiated_by, voided_at)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://your-bucket/kipo/raw/void_reversals.csv']
);

LOAD DATA INTO `kipo-case01.kipo_cardpayments.settlement_batch`
  (id, acquirer_id, settlement_date, transaction_count, gross_amount_usd,
   interchange_fee_usd, scheme_fee_usd, acquirer_fee_usd, net_amount_usd,
   status, created_at)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://your-bucket/kipo/raw/settlement_batches.csv']
);

LOAD DATA INTO `kipo-case01.kipo_cardpayments.refund`
  (id, capture_id, settlement_batch_id, amount_usd, is_partial, reason,
   status, initiated_by, requested_at, processed_at)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://your-bucket/kipo/raw/refunds.csv']
);

LOAD DATA INTO `kipo-case01.kipo_cardpayments.dispute`
  (id, capture_id, chargeback_id, reason_code, dispute_type,
   disputed_amount_usd, chargeback_fee_usd, status, outcome,
   opened_at, due_date, resolved_at)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://your-bucket/kipo/raw/disputes.csv']
);
