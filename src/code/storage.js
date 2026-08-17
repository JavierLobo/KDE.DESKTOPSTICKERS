import QtCore

// Storage v1 - Persistencia en JSON
function getStickersDir() {
    let home = StandardPaths.writableLocation(StandardPaths.HomeLocation)
    return home + "/.stickers"
}

function ensureDir() {
    let dir = getStickersDir()
    let dirObj = new QDir(dir)
    if (!dirObj.exists()) {
        dirObj.mkpath(".")
    }
}

function loadAllStickers() {
    ensureDir()
    let indexPath = getStickersDir() + "/stickers.json"
    let file = new QFile(indexPath)
    
    if (!file.exists()) {
        return []
    }
    
    if (!file.open(QIODevice.ReadOnly | QIODevice.Text)) {
        console.error("No se puede abrir:", indexPath)
        return []
    }
    
    let data = file.readAll()
    file.close()
    
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
    let file = new QFile(indexPath)
    
    if (!file.open(QIODevice.WriteOnly | QIODevice.Text)) {
        console.error("No se puede escribir:", indexPath)
        return false
    }
    
    let json = JSON.stringify({stickers: stickers}, null, 2)
    file.write(json)
    file.close()
    
    return true
}

function deleteSticker(id) {
    let stickers = loadAllStickers()
    stickers = stickers.filter(s => s.id !== id)
    
    let indexPath = getStickersDir() + "/stickers.json"
    let file = new QFile(indexPath)
    
    if (!file.open(QIODevice.WriteOnly | QIODevice.Text)) {
        console.error("No se puede escribir:", indexPath)
        return false
    }
    
    let json = JSON.stringify({stickers: stickers}, null, 2)
    file.write(json)
    file.close()
    
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
