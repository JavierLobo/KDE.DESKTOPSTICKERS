# KDE Stickers - Sticky Notes para Plasma Desktop

Sticky notes flotantes y arrastrables en el escritorio de KDE Plasma.

## Estructura del Proyecto

```
kde-stickers/
├── metadata.json              # Metadatos del plugin Plasma
├── src/
│   ├── ui/
│   │   └── main.qml          # Interfaz QML del sticker
│   └── code/
│       └── storage.js        # Módulo persistencia JSON
├── scripts/
│   ├── install.sh            # Instalación automática
│   └── test-sticker.sh       # Script de prueba
├── docs/
│   ├── QUICKSTART.md         # Guía instalación
│   ├── INSTALL_CHECKLIST.md  # Checklist
│   └── API.md                # Documentación (próx)
└── README.md                 # Documentación principal
```

## Versiones

- **V1** (Actual): UI básica + colores + almacenamiento JSON
- **V2** (Próx): Multi-desktop + Markdown renderer
- **V3** (Futuro): Plugin C++ + sincronización avanzada

## Instalación Rápida

```bash
cd ~/Proyectos/kde-stickers
chmod +x scripts/install.sh
./scripts/install.sh
```

## Stack Técnico

- **QML/Qt** para UI
- **JavaScript** para lógica
- **JSON** para persistencia
- **Bash** para scripts

## Estado de Features

| Feature | V1 | V2 | V3 |
|---------|----|----|-----|
| UI básica | ✅ | ✅ | ✅ |
| Editar texto | ✅ | ✅ | ✅ |
| Arrastrar | 🔶 | ✅ | ✅ |
| Colores | ✅ | ✅ | ✅ |
| Borrar | ✅ | ✅ | ✅ |
| Auto-guardado | 🔶 | ✅ | ✅ |
| Multi-desktop | ❌ | ✅ | ✅ |
| Markdown | ❌ | ✅ | ✅ |
| Preview mode | ❌ | ✅ | ✅ |
| Plugin C++ | ❌ | ❌ | ✅ |

## Git Workflow

```bash
# Clonar/actualizar
cd ~/Proyectos/kde-stickers
git pull origin main

# Crear rama para feature
git checkout -b feature/nueva-feature

# Commit
git add .
git commit -m "feat: descripción breve"

# Push
git push origin feature/nueva-feature
```

## Paths importantes

- **Instalación destino:** `~/.local/share/plasma/plasmoids/org.kde.stickers/`
- **Datos:** `~/.stickers/stickers.json`
- **Logs:** `journalctl -u plasmashell -f`

## Próximos pasos

1. [x] Crear repo
2. [ ] Instalar y probar V1
3. [ ] Conectar almacenamiento
4. [ ] Cargar stickers iniciales
5. [ ] Multi-desktop (V2)
6. [ ] Markdown (V2)
