# ✅ Repositorio kde-stickers Inicializado

## 📍 Ubicación

```
~/Proyectos/kde-stickers/
```

## 🗂️ Estructura

```
kde-stickers/
├── .git/                          # Repositorio git
├── .gitignore                     # Ignorar archivos
│
├── metadata.json                  # Metadatos plugin Plasma
├── PROJECT.md                     # Info del proyecto
├── README.md                      # Documentación principal
│
├── src/                           # Código fuente
│   ├── ui/
│   │   └── main.qml              # UI del sticker
│   └── code/
│       └── storage.js            # Persistencia JSON
│
├── scripts/                       # Scripts de utilidad
│   ├── install.sh                # Instalar plugin
│   └── test-sticker.sh           # Crear datos prueba
│
└── docs/                          # Documentación
    ├── QUICKSTART.md             # Guía instalación
    └── INSTALL_CHECKLIST.md      # Checklist visual
```

## 🔗 Git Configurado

```bash
User: Javi SearchDate <javi@searchdate.local>
Repo: ~/Proyectos/kde-stickers
Branch: master
Commit: b6dce5e (feat: init kde-stickers v1)
```

## 🚀 Próximos Pasos

### 1️⃣ Instalar el Plugin

```bash
cd ~/Proyectos/kde-stickers
chmod +x scripts/install.sh
./scripts/install.sh
```

### 2️⃣ Recargar Plasma

```bash
kquitapp6 plasmashell
kstart6 plasmashell &
```

### 3️⃣ Probar

```bash
# Crear datos de prueba
chmod +x scripts/test-sticker.sh
./scripts/test-sticker.sh

# Ver datos
cat ~/.stickers/stickers.json
```

## 📊 Status Actual

| Componente | Status | Path |
|-----------|--------|------|
| Plugin metadata | ✅ | `metadata.json` |
| QML UI | ✅ | `src/ui/main.qml` |
| Storage JS | ✅ | `src/code/storage.js` |
| Scripts | ✅ | `scripts/` |
| Docs | ✅ | `docs/` |
| Instalación | 🔶 | Pendiente prueba |
| Funcionalidad | 🔶 | V1 básica |

## 📝 Comandos Útiles

```bash
# Ver estado git
cd ~/Proyectos/kde-stickers
git status

# Ver histórico
git log --oneline

# Ver cambios
git diff

# Crear rama para desarrollo
git checkout -b feature/nombre

# Committed cambios
git add .
git commit -m "tipo: descripción"
```

## 🔍 Verificar Instalación

```bash
# Estructura plugin
ls -la ~/.local/share/plasma/plasmoids/org.kde.stickers/

# Datos
cat ~/.stickers/stickers.json | jq .

# Logs
journalctl -u plasmashell -f
```

## 📞 Documentación

- **Instalación:** Leer `docs/QUICKSTART.md`
- **Instalación paso-a-paso:** Leer `docs/INSTALL_CHECKLIST.md`
- **Proyecto:** Leer `PROJECT.md`
- **General:** Leer `README.md`

---

**¿Siguiente?** Instala y prueba el plugin 👇
