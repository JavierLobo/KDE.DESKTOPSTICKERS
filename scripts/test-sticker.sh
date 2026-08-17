#!/bin/bash
# Test script - crear stickers de prueba

STICKERS_DIR="$HOME/.stickers"

mkdir -p "$STICKERS_DIR"

# Crear sticker de ejemplo
cat > "$STICKERS_DIR/stickers.json" << 'EOF'
{
  "stickers": [
    {
      "id": "001",
      "text": "Primer sticker de prueba\nEditable y arrastrable",
      "color": "#FFD700",
      "x": 100,
      "y": 100,
      "created": "2026-08-17T10:00:00Z",
      "modified": "2026-08-17T10:00:00Z"
    },
    {
      "id": "002",
      "text": "Segundo sticker\n🎨 Cambia mi color\n✕ Elimínate",
      "color": "#87CEEB",
      "x": 450,
      "y": 150,
      "created": "2026-08-17T10:01:00Z",
      "modified": "2026-08-17T10:01:00Z"
    },
    {
      "id": "003",
      "text": "TODO:\n- Implementar arrastre real\n- Sincronizar con JSON\n- Soporte multi-desktop",
      "color": "#FFB6C1",
      "x": 250,
      "y": 400,
      "created": "2026-08-17T10:02:00Z",
      "modified": "2026-08-17T10:02:00Z"
    }
  ]
}
EOF

echo "✓ Stickers de prueba creados"
echo "  Archivo: $STICKERS_DIR/stickers.json"
echo ""
echo "Contenido:"
cat "$STICKERS_DIR/stickers.json" | jq .
