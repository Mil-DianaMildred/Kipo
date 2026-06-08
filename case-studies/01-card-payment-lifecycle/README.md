# Case Study 01 — Card Payment Lifecycle

> **English** (main) · [Español](#-versión-en-español)

---

# English version

> **Role:** Product Manager at Kipo, a Colombian fintech with a Sedpe license and Mastercard/Visa card programs.
> **Stack:** BigQuery · Looker Studio · Claude
> **Dataset:** 10,000 synthetic payment intents → 9,419 authorization attempts, 60 days (January–March 2025)

---

## Business Context

Kipo issues debit and credit cards under Mastercard and Visa to ~4.2 million users in Colombia's informal economy. Every card transaction travels a path: risk evaluation → authorization attempt → capture → settlement. If a transaction is declined before authorization, Kipo loses revenue and the user loses trust.

**Authorization rate** is the single most-watched metric in card payments: the percentage of authorization attempts that result in an approval. An auth rate of 85% means 15 out of every 100 attempts are declined by the issuing bank. A drop of even 5 percentage points has a direct and immediate impact on revenue.

---

## The Problem

In early February 2025, Kipo's Head of Payments flagged that the overall authorization rate had drifted down by several points over the previous two weeks. The question passed to the product manager:

> "What's causing the drop — and what do we fix first?"

---

## Data Model

The schema for this case study covers the full card payment lifecycle across 15 tables. See [`../../ERD.md`](../../ERD.md) for the complete entity-relationship diagram.

Key tables used in this analysis:

| Table | What it captures |
|---|---|
| `payment_intent` | Every payment attempt, approved or not |
| `auth_attempt` | Each individual authorization request sent to an acquirer |
| `authorization` | The final authorization result (auth code or decline code) |
| `risk_evaluation` | Kipo's internal fraud score and block decision, before the bank is asked |
| `card` + `bin_range` + `issuer` | Card metadata — which bank issued the card, card type, brand |
| `decline_code_catalog` | Mastercard/Visa decline codes classified as soft or hard |

---

## Analysis

### Q1 — Did the drop actually happen? When?

Overall auth rate over the 60-day window is **82.74%** (7,793 approved / 9,419 attempts). Splitting on `2025-01-31`:

| Phase | Window | Overall auth rate |
|---|---|---|
| Phase 1 | 2025-01-01 → 2025-01-30 | ~85% |
| Phase 2 | 2025-01-31 → 2025-03-01 | ~80% |

The drop is real and it is not a single bad day. Looking at a 3-day rolling auth rate for the affected issuers:

| Date | Bancolombia (3d roll) | Davivienda (3d roll) |
|---|---|---|
| 2025-01-29 | 85.0% | 85.6% |
| 2025-01-30 | 76.9% | 84.4% |
| 2025-01-31 | 71.8% | 82.4% |
| 2025-02-01 | 73.1% | 80.2% |
| 2025-02-02 | 81.2% | 75.9% |
| 2025-02-03 | 84.6% | 65.2% |
| 2025-02-04 | 75.0% | 61.6% |
| 2025-02-05 | 69.8% | 65.7% |

Two observations:
1. Bancolombia degrades first, around **2025-01-30**, settling roughly 10 pp below baseline within ~4 days.
2. Davivienda lags by **~2 days** and settles even lower, ~16 pp below baseline.

The lag between the two banks is the first piece of evidence that this is an issuer-side decision applied independently, not a Kipo-side event or a network outage.

### Q2 — Which issuers are responsible?

| Issuer | Phase 1 | Phase 2 | Δ | Phase 2 volume |
|---|---|---|---|---|
| **Davivienda** | 82.55% | **66.80%** | **−15.8 pp** | 970 |
| **Bancolombia** | 83.13% | **72.57%** | **−10.6 pp** | 915 |
| Nequi | 83.40% | 85.55% | +2.1 pp | 1,038 |
| Nubank CO | 85.65% | 88.63% | +3.0 pp | 853 |
| Kipo (self-issued) | 89.67% | 89.21% | −0.5 pp | 1,038 |

The drop is **concentrated entirely in Bancolombia and Davivienda**. The three neobanks (Nequi, Nubank CO, Kipo) are flat or slightly up in the same window. This rules out:
- a network outage (Mastercard/Visa would hit everyone),
- a Kipo-side regression (Kipo's own issuing rail is stable at ~89%),
- an acquirer routing issue (see Q7),
- 3DS2 friction at the scheme level (neobanks process e-commerce through the same 3DS rails).

### Q3 — What decline codes are driving it?

**All declines, full 60 days (top codes):**

| Code | Description | Type | Count | % of declines |
|---|---|---|---|---|
| `91` | Card Issuer Unavailable | soft | 394 | 24.2% |
| `51` | Insufficient Funds | soft | 340 | 20.9% |
| `96` | System Error | soft | 321 | 19.7% |
| `05` | Do Not Honor | **hard** | 271 | 16.7% |
| `61` | Exceeds Withdrawal Limit | **hard** | 63 | 3.9% |
| `57` | Transaction Not Permitted | **hard** | 62 | 3.8% |
| `43` | Stolen Card | hard | 46 | 2.8% |
| `41` | Lost Card | hard | 46 | 2.8% |

**Bancolombia + Davivienda, Phase 2 only (n = 573 declines):**

| Code | Type | Count | % of B+D P2 declines |
|---|---|---|---|
| `05` | **hard** | 160 | **27.9%** |
| `91` | soft | 138 | 24.1% |
| `51` | soft | 100 | 17.5% |
| `96` | soft | 93 | 16.2% |
| `61` | **hard** | 21 | 3.7% |
| `57` | **hard** | 19 | 3.3% |
| `41` | hard | 14 | 2.4% |
| `54` | hard | 11 | 1.9% |

Two signals stand out:

- **`05` (Do Not Honor) doubles its share** in the affected cohort — from ~17% of declines globally to ~28% on B+D in Phase 2. `05` is a hard, catch-all "the issuer's risk engine said no" code. There is no cardholder action that recovers it on the same attempt.
- **`91` (Card Issuer Unavailable) holds at ~24%**. This is a soft availability signal — the issuer's auth endpoint timed out. A sustained high `91` share suggests the bank's authorization stack is under load.

Together, `05` + `91` are **52% of all B+D Phase 2 declines**. The remaining mix (`51`, `96`, `57`, `61`, etc.) is broadly consistent with baseline traffic.

### Q4 — Soft vs. hard split by issuer (Phase 2)

| Issuer cohort | Hard | Soft | Hard share |
|---|---|---|---|
| Bancolombia + Davivienda (P2) | 242 | 331 | **42.2%** |
| Neobanks (P2) | small, baseline mix | — | <30% |

For B+D in Phase 2, **~42% of declines are hard** — well above the neobank baseline. The hard share is driven almost entirely by `05`, with `61` and `57` as smaller contributors. Hard declines cannot be recovered with a retry; the cardholder either needs a different payment method or has to call their bank.

### Q5 — Is the pattern tied to a specific card type or channel?

Auth rate by card type × channel, full window:

| | e-commerce | in-app | POS |
|---|---|---|---|
| **Credit** | **81.14%** | 84.12% | 82.73% |
| **Debit** | 83.93% | 80.84% | 84.90% |

The lowest cell on credit is **e-commerce at 81.14%**. Credit cards underperform debit on e-commerce by ~2.8 pp, and credit + e-commerce is also the largest single segment (n = 2,964 attempts, ~31% of all traffic). The debit + in-app cell (80.84%) is also low, but its volume is much smaller and the gap to other debit cells is consistent with statistical noise.

The credit + e-commerce signal aligns with Q3: the new declines from Bancolombia and Davivienda are codes (`05`, `91`, `61`) that are emitted by the issuer's risk engine **before** any cardholder interaction. The 3DS2 challenge layer is not involved in producing them — the bank is refusing the auth request itself, not failing an authentication step.

### Q6 — Can retries recover the soft declines?

Filtering to first-attempt soft declines (the only retryable pool), and computing how often a retry was attempted and how often it succeeded:

| Issuer | 1st-attempt soft | Retried | Recovered | Retry success of retried |
|---|---|---|---|---|
| Bancolombia | 225 | 128 | 67 | **52.3%** |
| Davivienda | 265 | 149 | 76 | **51.0%** |
| Nequi | 186 | 112 | 62 | 55.4% |
| Nubank CO | 137 | 77 | 46 | 59.7% |
| Kipo | 133 | 75 | 48 | 64.0% |

Retry on soft declines is genuinely effective (~51–64% conversion), but the addressable pool is small. For B+D in Phase 2, soft declines are only ~58% of declines; the other ~42% (`05`, `57`, `61`, etc.) cannot be recovered with a retry and **must not** be retried — retrying a hard decline looks to the issuer like a bad-actor pattern and can trigger card-level velocity blocks.

Sizing the retry opportunity: tuning retry to capture every soft B+D decline would recover an additional ~100–120 approvals/month, worth roughly **+1.0 to +1.5 pp** of overall auth rate. Useful, but not a fix for the −11 to −16 pp drop.

### Q7 — Is one acquirer performing better?

| Acquirer | Auth rate | Volume |
|---|---|---|
| Redeban | 83.16% | 3,177 |
| Credibanco | 83.00% | 3,136 |
| Yuno | 82.03% | 3,106 |

Auth rates across the three acquirers are within ~1 pp of each other, and **all three show the same Phase-2 dip on Bancolombia / Davivienda traffic**. This confirms the cause is on the issuer side: changing acquirer routing would not move the rate.

---

## Root Cause

Between 2025-01-30 and 2025-02-02, **Bancolombia and Davivienda tightened their card-not-present authorization policy on credit traffic**. The change is:

- **Where it lives:** the issuer's risk engine, evaluated **before** the cardholder authentication step.
- **What it emits:** `05` (Do Not Honor) jumps to 27.9% of declines in the affected cohort, with `91` (Card Issuer Unavailable) staying high at 24.1% as the issuer's auth endpoint slows under the new rule.
- **Where it lands:** credit cards on the e-commerce channel — the lowest cell in the Q5 matrix at 81.14%.
- **Who is affected:** Bancolombia (−10.6 pp) and Davivienda (−15.8 pp). Neobanks are unaffected, ruling out network, scheme, acquirer, and Kipo-side causes.
- **Timing pattern:** the two banks degrade ~2 days apart and each ramps over ~4 days. This is consistent with two issuers reacting independently to the same external trigger — most plausibly a SFC/UIAF fraud advisory or a Mastercard/Visa fraud bulletin issued in late January.

The 3DS2 hypothesis is **rejected**: `05` and `61` are issuer-side hard stops, not authentication-abandonment signals.

---

## Recommendations

Ordered by impact-per-week-of-effort.

### 1. Open issuer-relations channels with Bancolombia and Davivienda (this week)

This is the only lever that addresses the ~42% of declines in the affected cohort that are hard. Retry tuning and 3DS configuration cannot move `05`, `61`, or `57` — only the issuer can.

Targeted asks:
- Confirm the policy change and get the rule written down.
- Negotiate a TRA (Transaction Risk Analysis) exemption for low-value transactions (<30 USD) and for returning cardholders with successful prior captures on the same merchant.
- Ask for a BIN-level whitelist for Kipo's BaaS B2B traffic.

### 2. Retry policy — hard-coded allow-list

Implement automatic retry **only** for these soft codes:

| Code | Backoff | Notes |
|---|---|---|
| `91` | 30–60s | Issuer endpoint timed out; retry once. |
| `51` | notify, don't blind-retry | Insufficient funds requires cardholder action. |
| `96` | 30–60s | System error; never retry immediately. |

**Hard-block** retry on `05`, `57`, `61`, `14`, `54`, `41`, `43`. Retrying any of these escalates to a velocity-rule block on the card.

Expected lift: **+1.0 to +1.5 pp** of overall auth rate, concentrated on the Bancolombia and Davivienda soft pool.

### 3. BIN-level alerting (one-time build)

Set up a real-time alert on `auth_rate` by BIN prefix, with a 24-hour rolling window and a >5 pp drop threshold. This drop would have been detected on day 30 with a BIN alert rather than after two weeks of bleeding. Looker Studio can serve as a v1 of this; the long-term version belongs in the observability stack.

### 4. 3DS2 exemption strategy (medium-term)

Even though 3DS2 friction is **not** the root cause of the Phase-2 drop, the credit + e-commerce cell is structurally weak. A TRA-exemption program with the issuers would lift the headline rate independently of this incident. This is a 2–3 month integration; do not block on it for the current event.

### 5. Add the playbook to the runbook

Capture this category of incident with a decision tree:
- Drop concentrated in 1–2 issuers? → call issuer relations.
- Drop across all issuers? → check network / scheme status, then acquirer status.
- Drop on a single channel only? → check Kipo's own risk-engine deploy history.
- Hard share of new declines >40%? → retry tuning will not help; the lever is issuer-side.

---

## How to Run This Case Study

```bash
# 1. Install dependencies
pip install faker

# 2. Generate the synthetic dataset
cd case-studies/01-card-payment-lifecycle
python data/generate_data.py
# → 15 CSV files written to data/raw/

# 3. Create BigQuery tables
# Open sql/01_ddl.sql in BigQuery, replace project IDs if needed, and run.

# 4. Upload CSVs to GCS and load into BigQuery
gsutil -m cp data/raw/*.csv gs://your-bucket/kipo/raw/
# Then run sql/02_load_data.sql in BigQuery (replace project and bucket).

# 5. Run analysis queries
# Open sql/03_analysis.sql in BigQuery, run Q1–Q7 (page 1),
# Q8–Q13 (acceptance-rate page 2), and OV1–OV5 (overview page).

# 6. Build the dashboard
# Follow dashboard/README.md — each chart maps to one of the queries.
```

---

## Files

```
01-card-payment-lifecycle/
├── README.md                 ← this file (canonical analysis)
├── README_v2.md              ← methodology notes + extended recommendations
├── data/
│   ├── generate_data.py      ← synthetic data generator (staggered ramp, QUOTE_NONNUMERIC for BigQuery)
│   └── raw/                  ← generated CSVs (committed)
├── sql/
│   ├── 01_ddl.sql            ← BigQuery CREATE TABLE statements
│   ├── 02_load_data.sql      ← loads CSVs from GCS into BigQuery
│   └── 03_analysis.sql       ← Q1–Q13 + OV1–OV5
└── dashboard/
    └── README.md             ← Looker Studio build guide
```

---

# Versión en español

> **Rol:** Product Manager en Kipo, una fintech colombiana con licencia Sedpe y programas de tarjetas Mastercard/Visa.
> **Stack:** BigQuery · Looker Studio · Claude
> **Dataset:** 10.000 intentos de pago sintéticos → 9.419 intentos de autorización, 60 días (enero–marzo 2025)

---

## Contexto de negocio

Kipo emite tarjetas débito y crédito bajo Mastercard y Visa para ~4.2 millones de usuarios de la economía informal de Colombia. Cada transacción con tarjeta recorre un camino: evaluación de riesgo → intento de autorización → captura → liquidación. Si una transacción es declinada antes de la autorización, Kipo pierde ingresos y el usuario pierde la confianza.

La **tasa de autorización** es la métrica más vigilada en pagos con tarjeta: el porcentaje de intentos de autorización que terminan en aprobación. Una tasa de autorización del 85% significa que 15 de cada 100 intentos son declinados por el banco emisor. Una caída de incluso 5 puntos porcentuales tiene un impacto directo e inmediato sobre los ingresos.

---

## El problema

A inicios de febrero de 2025, el Head of Payments de Kipo alertó que la tasa de autorización global había venido cayendo varios puntos en las dos semanas anteriores. La pregunta llegó al product manager:

> "¿Qué está causando la caída — y qué arreglamos primero?"

---

## Modelo de datos

El esquema de este caso de estudio cubre el ciclo de vida completo del pago con tarjeta en 15 tablas. Ver [`../../ERD.md`](../../ERD.md) para el diagrama entidad-relación completo.

Tablas clave usadas en este análisis:

| Tabla | Lo que captura |
|---|---|
| `payment_intent` | Cada intento de pago, aprobado o no |
| `auth_attempt` | Cada solicitud de autorización individual enviada a un adquirente |
| `authorization` | El resultado final de la autorización (código de autorización o de declinación) |
| `risk_evaluation` | El score interno de fraude y la decisión de bloqueo de Kipo, antes de consultar al banco |
| `card` + `bin_range` + `issuer` | Metadata de la tarjeta — qué banco emitió la tarjeta, tipo de tarjeta, marca |
| `decline_code_catalog` | Códigos de declinación de Mastercard/Visa clasificados como soft o hard |

---

## Análisis

### Q1 — ¿La caída ocurrió realmente? ¿Cuándo?

La tasa de autorización global en la ventana de 60 días es del **82.74%** (7.793 aprobadas / 9.419 intentos). Partiendo en `2025-01-31`:

| Fase | Ventana | Tasa de autorización global |
|---|---|---|
| Fase 1 | 2025-01-01 → 2025-01-30 | ~85% |
| Fase 2 | 2025-01-31 → 2025-03-01 | ~80% |

La caída es real y no es un solo día malo. Mirando una tasa de autorización móvil de 3 días para los emisores afectados:

| Fecha | Bancolombia (móvil 3d) | Davivienda (móvil 3d) |
|---|---|---|
| 2025-01-29 | 85.0% | 85.6% |
| 2025-01-30 | 76.9% | 84.4% |
| 2025-01-31 | 71.8% | 82.4% |
| 2025-02-01 | 73.1% | 80.2% |
| 2025-02-02 | 81.2% | 75.9% |
| 2025-02-03 | 84.6% | 65.2% |
| 2025-02-04 | 75.0% | 61.6% |
| 2025-02-05 | 69.8% | 65.7% |

Dos observaciones:
1. Bancolombia se degrada primero, cerca del **2025-01-30**, estabilizándose unos 10 pp por debajo del baseline en ~4 días.
2. Davivienda llega con un rezago de **~2 días** y se estabiliza aún más bajo, ~16 pp por debajo del baseline.

El rezago entre los dos bancos es la primera evidencia de que se trata de una decisión del lado del emisor aplicada independientemente, no de un evento del lado de Kipo ni de una caída de la red.

### Q2 — ¿Qué emisores son responsables?

| Emisor | Fase 1 | Fase 2 | Δ | Volumen Fase 2 |
|---|---|---|---|---|
| **Davivienda** | 82.55% | **66.80%** | **−15.8 pp** | 970 |
| **Bancolombia** | 83.13% | **72.57%** | **−10.6 pp** | 915 |
| Nequi | 83.40% | 85.55% | +2.1 pp | 1.038 |
| Nubank CO | 85.65% | 88.63% | +3.0 pp | 853 |
| Kipo (auto-emisión) | 89.67% | 89.21% | −0.5 pp | 1.038 |

La caída está **concentrada totalmente en Bancolombia y Davivienda**. Los tres neobancos (Nequi, Nubank CO, Kipo) están planos o ligeramente al alza en la misma ventana. Esto descarta:
- una caída de red (Mastercard/Visa golpearía a todos),
- una regresión del lado de Kipo (el riel de emisión propio de Kipo se mantiene estable en ~89%),
- un problema de enrutamiento de adquirente (ver Q7),
- fricción 3DS2 a nivel de scheme (los neobancos procesan e-commerce por los mismos rieles 3DS).

### Q3 — ¿Qué códigos de declinación están impulsando esto?

**Todas las declinaciones, 60 días completos (códigos top):**

| Código | Descripción | Tipo | Conteo | % de declinaciones |
|---|---|---|---|---|
| `91` | Card Issuer Unavailable | soft | 394 | 24.2% |
| `51` | Insufficient Funds | soft | 340 | 20.9% |
| `96` | System Error | soft | 321 | 19.7% |
| `05` | Do Not Honor | **hard** | 271 | 16.7% |
| `61` | Exceeds Withdrawal Limit | **hard** | 63 | 3.9% |
| `57` | Transaction Not Permitted | **hard** | 62 | 3.8% |
| `43` | Stolen Card | hard | 46 | 2.8% |
| `41` | Lost Card | hard | 46 | 2.8% |

**Solo Bancolombia + Davivienda, Fase 2 (n = 573 declinaciones):**

| Código | Tipo | Conteo | % de declinaciones B+D F2 |
|---|---|---|---|
| `05` | **hard** | 160 | **27.9%** |
| `91` | soft | 138 | 24.1% |
| `51` | soft | 100 | 17.5% |
| `96` | soft | 93 | 16.2% |
| `61` | **hard** | 21 | 3.7% |
| `57` | **hard** | 19 | 3.3% |
| `41` | hard | 14 | 2.4% |
| `54` | hard | 11 | 1.9% |

Dos señales saltan a la vista:

- **`05` (Do Not Honor) duplica su participación** en el cohort afectado — de ~17% de las declinaciones globalmente a ~28% en B+D en la Fase 2. `05` es un código hard genérico de "el motor de riesgo del emisor dijo que no". No existe acción del tarjetahabiente que lo recupere en el mismo intento.
- **`91` (Card Issuer Unavailable) se mantiene en ~24%**. Es una señal soft de disponibilidad — el endpoint de autorización del emisor expiró. Una participación alta y sostenida de `91` sugiere que el stack de autorización del banco está bajo carga.

Juntos, `05` + `91` son el **52% de todas las declinaciones B+D en Fase 2**. La mezcla restante (`51`, `96`, `57`, `61`, etc.) es ampliamente consistente con el tráfico baseline.

### Q4 — Distribución soft vs. hard por emisor (Fase 2)

| Cohort de emisor | Hard | Soft | Participación hard |
|---|---|---|---|
| Bancolombia + Davivienda (F2) | 242 | 331 | **42.2%** |
| Neobancos (F2) | pequeña, mezcla baseline | — | <30% |

Para B+D en Fase 2, **~42% de las declinaciones son hard** — muy por encima del baseline de los neobancos. La participación hard es impulsada casi en su totalidad por `05`, con `61` y `57` como contribuyentes menores. Las declinaciones hard no se pueden recuperar con un reintento; el tarjetahabiente necesita otro método de pago o llamar a su banco.

### Q5 — ¿El patrón está atado a un tipo de tarjeta o canal específico?

Tasa de autorización por tipo de tarjeta × canal, ventana completa:

| | e-commerce | in-app | POS |
|---|---|---|---|
| **Crédito** | **81.14%** | 84.12% | 82.73% |
| **Débito** | 83.93% | 80.84% | 84.90% |

La celda más baja en crédito es **e-commerce a 81.14%**. Las tarjetas de crédito tienen un rendimiento ~2.8 pp por debajo de las de débito en e-commerce, y crédito + e-commerce es también el segmento individual más grande (n = 2.964 intentos, ~31% de todo el tráfico). La celda débito + in-app (80.84%) también es baja, pero su volumen es mucho más pequeño y la brecha con otras celdas de débito es consistente con ruido estadístico.

La señal de crédito + e-commerce se alinea con la Q3: las nuevas declinaciones de Bancolombia y Davivienda son códigos (`05`, `91`, `61`) que el motor de riesgo del emisor emite **antes** de cualquier interacción del tarjetahabiente. La capa de challenge 3DS2 no interviene en su producción — el banco está rechazando la solicitud de autorización en sí, no fallando un paso de autenticación.

### Q6 — ¿Pueden los reintentos recuperar las declinaciones soft?

Filtrando a declinaciones soft en primer intento (el único pool reintentable), y calculando con qué frecuencia se intentó un reintento y con qué frecuencia tuvo éxito:

| Emisor | Soft 1er intento | Reintentadas | Recuperadas | Éxito de reintento sobre reintentadas |
|---|---|---|---|---|
| Bancolombia | 225 | 128 | 67 | **52.3%** |
| Davivienda | 265 | 149 | 76 | **51.0%** |
| Nequi | 186 | 112 | 62 | 55.4% |
| Nubank CO | 137 | 77 | 46 | 59.7% |
| Kipo | 133 | 75 | 48 | 64.0% |

El reintento sobre declinaciones soft es genuinamente efectivo (~51–64% de conversión), pero el pool direccionable es pequeño. Para B+D en Fase 2, las declinaciones soft son solo ~58% de las declinaciones; el otro ~42% (`05`, `57`, `61`, etc.) no se puede recuperar con un reintento y **no debe** ser reintentado — reintentar una declinación hard le parece al emisor un patrón de mal actor y puede disparar bloqueos de velocidad a nivel de tarjeta.

Dimensionando la oportunidad de reintento: ajustar el reintento para capturar cada declinación soft de B+D recuperaría ~100–120 aprobaciones/mes adicionales, equivalentes a aproximadamente **+1.0 a +1.5 pp** de la tasa de autorización global. Útil, pero no es la solución para la caída de −11 a −16 pp.

### Q7 — ¿Hay un adquirente que tenga mejor desempeño?

| Adquirente | Tasa de autorización | Volumen |
|---|---|---|
| Redeban | 83.16% | 3.177 |
| Credibanco | 83.00% | 3.136 |
| Yuno | 82.03% | 3.106 |

Las tasas de autorización entre los tres adquirentes están a ~1 pp entre sí, y **los tres muestran el mismo bache de Fase 2 sobre el tráfico de Bancolombia / Davivienda**. Esto confirma que la causa está en el lado del emisor: cambiar el enrutamiento de adquirente no movería la tasa.

---

## Causa raíz

Entre el 2025-01-30 y el 2025-02-02, **Bancolombia y Davivienda endurecieron su política de autorización card-not-present sobre el tráfico de crédito**. El cambio es:

- **Dónde vive:** en el motor de riesgo del emisor, evaluado **antes** del paso de autenticación del tarjetahabiente.
- **Qué emite:** `05` (Do Not Honor) salta a 27.9% de las declinaciones en el cohort afectado, con `91` (Card Issuer Unavailable) manteniéndose alto en 24.1% mientras el endpoint de autorización del emisor se ralentiza bajo la nueva regla.
- **Dónde aterriza:** tarjetas de crédito en el canal e-commerce — la celda más baja en la matriz de Q5, en 81.14%.
- **A quién afecta:** Bancolombia (−10.6 pp) y Davivienda (−15.8 pp). Los neobancos no se ven afectados, descartando red, scheme, adquirente y causas del lado de Kipo.
- **Patrón temporal:** los dos bancos se degradan con ~2 días de diferencia y cada uno rampea durante ~4 días. Esto es consistente con dos emisores reaccionando independientemente al mismo disparador externo — lo más plausible es una alerta de fraude de SFC/UIAF o un boletín de fraude de Mastercard/Visa publicado a finales de enero.

La hipótesis 3DS2 queda **rechazada**: `05` y `61` son frenos hard del lado del emisor, no señales de abandono de autenticación.

---

## Recomendaciones

Ordenadas por impacto-por-semana-de-esfuerzo.

### 1. Abrir canales de issuer-relations con Bancolombia y Davivienda (esta semana)

Es la única palanca que ataca el ~42% de las declinaciones del cohort afectado que son hard. El ajuste de reintentos y la configuración 3DS no pueden mover `05`, `61` ni `57` — solo el emisor puede.

Pedidos puntuales:
- Confirmar el cambio de política y obtener la regla por escrito.
- Negociar una exención TRA (Transaction Risk Analysis) para transacciones de bajo valor (<30 USD) y para tarjetahabientes recurrentes con capturas previas exitosas en el mismo comercio.
- Pedir una whitelist a nivel de BIN para el tráfico B2B de Kipo BaaS.

### 2. Política de reintentos — allow-list fijo

Implementar reintento automático **solo** para estos códigos soft:

| Código | Backoff | Notas |
|---|---|---|
| `91` | 30–60s | El endpoint del emisor expiró; reintentar una vez. |
| `51` | notificar, no reintentar a ciegas | Fondos insuficientes requiere acción del tarjetahabiente. |
| `96` | 30–60s | Error de sistema; nunca reintentar inmediatamente. |

**Bloquear hard** el reintento sobre `05`, `57`, `61`, `14`, `54`, `41`, `43`. Reintentar cualquiera de estos escala a un bloqueo de velocidad sobre la tarjeta.

Levante esperado: **+1.0 a +1.5 pp** de la tasa de autorización global, concentrado en el pool soft de Bancolombia y Davivienda.

### 3. Alertamiento a nivel BIN (build de una sola vez)

Configurar una alerta en tiempo real sobre `auth_rate` por prefijo de BIN, con ventana móvil de 24 horas y umbral de caída >5 pp. Esta caída se habría detectado el día 30 con una alerta BIN en lugar de después de dos semanas de sangrado. Looker Studio puede servir de v1; la versión a largo plazo pertenece al stack de observabilidad.

### 4. Estrategia de exenciones 3DS2 (mediano plazo)

Aunque la fricción 3DS2 **no** es la causa raíz de la caída de Fase 2, la celda de crédito + e-commerce es estructuralmente débil. Un programa de exenciones TRA con los emisores levantaría la tasa de cabecera independientemente de este incidente. Es una integración de 2–3 meses; no bloquear sobre ella el evento actual.

### 5. Agregar el playbook al runbook

Capturar esta categoría de incidente con un árbol de decisión:
- ¿Caída concentrada en 1–2 emisores? → llamar a issuer relations.
- ¿Caída en todos los emisores? → revisar estado de red / scheme, luego estado del adquirente.
- ¿Caída en un solo canal? → revisar el historial de deploys del motor de riesgo de Kipo.
- ¿Participación hard de las nuevas declinaciones >40%? → el ajuste de reintentos no ayudará; la palanca está en el emisor.

---

## Cómo correr este caso de estudio

```bash
# 1. Instalar dependencias
pip install faker

# 2. Generar el dataset sintético
cd case-studies/01-card-payment-lifecycle
python data/generate_data.py
# → 15 archivos CSV escritos en data/raw/

# 3. Crear tablas en BigQuery
# Abrir sql/01_ddl.sql en BigQuery, reemplazar IDs de proyecto si es necesario, y ejecutar.

# 4. Subir CSVs a GCS y cargar en BigQuery
gsutil -m cp data/raw/*.csv gs://your-bucket/kipo/raw/
# Luego ejecutar sql/02_load_data.sql en BigQuery (reemplazar proyecto y bucket).

# 5. Ejecutar las queries de análisis
# Abrir sql/03_analysis.sql en BigQuery, correr Q1–Q7 (página 1),
# Q8–Q13 (página 2 de tasa de aceptación), y OV1–OV5 (página overview).

# 6. Construir el dashboard
# Seguir dashboard/README.md — cada chart mapea a una de las queries.
```

---

## Archivos

```
01-card-payment-lifecycle/
├── README.md                 ← este archivo (análisis canónico)
├── README_v2.md              ← notas de metodología + recomendaciones extendidas
├── data/
│   ├── generate_data.py      ← generador sintético (ramp escalonado, QUOTE_NONNUMERIC para BigQuery)
│   └── raw/                  ← CSVs generados (comiteados)
├── sql/
│   ├── 01_ddl.sql            ← sentencias CREATE TABLE para BigQuery
│   ├── 02_load_data.sql      ← carga CSVs desde GCS a BigQuery
│   └── 03_analysis.sql       ← Q1–Q13 + OV1–OV5
└── dashboard/
    └── README.md             ← guía de build para Looker Studio
```
