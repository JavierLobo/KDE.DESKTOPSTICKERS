# Desktop Stickers - Guía rápida

<p align="center">
  <a href="QUICKSTART-SP.md"><img alt="ES" src="https://img.shields.io/badge/lang-ES-red.svg"></a>
  <a href="QUICKSTART-IT.md"><img alt="IT" src="https://img.shields.io/badge/lang-IT-green.svg"></a>
  <a href="QUICKSTART-EN.md"><img alt="EN" src="https://img.shields.io/badge/lang-EN-blue.svg"></a>
  <a href="QUICKSTART-DE.md"><img alt="DE" src="https://img.shields.io/badge/lang-DE-orange.svg"></a>
  <a href="QUICKSTART-FR.md"><img alt="FR" src="https://img.shields.io/badge/lang-FR-9cf.svg"></a>
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

Esto compila el binario Qt6 (`build/desktop-stickers`), lo instala en
`~/.local/bin/desktop-stickers`, y registra el autostart en
`~/.config/autostart/io.github.javierlobo.desktopstickers.desktop`.

## Primer arranque

La app se lanzará automáticamente en tu próxima sesión de Plasma. Para
probarla ahora mismo sin reiniciar sesión:

```bash
~/.local/bin/desktop-stickers &
```

Deberías ver un icono en la bandeja del sistema ("Desktop Stickers") y,
si ya tienes stickers guardados, sus ventanas aparecerán en su última
posición real (persistida vía una regla de KWin por sticker — ver
`QA_CHECKLIST.md`). Los datos viven en
`$XDG_DATA_HOME/desktop-stickers/stickers.json` (típicamente
`~/.local/share/desktop-stickers/`), no en un directorio propio en el
home.

El idioma de la interfaz sigue el que tengas guardado en Settings (por
defecto, español). Para cambiarlo: clic derecho en el icono de la
bandeja → **Opciones → Configuración → Idiomas**.

## Crear tu primer sticker

- Click en el icono de la bandeja → "Nuevo sticker", o
- Click en el botón "+" de cualquier sticker existente

## Editar

Click dentro del sticker para editar en Markdown — aparece la barra de
formato (negrita, encabezados, listas, tablas, enlaces...) sobre el área
de texto. Click fuera para volver a la vista previa renderizada.

## Pin (todos los escritorios) y resize

- Botón 📍/📌 en el header: alterna si el sticker es visible en todos
  los escritorios virtuales (📌) o solo en el suyo (📍). Por defecto,
  todo sticker nuevo empieza sin pin (configurable en Settings).
- Arrastra desde la esquina inferior derecha para redimensionar.

## Panel de Opciones/Settings

Clic derecho en el icono de la bandeja → **Opciones → Configuración**
abre el panel con cuatro secciones:

- **Apariencia**: color por defecto de los stickers nuevos (aleatorio,
  acento del sistema o fijo), lista de preferencia de fuentes y tamaño
  de letra
- **Comportamiento**: barra de formato Markdown visible por defecto,
  confirmación antes de borrar, acción del clic izquierdo de la bandeja
- **Sistema**: autostart on/off, ruta de datos (con botón "abrir
  carpeta"), exportar/importar copia de seguridad
- **Idiomas**: selector de idioma de la interfaz

El resto del submenú **Opciones** trae Ayuda (documentación en GitHub),
Aportaciones (apoyar al desarrollador), Ver licencia y Acerca de.

## Panel de Stickers

Clic izquierdo en el icono de la bandeja (o "Panel de Stickers" en el
menú) abre el listado completo: buscar por texto, ordenar por
recientes/alfabético/color, clic para abrir una nota, menú contextual
(abrir, renombrar, duplicar) y selección múltiple para borrar varias a
la vez.

## Datos de prueba

⚠️ Este script **sobrescribe** tu `stickers.json` — si ya tienes
stickers creados, se perderán. Úsalo solo en una instalación nueva o si
no te importa perder los datos actuales.

```bash
chmod +x scripts/test-sticker.sh
./scripts/test-sticker.sh
```

Crea 3 stickers de ejemplo.

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
  `kreadconfig6 --file kwinrulesrc --group desktopstickers-sticker-<id> --key desktopsrule`
  debe devolver `2` (Force). Si devuelve `1` o está vacío, el pin no llegó a
  escribirse — reintenta el click en 📌.
- Verifica también que el grupo está listado:
  `kreadconfig6 --file kwinrulesrc --group General --key rules` debe incluir
  `desktopstickers-sticker-<id>`.
- Si los valores son correctos pero no aplica en vivo, fuerza la recarga:
  `qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure`

**No aparece un idioma nuevo que agregué a `src/i18n/`:**
- Tiene que tener exactamente las mismas claves que `src/i18n/es.json`
  (incluidas `Language.name` y `Language.flag`).
- Hace falta recompilar (`cmake --build build`) — el listado de
  diccionarios se re-detecta solo al configurar/compilar, no al arrancar
  la app ya instalada.

**Logs:**
```bash
journalctl --user -f
```
(la app es un proceso standalone, no parte de plasmashell, así que sus
mensajes salen en el log de sesión de usuario; ejecutar
`~/.local/bin/desktop-stickers` directamente desde una terminal para ver su
salida de consola en vivo sigue siendo la opción más fiable)
