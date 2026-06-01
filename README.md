# Kipo — Fintech Hipotética · Portafolio de PM de Pagos

> **"Tu plata, sin rodeos."**  
> Empresa ficticia creada como marco de trabajo para explorar y compartir cómo funciona realmente la infraestructura de pagos en Colombia: tarjetas, wallets, cash-in/cash-out, QR, BaaS y cumplimiento regulatorio.

---

## ¿Qué es Kipo?

Kipo es una fintech colombiana hipotética inspirada en empresas como Tpaga, Bold, Littio y Nubank. Nació como una super-app financiera dirigida a la Colombia informal — personas sin cuenta bancaria, sin historial crediticio y que operan principalmente en efectivo. A finales de 2025, Kipo abrió su infraestructura de pagos como plataforma de **Banking as a Service (BaaS)**, permitiendo que otras fintechs, marketplaces y empresas de tecnología construyan productos financieros sobre los mismos rieles que Kipo usa internamente.

Este repositorio contiene casos de estudio, análisis técnicos y documentación de producto que usan a Kipo como contexto para explorar y compartir cómo funciona el ecosistema de pagos en Colombia y Latam.

---

## Estructura del negocio

### B2C · Kipo App
**Segmento:** Colombia informal — personas sub-bancarizadas sin primera cuenta.

| Producto | Descripción técnica |
|---|---|
| Billetera digital | Cuenta de depósito de bajo valor regulada bajo esquema Sedpe. Saldo en tiempo real, movimientos y notificaciones push. |
| Tarjeta débito Mastercard | Emisión de tarjeta virtual + física. Flujo: autorización → red Mastercard → emisor Kipo → débito en wallet. Soporta tokenización NFC (Apple Pay / Google Wallet). |
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
| Emisión de tarjetas | Emisión white-label de tarjetas Mastercard débito (virtual y física). Control de límites, bloqueo/desbloqueo y configuración de controles por API. |
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
| Redes de pago | Mastercard · ACH Colombia · Transfiya |
| Corresponsales | Efecty · Baloto · puntos Éxito |

### Por qué Sedpe y no banco
La licencia Sedpe (el mismo esquema de Nequi y Daviplata) permite captar depósitos de bajo valor, operar wallets y conectarse a Transfiya/ACH sin requerir encaje bancario completo. Esto define los topes de saldo, los límites de transacción diaria y los requisitos de SARLAFT que aparecen en los casos de estudio.

### Por qué Mastercard
Para una fintech en etapa de crecimiento en Colombia, el programa de emisión de Mastercard ofrece mejores condiciones de acceso que Visa en este mercado. Esto es relevante al analizar interchange fees, unit economics de tarjeta y los flujos de autorización → compensación → liquidación.

---

## Stack técnico relevante

```
Emisión de tarjetas     Mastercard Debit Issuing Program
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

| # | Caso | Conceptos clave |
|---|---|---|
| 01 | Flujo completo de pago con tarjeta débito Mastercard | Autorización, captura, liquidación, interchange, contracargos |
| 02 | Cash-in vía corresponsal y acreditación en wallet | Protocolo corresponsal, conciliación, prevención de fraude en efectivo |
| 03 | Pagos QR interoperables con Transfiya | Generación de QR, instrucción de pago, tiempo de respuesta, fallback |
| 04 | Transferencias ACH en tiempo real | Ventanas de compensación, manejo de errores, devoluciones |
| 05 | Emisión de tarjeta white-label (BaaS) | API de emisión, controles de tarjeta, tokenización, gestión del ciclo de vida |
| 06 | Motor antifraude y scoring de transacciones | Señales de riesgo, reglas configurables, tasas de falsos positivos, 3DS2 |
| 07 | Conciliación automática y liquidación | Cuadre entre transacciones autorizadas, capturadas y fondos recibidos |
| 08 | Onboarding KYC y cumplimiento SARLAFT | Flujo biométrico, listas restrictivas, monitoreo transaccional UIAF |

---

## Inspiración y referentes reales

Kipo es una empresa ficticia construida tomando como referencia el funcionamiento real de:

- **Tpaga** — modelo B2C → BaaS, licencia Sedpe, corresponsales en Colombia
- **Bold** — infraestructura de pagos para comercios, adquirencia
- **Littio** — cuenta en dólares, perfil sub-bancarizado con aspiraciones globales
- **Nubank** — experiencia de usuario, onboarding digital, modelo de crédito
- **Yuno** — orquestación de pagos, múltiples adquirentes, smart routing

---

## Sobre este repositorio

Kipo es una empresa ficticia construida para tener un contexto concreto desde donde explorar y compartir cómo funcionan los pagos en Colombia y Latam. Todo el contenido (empresa, métricas, clientes) es ficticio y tiene fines educativos.

Los casos de estudio aterrizan conceptos reales del ecosistema: regulación SFC/UIAF, redes ACH y Transfiya, emisión Mastercard, flujos de autorización y liquidación, y arquitecturas BaaS — usando a Kipo como hilo conductor.

---

*Construido sobre los materiales del Roadmap para PM de Payments de Zaira Zatarain y el ecosistema real de pagos colombiano.*
