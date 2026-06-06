"""
Case Study 01 · Kipo Fintech · Card Payment Lifecycle
Generates synthetic CSV data for all 15 schema tables.

Usage:
    pip install faker
    python generate_data.py

Output: all CSVs are written to ./raw/
"""

import csv
import os
import random
import uuid
from datetime import datetime, timedelta, timezone

from faker import Faker

fake = Faker("es_CO")
random.seed(42)

RAW_DIR = os.path.join(os.path.dirname(__file__), "raw")
os.makedirs(RAW_DIR, exist_ok=True)

# ── Simulation parameters ──────────────────────────────────────────────────────
START_DATE = datetime(2025, 1, 1, tzinfo=timezone.utc)
TOTAL_DAYS = 60
N_PAYMENT_INTENTS = 10_000

# Auth-rate ramp per issuer.
#   p1            : baseline auth rate before the policy change
#   p2_trough     : auth rate after the policy fully takes effect
#   ramp_start_day: day-offset (0-indexed) when the degradation begins
#   ramp_days     : number of days to ramp from p1 to p2_trough
#
# Bancolombia and Davivienda are staggered by 2 days to look like two issuers
# reacting to the same external trigger on slightly different timelines, and
# the drop is spread over ~4 days instead of a clean step. Magnitudes are
# tuned for ~8–11 pp per bank (crisis-level but plausible for a policy
# tightening on card-not-present credit traffic), not the 18–20 pp jumps that
# would only land if a fraud ring forced an emergency lockdown.
ISSUER_RAMP = {
    "Bancolombia": {"p1": 0.85, "p2_trough": 0.76, "ramp_start_day": 29, "ramp_days": 4},
    "Davivienda":  {"p1": 0.84, "p2_trough": 0.74, "ramp_start_day": 31, "ramp_days": 4},
    "Nubank CO":   {"p1": 0.88, "p2_trough": 0.88, "ramp_start_day": 0,  "ramp_days": 1},
    "Nequi":       {"p1": 0.87, "p2_trough": 0.87, "ramp_start_day": 0,  "ramp_days": 1},
    "Kipo":        {"p1": 0.90, "p2_trough": 0.90, "ramp_start_day": 0,  "ramp_days": 1},
}

# Extra decline pressure on the credit + e-commerce surface for the two
# affected issuers during the drop window. 0.82 means "shave another ~18% off
# the day's base rate" for that cohort — keeps credit×e-commerce visibly the
# worst cell in the card-type × channel matrix without flipping it into an
# outlier the analyst trips over.
CREDIT_ECOM_PRESSURE = 0.82

# Decline codes (code, description, decline_type, recommended_action, source).
# 05/57 are HARD per ISO 8583 / Mastercard / Visa standards. 96 must wait
# 30–60s before retry, not retry immediately. 61 is added as a realistic
# secondary hard code seen when issuers tighten per-card limits.
DECLINE_CODES = [
    ("00", "Approved",                        "approved", "none",                                                    "Mastercard/Visa"),
    ("05", "Do Not Honor",                    "hard",     "Contact issuing bank; do not retry",                      "Mastercard/Visa"),
    ("51", "Insufficient Funds",              "soft",     "Advise cardholder to add funds",                          "Mastercard/Visa"),
    ("14", "Invalid Card Number",             "hard",     "Request new card from cardholder",                        "Mastercard/Visa"),
    ("54", "Expired Card",                    "hard",     "Request updated card information",                        "Mastercard/Visa"),
    ("57", "Transaction Not Permitted",       "hard",     "Cardholder must call bank to enable transaction type",    "Mastercard/Visa"),
    ("61", "Exceeds Withdrawal Limit",        "hard",     "Cardholder must request a limit increase from the issuer","Mastercard/Visa"),
    ("91", "Card Issuer Unavailable",         "soft",     "Retry after 30 minutes",                                  "Mastercard/Visa"),
    ("96", "System Error",                    "soft",     "Retry after 30–60 seconds",                               "Mastercard/Visa"),
    ("41", "Lost Card",                       "hard",     "Do not retry",                                            "Mastercard/Visa"),
    ("43", "Stolen Card",                     "hard",     "Do not retry",                                            "Mastercard/Visa"),
]

