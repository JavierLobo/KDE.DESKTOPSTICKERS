#!/bin/bash
# kde-stickers: compila el binario Qt6, registra autostart y la regla de KWin
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$REPO_DIR/build"
BIN_INSTALL_DIR="$HOME/.local/bin"
AUTOSTART_DIR="$HOME/.config/autostart"
BIN_PATH="$BIN_INSTALL_DIR/kde-stickers"
KWIN_RULE_ID="kdestickers-alldesktops"

echo "📦 Compilando kde-stickers..."
cmake -B "$BUILD_DIR" -S "$REPO_DIR" -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR"

echo "📦 Instalando binario en $BIN_PATH"
mkdir -p "$BIN_INSTALL_DIR"
cp "$BUILD_DIR/kde-stickers" "$BIN_PATH"

echo "📦 Registrando autostart"
mkdir -p "$AUTOSTART_DIR"
sed "s|__KDE_STICKERS_BIN__|$BIN_PATH|" \
    "$REPO_DIR/data/org.kde.stickers.desktop" \
    > "$AUTOSTART_DIR/org.kde.stickers.desktop"

echo "📦 Registrando regla de KWin (todos los escritorios)"
EXISTING_RULES="$(kreadconfig6 --file kwinrulesrc --group General --key rules 2>/dev/null || true)"
if [[ ",$EXISTING_RULES," != *",$KWIN_RULE_ID,"* ]]; then
    NEW_RULES="${EXISTING_RULES:+$EXISTING_RULES,}$KWIN_RULE_ID"
    kwriteconfig6 --file kwinrulesrc --group General --key rules "$NEW_RULES"
fi
kwriteconfig6 --file kwinrulesrc --group "$KWIN_RULE_ID" --key wmclass "org.kde.stickers"
kwriteconfig6 --file kwinrulesrc --group "$KWIN_RULE_ID" --key wmclassmatch 2
kwriteconfig6 --file kwinrulesrc --group "$KWIN_RULE_ID" --key wmclasscomplete false
kwriteconfig6 --file kwinrulesrc --group "$KWIN_RULE_ID" --key types 1
kwriteconfig6 --file kwinrulesrc --group "$KWIN_RULE_ID" --key desktops ""
kwriteconfig6 --file kwinrulesrc --group "$KWIN_RULE_ID" --key desktopsrule 2
qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null || true

mkdir -p "$HOME/.stickers"

echo "✓ kde-stickers instalado en $BIN_PATH"
echo "✓ Autostart registrado en $AUTOSTART_DIR/org.kde.stickers.desktop"
echo "✓ Regla de KWin '$KWIN_RULE_ID' registrada (todos los escritorios)"
echo ""
echo "Se iniciará automáticamente en tu próxima sesión de Plasma."
echo "Para lanzarlo ahora mismo:"
echo "  $BIN_PATH &"
