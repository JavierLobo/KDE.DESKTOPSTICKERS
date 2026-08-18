# KDE Stickers - Quick Start

## Instalación

```bash
cd <ruta-del-repo>  # navega al directorio donde clonaste el repositorio
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
sus ventanas aparecerán en su última posición real (persistida vía
una regla de KWin por sticker — ver `docs/QA_CHECKLIST.md`).

## Crear tu primer sticker

- Click en el icono de la bandeja → "Nuevo sticker", o
- Click en el botón "+" de cualquier sticker existente

## Editar

Click dentro del sticker para editar en Markdown. Click fuera para
volver a la vista previa renderizada.

## Pin (todos los escritorios) y resize

- Botón 📍/📌 en el header: alterna si el sticker es visible en todos
  los escritorios virtuales (📌) o solo en el suyo (📍). Por defecto,
  todo sticker nuevo empieza sin pin.
- Arrastra desde la esquina inferior derecha para redimensionar.

## Datos de prueba

⚠️ Este script **sobrescribe** `~/.stickers/stickers.json` — si ya tienes
stickers creados, se perderán. Úsalo solo en una instalación nueva o si no
te importa perder los datos actuales.

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
journalctl --user -f
```
(la app es un proceso standalone, no parte de plasmashell, así que sus
mensajes salen en el log de sesión de usuario; ejecutar
`~/.local/bin/kde-stickers` directamente desde una terminal para ver su
salida de consola en vivo sigue siendo la opción más fiable)
