# Sticker Name, Header Reorder, Stickers Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persisted, editable "name" per sticker, reorder the sticker header's buttons, randomize the color assigned on creation, simplify the tray menu's note rows to name-only, and add a new "Panel de Stickers" window listing/managing all stickers.

**Architecture:** `StickerManager.js` gains the data-layer pieces (a `name` field, a shared `displayName()` fallback function, a random-color helper, `updateName()`) that both `StickerWindow.qml` (its own header) and `Main.qml` (tray menu + the new `StickerPanel.qml`) consume. `StickerPanel.qml` is a plain QML `Window` — not a `Qt.labs.platform.Menu`/`Dialog` — declared once as a static child of `Main.qml`'s root and shown/hidden rather than recreated, since exactly one instance is ever needed. It reuses `Main.qml`'s already-shipped `openOrFocusSticker`/`confirmDeleteSticker` rather than duplicating that logic.

**Tech Stack:** Qt6 (Quick, QML, Widgets via `QApplication`), `Qt.labs.platform` (`SystemTrayIcon`, `Menu`, `MenuItem`, `MessageDialog` — all already in use, no new native mechanism), QtQuick.Controls (`TextField`, `Button`, `ScrollView` — already used elsewhere in this codebase).

**Spec:** `docs/superpowers/specs/2026-08-19-sticker-name-panel-design.md`

## Global Constraints

