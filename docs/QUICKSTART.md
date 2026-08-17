# KDE Stickers V1 - Quick Start

## Paso 1: Estructura

```bash
# Crear directorios
mkdir -p ~/.local/share/plasma/plasmoids/org.kde.stickers/contents/{ui,code}
mkdir -p ~/.stickers
```

## Paso 2: Copiar archivos

De los generados, copiar a:

```
~/.local/share/plasma/plasmoids/org.kde.stickers/
├── metadata.json
└── contents/
    ├── ui/
    │   └── main.qml           ← Usa main.qml.v2 (la corregida)
    └── code/
        └── storage.js
```

**OJO: Renombra `main.qml.v2` a `main.qml`**

## Paso 3: Verificar instalación

```bash
ls -la ~/.local/share/plasma/plasmoids/org.kde.stickers/
# Debe mostrar metadata.json y carpeta contents/
```

## Paso 4: Recargar Plasma

**Opción A (recomendada):**
```bash
kquitapp6 plasmashell
sleep 1
kstart6 plasmashell &
```

**Opción B (debug):**
```bash
# En terminal nueva
cd ~/.local/share/plasma/plasmoids/org.kde.stickers/
QT_QPA_PLATFORM=xcb QML_IMPORT_TRACE=1 plasmashell
```

## Paso 5: Probar

1. Abre Settings → Startup and Shutdown → Background Services
2. Busca "KDE Stickers" → activar
3. O crea stickers de prueba:
```bash
chmod +x test-sticker.sh
./test-sticker.sh
```

Verifica que aparece `~/.stickers/stickers.json` con los datos.

## Estado Actual (V1)

✅ **Funciona:**
- Interfaz QML básica
- Arrastrar sticker (en desarrollo)
- Cambiar color
- Eliminar sticker
- Auto-guardado JSON

❌ **Pendiente:**
- Conectar el arrastre real con persistencia
- Cargar stickers guardados al iniciar
- Multi-desktop
- Markdown

## Próximos pasos

1. **Conectar almacenamiento:** Integrar `storage.js` con las acciones QML
2. **Cargar stickers iniciales:** Leer `~/.stickers/stickers.json` al lanzar
3. **Persistencia real:** Guardar posiciones y texto
4. **Crear botón [+]:** Para agregar stickers nuevos desde UI

## Logs

```bash
# Ver errores del plugin
journalctl -u plasmashell -f

# Ver output de console.log() del QML
QML_IMPORT_TRACE=1 plasmashell 2>&1 | grep -i sticker
```

## Estructura de datos esperada

`~/.stickers/stickers.json`:
```json
{
  "stickers": [
    {
      "id": "001",
      "text": "Mi nota",
      "color": "#FFD700",
      "x": 100,
      "y": 100,
      "created": "2026-08-17T10:00:00Z",
      "modified": "2026-08-17T10:00:00Z"
    }
  ]
}
```

## Troubleshooting

**Error: "Plugin not found"**
- Verifica que `metadata.json` existe en la raíz del directorio del plugin
- Recarga Plasma

**No aparecen cambios**
- Asegúrate de haber renombrado `main.qml.v2` a `main.qml`
- Recarga Plasma completo

**Logs vacíos**
- Ejecuta plasmashell en foreground: `kquitapp6 plasmashell && plasmashell`

---

¿Preguntas? Revisa los archivos en el orden:
1. metadata.json
2. main.qml (después de renombrarlo)
3. storage.js
