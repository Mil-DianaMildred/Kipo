# Kipo — Fintech

> **English** (main) · [Español](#-versión-en-español)

---

# English version

> **"Your money, no detours."**
> A fictional company built as a framework to explore and share how payments infrastructure really works in Colombia: cards, wallets, cash-in/cash-out, QR, BaaS, and regulatory compliance.

---

## What is Kipo?

Kipo is a hypothetical Colombian fintech inspired by companies like Tpaga, Bold, and Nubank. It started as a financial super-app targeting informal Colombia — people without a bank account, without a credit history, and who operate primarily in cash. In late 2025, Kipo opened up its payments infrastructure as a **Banking as a Service (BaaS)** platform, allowing other fintechs, marketplaces, and tech companies to build financial products on the same rails Kipo uses internally.

This repository contains case studies, technical analyses, and product documentation that use Kipo as context to explore and share how the payments ecosystem works in Colombia and LatAm.

---

## Business structure

### B2C · Kipo App
**Segment:** Informal Colombia — under-banked people without a first account.

| Product | Technical description |
|---|---|
| Digital wallet | Low-value deposit account regulated under the Sedpe scheme. Real-time balance, transactions, and push notifications. |
| Mastercard · Visa debit and credit card | Virtual + physical card issuance (debit against the wallet, credit against an assigned line). Flow: authorization → network (Mastercard or Visa) → Kipo issuer. Supports NFC tokenization (Apple Pay / Google Wallet). |
| QR payments | Interoperable QR via Transfiya. The merchant generates the QR; Kipo resolves the payment instruction against the user's balance in <3s. |
| Transfers | Real-time ACH transfers and PSE debits for online payments. No cost to the user. |
| Bill pay | Integration with utility, telephony, and internet operators via collection agreements (SPE). |
| Cash-in | Cash deposit through a correspondent network: Efecty, Baloto, Éxito. The cashier generates a code; Kipo credits the balance in <60s after confirming the transaction with the correspondent. |
| Cash-out | Cash withdrawal at enabled ATMs and correspondents. The system validates available balance, generates a withdrawal PIN, and records the outflow with automatic reconciliation. |

### B2B · Kipo Platform (BaaS)
**Pivot:** launched in Q4 2025.
**Segment:** Fintechs, neobanks, marketplaces, and tech companies that need to process payments or issue financial products without connecting directly to the banking network.

| API / Module | Capability |
|---|---|
| Virtual accounts | Programmatic account opening, biometric KYC, balance and transaction management. Multi-tenant: each client company has its own namespace. |
| Card issuing | White-label issuing of Mastercard and Visa debit and credit cards (virtual and physical). Limit controls, block/unblock, and API-configurable controls. |
| Transfer engine | ACH Colombia and Transfiya. The client company instructs the movement via API; Kipo executes, confirms, and notifies via webhook. |
| QR gateway | QR generation and resolution for merchants. Supports one-off charges and dynamic QR with embedded amount. |
| Anti-fraud module | Configurable rules + ML scoring. Signals: device ID, geolocation, transactional velocity, UIAF blacklists. |
| Reconciliation | Real-time settlement reports. Export to CSV/JSON. Automatic reconciliation between processed transactions and received funds. |
| SMB accounts | Collection accounts for small businesses. Receive QR, PSE, and transfer payments; check balance and generate payment links. |

---

## Company context (fictional data)

| Field | Value |
|---|---|
| Country | Colombia |
| Founded | 2019 |
| Stage | Series B · USD $48M raised |
| B2C active users | ~4.2 million |
| B2B clients (Platform) | 38 companies |
| Regulatory license | Sedpe (Specialized Electronic Deposits and Payments Company) |
| Regulators | Colombian Financial Superintendency (SFC) · UIAF |
| Payment networks | Mastercard · Visa · ACH Colombia · Transfiya |
| Correspondents | Efecty · Baloto · Éxito locations |

### Why Sedpe and not a bank
The Sedpe license (the same scheme used by Nequi and Daviplata) allows for taking low-value deposits, operating wallets, and connecting to Transfiya/ACH without requiring full bank reserves. This defines the balance caps, daily transaction limits, and SARLAFT requirements that appear in the case studies.

### Card networks: Mastercard and Visa
Kipo operates with both networks in debit and credit mode to maximize coverage and flexibility in the issuance program. Mastercard offers better access conditions for growth-stage fintechs in Colombia; Visa expands international acceptance and access to certain merchant segments. Debit and credit have similar authorization flows but differ in settlement, interchange fees, and risk management — differences relevant to the case studies.

---

## Relevant tech stack

```
Card issuing            Mastercard Debit & Credit Issuing · Visa Debit & Credit Program
Transfers               ACH Colombia · Transfiya
Online payments         PSE (bank debit)
Authentication          3DS2 (3-D Secure 2.x)
Tokenization            NFC (Apple Pay / Google Wallet)
Anti-fraud              Rules engine + ML scoring · UIAF lists
Onboarding              Biometric KYC (ID + selfie + liveness)
Reconciliation          Automatic, real-time with JSON/CSV export
BaaS architecture       Multi-tenant virtual accounts · event webhooks
Compliance              SARLAFT · LAFT · UIAF reporting
```

---

## Case studies in this repository

> The cases explore how Colombia's payments infrastructure works technically — real flows, architectural decisions, and the business logic behind each payment method.

| # | Case | Key concepts | Status | Link |
|---|---|---|---|---|
| 01 | Full debit and credit card payment flow (Mastercard · Visa) | Authorization, capture, settlement, interchange, chargebacks | Published | [Case Study]([case-studies/01-card-payment-lifecycle/README.md](https://dianamildred.lovable.app/projects/kipo)) · [Dashboard]([case-studies/01-card-payment-lifecycle/README_v2.md](https://datastudio.google.com/reporting/3548d15e-10e5-4016-87c2-bb2645912af9)) · [Repo]([https://github.com/Mil-DianaMildred/Kipo/tree/main/case-studies#:~:text=..-,01%2Dcard%2Dpayment%2Dlifecycle,-Remove%20flag%20emojis]) | 
| 02 | Cash-in via correspondent and wallet credit | Correspondent protocol, reconciliation, cash fraud prevention | In progress |   |
| 03 | Interoperable QR payments with Transfiya | QR generation, payment instruction, response time, fallback | Backlog |   |
| 04 | Real-time ACH transfers | Clearing windows, error handling, returns | Backlog |   |
| 05 | White-label card issuing (BaaS) | Issuing API, card controls, tokenization, lifecycle management | Backlog |   |
| 06 | Anti-fraud engine and transaction scoring | Risk signals, configurable rules, false-positive rates, 3DS2 | Backlog |   |
| 07 | Automatic reconciliation and settlement | Match between authorized, captured, and received funds | Backlog |   |
| 08 | KYC onboarding and SARLAFT compliance | Biometric flow, restrictive lists, UIAF transactional monitoring | Backlog |   |

### ZAPIER AS A REFERENCE FOR HOW THEY TURNED AN API INTO A VIBECODER PRODUCT

---

## Inspiration and real-world references

Kipo is a fictional company built taking real references from:

- **Tpaga** — B2C → BaaS model, Sedpe license, correspondents in Colombia
- **Bold** — payments infrastructure for merchants, acquiring
- **Yuno** — payments orchestration, multiple acquirers, smart routing

> Kipo puts into practice all the Payments knowledge from Zaira Zatarain compiled in her [Payments PM Roadmap](https://zzatarain.gumroad.com/l/roadmap-pagos?layout=profile)
---

## About this repository

Kipo is a fictional company built to have a concrete context from which to explore and share how payments work in Colombia and LatAm. All content (company, metrics, clients) is fictional and intended for educational purposes.

The case studies ground real ecosystem concepts: SFC/UIAF regulation, ACH and Transfiya networks, Mastercard and Visa issuing, authorization and settlement flows, and BaaS architectures — using Kipo as the connecting thread.

---

# Versión en español

> **"Tu plata, sin rodeos."**
> Empresa ficticia creada como marco de trabajo para explorar y compartir cómo funciona realmente la infraestructura de pagos en Colombia: tarjetas, wallets, cash-in/cash-out, QR, BaaS y cumplimiento regulatorio.

---

## ¿Qué es Kipo?

Kipo es una fintech colombiana hipotética inspirada en empresas como Tpaga, Bold, y Nubank. Nació como una super-app financiera dirigida a la Colombia informal — personas sin cuenta bancaria, sin historial crediticio y que operan principalmente en efectivo. A finales de 2025, Kipo abrió su infraestructura de pagos como plataforma de **Banking as a Service (BaaS)**, permitiendo que otras fintechs, marketplaces y empresas de tecnología construyan productos financieros sobre los mismos rieles que Kipo usa internamente.

Este repositorio contiene casos de estudio, análisis técnicos y documentación de producto que usan a Kipo como contexto para explorar y compartir cómo funciona el ecosistema de pagos en Colombia y Latam.

---

## Estructura del negocio

### B2C · Kipo App
**Segmento:** Colombia informal — personas sub-bancarizadas sin primera cuenta.

| Producto | Descripción técnica |
|---|---|
| Billetera digital | Cuenta de depósito de bajo valor regulada bajo esquema Sedpe. Saldo en tiempo real, movimientos y notificaciones push. |
| Tarjeta débito y crédito Mastercard · Visa | Emisión de tarjeta virtual + física (débito contra wallet, crédito contra línea asignada). Flujo: autorización → red (Mastercard o Visa) → emisor Kipo. Soporta tokenización NFC (Apple Pay / Google Wallet). |
| Pagos QR | QR interoperable vía Transfiya. El comercio genera el QR; Kipo resuelve la instrucción de pago contra el saldo del usuario en <3s. |
| Transferencias | Transferencias ACH en tiempo real y débitos PSE para pagos online. Sin costo para el usuario. |
| Pago de facturas | Integración con operadores de servicios públicos, telefonía e internet vía convenios de recaudo (SPE). |
| Cash-in | Depósito de efectivo en red de corresponsales: Efecty, Baloto, Éxito. El cajero genera un código; Kipo acredita el saldo en <60s tras confirmar la transacción con el corresponsal. |
| Cash-out | Retiro de efectivo en cajeros habilitados y corresponsales. El sistema valida saldo disponible, genera PIN de retiro y registra el egreso con conciliación automática. |

### B2B · Kipo Platform (BaaS)
**Pivot:** lanzado en Q4 2025.
**Segmento:** Fintechs, neobancos, marketplaces y empresas de tecnología que necesitan procesar pagos o emitir productos financieros sin conectarse directamente a la red bancaria.

| API / Módulo | Capacidad |
|---|---|
| Cuentas virtuales | Apertura programática de cuentas, KYC biométrico, gestión de saldo y movimientos. Multi-tenant: cada empresa cliente tiene su propio namespace. |
| Emisión de tarjetas | Emisión white-label de tarjetas Mastercard y Visa débito y crédito (virtual y física). Control de límites, bloqueo/desbloqueo y configuración de controles por API. |
| Motor de transferencias | ACH Colombia y Transfiya. La empresa cliente instruye el movimiento vía API; Kipo ejecuta, confirma y notifica vía webhook. |
| Gateway QR | Generación y resolución de QR para comercios. Soporta cobros únicos y QR dinámico con monto embebido. |
| Módulo antifraude | Reglas configurables + scoring ML. Señales: device ID, geolocalización, velocidad transaccional, listas negras UIAF. |
| Conciliación | Reportes de liquidación en tiempo real. Exportación a CSV/JSON. Cuadre automático entre transacciones procesadas y fondos recibidos. |
| Cuentas pyme | Cuentas de cobro para pequeños negocios. Reciben pagos QR, PSE y transferencias; consultan saldo y generan links de pago. |

---

## Contexto de la empresa (datos ficticios)

| Dato | Valor |
|---|---|
| País | Colombia |
| Fundación | 2019 |
| Etapa | Serie B · USD $48M levantados |
| Usuarios activos B2C | ~4.2 millones |
| Clientes B2B (Platform) | 38 empresas |
| Licencia regulatoria | Sedpe (Sociedad Especializada en Depósitos y Pagos Electrónicos) |
| Reguladores | Superintendencia Financiera de Colombia (SFC) · UIAF |
| Redes de pago | Mastercard · Visa · ACH Colombia · Transfiya |
| Corresponsales | Efecty · Baloto · puntos Éxito |

### Por qué Sedpe y no banco
La licencia Sedpe (el mismo esquema de Nequi y Daviplata) permite captar depósitos de bajo valor, operar wallets y conectarse a Transfiya/ACH sin requerir encaje bancario completo. Esto define los topes de saldo, los límites de transacción diaria y los requisitos de SARLAFT que aparecen en los casos de estudio.

### Redes de tarjetas: Mastercard y Visa
Kipo opera con ambas redes en modalidad débito y crédito para maximizar cobertura y flexibilidad en el programa de emisión. Mastercard ofrece mejores condiciones de acceso para fintechs en etapa de crecimiento en Colombia; Visa amplía la aceptación internacional y el acceso a ciertos segmentos de comercios. Débito y crédito tienen flujos de autorización similares pero difieren en liquidación, interchange fees y gestión de riesgo — diferencias relevantes en los casos de estudio.

---

## Stack técnico relevante

```
Emisión de tarjetas     Mastercard Debit & Credit Issuing · Visa Debit & Credit Program
Transferencias          ACH Colombia · Transfiya
Pagos online            PSE (débito bancario)
Autenticación           3DS2 (3-D Secure 2.x)
Tokenización            NFC (Apple Pay / Google Wallet)
Antifraude              Motor de reglas + scoring ML · listas UIAF
Onboarding              KYC biométrico (cédula + selfie + liveness)
Conciliación            Automática en tiempo real con exportación JSON/CSV
Arquitectura BaaS       Cuentas virtuales multi-tenant · webhooks de eventos
Cumplimiento            SARLAFT · LAFT · reporte a UIAF
```

---

## Casos de estudio en este repositorio

> Los casos exploran cómo funciona la infraestructura técnica de pagos en Colombia — flujos reales, decisiones de arquitectura y lógica de negocio detrás de cada método de pago.

| # | Caso | Conceptos clave | Status | Link |
|---|---|---|---|---|
| 01 | Flujo completo de pago con tarjeta débito y crédito (Mastercard · Visa) | Autorización, captura, liquidación, interchange, contracargos | Publicado | [v1](case-studies/01-card-payment-lifecycle/README.md) · [v2](case-studies/01-card-payment-lifecycle/README_v2.md) |
| 02 | Cash-in vía corresponsal y acreditación en wallet | Protocolo corresponsal, conciliación, prevención de fraude en efectivo | En proceso |   |
| 03 | Pagos QR interoperables con Transfiya | Generación de QR, instrucción de pago, tiempo de respuesta, fallback | Backlog |   |
| 04 | Transferencias ACH en tiempo real | Ventanas de compensación, manejo de errores, devoluciones | Backlog |   |
| 05 | Emisión de tarjeta white-label (BaaS) | API de emisión, controles de tarjeta, tokenización, gestión del ciclo de vida | Backlog |   |
| 06 | Motor antifraude y scoring de transacciones | Señales de riesgo, reglas configurables, tasas de falsos positivos, 3DS2 | Backlog |   |
| 07 | Conciliación automática y liquidación | Cuadre entre transacciones autorizadas, capturadas y fondos recibidos | Backlog |   |
| 08 | Onboarding KYC y cumplimiento SARLAFT | Flujo biométrico, listas restrictivas, monitoreo transaccional UIAF | Backlog |   |

### ZAPIER COMO REFERENCIA DE COMO VOLVIERON UNA API PARA VIBECODER

---

## Inspiración y referentes reales

Kipo es una empresa ficticia construida tomando como referencia el funcionamiento real de:

- **Tpaga** — modelo B2C → BaaS, licencia Sedpe, corresponsales en Colombia
- **Bold** — infraestructura de pagos para comercios, adquirencia
- **Yuno** — orquestación de pagos, múltiples adquirentes, smart routing

> Kipo pone en plactica todo el conocimiento de Payments de Zaira Zatarain recopilado en su [Roadmap para PM de Payments](https://zzatarain.gumroad.com/l/roadmap-pagos?layout=profile)
---

## Sobre este repositorio

Kipo es una empresa ficticia construida para tener un contexto concreto desde donde explorar y compartir cómo funcionan los pagos en Colombia y Latam. Todo el contenido (empresa, métricas, clientes) es ficticio y tiene fines educativos.

Los casos de estudio aterrizan conceptos reales del ecosistema: regulación SFC/UIAF, redes ACH y Transfiya, emisión Mastercard y Visa, flujos de autorización y liquidación, y arquitecturas BaaS — usando a Kipo como hilo conductor.