- Qt6 only, unversioned QML imports (`import QtQuick`, not `import QtQuick 2.15`) — matches the rest of this codebase.
- No automated test framework. Verification is compile success + real manual runtime evidence (screenshots, real synthetic `/dev/uinput` clicks, `journalctl` output, actual file contents) — this project's established, non-negotiable standard. "Should work" / code-reasoning-only is not acceptable evidence for any task in this plan.
- `name` defaults to `""` (empty string) for both newly-created stickers and existing ones missing the field on load — never `null`/`undefined`.
- The display-fallback (first non-empty line of `text`, Markdown headers stripped, truncated at 30 chars) is **visual only** — it is never written back into `name`. A rename to an empty string is valid and simply reverts the display to that fallback.
- The random color assigned on creation is drawn only from the 6 fixed hex values already in `ColorPalette.qml`'s `swatchColors` — never a fully random RGB value.
- Renaming a sticker is reachable **only** from the Stickers Panel — the sticker window's own header displays the name but does not let the user edit it there (explicit design decision, avoids a second, redundant edit surface).
- No nested `Qt.labs.platform.Menu` anywhere (standing project-wide rule from the previous plan — still applies; this plan doesn't add any menu nesting, but no task may introduce one either).

---

## Task 1: Data model — `name` field, shared display-fallback, random color

**Files:**
- Modify: `src/code/storage.js`
- Modify: `src/qml/StickerManager.js`

**Interfaces:**
- Produces: `Storage.loadAllStickers(): Array<{..., name: string}>` — backfills `name: ""` for records missing it.
- Produces: `Storage.saveSticker(sticker: {..., name}): bool` — persists `name` (already object-shaped, no signature change from today).
- Produces: `Manager.updateName(id: string, name: string): void`.
- Produces: `Manager.displayName(sticker: {name: string, text: string}): string` — returns `sticker.name` if non-empty, otherwise the first non-empty line of `sticker.text` (Markdown headers stripped via `/^#+\s*/`, trimmed, truncated to 30 chars + `…` if longer), otherwise `"Sticker"`.
- Produces: `Manager.randomColor(): string` — one of the 6 fixed hex values, chosen at random.
- Produces: `Manager.createSticker(originX, originY): {..., name: "", color: <random>}` — signature unchanged, but the returned/persisted sticker now has `name: ""` and a random `color` instead of the fixed `"#FFD700"`.

- [ ] **Step 1: Add `name` backfill to `loadAllStickers()` in `src/code/storage.js`**

Change (inside the `.map(s => ({...}))` call):
```js
        return stickers.map(s => ({
            id: s.id,
            text: s.text,
            color: s.color,
            x: s.x,
            y: s.y,
            width: s.width !== undefined ? s.width : 300,
            height: s.height !== undefined ? s.height : 250,
            pinned: s.pinned !== undefined ? s.pinned : false,
            created: s.created,
            modified: s.modified
        }))
```
to:
```js
        return stickers.map(s => ({
            id: s.id,
            name: s.name !== undefined ? s.name : "",
            text: s.text,
            color: s.color,
            x: s.x,
            y: s.y,
            width: s.width !== undefined ? s.width : 300,
            height: s.height !== undefined ? s.height : 250,
            pinned: s.pinned !== undefined ? s.pinned : false,
            created: s.created,
            modified: s.modified
        }))
```

- [ ] **Step 2: Add `name` to the persisted record in `saveSticker()` in `src/code/storage.js`**

Change:
```js
    let record = {
        id: sticker.id,
        text: sticker.text,
        color: sticker.color,
        x: sticker.x,
        y: sticker.y,
        width: sticker.width,
        height: sticker.height,
        pinned: sticker.pinned,
        created: new Date().toISOString(),
        modified: new Date().toISOString()
    }
```
to:
```js
    let record = {
        id: sticker.id,
        name: sticker.name,
        text: sticker.text,
        color: sticker.color,
        x: sticker.x,
        y: sticker.y,
        width: sticker.width,
        height: sticker.height,
        pinned: sticker.pinned,
        created: new Date().toISOString(),
        modified: new Date().toISOString()
    }
```

- [ ] **Step 3: Add `updateName`, `displayName`, `randomColor` to `src/qml/StickerManager.js`, update `createSticker`**

The current file is:
```js
.pragma library
.import "../code/storage.js" as Storage
.import Stickers.KWin 1.0 as KWin

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
    KWin.KWinBridge.removeRules(id)
}
```

Replace the whole file with:
```js
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
```

- [ ] **Step 4: Build**

```bash
cmake --build build
```

Expected: clean build, no errors, no new warnings.

- [ ] **Step 5: Verify with real evidence — backfill, random color, name persistence**

```bash
./scripts/test-sticker.sh   # resets ~/.stickers/stickers.json to the 3-fixture (no "name" field at all)
pkill -9 -f "build/kde-stickers" 2>/dev/null; sleep 0.5
./build/kde-stickers &
sleep 1.5
```

Confirm the backfill happened correctly without corrupting anything else:
```bash
cat ~/.stickers/stickers.json | jq '.stickers[] | {id, name, color}'
```
Expected: `.name` is not yet written to the file at this point (backfill happens in-memory on load; the file itself only gets `name` written back the next time something calls `saveSticker` for that record) — this is expected and fine, matching how `width`/`height`/`pinned` backfill already behaves for old records. Confirm instead that the app didn't crash and the 3 stickers still show their original colors (`#FFD700`/`#87CEEB`/`#FFB6C1` per the fixture) — the backfill only needs to not break loading, not eagerly rewrite the file.

Real-click the sticker's own "+" button (find its real on-screen position via a KWin script's `workspace.windowList()` query for one sticker's geometry, then a screenshot to locate the button within it — same ground-truth technique used throughout this project) 3 times, creating 3 new stickers. Confirm via:
```bash
cat ~/.stickers/stickers.json | jq '.stickers[] | select(.id | test("00[4-6]")) | {id, name, color}'
```
Expected: all 3 new stickers have `"name": ""`, and their `color` values are real hex strings drawn from `["#FFD700", "#87CEEB", "#FFB6C1", "#FFA07A", "#98FB98", "#DDA0DD"]` — not necessarily all different from each other (it's random, repeats are fine), but each one must be one of those 6 exact values, confirmed by direct string comparison against the list, not eyeballing.

- [ ] **Step 6: Commit**

```bash
git add src/code/storage.js src/qml/StickerManager.js
git commit -m "feat: add sticker name field, shared display-fallback, random creation color"
```

---

## Task 2: Sticker header — reordered buttons, name/number display

**Files:**
- Modify: `src/qml/StickerWindow.qml`
- Modify: `src/qml/Main.qml`

**Interfaces:**
- Consumes: `Manager.displayName(sticker)` (Task 1).
- Produces: `StickerWindow`'s `property string stickerName` — a new initial property `Main.qml`'s `createStickerWindow` must set when instantiating a `StickerWindow`.

- [ ] **Step 1: Add `stickerName` property to `src/qml/StickerWindow.qml`**

Change (near the top, alongside the other `property string`/`property int` declarations):
```qml
    property string stickerId: "001"
    property string stickerText: "Nuevo sticker..."
    property string stickerColor: "#FFD700"
```
to:
```qml
    property string stickerId: "001"
    property string stickerName: ""
    property string stickerText: "Nuevo sticker..."
    property string stickerColor: "#FFD700"
```

- [ ] **Step 2: Reorder the header's `RowLayout` in `src/qml/StickerWindow.qml`**

Current code (inside `Rectangle { id: header ... }`):
```qml
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 8

                    Text {
                        text: "#" + stickerId
                        color: "#333"
                        font.bold: true
                        Layout.fillWidth: true
                        font.pixelSize: 12
                    }

                    Button {
                        text: stickerPinned ? "📌" : "📍"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: {
                            var newPinned = !stickerPinned
                            stickerPinned = newPinned
                            Manager.updatePinned(stickerId, newPinned)
                            KWin.KWinBridge.setPinned(stickerId, mainWindow.title, newPinned)
                        }
                    }

                    Button {
                        text: "+"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: mainWindow.appRoot.createNewSticker(mainWindow.x, mainWindow.y)
                    }

                    Button {
                        text: "🎨"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: colorPopup.open()
                    }

                    Button {
                        text: "✕"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: {
                            // "✕" only closes the window now -- the note
                            // itself is NOT deleted (stickers.json keeps the
                            // record, so it can be reopened from the tray
                            // menu's note list). Deleting is a separate,
                            // confirmed action reachable only from that
                            // menu (see Main.qml's confirmDeleteSticker).
                            mainWindow.appRoot.unregisterWindow(stickerId)
                            // close() alone only hides the window -- the QML
                            // object, its persistTimer above, and the
                            // Connections to KWinBridge.moveFinished stay
                            // alive for the rest of the process lifetime
                            // otherwise, a small per-deletion leak in this
                            // long-running autostart daemon. destroy()
                            // actually frees it.
                            mainWindow.close()
                            mainWindow.destroy()
                        }
                    }
                }
```

Replace with (number/name grouped on the left, all 4 buttons grouped on the
right in `+, pin, color, close` order — "✕"'s `onClicked` body is
byte-for-byte unchanged from above, only its position in the file moves):
```qml
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 8

                    Text {
                        text: "#" + stickerId
                        color: "#333"
                        font.bold: true
                        font.pixelSize: 12
                    }

                    Text {
                        text: "|"
                        color: "#333"
                        font.pixelSize: 12
                    }

                    Text {
                        text: Manager.displayName({ name: stickerName, text: stickerText })
                        color: "#333"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Button {
                        text: "+"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: mainWindow.appRoot.createNewSticker(mainWindow.x, mainWindow.y)
                    }

                    Button {
                        text: stickerPinned ? "📌" : "📍"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: {
                            var newPinned = !stickerPinned
                            stickerPinned = newPinned
                            Manager.updatePinned(stickerId, newPinned)
                            KWin.KWinBridge.setPinned(stickerId, mainWindow.title, newPinned)
                        }
                    }

                    Button {
                        text: "🎨"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: colorPopup.open()
                    }

                    Button {
                        text: "✕"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: {
                            // "✕" only closes the window now -- the note
                            // itself is NOT deleted (stickers.json keeps the
                            // record, so it can be reopened from the tray
                            // menu's note list). Deleting is a separate,
                            // confirmed action reachable only from that
                            // menu (see Main.qml's confirmDeleteSticker).
                            mainWindow.appRoot.unregisterWindow(stickerId)
                            // close() alone only hides the window -- the QML
                            // object, its persistTimer above, and the
                            // Connections to KWinBridge.moveFinished stay
                            // alive for the rest of the process lifetime
                            // otherwise, a small per-deletion leak in this
                            // long-running autostart daemon. destroy()
                            // actually frees it.
                            mainWindow.close()
                            mainWindow.destroy()
                        }
                    }
                }
```

- [ ] **Step 3: Pass `name` into `stickerName` when creating a window, in `src/qml/Main.qml`**

Change (inside `createStickerWindow`):
```qml
        var w = stickerWindowComponent.createObject(root, {
            stickerId: sticker.id,
            stickerText: sticker.text,
            stickerColor: sticker.color,
            posX: sticker.x,
            posY: sticker.y,
            posWidth: sticker.width,
            posHeight: sticker.height,
            stickerPinned: sticker.pinned,
            appRoot: root
        })
```
to:
```qml
        var w = stickerWindowComponent.createObject(root, {
            stickerId: sticker.id,
            stickerName: sticker.name,
            stickerText: sticker.text,
            stickerColor: sticker.color,
            posX: sticker.x,
            posY: sticker.y,
            posWidth: sticker.width,
            posHeight: sticker.height,
            stickerPinned: sticker.pinned,
            appRoot: root
        })
```

- [ ] **Step 4: Build**

```bash
cmake --build build
```

Expected: clean build.

- [ ] **Step 5: Verify with real evidence — header order and name/fallback display**

```bash
./scripts/test-sticker.sh
pkill -9 -f "build/kde-stickers" 2>/dev/null; sleep 0.5
./build/kde-stickers &
sleep 1.5
```

Locate one sticker's real geometry (KWin script, `workspace.windowList()`), screenshot its header, and crop/zoom it. Confirm:
- Left side reads `#001 | Primer sticker de prueba` (or whichever fixture sticker) — the derived fallback, since `name` is still `""` at this point.
- Right side shows exactly 4 buttons in order `+`, `📍`/`📌`, `🎨`, `✕` — "+" leftmost of the group, "✕" rightmost overall.

- [ ] **Step 6: Investigate the reported "+ opens the tray menu" issue, with real evidence**

Before this task's changes, a user report said clicking the sticker's own "+" button appeared to open the system tray icon's menu. In the current (pre- and post-reorder) code, that button's `onClicked` only calls `mainWindow.appRoot.createNewSticker(...)` — there is no code path from it to the tray menu. The most likely explanation is a visual/positional coincidence (the sticker's on-screen position happening to overlap the tray icon at the moment of the click) rather than a code defect, but confirm this with real evidence rather than assuming it away:

1. Locate the reordered "+" button's real on-screen position (screenshot, same technique as Step 5).
2. Real-click it (`/dev/uinput`) precisely on that button.
3. Immediately screenshot the full screen. Confirm: (a) a new sticker window appeared (via a fresh KWin `workspace.windowList()` query — one more `Sticker <id>` than before), and (b) the tray icon's own menu did NOT open (no `Platform.Menu` popup visible anywhere in the screenshot).
4. Repeat once more with the sticker window positioned somewhere clearly far from the system tray area (drag it there first via a real `startSystemMove()`-driven drag, or just use whichever fixture sticker's default KWin-placed position is furthest from the top-right panel corner) to rule out a coincidental screen-position overlap specifically.

If both real attempts show the correct behavior (new sticker created, no tray menu), record this in your report as "not reproduced" with the screenshots' evidence, and conclude it was very likely a one-off misclick or a coincidental visual overlap during the user's own testing, not a code defect — no further action needed. If you DO reproduce it, stop and investigate the real cause (check for any stray click-forwarding, unexpected shared MouseArea, or z-order issue) before proceeding, and fix it as part of this task.

- [ ] **Step 7: Commit**

```bash
git add src/qml/StickerWindow.qml src/qml/Main.qml
git commit -m "feat: reorder sticker header buttons, display name/fallback next to sticker number"
```

---

## Task 3: Tray menu — simplify note rows to name-only

**Files:**
- Modify: `src/qml/Main.qml`

**Interfaces:**
- Consumes: `Manager.displayName(sticker)` (Task 1).
- Produces: `root.noteList` items change shape from `{id, label}` to `{id, name, label, color}` — Task 4 (the Stickers Panel) consumes the new `name` and `color` fields.
- Removes: `root.noteLabel(text)` (superseded by `Manager.displayName`), the `"kind"` field from `root.noteMenuModel()`'s output, and `root.noteMenuModel()` itself (folded away — see Step 2).

- [ ] **Step 1: Update `refreshNoteList()` to produce `{id, name, label, color}` and drop `noteLabel()`, in `src/qml/Main.qml`**

Change:
```qml
    function refreshNoteList() {
        noteList = Manager.stickers.map(function(s) {
            return { id: s.id, label: noteLabel(s.text) }
        })
        var maxPage = Math.max(0, Math.ceil(noteList.length / notePageSize) - 1)
        if (notePage > maxPage) {
            notePage = maxPage
        }
    }

    function noteLabel(text) {
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].replace(/^#+\s*/, "").trim()
            if (line.length > 0) {
                return line.length > 30 ? line.substring(0, 30) + "…" : line
            }
        }
        return "Sticker"
    }
```
to:
```qml
    function refreshNoteList() {
        noteList = Manager.stickers.map(function(s) {
            return { id: s.id, name: s.name, label: Manager.displayName(s), color: s.color }
        })
        var maxPage = Math.max(0, Math.ceil(noteList.length / notePageSize) - 1)
        if (notePage > maxPage) {
            notePage = maxPage
        }
    }
```

- [ ] **Step 2: Simplify the tray menu's note `Instantiator` to one entry per note, in `src/qml/Main.qml`**

Change:
```qml
    // Flat, per-note "open" + "delete" entries for the tray menu, built as a
    // single list so a single Instantiator can insert them all in one
    // guaranteed-in-order pass. (An earlier version used two separate
    // Instantiators -- one for "Abrir" entries, one for "Eliminar" entries --
    // but real-click verification showed the second-declared Instantiator's
    // onObjectAdded firing (and inserting) before the first-declared one's,
    // which left "Salir" sandwiched between the two groups instead of last.
    // A single Instantiator has no such cross-instantiator ordering to race.)
    function noteMenuModel() {
        var notes = root.visibleNotes()
        var out = []
        for (var i = 0; i < notes.length; i++) {
            out.push({ kind: "open", id: notes[i].id, label: notes[i].label })
            out.push({ kind: "delete", id: notes[i].id, label: notes[i].label })
        }
        return out
    }

    Platform.SystemTrayIcon {
        id: trayIcon
        visible: true
        icon.name: "document-properties"
        tooltip: "KDE Stickers"

        menu: Platform.Menu {
            id: trayMenu
            Platform.MenuItem {
                text: "Nuevo sticker"
                onTriggered: root.createNewSticker(100, 100)
            }
            Platform.MenuSeparator { visible: root.noteList.length > 0 }
            Platform.MenuItem {
                text: "▲ Anteriores"
                visible: root.hasPrevPage()
                onTriggered: root.goPrevPage()
            }
            Instantiator {
                model: root.noteMenuModel()
                delegate: Platform.MenuItem {
                    text: modelData.kind === "open" ? ("Abrir: " + modelData.label) : ("🗑 Eliminar: " + modelData.label)
                    onTriggered: {
                        if (modelData.kind === "open") {
                            root.openOrFocusSticker(modelData.id)
                        } else {
                            root.confirmDeleteSticker(modelData.id, modelData.label)
                        }
                    }
                }
                onObjectAdded: (index, object) => trayMenu.insertItem(index + 3, object)
                onObjectRemoved: (index, object) => trayMenu.removeItem(object)
            }
            Platform.MenuItem {
                text: "▼ Siguientes (reabrir menú)"
                visible: root.hasNextPage()
                onTriggered: root.goNextPage()
            }
            Platform.MenuSeparator { visible: root.noteList.length > 0 }
            Platform.MenuItem {
                text: "Salir"
                onTriggered: Qt.quit()
            }
        }
    }
```
to:
```qml
    Platform.SystemTrayIcon {
        id: trayIcon
        visible: true
        icon.name: "document-properties"
        tooltip: "KDE Stickers"

        menu: Platform.Menu {
            id: trayMenu
            Platform.MenuItem {
                text: "Nuevo sticker"
                onTriggered: root.createNewSticker(100, 100)
            }
            Platform.MenuSeparator { visible: root.noteList.length > 0 }
            Platform.MenuItem {
                text: "▲ Anteriores"
                visible: root.hasPrevPage()
                onTriggered: root.goPrevPage()
            }
            Instantiator {
                model: root.visibleNotes()
                delegate: Platform.MenuItem {
                    text: modelData.label
                    onTriggered: root.openOrFocusSticker(modelData.id)
                }
                onObjectAdded: (index, object) => trayMenu.insertItem(index + 3, object)
                onObjectRemoved: (index, object) => trayMenu.removeItem(object)
            }
            Platform.MenuItem {
                text: "▼ Siguientes (reabrir menú)"
                visible: root.hasNextPage()
                onTriggered: root.goNextPage()
            }
            Platform.MenuSeparator { visible: root.noteList.length > 0 }
            Platform.MenuItem {
                text: "Salir"
                onTriggered: Qt.quit()
            }
        }
    }
```

(`confirmDeleteSticker`/`deleteConfirmDialog` stay exactly as they are in the
file — they're no longer called from the tray menu after this change, but
Task 4 wires them into the new Stickers Panel instead. Leave them in place.)

- [ ] **Step 3: Build**

```bash
cmake --build build
```

Expected: clean build. (`root.noteLabel` and `root.noteMenuModel` no longer
exist — confirm via `grep -rn "noteLabel\|noteMenuModel" src/qml/` that
nothing else in the codebase still references them; if something does,
that's a real gap this step must close, not something to leave dangling.)

- [ ] **Step 4: Verify with real evidence — tray menu shows name-only rows**

```bash
./scripts/test-sticker.sh
pkill -9 -f "build/kde-stickers" 2>/dev/null; sleep 0.5
./build/kde-stickers &
sleep 1.5
```

Identify the tray icon (`qdbus6 org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher.RegisteredStatusNotifierItems`, then `org.freedesktop.DBus.Properties.Get ... Title` to confirm `kde-stickers`), locate it via hover+tooltip screenshot, **real right-click** (the tray menu only opens on right-click — `Platform.SystemTrayIcon` has no `onActivated` handler, confirmed in the previous plan's spike). Screenshot the menu. Expected:
```
Nuevo sticker
──────────
Primer sticker de prueba
Segundo sticker
TODO:
──────────
Salir
```
No "Abrir:"/"🗑 Eliminar:" prefixes, no separate delete rows — one line per note, matching the labels' real derived text.

Real-left-click one note's row. Confirm via a fresh KWin `workspace.windowList()` query that its window is now open (or was refocused if already open) — the click still works via the already-proven `openOrFocusSticker`.

- [ ] **Step 5: Commit**

```bash
git add src/qml/Main.qml
git commit -m "feat: simplify tray menu note rows to name-only, drop inline delete"
```

---

## Task 4: Stickers Panel window

**Files:**
- Create: `src/qml/StickerPanel.qml`
- Modify: `src/qml/Main.qml`
- Modify: `CMakeLists.txt`

**Interfaces:**
- Consumes: `root.noteList` (Task 3's `{id, name, label, color}` shape), `root.openOrFocusSticker(id)`, `root.confirmDeleteSticker(id, label)`, `root.refreshNoteList()` (all already exist).
- Produces: `root.openStickerPanel(): void` — shows/raises the singleton Panel window.

- [ ] **Step 1: Register `StickerPanel.qml` in `CMakeLists.txt`**

The relevant block (lines 16-29) is:
```cmake
qt_add_qml_module(kde-stickers
    URI StickersApp
    VERSION 1.0
    QML_FILES
        src/qml/Main.qml
        src/qml/StickerWindow.qml
        src/qml/MarkdownView.qml
        src/qml/ColorPalette.qml
    SOURCES
        src/filestorage.h
        src/filestorage.cpp
        src/kwinbridge.h
        src/kwinbridge.cpp
)
```
Change the `QML_FILES` list to:
```cmake
    QML_FILES
        src/qml/Main.qml
        src/qml/StickerWindow.qml
        src/qml/MarkdownView.qml
        src/qml/ColorPalette.qml
        src/qml/StickerPanel.qml
```
(Everything else in that block — `SOURCES` and beyond — is unchanged.)

- [ ] **Step 2: Create `src/qml/StickerPanel.qml`**

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "StickerManager.js" as Manager

Window {
    id: panelWindow
    width: 420
    height: 400
    title: "Panel de Stickers"

    property var appRoot: null

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Text {
            text: "Stickers (" + (appRoot ? appRoot.noteList.length : 0) + ")"
            font.bold: true
            font.pixelSize: 14
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: panelWindow.width - 20
                spacing: 4

                Repeater {
                    model: appRoot ? appRoot.noteList : []

                    delegate: RowLayout {
                        id: row
                        Layout.fillWidth: true
                        spacing: 6

                        property bool renaming: false

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: modelData.color
                            border.color: "#555"
                            border.width: 1
                        }

                        Text {
                            text: "#" + modelData.id
                            font.pixelSize: 12
                        }

                        Text {
                            visible: !row.renaming
                            text: modelData.label
                            elide: Text.ElideRight
                            font.pixelSize: 12
                            Layout.fillWidth: true
                        }

                        TextField {
                            id: nameField
                            visible: row.renaming
                            Layout.fillWidth: true
                            text: modelData.name

                            onAccepted: focus = false

                            onActiveFocusChanged: {
                                if (!activeFocus && row.renaming) {
                                    Manager.updateName(modelData.id, text)
                                    row.renaming = false
                                    appRoot.refreshNoteList()
                                }
                            }
                        }

                        Button {
                            text: "Abrir"
                            onClicked: appRoot.openOrFocusSticker(modelData.id)
                        }

                        Button {
                            text: "✎"
                            visible: !row.renaming
                            onClicked: {
                                row.renaming = true
                                nameField.forceActiveFocus()
                                nameField.selectAll()
                            }
                        }

                        Button {
                            text: "🗑"
                            onClicked: appRoot.confirmDeleteSticker(modelData.id, modelData.label)
                        }
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 3: Wire the Panel into `Main.qml`**

Add, inside the root `Item` block (e.g. right after the `deleteConfirmDialog` block):
```qml
    function openStickerPanel() {
        stickerPanel.show()
        stickerPanel.raise()
        stickerPanel.requestActivate()
    }

    StickerPanel {
        id: stickerPanel
        visible: false
        appRoot: root
    }
```

Add a new `Platform.MenuItem` to the tray menu, between the note-list
block and the trailing `Platform.MenuSeparator`/`"Salir"` pair:
```qml
            Platform.MenuItem {
                text: "▼ Siguientes (reabrir menú)"
                visible: root.hasNextPage()
                onTriggered: root.goNextPage()
            }
            Platform.MenuSeparator { visible: root.noteList.length > 0 }
            Platform.MenuItem {
                text: "Panel de Stickers"
                onTriggered: root.openStickerPanel()
            }
            Platform.MenuSeparator {}
            Platform.MenuItem {
                text: "Salir"
                onTriggered: Qt.quit()
            }
```
(This replaces the block ending in `"Salir"` at the end of `trayMenu` — the
`"▲ Anteriores"`/`Instantiator`/`"▼ Siguientes"` lines above it are
unchanged from Task 3; only what comes after `"▼ Siguientes"` changes,
adding the new separator/`"Panel de Stickers"`/separator before `"Salir"`.)

- [ ] **Step 4: Build**

```bash
cmake --build build
```

Expected: clean build. If `StickerPanel.qml` isn't found/registered, revisit Step 1.

- [ ] **Step 5: Verify with real evidence — Panel opens, lists stickers, shows correct color/number/name**

```bash
./scripts/test-sticker.sh
pkill -9 -f "build/kde-stickers" 2>/dev/null; sleep 0.5
./build/kde-stickers &
sleep 1.5
```

Real right-click the tray icon (identify + locate as in prior tasks). Screenshot: confirm "Panel de Stickers" appears between the note rows and "Salir", with a separator on each side. Real-left-click it. Confirm via a KWin `workspace.windowList()` query that a window titled "Panel de Stickers" now exists. Screenshot it: confirm 3 rows, each showing a color swatch matching that sticker's real `color` (cross-check against `cat ~/.stickers/stickers.json | jq`), `#001`/`#002`/`#003`, and the derived label text (since `name` is still empty for the fixture).

- [ ] **Step 6: Verify with real evidence — Abrir, Renombrar, Eliminar from the Panel**

With the Panel still open:

1. Real-click "Abrir" on one row. Confirm via `workspace.windowList()` that sticker's window opened (or was refocused).
2. Real-click "✎" on a different row. Confirm via screenshot that row's label became an editable text field. Real-select-all + type a new name (synthetic keyboard) — e.g. `"Notas del proyecto"`. Real-click elsewhere in the Panel window (to blur the field) or press Enter. Confirm via `cat ~/.stickers/stickers.json | jq` that this sticker's `.name` field now reads `"Notas del proyecto"` for real. Confirm via a fresh screenshot of the Panel that the row now shows `"Notas del proyecto"` instead of the old derived label.
3. Real-click "🗑" on a third row. Confirm a real confirmation dialog appears (reusing `confirmDeleteSticker`/`deleteConfirmDialog`, already proven in the previous plan) showing that row's real label. Real-click "Sí". Confirm via `cat ~/.stickers/stickers.json | jq '.stickers[].id'` that sticker is gone, and via a fresh Panel screenshot that its row is gone too (proving `refreshNoteList()` ran and the Panel's `Repeater` picked up the change, same reactive `noteList` binding the tray menu already uses).

- [ ] **Step 7: Commit**

```bash
git add src/qml/StickerPanel.qml src/qml/Main.qml CMakeLists.txt
git commit -m "feat: add Stickers Panel window (list, open, rename, delete)"
```
