-- ============================================================
-- Case Study 01 · Kipo Fintech · Card Payment Lifecycle
-- BigQuery DDL — create all 15 tables
-- Dataset: kipo_payments
-- ============================================================

-- Replace `your-project-id` with your actual GCP project ID.
-- Run statements in order: catalogs first, then transactional tables.


-- ── Catalog tables ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS `your-project-id.kipo_payments.issuer` (
  id                    STRING    NOT NULL,
  name                  STRING    NOT NULL,
  short_name            STRING,
  country               STRING,
  network               STRING,
  issuer_type           STRING,
  avg_auth_rate         NUMERIC,
  avg_soft_decline_rate NUMERIC,
  created_at            TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `your-project-id.kipo_payments.bin_range` (
  id          STRING    NOT NULL,
  issuer_id   STRING    NOT NULL,
  bin_prefix  STRING,
  bin_length  INT64,
  card_type   STRING,
  card_brand  STRING,
  card_level  STRING,
  is_active   BOOL,
  created_at  TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `your-project-id.kipo_payments.card` (
  id            STRING    NOT NULL,
  user_id       STRING    NOT NULL,
  bin_range_id  STRING    NOT NULL,
  last_four     STRING,
  network_token STRING,
  card_type     STRING,
  status        STRING,
  created_at    TIMESTAMP,
  expires_at    TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `your-project-id.kipo_payments.merchant` (
  id              STRING    NOT NULL,
  name            STRING,
  legal_name      STRING,
  mcc             STRING,
  mcc_description STRING,
  country         STRING,
  city            STRING,
  channel         STRING,
  status          STRING,
  onboarded_at    TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `your-project-id.kipo_payments.acquirer` (
  id                   STRING  NOT NULL,
  name                 STRING,
  processor_name       STRING,
  network              STRING,
  country              STRING,
  historical_auth_rate NUMERIC,
  status               STRING
);

CREATE TABLE IF NOT EXISTS `your-project-id.kipo_payments.decline_code_catalog` (
  code               STRING  NOT NULL,
  description        STRING,
  decline_type       STRING,
  recommended_action STRING,
  source             STRING
);


-- ── Transactional tables ─────────────────────────────────────

-- Partitioned by date for cost-efficient queries over time ranges.
CREATE TABLE IF NOT EXISTS `your-project-id.kipo_payments.payment_intent` (
  id               STRING    NOT NULL,
  card_id          STRING    NOT NULL,
  network_token    STRING,
  user_id          STRING    NOT NULL,
  merchant_id      STRING    NOT NULL,
  order_id         STRING,
  customer_type    STRING,
  amount_usd       NUMERIC,
  currency         STRING,
  channel          STRING,
  entry_mode       STRING,
  idempotency_key  STRING,
  status           STRING,
  created_at       TIMESTAMP NOT NULL
)
PARTITION BY DATE(created_at);

CREATE TABLE IF NOT EXISTS `your-project-id.kipo_payments.risk_evaluation` (
  id                 STRING    NOT NULL,
  payment_intent_id  STRING    NOT NULL,
  fraud_score        INT64,
  decision           STRING,
  block_reason       STRING,
  device_id          STRING,
  ip_address         STRING,
  geolocation        STRING,
  velocity_flag      BOOL,
  bin_flag           BOOL,
  blacklist_hit      BOOL,
  evaluated_at       TIMESTAMP
);

-- Clustered by payment_intent_id to speed up per-intent lookups.
CREATE TABLE IF NOT EXISTS `your-project-id.kipo_payments.auth_attempt` (
  id                 STRING    NOT NULL,
  payment_intent_id  STRING    NOT NULL,
  acquirer_id        STRING    NOT NULL,
  attempt_number     INT64,
  routing_reason     STRING,
  response_code      STRING,
  decline_code       STRING,
  decline_type       STRING,
  retried            BOOL,
  attempted_at       TIMESTAMP
)
CLUSTER BY payment_intent_id;

CREATE TABLE IF NOT EXISTS `your-project-id.kipo_payments.authorization` (
  id                    STRING    NOT NULL,
  payment_intent_id     STRING    NOT NULL,
  acquirer_id           STRING    NOT NULL,
  processor_id          STRING,
  network               STRING,
  auth_code             STRING,
  response_code         STRING,
  decline_code          STRING,
  decline_type          STRING,
  is_3ds                BOOL,
  three_ds_result       STRING,
  authorized_amount_usd NUMERIC,
  authorized_at         TIMESTAMP,
  expires_at            TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `your-project-id.kipo_payments.capture` (
  id                    STRING    NOT NULL,
  authorization_id      STRING    NOT NULL,
  captured_amount_usd   NUMERIC,
  is_partial            BOOL,
  captured_at           TIMESTAMP,
  late_capture_at       TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `your-project-id.kipo_payments.void_reversal` (
  id               STRING    NOT NULL,
  authorization_id STRING    NOT NULL,
  reason           STRING,
  initiated_by     STRING,
  voided_at        TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `your-project-id.kipo_payments.settlement_batch` (
  id                  STRING    NOT NULL,
  acquirer_id         STRING    NOT NULL,
  settlement_date     DATE,
  transaction_count   INT64,
  gross_amount_usd    NUMERIC,
  interchange_fee_usd NUMERIC,
  scheme_fee_usd      NUMERIC,
  acquirer_fee_usd    NUMERIC,
  net_amount_usd      NUMERIC,
  status              STRING,
  created_at          TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `your-project-id.kipo_payments.refund` (
  id                  STRING    NOT NULL,
  capture_id          STRING    NOT NULL,
  settlement_batch_id STRING,
  amount_usd          NUMERIC,
  is_partial          BOOL,
  reason              STRING,
  status              STRING,
  initiated_by        STRING,
  requested_at        TIMESTAMP,
  processed_at        TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `your-project-id.kipo_payments.dispute` (
  id                  STRING    NOT NULL,
  capture_id          STRING    NOT NULL,
  chargeback_id       STRING,
  reason_code         STRING,
  dispute_type        STRING,
  disputed_amount_usd NUMERIC,
  chargeback_fee_usd  NUMERIC,
  status              STRING,
  outcome             STRING,
  opened_at           TIMESTAMP,
  due_date            TIMESTAMP,
  resolved_at         TIMESTAMP
);
