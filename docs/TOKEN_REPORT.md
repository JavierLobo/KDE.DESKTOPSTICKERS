# Desktop Stickers Token Ledger

Consumo real de tokens y coste hipotético a tarifa de API de Claude,
calculado a partir de las transcripciones locales de Claude Code
guardadas para este proyecto (`~/.claude/projects/…KDE-STICKERS/`) — no
de una estimación. Desglosado por versión usando el commit de cada tag
(`v1.0.0`, `v1.1.0`, `v1.1.1`) como frontera temporal; lo posterior a
`v1.1.1` es la versión 1.2.0, todavía sin tag.

- **Proyecto:** Desktop Stickers
- **Periodo real:** 17 ago – 13 oct 2026
- **Sesiones analizadas:** 13 (10 con transcripción disponible + 3 ya eliminadas, con las cifras del informe anterior)
- **Fronteras de versión:** commits de los tags `v1.0.0` (7 sep 2026 10:38), `v1.1.0` (14 sep 2026 19:10) y `v1.1.1` (16 sep 2026 22:35), hora CEST
- **Facturación real del usuario:** Claude Pro, $20/mes (tarifa plana)

## Resumen

### Totales del proyecto

| Métrica | Valor |
|---|---:|
| Coste hipotético | **$602.17** |
| Tokens totales | 2,221.1M |
| Mensajes de modelo | 8,862 (sin contar las sesiones eliminadas) |
| Modelos usados | 4 (Sonnet 5 · Opus 5 · Opus 5.5 · Haiku 4.5) |

### Totales versión 1.0.0

| Métrica | Valor |
|---|---:|
| Coste hipotético | **$331.30** |
| Tokens totales | 1,206.5M |
| Mensajes de modelo | 5,903 (sin contar las sesiones eliminadas) |
| Modelos usados | 3 (Sonnet 5 · Opus 5 · Haiku 4.5) |

### Totales versión 1.1.0

| Métrica | Valor |
|---|---:|
| Coste hipotético | **$119.67** |
| Tokens totales | 497.7M |
| Mensajes de modelo | 1,182 (sin contar las sesiones eliminadas) |
| Modelos usados | 2 (Sonnet 5 · Haiku 4.5) |

### Totales versión 1.1.1

| Métrica | Valor |
|---|---:|
| Coste hipotético | **$84.46** |
| Tokens totales | 307.0M |
| Mensajes de modelo | 1,063 |
| Modelos usados | 3 (Sonnet 5 · Opus 5 · Haiku 4.5) |

### Totales versión 1.2.0

| Métrica | Valor |
|---|---:|
| Coste hipotético | **$66.74** |
| Tokens totales | 209.8M |
| Mensajes de modelo | 714 |
| Modelos usados | 2 (Sonnet 5 · Opus 5.5) |

## Coste y tokens por modelo

Solo sesiones con transcripción disponible: las sesiones ya eliminadas no
tienen desglose por modelo ni por tipo de token (se indican debajo de cada
tabla).

### Totales del proyecto

| Modelo | Mensajes | Input | Output | Caché lectura | Caché escritura | Coste |
|---|---:|---:|---:|---:|---:|---:|
| Claude Sonnet 5 | 7,596 | 21,058 | 3,582,849 | 1,894,942,843 | 25,357,998 | $505.26 |
| Claude Opus 5 | 478 | 1,507 | 55,253 | 43,774,079 | 1,444,408 | $32.30 |
| Claude Opus 5.5 | 258 | 516 | 200,035 | 70,491,092 | 445,562 | $21.67 |
| Claude Haiku 4.5 | 530 | 4,328 | 15,904 | 22,183,025 | 1,382,867 | $4.05 |
| **Total** | **8,862** | **27,409** | **3,854,041** | **2,031,391,039** | **28,630,835** | **$563.28** |

Más 157,229,017 tokens y $38.89 de sesiones ya eliminadas, sin desglose (Sonnet 5).

### Versión 1.0.0

| Modelo | Mensajes | Input | Output | Caché lectura | Caché escritura | Coste |
|---|---:|---:|---:|---:|---:|---:|
| Claude Sonnet 5 | 5,207 | 16,161 | 1,437,303 | 1,011,138,332 | 16,495,923 | $273.25 |
| Claude Opus 5 | 351 | 1,253 | 43,047 | 31,866,989 | 1,116,704 | $23.99 |
| Claude Haiku 4.5 | 345 | 2,808 | 15,520 | 14,376,387 | 677,788 | $2.39 |
| **Total** | **5,903** | **20,222** | **1,495,870** | **1,057,381,708** | **18,290,415** | **$299.63** |

