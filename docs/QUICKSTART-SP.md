# KDE Stickers - Guía rápida

<p align="center">
  <a href="QUICKSTART-SP.md"><img alt="ES" src="https://img.shields.io/badge/lang-ES-red.svg"></a>
  <a href="QUICKSTART-IT.md"><img alt="IT" src="https://img.shields.io/badge/lang-IT-green.svg"></a>
  <a href="QUICKSTART-EN.md"><img alt="EN" src="https://img.shields.io/badge/lang-EN-blue.svg"></a>
  <a href="QUICKSTART-DE.md"><img alt="DE" src="https://img.shields.io/badge/lang-DE-orange.svg"></a>
  <a href="QUICKSTART-RU.md"><img alt="RU" src="https://img.shields.io/badge/lang-RU-blueviolet.svg"></a>
  <a href="QUICKSTART-CN.md"><img alt="CN" src="https://img.shields.io/badge/lang-CN-yellow.svg"></a>
  <a href="QUICKSTART-JP.md"><img alt="JP" src="https://img.shields.io/badge/lang-JP-lightgrey.svg"></a>
</p>

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
una regla de KWin por sticker — ver `QA_CHECKLIST.md`).

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

Ver `QA_CHECKLIST.md` para el checklist manual de todas las
funcionalidades.

## Troubleshooting

**El binario no compila:**
- Verifica que tienes Qt6 (`Core`, `Gui`, `Qml`, `Quick`, `Widgets`, `DBus`) instalado
- Revisa el output de `cmake -B build -S .` para el paquete faltante

**Un sticker no aparece en todos los escritorios:**
- "Todos los escritorios" es un opt-in **por sticker** vía el botón de pin
  (📍/📌) del header, no una regla global de la app — primero verifica que
  el sticker en cuestión tiene el pin activo (📌).
- Si el pin está activo pero el sticker sigue sin seguirte entre
  escritorios, verifica la regla de KWin de ese sticker específico:
  `kreadconfig6 --file kwinrulesrc --group kdestickers-sticker-<id> --key desktopsrule`
  debe devolver `2` (Force). Si devuelve `1` o está vacío, el pin no llegó a
  escribirse — reintenta el click en 📌.
- Verifica también que el grupo está listado:
  `kreadconfig6 --file kwinrulesrc --group General --key rules` debe incluir
  `kdestickers-sticker-<id>`.
- Si los valores son correctos pero no aplica en vivo, fuerza la recarga:
  `qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure`
- Detalle completo del mecanismo (una regla de KWin por sticker, compartida
  entre pin y posición) en
  `superpowers/specs/2026-08-18-sticker-pin-position-resize-design.md`,
  sección "Arquitectura: de regla global a reglas por-ventana"

**Logs:**
```bash
journalctl --user -f
```
(la app es un proceso standalone, no parte de plasmashell, así que sus
mensajes salen en el log de sesión de usuario; ejecutar
`~/.local/bin/kde-stickers` directamente desde una terminal para ver su
salida de consola en vivo sigue siendo la opción más fiable)
