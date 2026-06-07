# Case Study 01 — Why did our authorization rate drop?

**Kipo Fintech · Card Payments · Enero–Marzo 2025**

> **Rol:** Product Manager
> **Stack:** BigQuery · Data Studio
> **Dataset:** 10,000 payment intents sintéticos · 9,419 authorization attempts · 60 días

---

## 01 · Contexto

Kipo es una fintech colombiana hipotética con licencia Sedpe que emite tarjetas débito y crédito Mastercard y Visa para ~4.2 millones de usuarios en la Colombia, y procesa pagos de comercios pequeños.

El **authorization rate** es la métrica más vigilada en pagos con tarjeta: el porcentaje de intentos de autorización que resultan en una aprobación. Una caída de 5 puntos porcentuales tiene impacto inmediato en ingresos y en la confianza del usuario. Si la transacción no pasa, Kipo no cobra interchange.

El flujo de una transacción sigue este orden: evaluación de riesgo → intento de autorización → captura → liquidación. Si un pago es rechazado antes de la autorización, todo el pipeline se rompe.

Kipo actúa como emisor, y procesador de pagos. Sus adquirentes son Credibanco, Redeban y Yuno. Los issuers de las tarjetas de los usuarios son Bancolombia, Davivienda, Nequi, Nubank y Kipo self-issued.

---

## 02 · Problem statement

> "¿Qué está causando la caída en el auth rate — y qué arreglamos primero?"
>
> — Head of Payments, Kipo · Febrero 2025

El auth rate pasó de ~85% en enero a ~80% en febrero. Una caída de 5 pp que se sostuvo durante semanas, no fue un evento aislado de un día.

Sin datos segmentados, la pregunta no tiene respuesta: ¿es el acquirer? ¿el issuer? ¿un canal específico? ¿un tipo de tarjeta? ¿un cambio de política del banco?

---

## 03 · El proceso

### 1. Diseño del esquema de datos

Diseño de un modelo de 15 tablas que cubre todo el ciclo de un pago con tarjeta (desde la intención hasta la disputa), estructurado para medir métricas críticas de negocio (tasas de autorización, aceptación, fraude, contracargos y costos).

### 2. Generación de datos sintéticos

Generación con Python de 10,000 registros que simulan 60 días de operación, incluyendo una caída deliberada en el rendimiento de Bancolombia y Davivienda a mitad del periodo para ser investigada.

### 3. Infraestructura y Visualización:

Carga de datos en BigQuery, creación de queries analíticas avanzadas (incluyendo reintentos y segmentación) y construcción de un dashboard de 3 páginas en Looker Studio (Visión General, Tasa de Autorización y Tasa de Aceptación).

### 4. Análisis de causa raíz

Con la data en BigQuery, hice un diagnóstico sistemático siguiendo cinco ejes de segmentación para identificar la causa raíz de la caída. Ver detalle en la sección siguiente. 

---

## 04 · El análisis de causa raíz

Ante una caída en el auth rate, hay cuatro dimensiones en este caso que segmentar: acquirer, issuer, canal y decline codes.

### Eje 1 · Performance por acquirer

Comparé Credibanco, Redeban y Yuno. Los tres tienen tasas de autorización dentro de ~1 pp entre sí:

| Acquirer | Auth rate |
|---|---|
| Redeban | 83.16% |
| Credibanco | 83.00% |
| Yuno | 82.03% |

Los tres muestran la misma degradación en el periodo de caída. Si el problema fuera del acquirer, un solo acquirer mostraría el dip — aquí todos lo muestran por igual.

### Eje 2 · Performance por issuer

Aquí apareció el primer finding relevante.

| Issuer | Enero | Febrero | Δ |
|---|---|---|---|
| Davivienda | 82.55% | 66.80% | **−15.8 pp** |
| Bancolombia | 83.13% | 72.57% | **−10.6 pp** |
| Nequi | 83.40% | 85.55% | +2.1 pp |
| Nubank CO | 85.65% | 88.63% | +3.0 pp |
| Kipo (self-issued) | 89.67% | 89.21% | −0.5 pp |

El problema está concentrado enteramente en Davivienda y Bancolombia.

### Eje 3 · Segmentación por canal y tipo de tarjeta

Pivot de auth rate por canal × tipo de tarjeta:

| | E-commerce | In-app | POS |
|---|---|---|---|
| Crédito | **81.14%** | 84.12% | 82.73% |
| Débito | 83.93% | 80.84% | 84.90% |

El performance más baja es crédito + e-commerce (81.14%). El diferencial existe, pero no es lo suficientemente marcado para ser la causa raíz.

### Eje 4 · Segmentación de decline codes

Este fue el eje con más insights. La distribución global de declines:

| Código | Descripción | Tipo | Conteo | % del total |
|---|---|---|---|---|
| `91` | Card Issuer Unavailable | soft | 394 | 24.2% |
| `51` | Insufficient Funds | soft | 340 | 20.9% |
| `96` | System Error | soft | 321 | 19.7% |
| `05` | Do Not Honor | hard | 271 | 16.7% |
| `61` | Exceeds Withdrawal Limit | hard | 63 | 3.9% |
| `57` | Transaction Not Permitted | hard | 62 | 3.8% |

