LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.issuer`
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/issuers.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.bin_range`
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/bin_ranges.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.card`
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/cards.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.merchant`
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/merchants.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.acquirer`
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/acquirers.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.decline_code_catalog`
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/decline_code_catalog.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.payment_intent`
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/payment_intents.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.risk_evaluation`
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/risk_evaluations.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.auth_attempt`
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/auth_attempts.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.authorization`
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/authorizations.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.capture`
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/captures.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.void_reversal`
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/void_reversals.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.settlement_batch`
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/settlement_batches.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.refund`
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/refunds.csv']
);

LOAD DATA OVERWRITE `kipo-case01.kipo_cardpayments.dispute`
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://kipo-case01-raw-data/kipo/raw/disputes.csv']
);
