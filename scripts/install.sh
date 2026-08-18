#!/bin/bash
# kde-stickers: compila el binario Qt6, registra autostart y migra config antigua de KWin
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

echo "📦 Migrando: retirando la regla global de todos-los-escritorios (ahora es por sticker, vía pin)"
EXISTING_RULES="$(kreadconfig6 --file kwinrulesrc --group General --key rules 2>/dev/null || true)"
if [[ ",$EXISTING_RULES," == *",$KWIN_RULE_ID,"* ]]; then
    NEW_RULES="$(echo ",$EXISTING_RULES," | sed "s/,$KWIN_RULE_ID,/,/" | sed 's/^,//;s/,$//')"
    kwriteconfig6 --file kwinrulesrc --group General --key rules "$NEW_RULES"
    if ! qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null; then
        echo "⚠ No se pudo recargar KWin en caliente tras retirar la regla global; se aplicará en tu próxima sesión"
    fi
    echo "✓ Regla global '$KWIN_RULE_ID' retirada de la lista activa"
fi

mkdir -p "$HOME/.stickers"

if command -v jq >/dev/null 2>&1; then
    echo "📦 Limpiando reglas KWin huérfanas de stickers ya eliminados"
    STICKERS_JSON="$HOME/.stickers/stickers.json"
    STICKER_IDS="$( [ -f "$STICKERS_JSON" ] && jq -r '.stickers[].id' "$STICKERS_JSON" 2>/dev/null || true)"
    EXISTING_RULES="$(kreadconfig6 --file kwinrulesrc --group General --key rules 2>/dev/null || true)"
    IFS=',' read -ra RULE_ARRAY <<< "$EXISTING_RULES"
    NEW_RULE_LIST=""
    SWEPT_ANY=0
    for rule in "${RULE_ARRAY[@]}"; do
        if [[ "$rule" =~ ^kdestickers-sticker-(.+)$ ]]; then
            rule_sticker_id="${BASH_REMATCH[1]}"
            if ! echo "$STICKER_IDS" | grep -qx "$rule_sticker_id"; then
                SWEPT_ANY=1
                continue
            fi
        fi
        NEW_RULE_LIST="${NEW_RULE_LIST:+$NEW_RULE_LIST,}$rule"
    done
    if [ "$SWEPT_ANY" = "1" ]; then
        kwriteconfig6 --file kwinrulesrc --group General --key rules "$NEW_RULE_LIST"
        qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null || true
        echo "✓ Reglas huérfanas retiradas de la lista activa"
    fi
else
    echo "⚠ jq no disponible — se omite la limpieza de reglas huérfanas (no crítico)"
fi

echo "✓ kde-stickers instalado en $BIN_PATH"
echo "✓ Autostart registrado en $AUTOSTART_DIR/org.kde.stickers.desktop"
echo ""
echo "Se iniciará automáticamente en tu próxima sesión de Plasma."
echo "Para lanzarlo ahora mismo:"
echo "  $BIN_PATH &"
