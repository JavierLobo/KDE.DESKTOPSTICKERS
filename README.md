# KDE Stickers

Sticky notes flotantes para el escritorio de KDE Plasma. Aplicación
standalone Qt6/QML (no un plasmoid) que se instala como programa normal con
autostart — cada sticker es una ventana independiente, sin decoración, con
posición y tamaño persistentes, y visibilidad en todos los escritorios
virtuales como opción por-sticker (pin).

## Requisitos

- Plasma 6.x (verificado con 6.7.4) y KWin, sesión Wayland
- Qt 6.5+ (`Core`, `Gui`, `Qml`, `Quick`, `Widgets`, `DBus`)
- CMake, Bash

## Instalación

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

Compila el binario, lo instala en `~/.local/bin/kde-stickers` y registra el
autostart. Ver `docs/QUICKSTART.md` para la guía completa (primer arranque,
datos de prueba, troubleshooting) y `docs/QA_CHECKLIST.md` para el
checklist manual de verificación.

## Features

- Crear stickers individuales desde el icono de la bandeja o el botón "+"
  de cualquier sticker existente, con id incremental
- Arrastrar por el escritorio (movimiento real vía `Window.startSystemMove()`),
  con la posición real (reportada por KWin, no por Qt) persistida tras cada
  arrastre y restaurada al reiniciar la app, vía una regla de ventana de
  KWin por sticker (`kdestickers-sticker-<id>`)
- Redimensionar desde la esquina inferior derecha, con el tamaño persistido
  y restaurado igual que la posición
- Pin por sticker (botón 📍/📌): opt-in individual para que ese sticker sea
  visible en todos los escritorios virtuales a la vez, vía la misma regla
  de ventana de KWin del sticker; sin pin, el sticker solo existe en el
  escritorio donde se creó o se movió. Por defecto, todo sticker nuevo
  empieza sin pin
- Edición de texto en **Markdown completo** (tablas, código, citas, listas,
  negrita/cursiva, enlaces, checkboxes), con alternancia automática:
  click para editar, perder el foco para volver a la vista previa
  renderizada
- Color de fondo: paleta fija de 6 tonos pastel (asignado al azar en cada
  sticker nuevo) o selector de color libre
- Nombre por sticker, editable desde el Panel de Stickers: si no se
  establece, se deriva automáticamente de la primera línea con contenido del
  texto. La cabecera del sticker muestra `#<id> | <nombre o respaldo>`
- El icono de la bandeja del sistema lista todas las notas creadas (paginado
  de 10 en 10) — cada fila abre o reenfoca esa nota. Un nuevo "Panel de
  Stickers" en el mismo menú abre una ventana con el listado completo: abrir,
  renombrar y eliminar (con confirmación) cada nota
- El botón "✕" del sticker solo cierra su ventana — la nota sigue existiendo
  y se puede reabrir desde el menú de la bandeja. Eliminar una nota es una
  acción aparte, solo alcanzable desde el Panel de Stickers, y siempre pide
  confirmación
- Persistencia en `~/.stickers/stickers.json`
- Autostart vía `.desktop` freedesktop estándar (no "Background Services"
  de Plasma)

Detalle completo del mecanismo de reglas de KWin (una por sticker,
compartida entre pin y posición) en
`docs/superpowers/specs/2026-08-18-sticker-pin-position-resize-design.md`.

## Almacenamiento

Los stickers se guardan en `~/.stickers/stickers.json`:

```json
{
  "stickers": [
    {
      "id": "001",
      "name": "",
      "text": "Contenido en Markdown",
      "color": "#FFD700",
      "x": 100,
      "y": 200,
      "width": 300,
      "height": 250,
      "pinned": false,
      "created": "2026-08-17T10:30:00Z",
      "modified": "2026-08-17T15:45:00Z"
    }
  ]
}
```

## Problemas conocidos

- **El menú de la bandeja a veces se abre solo, sin que el usuario haga
  click.** Causa: cualquier llamada a `refreshNoteList()` (crear, editar,
  renombrar o eliminar una nota) reconstruye por completo la lista de
  entradas del menú (`Instantiator` sin identidad estable por elemento),
  y esa reconstrucción parece hacer que el widget de bandeja de Plasma
  muestre el menú espontáneamente. Confirmado con reproducciones reales
  y controles negativos — no es un clic accidental. No es nuevo de esta
  rama, y esta rama en concreto reduce el número de entradas reconstruidas
  por evento (de 2 por nota a 1). Arreglo recomendado, no implementado
  todavía: (1) primero, un chequeo de "¿cambió de verdad la lista?" en
  `refreshNoteList()` que evite reasignar `noteList` cuando el contenido
  no ha cambiado — elimina el disparador más frecuente (guardar una
  edición de texto) con muy poco riesgo; (2) si no basta, sustituir el
  modelo de array plano del `Instantiator` del menú por un `ListModel`
  real con `append()`/`remove()` incrementales, re-verificando que la
  paginación siga funcionando.

## Licencia

GPL-2.0+
