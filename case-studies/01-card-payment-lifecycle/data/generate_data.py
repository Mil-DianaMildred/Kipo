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
DROP_DAY = 30          # auth rate drops after this day
N_PAYMENT_INTENTS = 10_000

# Auth rates by phase and issuer (phase 0 = days 1–30, phase 1 = days 31–60)
ISSUER_AUTH_RATES = {
    "Bancolombia":  [0.84, 0.70],   # drops in phase 1
    "Davivienda":   [0.83, 0.69],   # drops in phase 1
    "Nubank CO":    [0.88, 0.88],   # stable
    "Nequi":        [0.87, 0.87],   # stable
    "Kipo":         [0.90, 0.90],   # stable
}

# Decline codes (code, description, decline_type, recommended_action, source)
DECLINE_CODES = [
    ("00", "Approved",                        "approved",      "none",                                  "Mastercard/Visa"),
    ("05", "Do Not Honor",                    "soft",          "Retry once after short delay",           "Mastercard/Visa"),
    ("51", "Insufficient Funds",              "soft",          "Advise cardholder to add funds",         "Mastercard/Visa"),
    ("14", "Invalid Card Number",             "hard",          "Request new card from cardholder",       "Mastercard/Visa"),
    ("54", "Expired Card",                    "hard",          "Request updated card information",       "Mastercard/Visa"),
    ("57", "Transaction Not Permitted",       "soft",          "Retry with 3DS2 or alternative method",  "Mastercard/Visa"),
    ("91", "Card Issuer Unavailable",         "soft",          "Retry after 30 minutes",                 "Mastercard/Visa"),
    ("96", "System Error",                    "soft",          "Retry immediately",                      "Mastercard/Visa"),
    ("41", "Lost Card",                       "hard",          "Do not retry",                           "Mastercard/Visa"),
    ("43", "Stolen Card",                     "hard",          "Do not retry",                           "Mastercard/Visa"),
]

# Soft decline codes that drive the drop (weighted toward phase 1, e-commerce, credit)
DROP_DECLINE_CODES = ["05", "57", "91"]

# ── Helpers ────────────────────────────────────────────────────────────────────

def uid():
    return str(uuid.uuid4())

def ts(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%d %H:%M:%S UTC")

def rand_date(start: datetime, days: int) -> datetime:
    return start + timedelta(seconds=random.randint(0, days * 86400))

def write_csv(filename: str, rows: list[dict]):
    if not rows:
        return
    path = os.path.join(RAW_DIR, filename)
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
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
    i = {
        "id":                    uid(),
        "name":                  d["name"],
        "short_name":            d["short_name"],
        "country":               "CO",
        "network":               d["network"],
        "issuer_type":           d["issuer_type"],
        "avg_auth_rate":         round(sum(ISSUER_AUTH_RATES[d["name"]]) / 2, 4),
        "avg_soft_decline_rate": round(random.uniform(0.04, 0.12), 4),
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
    issuer_name = random.choice(list(ISSUER_AUTH_RATES.keys()))
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
    # Pick a random day and determine phase
    day_offset = random.randint(0, TOTAL_DAYS - 1)
    created_at = START_DATE + timedelta(
        seconds=day_offset * 86400 + random.randint(0, 86399)
    )
    phase = 1 if day_offset >= DROP_DAY else 0

    # Pick a card (active preferred)
    card_id, user_id, issuer_name, card_type, card_brand = random.choice(card_records)
    merchant_info = random.choice(list(merchant_ids.values()))
    merchant_id = merchant_info["id"]
    channel = merchant_info["channel"]
    entry_mode = "manual" if channel == "ecommerce" else random.choice(["chip", "contactless", "token"])
    amount = round(random.uniform(2.0, 500.0), 2)

    pi = {
        "id":              uid(),
        "card_id":         card_id,
        "network_token":   uid(),
        "user_id":         user_id,
        "merchant_id":     merchant_id,
        "order_id":        uid(),
        "customer_type":   random.choice(CUSTOMER_TYPES),
        "amount_usd":      amount,
        "currency":        "COP",
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

    # Authorization attempt
    acq_id = random.choice(acquirer_ids)
    auth_rate = ISSUER_AUTH_RATES[issuer_name][phase]

    # Extra decline pressure: e-commerce + credit in phase 1 for Bancolombia/Davivienda
    if phase == 1 and channel == "ecommerce" and card_type == "credit" and issuer_name in ("Bancolombia", "Davivienda"):
        auth_rate *= 0.78  # additional ~22% decline pressure

    approved = random.random() < auth_rate
    attempt_at = created_at + timedelta(milliseconds=random.randint(300, 800))

    if approved:
        decline_code_val = ""
        decline_type_val = ""
        response_code = "00"
    else:
        # Soft declines dominate the drop period for the affected issuers
        if phase == 1 and issuer_name in ("Bancolombia", "Davivienda") and channel == "ecommerce":
            dc_code = random.choices(DROP_DECLINE_CODES, weights=[50, 35, 15])[0]
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
            r_dc = random.choice(DROP_DECLINE_CODES)
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
            "chargeback_fee_usd":  round(random.uniform(15.0, 25.0), 2),
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
