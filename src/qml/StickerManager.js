.pragma library
.import "../code/storage.js" as Storage

var stickers = []

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

function createSticker(originX, originY) {
    var id = Storage.newStickerId()
    var sticker = {
        id: id,
        text: "Nuevo sticker...",
        color: "#FFD700",
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
}