# Decline-code mix inside the affected cohort (Bancolombia/Davivienda credit
# e-commerce during the drop window). Heavy on 05 (catch-all risk refusal),
# 91 (issuer endpoint slow under the new rule), with a smaller share of 51
# (month-end insufficient funds), 96 (system error), 57 (transaction-type
# restriction), and 61 (per-card limit tightening).
DROP_DECLINE_WEIGHTS = [
    ("05", 50),
    ("91", 25),
    ("51", 10),
    ("96",  8),
    ("57",  4),
    ("61",  3),
]

# ── Helpers ────────────────────────────────────────────────────────────────────

def uid():
    return str(uuid.uuid4())

def ts(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%d %H:%M:%S UTC")

def rand_date(start: datetime, days: int) -> datetime:
    return start + timedelta(seconds=random.randint(0, days * 86400))

def daily_auth_rate(issuer_name: str, day_offset: int) -> float:
    """Linear ramp from p1 to p2_trough between ramp_start_day and
    ramp_start_day + ramp_days. Stable on both sides of the window."""
    cfg = ISSUER_RAMP[issuer_name]
    start, span = cfg["ramp_start_day"], cfg["ramp_days"]
    if day_offset < start:
        return cfg["p1"]
    if day_offset >= start + span:
        return cfg["p2_trough"]
    t = (day_offset - start) / span
    return cfg["p1"] + (cfg["p2_trough"] - cfg["p1"]) * t


def in_drop_window(issuer_name: str, day_offset: int) -> bool:
    """True once the issuer has at least started ramping down — used to
    bias the decline-code mix toward the drop-window distribution."""
    cfg = ISSUER_RAMP[issuer_name]
    return cfg["p2_trough"] < cfg["p1"] and day_offset >= cfg["ramp_start_day"]


def pick_drop_decline_code() -> str:
    codes, weights = zip(*DROP_DECLINE_WEIGHTS)
    return random.choices(codes, weights=weights, k=1)[0]


def write_csv(filename: str, rows: list[dict]):
    """Write CSV with QUOTE_NONNUMERIC so every string is wrapped in double
    quotes. This is the defensive option for BigQuery LOAD: it guarantees
    leading-zero codes like ``05``/``00`` survive as strings and prevents any
    downstream tool (Excel, autodetection, etc.) from re-typing them as
    integers."""
    if not rows:
        return
    path = os.path.join(RAW_DIR, filename)
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=rows[0].keys(),
            quoting=csv.QUOTE_NONNUMERIC,
        )
        writer.writeheader()
        normalized = [
            {k: ("true" if v is True else "false" if v is False else v)
             for k, v in row.items()}
            for row in rows
        ]
        writer.writerows(normalized)
    print(f"  {filename}: {len(rows)} rows")

# ── 1. Issuers ─────────────────────────────────────────────────────────────────
ISSUER_DATA = [
    {"name": "Bancolombia",  "short_name": "BCOL",  "network": "Mastercard", "issuer_type": "bank"},
    {"name": "Davivienda",   "short_name": "DAVI",  "network": "Visa",       "issuer_type": "bank"},
    {"name": "Nubank CO",    "short_name": "NUBK",  "network": "Mastercard", "issuer_type": "neobank"},
    {"name": "Nequi",        "short_name": "NEQI",  "network": "Visa",       "issuer_type": "neobank"},
    {"name": "Kipo",         "short_name": "KIPO",  "network": "Mastercard", "issuer_type": "fintech"},
]

issuers = []
issuer_ids = {}
for d in ISSUER_DATA:
    cfg = ISSUER_RAMP[d["name"]]
    avg_rate = round((cfg["p1"] + cfg["p2_trough"]) / 2, 4)
    i = {
        "id":                    uid(),
        "name":                  d["name"],
        "short_name":            d["short_name"],
        "country":               "CO",
        "network":               d["network"],
        "issuer_type":           d["issuer_type"],
        "avg_auth_rate":         avg_rate,
        "avg_soft_decline_rate": round((1 - avg_rate) * 0.80, 4),
        "created_at":            ts(START_DATE - timedelta(days=random.randint(180, 730))),
    }
    issuers.append(i)
    issuer_ids[d["name"]] = i["id"]

# ── 2. BIN ranges ──────────────────────────────────────────────────────────────
BIN_PREFIXES = {
    "Bancolombia":  [("453987", "Visa",       "debit",  "classic"), ("535800", "Mastercard", "credit", "gold")],
    "Davivienda":   [("446200", "Visa",       "debit",  "classic"), ("512300", "Mastercard", "credit", "classic")],
    "Nubank CO":    [("535902", "Mastercard", "debit",  "classic"), ("546150", "Mastercard", "credit", "platinum")],
    "Nequi":        [("453612", "Visa",       "debit",  "classic"), ("411000", "Visa",       "credit", "classic")],
    "Kipo":         [("542300", "Mastercard", "debit",  "classic"), ("543100", "Mastercard", "credit", "gold"),
                     ("453200", "Visa",       "debit",  "classic"), ("454700", "Visa",       "credit", "classic")],
}

