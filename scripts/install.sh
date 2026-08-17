#!/bin/bash
# Instalación rápida kde-stickers v1

set -e

PLUGIN_DIR="$HOME/.local/share/plasma/plasmoids/org.kde.stickers"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📦 Instalando kde-stickers v1..."

# Crear estructura
mkdir -p "$PLUGIN_DIR"/contents/{ui,code}

# Copiar archivos
cp "$SCRIPT_DIR"/metadata.json "$PLUGIN_DIR/"
cp "$SCRIPT_DIR"/main.qml "$PLUGIN_DIR"/contents/ui/
cp "$SCRIPT_DIR"/storage.js "$PLUGIN_DIR"/contents/code/

# Crear directorio de almacenamiento
mkdir -p "$HOME/.stickers"

echo "✓ Archivos instalados en: $PLUGIN_DIR"
echo ""
echo "Ahora reinicia Plasma:"
echo "  kquitapp6 plasmashell"
echo "  kstart6 plasmashell &"
echo ""
echo "O ejecuta en otra terminal:"
echo "  plasmashell"
