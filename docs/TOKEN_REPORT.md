# Stickers Token Ledger

Consumo real de tokens y costo hipotético a tarifa de API de Claude,
calculado a partir de las transcripciones locales de Claude Code
guardadas para este proyecto (`~/.claude/projects/…KDE-STICKERS/`) — no
de una estimación.

- **Proyecto:** KDE Stickers
- **Periodo real:** 17 ago – 7 sep 2026 (no hay ningún commit en julio)
- **Sesiones analizadas:** 3
- **Facturación real del usuario:** Claude Pro, $20/mes (tarifa plana)

## Costo y tokens por modelo

| Modelo | Mensajes | Input | Output | Caché lectura | Caché escritura | Costo |
|---|---:|---:|---:|---:|---:|---:|
| Claude Sonnet 5 | 1,370 | 4,618 | 1,358,033 | 543,991,181 | 10,704,818 | $165.21 |
| Claude Haiku 4.5 | 9 | 80 | 6,228 | 324,658 | 32,418 | $0.13 |
| **Total** | **1,379** | **4,698** | **1,364,261** | **544,315,839** | **10,737,236** | **$165.34** |

## Costo por sesión

| Sesión | Tokens totales | Costo |
|---|---:|---:|
| Desarrollo principal (17–20 ago 2026, `f5e6aa6a…`) | 503,671,486 | $149.84 |
| Sesión de mañana (7 sep 2026, `ff3871df…`) | 1,599,834 | $1.44 |
| Esta conversación (7 sep 2026, `bb0f67b2…`, en curso al momento de este informe) | 51,150,714 | $14.05 |

## Esto no es lo que se pagó

El costo de arriba es una reconstrucción a tarifa de API pública, útil
como referencia de volumen — pero la facturación real es **Claude Pro**
(tarifa plana de $20/mes), así que el gasto real fueron los meses de
suscripción cubiertos, sin importar este total.

## Metodología

- Datos extraídos de las 3 transcripciones locales de Claude Code aún
  presentes en `~/.claude/projects/…KDE-STICKERS/`; sesiones ya rotadas
  o eliminadas no están incluidas, así que este es un piso, no
  necesariamente el 100% del consumo histórico.
- Precios usados: Sonnet 5 `$2 / $10` por millón de tokens
  input/output; Haiku 4.5 `$1 / $5`; lectura de caché al `0.1×` el
  precio de input; escritura de caché (TTL 1h) al `2×` el precio de
  input — tarifas vigentes consultadas en agosto de 2026.
- El historial de commits del proyecto corre del 17 de agosto al 7 de
  septiembre de 2026 — no de julio a agosto como se asumía inicialmente.
- La sesión "Esta conversación" seguía activa al momento de generar
  este informe: su costo y conteo de tokens crecieron después.

Versión HTML autocontenida (para compartir, abrir directo en el navegador):
[TOKEN_REPORT.html](TOKEN_REPORT.html)

Versión interactiva: [Stickers Token Ledger](https://claude.ai/code/artifact/de7ea325-2c2c-4772-a104-ad4999c8f29d)