bin_ranges = []
bin_range_ids = {}  # (issuer_name, card_type, brand) -> list of bin_range ids
for issuer_name, bins in BIN_PREFIXES.items():
    for prefix, brand, card_type, level in bins:
        br = {
            "id":         uid(),
            "issuer_id":  issuer_ids[issuer_name],
            "bin_prefix": prefix,
            "bin_length": 6,
            "card_type":  card_type,
            "card_brand": brand,
            "card_level": level,
            "is_active":  True,
            "created_at": ts(START_DATE - timedelta(days=random.randint(90, 365))),
        }
        bin_ranges.append(br)
        key = (issuer_name, card_type)
        bin_range_ids.setdefault(key, []).append(br["id"])

# ── 3. Cards ───────────────────────────────────────────────────────────────────
cards = []
card_records = []  # (card_id, issuer_name, card_type, card_brand)

for _ in range(500):
    issuer_name = random.choice(list(ISSUER_RAMP.keys()))
    card_type = random.choice(["debit", "credit"])
    key = (issuer_name, card_type)
    if key not in bin_range_ids:
        key = (issuer_name, "debit")
    br_id = random.choice(bin_range_ids[key])
    br = next(b for b in bin_ranges if b["id"] == br_id)
    created = rand_date(START_DATE - timedelta(days=730), 600)
    c = {
        "id":            uid(),
        "user_id":       uid(),
        "bin_range_id":  br_id,
        "last_four":     str(random.randint(1000, 9999)),
        "network_token": uid(),
        "card_type":     card_type,
        "status":        random.choices(["active", "inactive", "blocked"], weights=[90, 7, 3])[0],
        "created_at":    ts(created),
        "expires_at":    ts(created + timedelta(days=365 * 4)),
    }
    cards.append(c)
    card_records.append((c["id"], c["user_id"], issuer_name, card_type, br["card_brand"]))

# ── 4. Merchants ───────────────────────────────────────────────────────────────
MERCHANT_DATA = [
    {"name": "Éxito",        "mcc": "5411", "mcc_description": "Grocery Stores",       "channel": "pos"},
    {"name": "Rappi CO",     "mcc": "5812", "mcc_description": "Eating Places",         "channel": "ecommerce"},
    {"name": "Falabella CO", "mcc": "5651", "mcc_description": "Retail Clothing Stores","channel": "ecommerce"},
    {"name": "InDriver CO",  "mcc": "4121", "mcc_description": "Taxicabs and Limousines","channel": "in_app"},
    {"name": "Netflix CO",   "mcc": "7922", "mcc_description": "Digital Entertainment", "channel": "ecommerce"},
]

merchants = []
merchant_ids = {}
for d in MERCHANT_DATA:
    m = {
        "id":              uid(),
        "name":            d["name"],
        "legal_name":      d["name"] + " S.A.S.",
        "mcc":             d["mcc"],
        "mcc_description": d["mcc_description"],
        "country":         "CO",
        "city":            random.choice(["Bogotá", "Medellín", "Cali", "Barranquilla"]),
        "channel":         d["channel"],
        "status":          "active",
        "onboarded_at":    ts(START_DATE - timedelta(days=random.randint(90, 365))),
    }
    merchants.append(m)
    merchant_ids[d["name"]] = {"id": m["id"], "channel": d["channel"]}

# ── 5. Acquirers ───────────────────────────────────────────────────────────────
ACQUIRER_DATA = [
    {"name": "Credibanco", "processor_name": "Credibanco",  "network": "Visa"},
    {"name": "Redeban",    "processor_name": "Redeban",     "network": "Mastercard"},
    {"name": "Yuno",       "processor_name": "Yuno",        "network": "Mastercard/Visa"},
]

acquirers = []
acquirer_ids = []
for d in ACQUIRER_DATA:
    a = {
        "id":                   uid(),
        "name":                 d["name"],
        "processor_name":       d["processor_name"],
        "network":              d["network"],
        "country":              "CO",
        "historical_auth_rate": round(random.uniform(0.80, 0.92), 4),
        "status":               "active",
    }
    acquirers.append(a)
    acquirer_ids.append(a["id"])

