# KDE Stickers v1

Sticky notes flotantes en el escritorio de Plasma.

## Requisitos

- Plasma 6.x (verificado con 6.7.4)
- Qt 5.15+ ó Qt 6.x
- Bash

## Instalación

```bash
chmod +x install.sh
./install.sh
```

Luego reinicia Plasma:

```bash
kquitapp6 plasmashell
sleep 1
kstart6 plasmashell &
```

O abre una terminal nueva y ejecuta:

```bash
plasmashell
```

## Estructura

```
~/.local/share/plasma/plasmoids/org.kde.stickers/
├── metadata.json          # Metadatos del plugin
└── contents/
    ├── ui/
    │   └── main.qml       # UI del sticker
    └── code/
        └── storage.js     # Persistencia JSON
```

## Almacenamiento

Los stickers se guardan en: `~/.stickers/stickers.json`

Formato:
```json
{
  "stickers": [
    {
      "id": "001",
      "text": "Contenido del sticker",
      "color": "#FFD700",
      "x": 100,
      "y": 200,
      "created": "2026-08-17T10:30:00Z",
      "modified": "2026-08-17T15:45:00Z"
    }
  ]
}
```

## Features v1

✅ Crear stickers individuales
✅ Editar texto en tiempo real
✅ Arrastrar por pantalla
✅ Cambiar color (7 colores disponibles)
✅ Eliminar stickers
✅ Auto-guardado cada 500ms
✅ Persistencia en JSON

## Próximas versiones

v2:
- Soporte para múltiples escritorios
- Renderizador Markdown
- Preview mode vs Edit mode

v3:
- Plugin C++ para sincronización
- Copiar/pegar entre stickers
- Resize dinámico

## Debug

Ver logs:
```bash
journalctl -u plasmashell -f
```

Ver estructura de archivos:
```bash
tree ~/.local/share/plasma/plasmoids/org.kde.stickers/
cat ~/.stickers/stickers.json
```

## Problemas comunes

**El plugin no aparece:**
- Asegúrate que `~/.local/share/plasma/plasmoids/org.kde.stickers/metadata.json` existe
- Recarga Plasma: `kquitapp6 plasmashell && kstart6 plasmashell &`

**Los stickers no se guardan:**
- Verifica que `~/.stickers/` existe y es escribible
- Revisa los logs: `journalctl -u plasmashell -f`

## Licencia

GPL-2.0+
