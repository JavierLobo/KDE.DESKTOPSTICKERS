.pragma library
.import "../code/storage.js" as Storage
.import Stickers.KWin 1.0 as KWin

var stickers = []

// Same 6 tones as ColorPalette.qml's swatchColors. Duplicated deliberately:
// this file is a .pragma library (plain JS, no QML component access), so
// it cannot import a QML Item's property list, and 6 static hex strings
// aren't worth an extra indirection to avoid repeating.
var RANDOM_COLORS = ["#FFD700", "#87CEEB", "#FFB6C1", "#FFA07A", "#98FB98", "#DDA0DD"]

function randomColor() {
    return RANDOM_COLORS[Math.floor(Math.random() * RANDOM_COLORS.length)]
}

// Shared by StickerWindow.qml's own header and Main.qml's tray menu /
// Stickers Panel, so the "what do we show when there's no name yet"
// fallback logic lives in exactly one place. Visual-only: never writes
// back into sticker.name.
function displayName(sticker) {
    if (sticker.name && sticker.name.length > 0) {
        return sticker.name
    }
    var lines = sticker.text.split("\n")
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].replace(/^#+\s*/, "").trim()
        if (line.length > 0) {
            return line.length > 30 ? line.substring(0, 30) + "…" : line
        }
    }
    return "Sticker"
}

function loadStickers() {
    stickers = Storage.loadAllStickers()
    return stickers
}

function updatePosition(id, x, y) {
    var sticker = stickers.find(function(s) { return s.id === id })
    if (!sticker) return
    sticker.x = x
    sticker.y = y
    Storage.saveSticker(sticker)
}

function updateSize(id, width, height) {
    var sticker = stickers.find(function(s) { return s.id === id })
    if (!sticker) return
    sticker.width = width
    sticker.height = height
    Storage.saveSticker(sticker)
}

function updatePinned(id, pinned) {
    var sticker = stickers.find(function(s) { return s.id === id })
    if (!sticker) return
    sticker.pinned = pinned
    Storage.saveSticker(sticker)
}

function updateText(id, text) {
    var sticker = stickers.find(function(s) { return s.id === id })
    if (!sticker) return
    sticker.text = text
    Storage.saveSticker(sticker)
}

function updateColor(id, color) {
    var sticker = stickers.find(function(s) { return s.id === id })
    if (!sticker) return
    sticker.color = color
    Storage.saveSticker(sticker)
}

function updateName(id, name) {
    var sticker = stickers.find(function(s) { return s.id === id })
    if (!sticker) return
    sticker.name = name
    Storage.saveSticker(sticker)
}

function createSticker(originX, originY) {
    var id = Storage.newStickerId()
    var sticker = {
        id: id,
        name: "",
        text: "Nuevo sticker...",
        color: randomColor(),
        x: originX + 30,
        y: originY + 30,
        width: 300,
        height: 250,
        pinned: false
    }
    stickers.push(sticker)
    Storage.saveSticker(sticker)
    return sticker
}

function removeSticker(id) {
    stickers = stickers.filter(function(s) { return s.id !== id })
    Storage.deleteSticker(id)
    KWin.KWinBridge.removeRules(id)
}
