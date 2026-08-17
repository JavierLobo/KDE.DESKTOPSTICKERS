# ✅ CHECKLIST INSTALACIÓN KDE STICKERS V1

## 📋 Paso 1: Descarga y Estructura

```bash
# Descargar archivos (ya están abajo)
cd ~/Descargas  # o donde descargues

# Crear estructura
mkdir -p ~/.local/share/plasma/plasmoids/org.kde.stickers/contents/{ui,code}
mkdir -p ~/.stickers
```

## 📋 Paso 2: Copiar Archivos

```bash
# Desde el directorio donde está tu descarga:

cp metadata.json ~/.local/share/plasma/plasmoids/org.kde.stickers/
cp main.qml.v2 ~/.local/share/plasma/plasmoids/org.kde.stickers/contents/ui/main.qml
cp storage.js ~/.local/share/plasma/plasmoids/org.kde.stickers/contents/code/
```

⚠️ **IMPORTANTE:** Renombra `main.qml.v2` a `main.qml`

## 📋 Paso 3: Verificar

```bash
# Debe mostrar todo esto:
ls -la ~/.local/share/plasma/plasmoids/org.kde.stickers/
# Output esperado:
# metadata.json
# contents/

tree ~/.local/share/plasma/plasmoids/org.kde.stickers/
# contents/
# ├── code/
# │   └── storage.js
# └── ui/
#     └── main.qml
```

## 📋 Paso 4: Recargar Plasma

```bash
# Opción A - Reinicio limpio (RECOMENDADO)
kquitapp6 plasmashell
sleep 1
kstart6 plasmashell &

# Opción B - Debug en foreground
kquitapp6 plasmashell
plasmashell
```

## 📋 Paso 5: Verificar que funciona

En **System Settings → Startup and Shutdown → Background Services**
- Busca "KDE Stickers" 
- Debe estar disponible

O crea datos de prueba:
```bash
chmod +x test-sticker.sh
./test-sticker.sh

# Verifica que se creó:
cat ~/.stickers/stickers.json
```

## ❌ Si no funciona

```bash
# Ver logs
journalctl -u plasmashell -f

# Ejecutar en debug
QML_IMPORT_TRACE=1 plasmashell 2>&1 | grep -i sticker

# Verificar estructura
find ~/.local/share/plasma/plasmoids/org.kde.stickers/
# Debe listar metadata.json, contents/ui/main.qml, contents/code/storage.js
```

## 🚀 SIGUIENTE: Conectar almacenamiento

Una vez que la UI cargue, los próximos pasos son:

1. **Conectar `storage.js` con QML**
   - Hacer que guardar texto/color/posición funcione
   - Leer datos de `~/.stickers/stickers.json`

2. **Cargar stickers existentes**
   - Al iniciar, mostrar stickers de `stickers.json`
   - Crear una ventana por cada uno

3. **Crear botón [+]**
   - Agregar stickers nuevos desde UI
   - Generar IDs automáticamente

---

## 📦 ARCHIVOS QUE NECESITAS

| Archivo | Destino | Notas |
|---------|---------|-------|
| `metadata.json` | `~/.local/share/plasma/plasmoids/org.kde.stickers/` | Metadatos plugin |
| `main.qml.v2` | `~/.local/share/plasma/plasmoids/org.kde.stickers/contents/ui/main.qml` | **RENOMBRA a main.qml** |
| `storage.js` | `~/.local/share/plasma/plasmoids/org.kde.stickers/contents/code/` | Sin cambios |

---

## 💡 COMANDOS ÚTILES

```bash
# Recargar rápido
kquitapp6 plasmashell && kstart6 plasmashell &

# Ver si hay stickers guardados
jq . ~/.stickers/stickers.json

# Limpiar todo (volver a empezar)
rm -rf ~/.local/share/plasma/plasmoids/org.kde.stickers/
mkdir -p ~/.local/share/plasma/plasmoids/org.kde.stickers/contents/{ui,code}

# Debug con más detalle
QML_IMPORT_TRACE=1 QT_QPA_PLATFORM=xcb plasmashell
```

---

**¿Todo instalado?** Avísame si necesitas conectar el almacenamiento.
