.pragma library
.import "../code/settingsStorage.js" as Storage

// Same module-level-var singleton pattern as StickerManager.js's `stickers`
// array: loaded once per process, mutated in place, persisted on every
// change.
var settings = Storage.loadSettings()

function get() {
    return settings
}

function update(category, key, value) {
    settings[category][key] = value
    return Storage.saveSettings(settings)
}

function resetToDefaults() {
    settings = Storage.defaultSettings()
    Storage.saveSettings(settings)
    return settings
}
