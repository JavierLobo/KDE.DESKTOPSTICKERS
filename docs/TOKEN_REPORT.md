# Desktop Stickers Token Ledger

Consumo real de tokens y coste hipotético a tarifa de API de Claude,
calculado a partir de las transcripciones locales de Claude Code
guardadas para este proyecto (`~/.claude/projects/…KDE-STICKERS/`) — no
de una estimación. Desglosado por versión usando el commit de cada tag
(`v1.0.0`, `v1.1.0`) como frontera temporal.

- **Proyecto:** Desktop Stickers
- **Periodo real:** 17 ago – 14 sep 2026
- **Sesiones analizadas:** 9
- **Frontera v1.0.0 / v1.1.0:** commit del tag `v1.0.0`, 2026-09-07 10:38:51 +02:00
- **Facturación real del usuario:** Claude Pro, $20/mes (tarifa plana)

## Resumen

### Totales del proyecto

| Métrica | Valor |
|---|---:|
| Coste hipotético total | **$303.55** |
| Tokens totales | 1,136.1M |
| Mensajes de modelo | 2,807 |
| Modelos usados | 2 (Sonnet 5 · Haiku 4.5) |

### Totales versión 1.0.0

| Métrica | Valor |
|---|---:|
| Coste hipotético | **$182.96** |
| Tokens totales | 634.6M |
| Mensajes de modelo | 1,531 |
| Modelos usados | 2 (Sonnet 5 · Haiku 4.5) |

### Totales versión 1.1.0

| Métrica | Valor |
|---|---:|
| Coste hipotético | **$120.59** |
| Tokens totales | 501.5M |
| Mensajes de modelo | 1,276 |
| Modelos usados | 1 (Sonnet 5) |

## Coste y tokens por modelo

### Totales del proyecto

| Modelo | Mensajes | Input | Output | Caché lectura | Caché escritura | Coste |
|---|---:|---:|---:|---:|---:|---:|
| Claude Sonnet 5 | 2,798 | 7,494 | 2,573,234 | 1,119,754,119 | 13,431,266 | $303.42 |
| Claude Haiku 4.5 | 9 | 80 | 6,228 | 324,658 | 32,418 | $0.13 |
| **Total** | **2,807** | **7,574** | **2,579,462** | **1,120,078,777** | **13,463,684** | **$303.55** |

### Versión 1.0.0

| Modelo | Mensajes | Input | Output | Caché lectura | Caché escritura | Coste |
|---|---:|---:|---:|---:|---:|---:|
| Claude Sonnet 5 | 1,522 | 4,922 | 1,471,131 | 621,851,284 | 10,935,076 | $182.83 |
| Claude Haiku 4.5 | 9 | 80 | 6,228 | 324,658 | 32,418 | $0.13 |
| **Total** | **1,531** | **5,002** | **1,477,359** | **622,175,942** | **10,967,494** | **$182.96** |

### Versión 1.1.0

| Modelo | Mensajes | Input | Output | Caché lectura | Caché escritura | Coste |
|---|---:|---:|---:|---:|---:|---:|
| Claude Sonnet 5 | 1,276 | 2,572 | 1,102,103 | 497,902,835 | 2,496,190 | $120.59 |
| **Total** | **1,276** | **2,572** | **1,102,103** | **497,902,835** | **2,496,190** | **$120.59** |

Ninguna llamada de Haiku 4.5 cae después de la frontera de `v1.0.0` —
las 9 quedaron dentro del desarrollo de esa versión.

## Coste por sesión

Varias sesiones cruzan la frontera entre versiones (siguieron activas
después del commit de `v1.0.0`), así que la misma sesión puede aparecer
partida entre las dos tablas — el token/coste de cada mitad corresponde
solo a los mensajes de ese lado de la frontera.

### Sesiones versión 1.0.0

| Sesión | Periodo | Tokens | Coste |
|---|---|---:|---:|
| `f5e6aa6a…` | 17–20 ago 2026 | 503,671,486 | $149.84 |
| `ff3871df…` | 19 ago 2026 (fragmento, continúa en v1.1.0) | 1,599,834 | $1.44 |
| `bb0f67b2…` | 20 ago – 7 sep 2026 (fragmento, continúa en v1.1.0) | 129,354,477 | $31.67 |
| **Total v1.0.0** | | **634,625,797** | **$182.96** |

### Sesiones versión 1.1.0

| Sesión | Periodo | Tokens | Coste |
|---|---|---:|---:|
| `ff3871df…` | 7–9 sep 2026 (continuación) | 39,360,169 | $11.70 |
| `bb0f67b2…` | 7 sep 2026 (continuación) | 21,394,341 | $4.59 |
| `9e9c7906…` | 7 sep 2026 | 5,748,825 | $1.90 |
| `ec74bf68…` | 7–14 sep 2026 | 1,215,725 | $0.93 |
| `8fe755f9…` | 9 sep 2026 | 731,374 | $0.73 |
| `6dd1714e…` | 14 sep 2026 (en curso, esta conversación) | 2,736,125 | $1.27 |
| `06361e69…` | 14 sep 2026 | 425,735,068 | $97.58 |
| `e8439121…` | 14 sep 2026 | 4,582,073 | $1.90 |
| **Total v1.1.0** | | **501,503,700** | **$120.59** |

## Esto no es lo que se pagó

El coste de arriba es una reconstrucción a tarifa de API pública, útil
como referencia de volumen — pero la facturación real es **Claude Pro**
(tarifa plana de $20/mes), así que el gasto real fueron los meses de
suscripción cubiertos, sin importar este total.

## Metodología

- Datos extraídos de las 9 transcripciones locales de Claude Code aún
  presentes en `~/.claude/projects/…KDE-STICKERS/`; sesiones ya rotadas
  o eliminadas no están incluidas, así que este es un piso, no
  necesariamente el 100% del consumo histórico.
- Cada llamada a la API se identifica por su `requestId` y se cuenta
  una sola vez a nivel global, aunque el mismo mensaje aparezca
  duplicado en varios archivos de sesión (2,406 duplicados detectados
  y descartados) por reanudaciones/forks de conversación.
- La frontera de versión es el timestamp del commit del tag `v1.0.0`
  (`2026-09-07T10:38:51+02:00` → `08:38:51Z`): todo mensaje con
  timestamp igual o anterior cuenta como `v1.0.0`; todo mensaje
  posterior cuenta como `v1.1.0` (no hay tag más nuevo, así que ese
  bucket incluye también el trabajo posterior al commit de `v1.1.0`
  hasta hoy).
- Precios usados: Sonnet 5 `$2 / $10` por millón de tokens
  input/output; Haiku 4.5 `$1 / $5`; lectura de caché al `0.1×` el
  precio de input; escritura de caché al `2×` el precio de input para
  el TTL de 1 hora (`1.25×` para TTL de 5 minutos, sin uso registrado
  en este proyecto) — tarifas vigentes consultadas en septiembre de
  2026.
- El historial de commits del proyecto corre del 17 de agosto al 14 de
  septiembre de 2026.
- La sesión `6dd1714e…` (esta conversación) seguía activa al momento de
  generar este informe: su coste y recuento de tokens crecieron después.

Versión HTML autocontenida (para compartir, abrir directo en el navegador):
[TOKEN_REPORT.html](TOKEN_REPORT.html)

Versión interactiva: [Stickers Token Ledger](https://claude.ai/code/artifact/de7ea325-2c2c-4772-a104-ad4999c8f29d)
