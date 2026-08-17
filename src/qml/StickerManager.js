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
    Storage.saveSticker(sticker.id, sticker.text, sticker.color, x, y)
}

function updateText(id, text) {
    var sticker = stickers.find(function(s) { return s.id === id })
    if (!sticker) return
    sticker.text = text
    Storage.saveSticker(sticker.id, text, sticker.color, sticker.x, sticker.y)
}
