LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.issuer`
  (id STRING,
   name STRING,
   short_name STRING,
   country STRING,
   network STRING,
   issuer_type STRING,
   avg_auth_rate NUMERIC,
   avg_soft_decline_rate NUMERIC,
   created_at TIMESTAMP)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/issuers.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.bin_range`
  (id STRING,
   issuer_id STRING,
   bin_prefix STRING,
   bin_length INT64,
   card_type STRING,
   card_brand STRING,
   card_level STRING,
   is_active BOOL,
   created_at TIMESTAMP)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/bin_ranges.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.card`
  (id STRING,
   user_id STRING,
   bin_range_id STRING,
   last_four STRING,
   network_token STRING,
   card_type STRING,
   status STRING,
   created_at TIMESTAMP,
   expires_at TIMESTAMP)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/cards.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.merchant`
  (id STRING,
   name STRING,
   legal_name STRING,
   mcc STRING,
   mcc_description STRING,
   country STRING,
   city STRING,
   channel STRING,
   status STRING,
   onboarded_at TIMESTAMP)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/merchants.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.acquirer`
  (id STRING,
   name STRING,
   processor_name STRING,
   network STRING,
   country STRING,
   historical_auth_rate NUMERIC,
   status STRING)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/acquirers.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.decline_code_catalog`
  (code STRING,
   description STRING,
   decline_type STRING,
   recommended_action STRING,
   source STRING)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/decline_code_catalog.csv']
);

LOAD DATA INTO `kipo-case01.kipo_cardpayments.payment_intent`
  (id STRING,
   card_id STRING,
   network_token STRING,
   user_id STRING,
   merchant_id STRING,
   order_id STRING,
   customer_type STRING,
   amount_usd NUMERIC,
   currency STRING,
   channel STRING,
   entry_mode STRING,
   idempotency_key STRING,
   status STRING,
   created_at TIMESTAMP)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/payment_intents.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.risk_evaluation`
  (id STRING,
   payment_intent_id STRING,
   fraud_score INT64,
   decision STRING,
   block_reason STRING,
   device_id STRING,
   ip_address STRING,
   geolocation STRING,
   velocity_flag BOOL,
   bin_flag BOOL,
   blacklist_hit BOOL,
   evaluated_at TIMESTAMP)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/risk_evaluations.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.auth_attempt`
  (id STRING,
   payment_intent_id STRING,
   acquirer_id STRING,
   attempt_number INT64,
   routing_reason STRING,
   response_code STRING,
   decline_code STRING,
   decline_type STRING,
   retried BOOL,
   attempted_at TIMESTAMP)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/auth_attempts.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.authorization`
  (id STRING,
   payment_intent_id STRING,
   acquirer_id STRING,
   processor_id STRING,
   network STRING,
   auth_code STRING,
   response_code STRING,
   decline_code STRING,
   decline_type STRING,
   is_3ds BOOL,
   three_ds_result STRING,
   authorized_amount_usd NUMERIC,
   authorized_at TIMESTAMP,
   expires_at TIMESTAMP)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/authorizations.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.capture`
  (id STRING,
   authorization_id STRING,
   captured_amount_usd NUMERIC,
   is_partial BOOL,
   captured_at TIMESTAMP,
   late_capture_at TIMESTAMP)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/captures.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.void_reversal`
  (id STRING,
   authorization_id STRING,
   reason STRING,
   initiated_by STRING,
   voided_at TIMESTAMP)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/void_reversals.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.settlement_batch`
  (id STRING,
   acquirer_id STRING,
   settlement_date DATE,
   transaction_count INT64,
   gross_amount_usd NUMERIC,
   interchange_fee_usd NUMERIC,
   scheme_fee_usd NUMERIC,
   acquirer_fee_usd NUMERIC,
   net_amount_usd NUMERIC,
   status STRING,
   created_at TIMESTAMP)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/settlement_batches.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.refund`
  (id STRING,
   capture_id STRING,
   settlement_batch_id STRING,
   amount_usd NUMERIC,
   is_partial BOOL,
   reason STRING,
   status STRING,
   initiated_by STRING,
   requested_at TIMESTAMP,
   processed_at TIMESTAMP)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/refunds.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.dispute`
  (id STRING,
   capture_id STRING,
   chargeback_id STRING,
   reason_code STRING,
   dispute_type STRING,
   disputed_amount_usd NUMERIC,
   chargeback_fee_usd NUMERIC,
   status STRING,
   outcome STRING,
   opened_at TIMESTAMP,
   due_date TIMESTAMP,
   resolved_at TIMESTAMP)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/disputes.csv']
);