# ── 6. Decline code catalog ────────────────────────────────────────────────────
decline_catalog = [
    {
        "code":               code,
        "description":        desc,
        "decline_type":       dtype,
        "recommended_action": action,
        "source":             source,
    }
    for code, desc, dtype, action, source in DECLINE_CODES
]

# ── 7–15. Transactional data ───────────────────────────────────────────────────
payment_intents = []
risk_evaluations = []
auth_attempts = []
authorizations = []
captures = []
void_reversals = []
settlement_batches_map = {}  # acquirer_id + date -> batch
settlement_batches = []
refunds = []
disputes = []

CHANNELS = ["ecommerce", "pos", "in_app"]
ENTRY_MODES = ["manual", "chip", "contactless", "token"]
CUSTOMER_TYPES = ["b2c", "b2b"]
CURRENCIES = ["COP"]

# Pre-build daily settlement batches per acquirer
for acq_id in acquirer_ids:
    for day_offset in range(TOTAL_DAYS):
        batch_date = (START_DATE + timedelta(days=day_offset)).date()
        batch = {
            "id":                  uid(),
            "acquirer_id":         acq_id,
            "settlement_date":     str(batch_date),
            "transaction_count":   0,
            "gross_amount_usd":    0.0,
            "interchange_fee_usd": 0.0,
            "scheme_fee_usd":      0.0,
            "acquirer_fee_usd":    0.0,
            "net_amount_usd":      0.0,
            "status":              "settled",
            "created_at":          ts(START_DATE + timedelta(days=day_offset + 1)),
        }
        settlement_batches_map[(acq_id, str(batch_date))] = batch

