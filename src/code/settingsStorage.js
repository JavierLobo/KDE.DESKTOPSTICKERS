.import Stickers.Storage 1.0 as App

// Settings v1 - Persistencia en JSON
//
// Same delegation pattern as storage.js: file I/O goes through the
// FileStorage QML singleton, this file only owns the JSON shape. Lives in
// ~/.stickers/settings.json, alongside stickers.json.
//
// Unlike stickers.json (an array of independent records), settings.json is
// a single nested object -- a future version adding a new key must not make
// an older settings.json look "corrupt". loadSettings() merges the file's
// contents onto defaultSettings() one category at a time so missing keys
// (new field, or a hand-edited/partial file) fall back individually instead
// of losing the whole category.
function getStickersDir() {
    return App.FileStorage.stickersDir()
}

function ensureDir() {
    let dir = getStickersDir()
    App.FileStorage.ensureDir(dir)
}

function defaultSettings() {
    return {
        appearance: {
            defaultColorMode: "random", // "random" | "accent" | "fixed"
            defaultFixedColor: "#FFD700",
            fontFamilyPreferences: ["Times New Roman", "Liberation Serif"],
            fontSize: 10
        },
        behavior: {
            markdownToolbarVisibleByDefault: true,
            askBeforeDeleting: true,
            trayLeftClickAction: "openPanel" // "openPanel" | "newSticker"
        },
        desktops: {
            pinNewStickersByDefault: false
        },
        system: {
            autostartEnabled: true
        }
    }
}

function mergeWithDefaults(loaded) {
    let defaults = defaultSettings()
    let merged = {}
    for (let category in defaults) {
        merged[category] = Object.assign({}, defaults[category], loaded && loaded[category] ? loaded[category] : {})
    }
    return merged
}

function loadSettings() {
    ensureDir()
    let path = getStickersDir() + "/settings.json"

    if (!App.FileStorage.exists(path)) {
        return defaultSettings()
    }

    let data = App.FileStorage.readFile(path)

    try {
        let loaded = JSON.parse(data)
        return mergeWithDefaults(loaded)
    } catch (e) {
        console.error("Error parsing settings JSON:", e)
        return defaultSettings()
    }
}

function saveSettings(settings) {
    ensureDir()
    let path = getStickersDir() + "/settings.json"
    let json = JSON.stringify(settings, null, 2)

    if (!App.FileStorage.writeFile(path, json)) {
        console.error("No se puede escribir:", path)
        return false
    }

    return true
}