Más 129,354,477 tokens y $31.67 de sesiones ya eliminadas, sin desglose (Sonnet 5).

### Versión 1.1.0

| Modelo | Mensajes | Input | Output | Caché lectura | Caché escritura | Coste |
|---|---:|---:|---:|---:|---:|---:|
| Claude Sonnet 5 | 1,165 | 2,350 | 976,403 | 465,896,262 | 2,495,719 | $112.35 |
| Claude Haiku 4.5 | 17 | 138 | 54 | 434,871 | 44,570 | $0.10 |
| **Total** | **1,182** | **2,488** | **976,457** | **466,331,133** | **2,540,289** | **$112.45** |

Más 27,874,540 tokens y $7.22 de sesiones ya eliminadas, sin desglose (Sonnet 5).

### Versión 1.1.1

| Modelo | Mensajes | Input | Output | Caché lectura | Caché escritura | Coste |
|---|---:|---:|---:|---:|---:|---:|
| Claude Sonnet 5 | 768 | 1,536 | 627,710 | 282,937,687 | 3,200,044 | $74.58 |
| Claude Opus 5 | 127 | 254 | 12,206 | 11,907,090 | 327,704 | $8.31 |
| Claude Haiku 4.5 | 168 | 1,382 | 330 | 7,371,767 | 660,509 | $1.57 |
| **Total** | **1,063** | **3,172** | **640,246** | **302,216,544** | **4,188,257** | **$84.46** |

### Versión 1.2.0

| Modelo | Mensajes | Input | Output | Caché lectura | Caché escritura | Coste |
|---|---:|---:|---:|---:|---:|---:|
| Claude Sonnet 5 | 456 | 1,011 | 541,433 | 134,970,562 | 3,166,312 | $45.08 |
| Claude Opus 5.5 | 258 | 516 | 200,035 | 70,491,092 | 445,562 | $21.66 |
| **Total** | **714** | **1,527** | **741,468** | **205,461,654** | **3,611,874** | **$66.74** |

## Coste por sesión

Varias sesiones cruzan la frontera entre versiones, así que la misma
sesión puede aparecer partida entre tablas — los tokens y el coste de
cada parte corresponden solo a los mensajes de ese lado de la frontera.

### Sesiones versión 1.0.0

| Sesión | Descripción | Periodo | Tokens | Coste |
|---|---|---|---:|---:|
| `f5e6aa6a…` | Desarrollo principal | 17–20 ago 2026 | 1,075,588,381 | $298.19 |
| `ff3871df…` | Publicación y distribución | 19 ago – 7 sep 2026 | 1,599,834 | $1.44 |
| `bb0f67b2…` | Fragmento (sesión ya eliminada) | 20 ago – 7 sep 2026 | 129,354,477 | $31.67 |
| **Total v1.0.0** | | | **1,206,542,692** | **$331.30** |

### Sesiones versión 1.1.0

| Sesión | Descripción | Periodo | Tokens | Coste |
|---|---|---|---:|---:|
| `ec74bf68…` | Post de LinkedIn | 7 sep 2026 | 302,515 | $0.22 |
| `ff3871df…` | Publicación y distribución | 7–9 sep 2026 | 39,360,169 | $11.70 |
| `06361e69…` | Desarrollo v1.1.0 | 14 sep 2026 | 425,125,977 | $98.54 |
| `e8439121…` | Traducciones con modelos locales | 14 sep 2026 | 5,061,706 | $1.99 |
| `bb0f67b2…` | Continuación (sesión ya eliminada) | 7 sep 2026 | 21,394,341 | $4.59 |
| `9e9c7906…` | Sesión del día (ya eliminada) | 7 sep 2026 | 5,748,825 | $1.90 |
| `8fe755f9…` | Sesión del día (ya eliminada) | 9 sep 2026 | 731,374 | $0.73 |
| **Total v1.1.0** | | | **497,724,907** | **$119.67** |

### Sesiones versión 1.1.1

