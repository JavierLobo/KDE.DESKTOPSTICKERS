<p align="center">
  <img src="../img/logo-sticker.png" alt="Desktop Stickers logo" width="120">
</p>

<h1 align="center">Desktop Stickers</h1>

<p align="center">
  <a href="../LICENSE"><img alt="License: GPL-3.0" src="https://img.shields.io/badge/License-GPL--3.0-blue.svg"></a>
  <a href="README-SP.md"><img alt="ES" src="https://img.shields.io/badge/lang-ES-red.svg"></a>
  <a href="README-IT.md"><img alt="IT" src="https://img.shields.io/badge/lang-IT-green.svg"></a>
  <a href="README-EN.md"><img alt="EN" src="https://img.shields.io/badge/lang-EN-blue.svg"></a>
  <a href="README-DE.md"><img alt="DE" src="https://img.shields.io/badge/lang-DE-orange.svg"></a>
  <a href="README-RU.md"><img alt="RU" src="https://img.shields.io/badge/lang-RU-blueviolet.svg"></a>
  <a href="README-CN.md"><img alt="CN" src="https://img.shields.io/badge/lang-CN-yellow.svg"></a>
  <a href="README-JP.md"><img alt="JP" src="https://img.shields.io/badge/lang-JP-lightgrey.svg"></a>
</p>

Sticky notes flotantes para el escritorio de KDE Plasma. Aplicación
standalone Qt6/QML (no un plasmoid) que se instala como programa normal con
autostart — cada sticker es una ventana independiente, sin decoración, con
posición y tamaño persistentes, y visibilidad en todos los escritorios
virtuales como opción por-sticker (pin).

<p align="center">
  <img src="../img/screenshot-desktop.png" alt="Stickers flotantes sobre el escritorio de KDE Plasma" width="720">
</p>

## Requisitos

- Plasma 6.x (verificado con 6.7.4) y KWin, sesión Wayland
- Qt 6.5+ (`Core`, `Gui`, `Qml`, `Quick`, `Widgets`, `DBus`)
- CMake, Bash

## Instalación

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

Compila el binario, lo instala en `~/.local/bin/desktop-stickers` y registra el
autostart. Ver [QUICKSTART-SP.md](QUICKSTART-SP.md) para la guía completa
(primer arranque, datos de prueba, troubleshooting) y `QA_CHECKLIST.md`
para el checklist manual de verificación.

## Features

- Crear stickers desde el icono de la bandeja o el botón "+" de un sticker
  existente (aparece en cascada, desplazado respecto al de origen), con id
  incremental
- Arrastrar por el escritorio (movimiento real vía `Window.startSystemMove()`),
  con la posición real (reportada por KWin, no por Qt) persistida tras cada
  arrastre y restaurada al reiniciar la app, vía una regla de ventana de
  KWin por sticker (`desktopstickers-sticker-<id>`)
- Redimensionar desde la esquina inferior derecha, con el tamaño persistido
  y restaurado igual que la posición
- Pin por sticker (botón 📍/📌): opt-in individual para que ese sticker sea
  visible en todos los escritorios virtuales a la vez, vía la misma regla
  de ventana de KWin del sticker; sin pin, el sticker solo existe en el
  escritorio donde se creó o se movió. Por defecto, todo sticker nuevo
  empieza sin pin
- Edición de texto en **Markdown completo** (encabezados, tablas, código,
  citas, listas, negrita/cursiva, enlaces, checkboxes), con alternancia
  automática: click para editar, perder el foco para volver a la vista
  previa renderizada
- En la vista previa, los enlaces son clicables (se abren con el manejador
  de URLs del sistema) y los bloques de código se muestran en una caja con
  fondo diferenciado
- Contenido con scroll: una nota larga no desborda el sticker, y el área de
  edición se desplaza automáticamente para mantener visible el cursor
  mientras se escribe
- Color de fondo: paleta fija de 6 tonos pastel (asignado al azar en cada
  sticker nuevo) o selector de color libre
- Nombre por sticker, editable desde el Panel de Stickers: si no se
  establece, se deriva automáticamente de la primera línea con contenido
  del texto (sin los `#` de encabezado). Se trunca a 30 caracteres tanto en
  la cabecera del sticker (`#<id> | <nombre o respaldo>`) como en el menú
  de bandeja y el Panel
- El icono de la bandeja del sistema lista las 10 notas modificadas más
  recientemente (sin paginación) — cada fila abre o reenfoca esa nota. El
  "Panel de Stickers" en el mismo menú abre una ventana con el listado
  completo, sin límite: abrir, renombrar y eliminar (con confirmación) cada
  nota
- El botón "✕" del sticker solo cierra su ventana — la nota sigue existiendo
  y se puede reabrir desde el menú de la bandeja. Eliminar una nota es una
  acción aparte, solo alcanzable desde el Panel de Stickers, y siempre pide
  confirmación; al eliminarla se borra también su regla de ventana de KWin
- Persistencia en `~/.stickers/stickers.json`
- Instancia única: si la app ya está corriendo, un segundo lanzamiento no
  abre una copia duplicada
- Recuperación automática si KWin se reinicia en mitad de la sesión (un
  crash, o `kwin_wayland --replace`): la persistencia de posición se
  re-engancha sola, sin reiniciar la app
- El instalador limpia reglas de KWin huérfanas de stickers ya eliminados
  en sesiones anteriores
- Autostart vía `.desktop` freedesktop estándar (no "Background Services"
  de Plasma)

<p align="center">
  <img src="../img/Desktop-stickers-markdown.png" alt="Ejemplo de sticker con Markdown renderizado: títulos, tablas y bloques de código" width="720">
</p>

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
## Descargas

Todas las versiones publicadas están en la página de
[Releases](https://github.com/JavierLobo/KDE.DESKTOPSTICKERS/releases)
del repositorio, cada una con su código fuente y notas de la versión.

## Licencia

GPL-3.0