for _ in range(N_PAYMENT_INTENTS):
    # Pick a random day. Phase / ramp position is resolved per-issuer below.
    day_offset = random.randint(0, TOTAL_DAYS - 1)
    created_at = START_DATE + timedelta(
        seconds=day_offset * 86400 + random.randint(0, 86399)
    )

    # Pick a card (active preferred)
    card_id, user_id, issuer_name, card_type, card_brand = random.choice(card_records)
    merchant_info = random.choice(list(merchant_ids.values()))
    merchant_id = merchant_info["id"]
    channel = merchant_info["channel"]
    entry_mode = "manual" if channel == "ecommerce" else random.choice(["chip", "contactless", "token"])
    amount = round(random.uniform(1.0, 60.0), 2)

    pi = {
        "id":              uid(),
        "card_id":         card_id,
        "network_token":   uid(),
        "user_id":         user_id,
        "merchant_id":     merchant_id,
        "order_id":        uid(),
        "customer_type":   random.choice(CUSTOMER_TYPES),
        "amount_usd":      amount,
        "currency":        "USD",
        "channel":         channel,
        "entry_mode":      entry_mode,
        "idempotency_key": uid(),
        "status":          "pending",
        "created_at":      ts(created_at),
    }

    # Risk evaluation
    fraud_score = random.randint(1, 100)
    velocity_flag = fraud_score > 80
    bin_flag = random.random() < 0.03
    blacklist_hit = random.random() < 0.01
    fraud_block = blacklist_hit or (fraud_score > 90)
    decision = "block" if fraud_block else "allow"
    re = {
        "id":                uid(),
        "payment_intent_id": pi["id"],
        "fraud_score":       fraud_score,
        "decision":          decision,
        "block_reason":      "blacklist" if blacklist_hit else ("velocity" if velocity_flag and fraud_block else ""),
        "device_id":         uid(),
        "ip_address":        fake.ipv4(),
        "geolocation":       f"{fake.latitude()},{fake.longitude()}",
        "velocity_flag":     velocity_flag,
        "bin_flag":          bin_flag,
        "blacklist_hit":     blacklist_hit,
        "evaluated_at":      ts(created_at + timedelta(milliseconds=random.randint(50, 300))),
    }
    risk_evaluations.append(re)

    if fraud_block:
        pi["status"] = "blocked"
        payment_intents.append(pi)
        continue

    # Authorization attempt — auth rate is resolved per-day, per-issuer along
    # the ramp curve, so the drop is visible as a 3–5 day ramp rather than a
    # clean step on day 30.
    acq_id = random.choice(acquirer_ids)
    auth_rate = daily_auth_rate(issuer_name, day_offset)

    # Extra decline pressure on credit + e-commerce for the two affected
    # issuers once their ramp has started — keeps that cell the worst in the
    # card-type × channel matrix without making it an outlier.
    in_drop = in_drop_window(issuer_name, day_offset)
    affected_cohort = (
        in_drop
        and channel == "ecommerce"
        and card_type == "credit"
        and issuer_name in ("Bancolombia", "Davivienda")
    )
    if affected_cohort:
        auth_rate *= CREDIT_ECOM_PRESSURE

    approved = random.random() < auth_rate
    attempt_at = created_at + timedelta(milliseconds=random.randint(300, 800))

    if approved:
        decline_code_val = ""
        decline_type_val = ""
        response_code = "00"
    else:
        # In the affected cohort, draw the decline code from the drop-window
        # mix (heavy on 05, then 91, with smaller shares of 51/96/57/61).
        # Elsewhere, fall back to a broad realistic mix.
        if affected_cohort:
            dc_code = pick_drop_decline_code()
        else:
            soft_codes = [c for c in DECLINE_CODES if c[2] == "soft" and c[0] != "00"]
            hard_codes = [c for c in DECLINE_CODES if c[2] == "hard"]
            pool = random.choices(soft_codes, k=3) + random.choices(hard_codes, k=1)
            dc_code = random.choice(pool)[0]
        dc_entry = next(d for d in DECLINE_CODES if d[0] == dc_code)
        decline_code_val = dc_code
        decline_type_val = dc_entry[2]
        response_code = dc_code

    # Retry on soft decline
    retried = (not approved) and decline_type_val == "soft" and random.random() < 0.6
    aa = {
        "id":                uid(),
        "payment_intent_id": pi["id"],
        "acquirer_id":       acq_id,
        "attempt_number":    1,
        "routing_reason":    "primary",
        "response_code":     response_code,
        "decline_code":      decline_code_val,
        "decline_type":      decline_type_val,
        "retried":           retried,
        "attempted_at":      ts(attempt_at),
    }
    auth_attempts.append(aa)

    # Second attempt after soft decline retry
    if retried:
        retry_approved = random.random() < (auth_rate * 0.70)
        retry_at = attempt_at + timedelta(seconds=random.randint(5, 30))
        if retry_approved:
            r_dc = ""
            r_dt = ""
            r_rc = "00"
            approved = True
        else:
            r_dc = pick_drop_decline_code()
            r_dc_entry = next(d for d in DECLINE_CODES if d[0] == r_dc)
            r_dt = r_dc_entry[2]
            r_rc = r_dc
        aa2 = {
            "id":                uid(),
            "payment_intent_id": pi["id"],
            "acquirer_id":       acq_id,
            "attempt_number":    2,
            "routing_reason":    "retry_soft_decline",
            "response_code":     r_rc,
            "decline_code":      r_dc,
            "decline_type":      r_dt,
            "retried":           False,
            "attempted_at":      ts(retry_at),
        }
        auth_attempts.append(aa2)

    if not approved:
        pi["status"] = "declined"
        payment_intents.append(pi)
        continue

    # Authorization record
    auth_at = attempt_at + timedelta(milliseconds=random.randint(100, 400))
    is_3ds = channel == "ecommerce" and random.random() < 0.75
    auth_id = uid()
    az = {
        "id":                    auth_id,
        "payment_intent_id":     pi["id"],
        "acquirer_id":           acq_id,
        "processor_id":          uid(),
        "network":               card_brand,
        "auth_code":             str(random.randint(100000, 999999)),
        "response_code":         "00",
        "decline_code":          "",
        "decline_type":          "",
        "is_3ds":                is_3ds,
        "three_ds_result":       "Y" if is_3ds else "",
        "authorized_amount_usd": amount,
        "authorized_at":         ts(auth_at),
        "expires_at":            ts(auth_at + timedelta(hours=24 * 7)),
    }
    authorizations.append(az)

    # Void (5% of authorizations)
    if random.random() < 0.05:
        void_reversals.append({
            "id":               uid(),
            "authorization_id": auth_id,
            "reason":           random.choice(["customer_cancelled", "merchant_cancelled", "timeout"]),
            "initiated_by":     random.choice(["customer", "merchant", "system"]),
            "voided_at":        ts(auth_at + timedelta(minutes=random.randint(1, 60))),
        })
        pi["status"] = "voided"
        payment_intents.append(pi)
        continue

    # Capture (95% of remaining authorizations)
    if random.random() > 0.95:
        pi["status"] = "authorized"
        payment_intents.append(pi)
        continue

    cap_at = auth_at + timedelta(seconds=random.randint(1, 600))
    is_partial = random.random() < 0.02
    cap_amount = round(amount * random.uniform(0.5, 0.99), 2) if is_partial else amount
    cap_id = uid()
    cap = {
        "id":                   cap_id,
        "authorization_id":     auth_id,
        "captured_amount_usd":  cap_amount,
        "is_partial":           is_partial,
        "captured_at":          ts(cap_at),
        "late_capture_at":      "",
    }
    captures.append(cap)
    pi["status"] = "captured"

    # Settlement batch
    batch_date = cap_at.date()
    batch_key = (acq_id, str(batch_date))
    if batch_key in settlement_batches_map:
        sb = settlement_batches_map[batch_key]
        interchange = round(cap_amount * 0.0175, 4)
        scheme_fee = round(cap_amount * 0.003, 4)
        acq_fee = round(cap_amount * 0.005, 4)
        sb["transaction_count"] += 1
        sb["gross_amount_usd"] = round(sb["gross_amount_usd"] + cap_amount, 4)
        sb["interchange_fee_usd"] = round(sb["interchange_fee_usd"] + interchange, 4)
        sb["scheme_fee_usd"] = round(sb["scheme_fee_usd"] + scheme_fee, 4)
        sb["acquirer_fee_usd"] = round(sb["acquirer_fee_usd"] + acq_fee, 4)
        sb["net_amount_usd"] = round(
            sb["gross_amount_usd"]
            - sb["interchange_fee_usd"]
            - sb["scheme_fee_usd"]
            - sb["acquirer_fee_usd"],
            4,
        )

    # Refund (4% of captures)
    if random.random() < 0.04:
        ref_at = cap_at + timedelta(days=random.randint(1, 15))
        refunds.append({
            "id":                  uid(),
            "capture_id":          cap_id,
            "settlement_batch_id": settlement_batches_map.get(batch_key, {}).get("id", ""),
            "amount_usd":          round(cap_amount * random.uniform(0.3, 1.0), 2),
            "is_partial":          random.random() < 0.3,
            "reason":              random.choice(["customer_request", "product_not_received", "duplicate_charge"]),
            "status":              "processed",
            "initiated_by":        random.choice(["customer", "merchant"]),
            "requested_at":        ts(ref_at),
            "processed_at":        ts(ref_at + timedelta(hours=random.randint(1, 48))),
        })

    # Dispute (1.5% of captures)
    if random.random() < 0.015:
        disp_at = cap_at + timedelta(days=random.randint(5, 60))
        disputes.append({
            "id":                  uid(),
            "capture_id":          cap_id,
            "chargeback_id":       "CB-" + str(random.randint(100000, 999999)),
            "reason_code":         random.choice(["4853", "4855", "4863", "UA02"]),
            "dispute_type":        random.choice(["fraud", "not_as_described", "not_received"]),
            "disputed_amount_usd": cap_amount,
            "chargeback_fee_usd":  round(random.uniform(5.0, 15.0), 2),
            "status":              random.choice(["open", "won", "lost"]),
            "outcome":             random.choice(["merchant_win", "cardholder_win", "pending"]),
            "opened_at":           ts(disp_at),
            "due_date":            ts(disp_at + timedelta(days=45)),
            "resolved_at":         ts(disp_at + timedelta(days=random.randint(10, 45))),
        })

    payment_intents.append(pi)

# Flatten settlement batches (keep only those with transactions)
settlement_batches = [
    sb for sb in settlement_batches_map.values() if sb["transaction_count"] > 0
]

# ── Write CSVs ─────────────────────────────────────────────────────────────────
print("Writing CSVs to", RAW_DIR)
write_csv("issuers.csv",              issuers)
write_csv("bin_ranges.csv",           bin_ranges)
write_csv("cards.csv",                cards)
write_csv("merchants.csv",            merchants)
write_csv("acquirers.csv",            acquirers)
write_csv("decline_code_catalog.csv", decline_catalog)
write_csv("payment_intents.csv",      payment_intents)
write_csv("risk_evaluations.csv",     risk_evaluations)
write_csv("auth_attempts.csv",        auth_attempts)
write_csv("authorizations.csv",       authorizations)
write_csv("captures.csv",             captures)
write_csv("void_reversals.csv",       void_reversals)
write_csv("settlement_batches.csv",   settlement_batches)
write_csv("refunds.csv",              refunds)
write_csv("disputes.csv",             disputes)
print("Done.")