| Sesión | Descripción | Periodo | Tokens | Coste |
|---|---|---|---:|---:|
| `06361e69…` | Desarrollo v1.1.0 | 14 sep 2026 | 2,784,998 | $0.59 |
| `ec74bf68…` | Post de LinkedIn | 14 sep 2026 | 913,210 | $0.71 |
| `6dd1714e…` | Informe de tokens | 14 sep 2026 | 4,780,247 | $1.98 |
| `0bd55827…` | v1.1.1: renderizado Markdown | 16 sep 2026 | 298,569,764 | $81.18 |
| **Total v1.1.1** | | | **307,048,219** | **$84.46** |

### Sesiones versión 1.2.0

| Sesión | Descripción | Periodo | Tokens | Coste |
|---|---|---|---:|---:|
| `0bd55827…` | v1.1.1: renderizado Markdown | 16 sep 2026 | 5,322,299 | $1.11 |
| `f221fe8e…` | Grabación de vídeo de la app | 20 sep 2026 | 130,400,731 | $42.42 |
| `ec74bf68…` | Post de LinkedIn | 21 sep 2026 | 1,104,641 | $0.72 |
| `f438299b…` | Medición de rendimiento | 22 sep 2026 | 1,851,647 | $0.82 |
| `ed626d13…` | v1.2.0 (esta conversación) | 13 oct 2026 | 71,137,205 | $21.67 |
| **Total v1.2.0** | | | **209,816,523** | **$66.74** |

## Esto no es lo que se pagó

El coste de arriba es una reconstrucción a tarifa de API pública, útil
como referencia de volumen — pero la facturación real es **Claude Pro**
(tarifa plana de $20/mes), así que el gasto real fueron los meses de
suscripción cubiertos, sin importar este total.

## Metodología

- Datos extraídos de las transcripciones locales de Claude Code aún
  presentes en `~/.claude/projects/…KDE-STICKERS/`: 10 sesiones y las
  transcripciones de sus **subagentes** (`<sesión>/subagents/`), que
  también son llamadas reales a la API.
- **Cambio respecto al informe del 14 sep 2026:** aquel contaba solo las
  transcripciones principales y dejaba fuera las de subagentes, por eso
  las cifras de v1.0.0 y v1.1.0 son ahora mayores (sobre todo la sesión
  `f5e6aa6a…`, cuyos 72 subagentes suman más tokens que la propia sesión).
  Las 3 sesiones que ya no están en disco (`bb0f67b2…`, `9e9c7906…`,
  `8fe755f9…`) conservan las cifras de aquel informe, sin desglose por
  modelo, así que el total sigue siendo un mínimo, no el 100% del consumo
  histórico.
- Cada llamada a la API se identifica por su `requestId` y se cuenta una
  sola vez, aunque el mismo mensaje aparezca duplicado en varios archivos
  de sesión por reanudaciones o bifurcaciones de la conversación.
- Fronteras de versión: timestamp del commit de cada tag — `v1.0.0`
  (`2026-09-07T08:38:51Z`), `v1.1.0` (`2026-09-14T17:10:59Z`) y `v1.1.1`
  (`2026-09-16T20:35:20Z`). Cada mensaje cuenta para la primera versión
  cuya frontera es igual o posterior a su timestamp; lo posterior a
  `v1.1.1` cuenta como versión 1.2.0 (todavía sin tag), e incluye también
  sesiones de esa época que no tocaron el código (vídeo, rendimiento,
  post de LinkedIn).
- Precios usados, por millón de tokens input/output: Opus 5.5 `$4 / $20`,
  Opus 5 `$5 / $25`, Sonnet 5 `$2 / $10`, Haiku 4.5 `$1 / $5`. Lectura de
  caché al `0.1×` el precio de input (`0.05×` en Opus 5.5); escritura de
  caché al `1.25×` con TTL de 5 minutos y al `2×` con TTL de 1 hora,
  según el desglose por TTL que trae cada mensaje — tarifas vigentes
  consultadas en octubre de 2026.
- La sesión `ed626d13…` (esta conversación) seguía activa al generar este
  informe: su coste y recuento de tokens crecieron después.

Versión HTML autocontenida (para compartir, abrir directo en el navegador):
[TOKEN_REPORT.html](TOKEN_REPORT.html)

Versión interactiva (con los datos del 14 sep 2026, sin actualizar): [Stickers Token Ledger](https://claude.ai/code/artifact/de7ea325-2c2c-4772-a104-ad4999c8f29d)
