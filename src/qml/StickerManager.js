.pragma library
.import "../code/storage.js" as Storage
.import Stickers.KWin 1.0 as KWin
.import Stickers.System 1.0 as System
.import "SettingsManager.js" as Settings

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
        return sticker.name.length > 30 ? sticker.name.substring(0, 30) + "…" : sticker.name
    }
    if (!sticker.text) {
        return "Sticker"
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

// Whether displayName(sticker) would return a real title (an explicit
// name, or a non-empty first line of content) rather than falling back to
// its own placeholder. Kept separate from displayName() itself -- which
// stays a plain string for its other callers (StickerWindow's header, the
// tray menu) -- because the Stickers Panel needs to render its own
// distinct "Sin título" placeholder in italic/muted style, which requires
// knowing WHETHER a fallback happened, not just the text.
function hasTitle(sticker) {
    if (sticker.name && sticker.name.length > 0) {
        return true
    }
    if (!sticker.text) {
        return false
    }
    var lines = sticker.text.split("\n")
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].replace(/^#+\s*/, "").trim()
        if (line.length > 0) {
            return true
        }
    }
    return false
}

// A single-line preview of the sticker's content for the Stickers Panel's
// second row line. If the title (see hasTitle/displayName above) came
// from the content's own first non-empty line, that line is skipped here
// so the snippet doesn't just repeat the title verbatim. Actual visual
// truncation with an ellipsis is left to the QML Text/Label's own `elide`
// -- it truncates correctly against the real available width, which a
// fixed character count here could not.
function contentSnippet(sticker) {
    if (!sticker.text) {
        return ""
    }
    var text = sticker.text
    if (!sticker.name || sticker.name.length === 0) {
        var lines = text.split("\n")
        var skipped = false
        var rest = []
        for (var i = 0; i < lines.length; i++) {
            var trimmed = lines[i].replace(/^#+\s*/, "").trim()
            if (!skipped && trimmed.length > 0) {
                skipped = true
                continue
            }
            rest.push(lines[i])
        }
        text = rest.join(" ")
    }
    return text.replace(/\s+/g, " ").trim()
}

var MONTH_ABBREVIATIONS_ES = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]

// Relative for anything recent ("hace 2 h", "ayer"), absolute from a week
// onward ("3 mar") -- matches how most desktop file managers/chat apps
// timestamp a list. Callers should re-evaluate this periodically (e.g. a
// once-a-minute Timer) since its result changes purely with wall-clock
// time, not with any sticker data.
function formatRelativeDate(isoString) {
    if (!isoString) {
        return ""
    }
    var then = new Date(isoString)
    if (isNaN(then.getTime())) {
        return ""
    }
    var diffMs = Date.now() - then.getTime()
    var diffMin = Math.floor(diffMs / 60000)
    if (diffMin < 1) {
        return "ahora"
    }
    if (diffMin < 60) {
        return "hace " + diffMin + " min"
    }
    var diffHours = Math.floor(diffMin / 60)
    if (diffHours < 24) {
        return "hace " + diffHours + " h"
    }
    var diffDays = Math.floor(diffHours / 24)
    if (diffDays === 1) {
        return "ayer"
    }
    if (diffDays < 7) {
        return "hace " + diffDays + " días"
    }
    return then.getDate() + " " + MONTH_ABBREVIATIONS_ES[then.getMonth()]
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
    sticker.name = name.trim()
    Storage.saveSticker(sticker)
}

// accentColor is the caller's current system accent color (a live QML
// SystemPalette binding, read in Main.qml -- a .pragma library file can't
// instantiate a QML Item itself, same reason RANDOM_COLORS is duplicated
// above instead of read from ColorPalette.qml). Only used when the
// "appearance.defaultColorMode" setting is "accent".
function resolveDefaultColor(accentColor) {
    var mode = Settings.get().appearance.defaultColorMode
    if (mode === "fixed") return Settings.get().appearance.defaultFixedColor
    if (mode === "accent" && accentColor) return accentColor
    return randomColor()
}

function createSticker(originX, originY, accentColor) {
    var id = Storage.newStickerId()
    var appearance = Settings.get().appearance
    var sticker = {
        id: id,
        name: "",
        text: "Nuevo sticker...",
        color: resolveDefaultColor(accentColor),
        x: originX + 30,
        y: originY + 30,
        width: 300,
        height: 250,
        pinned: Settings.get().desktops.pinNewStickersByDefault,
        fontFamily: System.SystemIntegration.resolveFontFamily(appearance.fontFamilyPreferences, "Sans Serif"),
        fontSize: appearance.fontSize
    }
    stickers.push(sticker)
    Storage.saveSticker(sticker)
    return sticker
}

// Panel context menu's "Duplicar". Offset from the original so the copy
// doesn't land exactly on top of it; never pinned (pinning is per-window
// KWin state tied to a specific sticker id/title, not something to clone).
function duplicateSticker(id) {
    var original = stickers.find(function(s) { return s.id === id })
    if (!original) return null
    var copy = {
        id: Storage.newStickerId(),
        name: original.name,
        text: original.text,
        color: original.color,
        x: original.x + 24,
        y: original.y + 24,
        width: original.width,
        height: original.height,
        pinned: false,
        fontFamily: original.fontFamily,
        fontSize: original.fontSize
    }
    stickers.push(copy)
    Storage.saveSticker(copy)
    return copy
}

// Re-inserts a full sticker record previously removed by removeSticker()
// -- the Stickers Panel's delete-undo toast keeps a deep-copied snapshot
// of exactly what removeSticker() took out, and this is its mirror image.
// Does not restore any KWin pin rule (removeSticker's KWin.KWinBridge.
// removeRules(id) already tore that down); a still-pinned sticker just
// gets its rule re-applied the next time its window opens, the same as
// any other sticker.
function restoreSticker(sticker) {
    stickers.push(sticker)
    Storage.saveSticker(sticker)
}

function removeSticker(id) {
    stickers = stickers.filter(function(s) { return s.id !== id })
    Storage.deleteSticker(id)
    KWin.KWinBridge.removeRules(id)
}
