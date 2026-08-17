.import QtCore 6.2 as QC
.import Stickers.Storage 1.0 as App

// Storage v1 - Persistencia en JSON
//
// File I/O (exists/ensureDir/readFile/writeFile) is delegated to the
// FileStorage QML singleton (src/filestorage.h/.cpp) because QDir/QFile/
// QIODevice are not registered as QML-accessible types in Qt6's QtCore QML
// module — only StandardPaths is. The JSON schema and all four public
// functions below are unchanged from the original design.
function getStickersDir() {
    // writableLocation() returns a QUrl (e.g. "file:///home/user"), not a
    // plain path -- FileStorage's QFile/QDir calls need a plain local path,
    // so the "file://" scheme prefix must be stripped before use.
    let home = String(QC.StandardPaths.writableLocation(QC.StandardPaths.HomeLocation))
    if (home.indexOf("file://") === 0) {
        home = home.substring(7)
    }
    return home + "/.stickers"
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
