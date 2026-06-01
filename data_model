# Esquema de datos — Pagos con tarjeta

> Caso de estudio 01 · Kipo Fintech · Ciclo de vida completo de una transacción con tarjeta débito (Mastercard · Visa).

El esquema cubre desde la evaluación de riesgo previa a la autorización hasta la liquidación, reembolsos y disputas. Incluye catálogos de emisores, BINs, adquirentes y decline codes para análisis segmentado.

---

## Diagrama ERD

```mermaid
erDiagram

  issuer {
    uuid id PK
    varchar name
    varchar short_name
    varchar country
    varchar network
    varchar issuer_type
    decimal avg_auth_rate
    decimal avg_soft_decline_rate
    timestamp created_at
  }

  bin_range {
    uuid id PK
    uuid issuer_id FK
    varchar bin_prefix
    varchar bin_length
    varchar card_type
    varchar card_brand
    varchar card_level
    boolean is_active
    timestamp created_at
  }

  card {
    uuid id PK
    uuid user_id FK
    uuid bin_range_id FK
    varchar last_four
    varchar network_token
    varchar card_type
    varchar status
    timestamp created_at
    timestamp expires_at
  }

  merchant {
    uuid id PK
    varchar name
    varchar legal_name
    varchar mcc
    varchar mcc_description
    varchar country
    varchar city
    varchar channel
    varchar status
    timestamp onboarded_at
  }

  acquirer {
    uuid id PK
    varchar name
    varchar processor_name
    varchar network
    varchar country
    decimal historical_auth_rate
    varchar status
  }

  decline_code_catalog {
    varchar code PK
    varchar description
    varchar decline_type
    varchar recommended_action
    varchar source
  }

  payment_intent {
    uuid id PK
    uuid card_id FK
    varchar network_token
    uuid user_id FK
    uuid merchant_id FK
    uuid order_id FK
    varchar customer_type
    decimal amount_usd
    varchar currency
    varchar channel
    varchar entry_mode
    varchar idempotency_key
    varchar status
    timestamp created_at
  }

  risk_evaluation {
    uuid id PK
    uuid payment_intent_id FK
    int fraud_score
    varchar decision
    varchar block_reason
    varchar device_id
    varchar ip_address
    varchar geolocation
    boolean velocity_flag
    boolean bin_flag
    boolean blacklist_hit
    timestamp evaluated_at
  }

  authorization {
    uuid id PK
    uuid payment_intent_id FK
    uuid acquirer_id FK
    varchar processor_id
    varchar network
    varchar auth_code
    varchar response_code
    varchar decline_code FK
    varchar decline_type
    boolean is_3ds
    varchar three_ds_result
    decimal authorized_amount_usd
    timestamp authorized_at
    timestamp expires_at
  }

  auth_attempt {
    uuid id PK
    uuid payment_intent_id FK
    uuid acquirer_id FK
    int attempt_number
    varchar routing_reason
    varchar response_code
    varchar decline_code FK
    varchar decline_type
    boolean retried
    timestamp attempted_at
  }

  capture {
    uuid id PK
    uuid authorization_id FK
    decimal captured_amount_usd
    boolean is_partial
    timestamp captured_at
    timestamp late_capture_at
  }

  void_reversal {
    uuid id PK
    uuid authorization_id FK
    varchar reason
    varchar initiated_by
    timestamp voided_at
  }

  settlement_batch {
    uuid id PK
    uuid acquirer_id FK
    date settlement_date
    int transaction_count
    decimal gross_amount_usd
    decimal interchange_fee_usd
    decimal scheme_fee_usd
    decimal acquirer_fee_usd
    decimal net_amount_usd
    varchar status
    timestamp created_at
  }

  refund {
    uuid id PK
    uuid capture_id FK
    uuid settlement_batch_id FK
    decimal amount_usd
    boolean is_partial
    varchar reason
    varchar status
    varchar initiated_by
    timestamp requested_at
    timestamp processed_at
  }

  dispute {
    uuid id PK
    uuid capture_id FK
    varchar chargeback_id
    varchar reason_code
    varchar dispute_type
    decimal disputed_amount_usd
    decimal chargeback_fee_usd
    varchar status
    varchar outcome
    timestamp opened_at
    timestamp due_date
    timestamp resolved_at
  }

  issuer ||--o{ bin_range : "owns"
  bin_range ||--o{ card : "classifies"
  card ||--o{ payment_intent : "used in"
  merchant ||--o{ payment_intent : "receives"
  acquirer ||--o{ authorization : "processes via"
  acquirer ||--o{ auth_attempt : "attempted via"
  acquirer ||--o{ settlement_batch : "settles in"
  decline_code_catalog ||--o{ authorization : "explains"
  decline_code_catalog ||--o{ auth_attempt : "explains"
  payment_intent ||--|| risk_evaluation : "evaluates"
  payment_intent ||--o{ auth_attempt : "logs"
  payment_intent ||--o| authorization : "results in"
  authorization ||--o| capture : "captured via"
  authorization ||--o| void_reversal : "voided via"
  capture ||--o{ refund : "refunded via"
  capture ||--o{ dispute : "disputed via"
  capture }o--|| settlement_batch : "settled in"
```

---

## Tablas y propósito

| Tabla | Tipo | Propósito |
|---|---|---|
| `issuer` | Catálogo | Emisores (bancos y fintechs) con métricas de auth rate y soft decline rate por banco |
| `bin_range` | Catálogo | Rangos de BIN asociados a cada emisor. Permite segmentar por tipo y nivel de tarjeta |
| `card` | Catálogo | Instrumento de pago del usuario, vinculado a su BIN y por tanto a su emisor |
| `merchant` | Catálogo | Comercios con MCC para análisis de interchange y segmentación por industria |
| `acquirer` | Catálogo | Adquirentes con los que Kipo tiene contrato. Base para análisis de performance |
| `decline_code_catalog` | Catálogo | Códigos de rechazo de Mastercard y Visa con descripción, tipo (hard/soft) y acción recomendada |
| `payment_intent` | Transaccional | Intento de pago del usuario. Centro del esquema. Registra todos los intentos, aprobados o no |
| `risk_evaluation` | Transaccional | Evaluación del motor antifraude de Kipo antes de enviar a la red. Registra bloqueos internos |
| `auth_attempt` | Transaccional | Cada intento individual hacia un adquirente. Permite analizar retry logic y cascading |
| `authorization` | Transaccional | Resultado final de la autorización. Tiene el auth code si fue aprobada o el decline code si no |
| `capture` | Transaccional | Confirmación del cobro. El dinero queda retenido. Puede ser parcial |
| `void_reversal` | Transaccional | Cancelación antes de captura. La autorización se revierte sin cobro |
| `settlement_batch` | Transaccional | Batch de liquidación con fees desglosados: interchange, scheme fee y acquirer fee |
| `refund` | Transaccional | Devolución total o parcial después de captura |
| `dispute` | Transaccional | Contracargo formal. Incluye costo de gestión y resultado (ganado/perdido) |

---

## Métricas que se pueden construir con este esquema

| Métrica | Tablas involucradas |
|---|---|
| Auth rate | `auth_attempt` + `payment_intent` |
| Acceptance rate | `risk_evaluation` + `payment_intent` + `capture` |
| Fraud rate | `risk_evaluation` + `dispute` |
| Chargeback rate | `dispute` + `capture` |
| Cost per transaction | `settlement_batch` + `dispute` |
| Settlement time | `capture` + `settlement_batch` |
| Soft declines por emisor | `auth_attempt` + `payment_intent` + `card` + `bin_range` + `issuer` |

---
