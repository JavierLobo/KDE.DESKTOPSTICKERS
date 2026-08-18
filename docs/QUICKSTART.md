# KDE Stickers - Quick Start

## Instalación

```bash
cd ~/Repositorios/KDE.STICKERS
chmod +x scripts/install.sh
./scripts/install.sh
```

Esto compila el binario Qt6 (`build/kde-stickers`), lo instala en
`~/.local/bin/kde-stickers`, y registra el autostart en
`~/.config/autostart/org.kde.stickers.desktop`.

## Primer arranque

La app se lanzará automáticamente en tu próxima sesión de Plasma. Para
probarla ahora mismo sin reiniciar sesión:

```bash
~/.local/bin/kde-stickers &
```

Deberías ver un icono en la bandeja del sistema ("KDE Stickers") y,
si ya tienes stickers guardados en `~/.stickers/stickers.json`,
sus ventanas aparecerán (en la posición que decida KWin — la posición exacta no se restaura entre sesiones, ver limitación conocida en la sección "Movimiento" de `docs/QA_CHECKLIST.md`).

## Crear tu primer sticker

- Click en el icono de la bandeja → "Nuevo sticker", o
- Click en el botón "+" de cualquier sticker existente

## Editar

Click dentro del sticker para editar en Markdown. Click fuera para
volver a la vista previa renderizada.

## Datos de prueba

```bash
chmod +x scripts/test-sticker.sh
./scripts/test-sticker.sh
```

Crea 3 stickers de ejemplo en `~/.stickers/stickers.json`.

## Verificación completa

Ver `docs/QA_CHECKLIST.md` para el checklist manual de todas las
funcionalidades.

## Troubleshooting

**El binario no compila:**
- Verifica que tienes Qt6 (`Core`, `Gui`, `Qml`, `Quick`, `Widgets`) instalado
- Revisa el output de `cmake -B build -S .` para el paquete faltante

**Los stickers no aparecen en todos los escritorios:**
- El mecanismo es una regla de KWin, no código de la app — verifica que existe:
  `kreadconfig6 --file kwinrulesrc --group General --key rules` debe incluir `kdestickers-alldesktops`
- Si falta, vuelve a correr `./scripts/install.sh` (la escribe de forma idempotente)
- Si existe pero no aplica, fuerza la recarga: `qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure`
- Detalle completo del mecanismo en
  `docs/superpowers/specs/2026-08-17-multidesktop-markdown-stickers-design.md`, sección "Multi-desktop: mecánica exacta"

**Logs:**
```bash
journalctl -u plasmashell -f
```
(o ejecuta `~/.local/bin/kde-stickers` directamente desde una
terminal para ver su salida de consola en vivo)
