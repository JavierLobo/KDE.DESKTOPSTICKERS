# KDE Stickers

Sticky notes flotantes para el escritorio de KDE Plasma. Aplicación
standalone Qt6/QML (no un plasmoid) que se instala como programa normal con
autostart — cada sticker es una ventana independiente, sin decoración,
visible en **todos** los escritorios virtuales a la vez.

## Requisitos

- Plasma 6.x (verificado con 6.7.4) y KWin, sesión Wayland
- Qt 6.5+ (`Core`, `Gui`, `Qml`, `Quick`, `Widgets`)
- CMake, Bash

## Instalación

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

Compila el binario, lo instala en `~/.local/bin/kde-stickers`, registra el
autostart y da de alta la regla de KWin que mantiene los stickers visibles
en todos los escritorios. Ver `docs/QUICKSTART.md` para la guía completa
(primer arranque, datos de prueba, troubleshooting) y `docs/QA_CHECKLIST.md`
para el checklist manual de verificación.

## Features

- Crear stickers individuales desde el icono de la bandeja o el botón "+"
  de cualquier sticker existente, con id incremental
- Arrastrar por el escritorio (movimiento real vía `Window.startSystemMove()`)
- Visibles simultáneamente en todos los escritorios virtuales, vía una
  regla de ventana de KWin (no requiere código por sticker)
- Edición de texto en **Markdown completo** (tablas, código, citas, listas,
  negrita/cursiva, enlaces, checkboxes), con alternancia automática:
  click para editar, perder el foco para volver a la vista previa
  renderizada
- Color de fondo: paleta fija de 6 tonos pastel o selector de color libre
- Eliminar stickers (sin diálogo de confirmación)
- Persistencia en `~/.stickers/stickers.json`
- Autostart vía `.desktop` freedesktop estándar (no "Background Services"
  de Plasma)

**Limitación conocida y aceptada:** por una limitación del protocolo
Wayland, la app no puede leer la posición real de un sticker tras moverlo,
así que la posición no se restaura con precisión entre reinicios — al
volver a lanzar la app, cada sticker abre donde decida la política de
colocación de KWin, no en su última posición arrastrada. El arrastre en sí
sí mueve la ventana de verdad. Detalle completo en
`docs/superpowers/specs/2026-08-17-multidesktop-markdown-stickers-design.md`,
sección "Modelo de datos y persistencia".

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
      "created": "2026-08-17T10:30:00Z",
      "modified": "2026-08-17T15:45:00Z"
    }
  ]
}
```

## Licencia

GPL-2.0+
