# KDE Stickers - Sticky Notes para Plasma Desktop

Sticky notes flotantes y arrastrables en el escritorio de KDE Plasma, con
posición y tamaño persistentes y visibilidad en todos los escritorios
virtuales como opción por-sticker (pin), con edición en Markdown.
Aplicación standalone Qt6/QML + C++ mínimo (no un plasmoid `Plasma/Applet`).

## Estructura del Proyecto

```
kde-stickers/
├── CMakeLists.txt                 # Build Qt6 (compila el binario + módulo QML)
├── src/
│   ├── main.cpp                   # Bootstrap QApplication + QQmlApplicationEngine
│   ├── filestorage.h/.cpp         # Singleton QML: primitivas de archivo para storage.js
│   ├── kwinbridge.h/.cpp          # Singleton QML: reglas de ventana KWin (pin, posición) vía D-Bus/KWin scripting
│   ├── qml/
│   │   ├── Main.qml               # Entry point: StickerManager, SystemTrayIcon
│   │   ├── StickerWindow.qml      # Ventana individual de cada sticker
│   │   ├── MarkdownView.qml       # Preview de Markdown (Text.MarkdownText)
│   │   ├── ColorPalette.qml       # Paleta de colores + selector libre
│   │   └── StickerManager.js      # Singleton JS: load/create/update/delete stickers
│   └── code/
│       └── storage.js             # Persistencia JSON (delega I/O en FileStorage)
├── data/
│   └── org.kde.stickers.desktop   # Entrada de autostart freedesktop
├── scripts/
│   ├── install.sh                 # Compila, instala binario, autostart; migra/limpia reglas KWin
│   └── test-sticker.sh            # Crea stickers de ejemplo (sobrescribe datos reales)
└── docs/
    ├── QUICKSTART.md              # Guía de instalación y primer uso
    ├── QA_CHECKLIST.md            # Checklist manual de QA
    └── superpowers/                # Spec y plan de diseño de esta rebuild
```

## Stack Técnico

- **Qt6** (Core, Gui, Qml, Quick, Widgets, DBus) + CMake
- **QML/JavaScript** para toda la UI y lógica de negocio
- **C++ mínimo** (`FileStorage`, `KWinBridge`): I/O de archivos y puente
  D-Bus/KWin-scripting para reglas de ventana (pin, posición), sin más
  lógica de negocio
- **JSON** para persistencia (`~/.stickers/stickers.json`)
- **Bash** para instalación (`scripts/install.sh`, migra/limpia reglas KWin)

## Instalación Rápida

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

Ver `docs/QUICKSTART.md` para el detalle completo.

## Estado de Features

| Feature | Estado |
|---|---|
| Crear sticker (tray icon / botón "+") | ✅ |
| Arrastrar (`Window.startSystemMove()`) | ✅ |
| Pin por sticker, todos los escritorios (regla de ventana de KWin, opt-in) | ✅ |
| Persistencia real de posición entre reinicios (regla de ventana de KWin) | ✅ |
| Resize desde esquina inferior derecha, con persistencia de tamaño | ✅ |
| Edición Markdown (click-to-edit / blur-to-preview) | ✅ |
| Colores (paleta fija + selector libre) | ✅ |
| Eliminar sticker | ✅ |
| Persistencia JSON (texto, color, posición, tamaño, pin) | ✅ |
| Autostart (freedesktop `.desktop`) | ✅ |
| Atajo de teclado global para crear stickers | ❌ (diferido a V2) |
| Sincronización/backend avanzado | ❌ (diferido a V3) |

## Paths importantes

- **Binario instalado:** `~/.local/bin/kde-stickers`
- **Autostart:** `~/.config/autostart/org.kde.stickers.desktop`
- **Datos:** `~/.stickers/stickers.json`
- **Reglas de KWin:** `~/.config/kwinrulesrc` (un grupo `kdestickers-sticker-<id>`
  por sticker, compartido entre pin y posición)
- **Logs:** `journalctl --user -f`, o ejecutar el binario directo en terminal

## Documentación

- **Instalación y uso:** `docs/QUICKSTART.md`
- **Checklist de QA:** `docs/QA_CHECKLIST.md`
- **Diseño (spec + plan de esta rebuild):** `docs/superpowers/`