El código `05` (Do Not Honor) pasó de ~17% a ~28% de todos los declines. Al ser un hard decline: la decisión la toma el risk engine del banco y no se debe hacer retry.

**Sof: 65%**
- **`91` (Card Issuer Unavailable):** el issuer tuvo un timeout → retry una vez con delay de 30–60s.
- **`51` (Insufficient Funds):** el usuario no tiene fondos → no hacer retry. Notificar al usuario para que tome acción.
- **`96` (System Error):** error de sistema → retry con delay. Nunca retry inmediato.

**Hard: 65%**
- **`05`, `57`, `61`, `14`, `54`, `41`, `43`:** Mantener bloqueados para retry.

### Eje 5 · Performance del retry en soft declines

Del pool de soft declines, analicé la tasa de conversión en segundo intento:

| Issuer | Soft declines | Retried | Recovered | Retry success |
|---|---|---|---|---|
| Bancolombia | 225 | 128 | 67 | 52.3% |
| Davivienda | 265 | 149 | 76 | 51.0% |
| Nequi | 186 | 112 | 62 | 55.4% |
| Nubank CO | 137 | 77 | 46 | 59.7% |
| Kipo | 133 | 75 | 48 | 64.0% |

El retry funciona (~51–64% de conversión). Sin embargo, el pool addressable es pequeño.

---

## 05 · El dashboard

Dashboard de 3 páginas en Looker Studio. Métricas comparadas contra benchmark de mercado para Latam y Colombia.

**Página 1 · Overview**

Funnel completo: 10,000 intents → 8,878 attempted (−11.2%) → 7,793 authorized (−12.2%) → 7,009 captured (−10.1%).

---

## 06 · Key findings

**1. La caída es real y sostenida.** El auth rate pasó de ~85% en Enero a ~80% en febrero. No es un evento de un día — se sostuvo durante semanas, lo que descarta errores transitorios de red.

**2. Bancolombia y Davivienda son el origen.** Caídas de −10.6 pp y −15.8 pp respectivamente. Los tres neobancos se mantuvieron estables.


**3. El código 05 (Do Not Honor) es la señal más fuerte.** El decline `05` pasó de ~17% a ~28% de todos los declines en febrero. Es una decisión del risk engine del banco.

**4. El retry funciona — pero sobre un pool limitado.** Los soft declines (91, 96) tienen ~51–64% de conversión en segundo intento. 

Adicional a la caida del auth rate, valide otras metricas importantes:

**5. El acceptance rate (70%) está muy por debajo del auth rate (82.7%).** Un 11.2% de los intents no llegan a auth attempt porque son bloqueados internamente. Un hallazgo importante para revisar.

---

## 07 · Recomendaciones

Ordenadas por impacto por semana de esfuerzo.

### P1 · Abrir conversación con Bancolombia y Davivienda 

El objetivo:

- Entender la política de cambio y tenerla documentada.
- Negociar exenciones TRA para transacciones de bajo valor 30USD, considerando que el promedio de transaccion de Kipo es 30.51USD la medida podria tener algo impacto

### P2 · Ajustar la política de retry con allow-list por código

Implementar retry automático **solo** para códigos soft:

| Código | Backoff | Notas |
|---|---|---|
| `91` | 30–60s | Timeout del issuer. Retry una vez. |
| `96` | 30–60s | Error de sistema. Nunca retry inmediato. |

### P3 · Ajustar la experiencia de fondos insuficientes

Notificar al usuario sobre la falta de fondos e invitarlo a que busque completar la transacción. 

---

## 08 · Reflection

Lo más valioso del proceso fue entender el orden en que hay que hacer las preguntas. Ante una caída en auth rate, la tentación es ir directo a los decline codes. Pero si no segmentas primero por acquirer e issuer, cualquier finding sobre decline codes puede ser ruido.

La segunda lección fue sobre el retry. Es fácil pensar en que todo soft decline debe ser parte del proceso de retry, pero hay algunos que van a necesitar mas acciones por parte del usuario.

---

## 09 · Skills demostradas

| Área | Skills |
|---|---|
| Payments | Authorization flow · Decline codes · Retry logic · Issuer vs acquirer economics |
| Data | BigQuery · SQL · Looker Studio · Python (Faker) |
| Arquitectura | ERD design · 15-tabla schema · partitioning · clustering |
| PM analysis | Causa raíz · Segmentación sistemática · Priorización por impacto |
| Ecosistema | Issuers · Acquirers · 3DS2 · TRA exemptions · Benchmarks Latam |
| Producto | Acceptance rate · Fraud rate · Chargeback rate · Cost per txn |

---

*Kipo es una empresa ficticia creada para explorar y compartir cómo funciona la infraestructura de pagos en Colombia y Latam. Todo el contenido es sintético y tiene fines educativos.*