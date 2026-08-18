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
- Color de fondo: paleta fija de 6 tonos pastel o selector de color libre
- Eliminar stickers (sin diálogo de confirmación)
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

## Licencia

GPL-2.0+
