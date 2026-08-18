.import Stickers.Storage 1.0 as App

// Storage v1 - Persistencia en JSON
//
// File I/O (exists/ensureDir/readFile/writeFile/stickersDir) is delegated to
// the FileStorage QML singleton (src/filestorage.h/.cpp) because QDir/QFile/
// QIODevice are not registered as QML-accessible types in Qt6's QtCore QML
// module — only StandardPaths is. The JSON schema and all four public
// functions below are unchanged from the original design.
//
// getStickersDir() used to compute this itself via QtCore's
// StandardPaths.writableLocation(), which returns a QUrl whose string form
// varies ("file:///home/user" vs "file:/home/user"); a hand-rolled
// "file://" prefix strip missed the single-slash variant and silently
// produced a bogus relative path. Resolving the path in C++ instead (where
// QStandardPaths::writableLocation() returns a plain local QString, no URL
// involved) removes that failure mode entirely.
function getStickersDir() {
    return App.FileStorage.stickersDir()
}

function ensureDir() {
    let dir = getStickersDir()
    App.FileStorage.ensureDir(dir)
}

function loadAllStickers() {
    ensureDir()
    let indexPath = getStickersDir() + "/stickers.json"

    if (!App.FileStorage.exists(indexPath)) {
        return []
    }

    let data = App.FileStorage.readFile(indexPath)

    try {
        let json = JSON.parse(data)
        return json.stickers || []
    } catch (e) {
        console.error("Error parsing JSON:", e)
        return []
    }
}

function saveSticker(id, text, color, x, y) {
    ensureDir()

    let stickers = loadAllStickers()
    let idx = stickers.findIndex(s => s.id === id)

    let sticker = {
        id: id,
        text: text,
        color: color,
        x: x,
        y: y,
        created: new Date().toISOString(),
        modified: new Date().toISOString()
    }

    if (idx >= 0) {
        sticker.created = stickers[idx].created
        stickers[idx] = sticker
    } else {
        stickers.push(sticker)
    }

    let indexPath = getStickersDir() + "/stickers.json"
    let json = JSON.stringify({stickers: stickers}, null, 2)

    if (!App.FileStorage.writeFile(indexPath, json)) {
        console.error("No se puede escribir:", indexPath)
        return false
    }

    return true
}

function deleteSticker(id) {
    let stickers = loadAllStickers()
    stickers = stickers.filter(s => s.id !== id)

    let indexPath = getStickersDir() + "/stickers.json"
    let json = JSON.stringify({stickers: stickers}, null, 2)

    if (!App.FileStorage.writeFile(indexPath, json)) {
        console.error("No se puede escribir:", indexPath)
        return false
    }

    return true
}

function newStickerId() {
    let stickers = loadAllStickers()
    let maxId = stickers.reduce((max, s) => {
        let num = parseInt(s.id)
        return num > max ? num : max
    }, 0)

    return String(maxId + 1).padStart(3, '0')
}
