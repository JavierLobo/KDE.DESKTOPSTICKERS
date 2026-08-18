# Sticker Pin, Position Persistence, and Resize Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-sticker pin (opt-in "all virtual desktops"), real position persistence across restarts, and corner-drag resize to the already-shipped KDE Stickers app, replacing the current global KWin rule with dynamically-managed per-window rules.

**Architecture:** Extends the shipped app's existing "let KWin's rule engine do the work" philosophy to per-window granularity. Each `StickerWindow` gets a unique `title` so KWin can address it individually. A new C++ bridge (`KWinBridge`) writes/removes per-sticker KWin window rules (matched by `wmclass` + `title`) at runtime instead of the one static, app-wide rule installed today, and queries each window's real on-screen geometry (which Qt itself cannot report under this Wayland stack — see the 2026-08-17 spec). The riskiest, previously-unverified assumptions (`positionrule=Force` behaving like the already-proven `desktopsrule=Force` when reconfigured live; a working runtime geometry-read mechanism; reliable per-window rule matching by title) are gated behind a spike (Task 5) that is also this plan's only source of `KWinBridge`'s two hardest methods — everything after it builds on what the spike actually proves, not on assumption.

**Tech Stack:** Qt6 (Core, Gui, Qml, Quick, Widgets, **DBus** — new), CMake, QML/JavaScript, KWin window rules (`kwinrulesrc` via `kreadconfig6`/`kwriteconfig6`), KWin scripting (`org.kde.kwin.Scripting` D-Bus interface).

**Spec:** `docs/superpowers/specs/2026-08-18-sticker-pin-position-resize-design.md` (depends on and extends `docs/superpowers/specs/2026-08-17-multidesktop-markdown-stickers-design.md`)

## Global Constraints

- Qt6 only, unversioned QML imports (`import QtQuick`, not `import QtQuick 2.15`).
- No automated test framework. Verification is compile success + real manual runtime evidence (screenshots, KWin ground-truth queries via `workspace.windowList()`, process/file checks) — this project's established, non-negotiable standard. "Should work" / code-reasoning-only is not acceptable evidence for any task in this plan; every prior task in the shipped app found real bugs that only surfaced by actually running the code.
- Single persistence file `~/.stickers/stickers.json`. Schema gains `width` (int), `height` (int), `pinned` (bool) per sticker. Existing records lacking these fields must load with defaults (`width: 300, height: 250, pinned: false`) — do not require users to delete/recreate existing stickers.
- `pinned` defaults to `false` for both newly-created stickers and existing ones missing the field (explicit user decision, 2026-08-18) — more conservative than the shipped app's current behavior (currently *every* sticker is on all desktops, unconditionally).
- Resize minimum ~150×120px (must fit the header and its buttons), no maximum.
- The global KWin rule `kdestickers-alldesktops` (installed by the shipped `scripts/install.sh`) is retired — multi-desktop becomes per-sticker opt-in via pin, not app-wide.
- The spike (Task 5) is deliberately placed at the end of the task sequence, not the start — explicit user decision, 2026-08-18: design and build the lower-risk pieces (data model, resize, rule/title migration) first, gate only position+pin behind the spike, mirroring how the original MVP's Task 1 gated the rest of that plan.
- If the spike fails on any of its three checks, **stop and report to the user** — do not proceed to Tasks 6/7 with an unverified mechanism, matching how the original MVP handled its Task 1 gate.

---

## Task 1: Data model — width, height, pinned fields

**Files:**
- Modify: `src/code/storage.js`
- Modify: `src/qml/StickerManager.js`

**Interfaces:**
- Produces: `Storage.saveSticker(sticker: {id, text, color, x, y, width, height, pinned}): bool` — **signature change** from the shipped `saveSticker(id, text, color, x, y)`. Every caller in `StickerManager.js` is updated in this same task.
- Produces: `Storage.loadAllStickers(): Array<{id, text, color, x, y, width, height, pinned, created, modified}>` — backfills `width: 300, height: 250, pinned: false` for records missing them.
- Produces: `Manager.updateSize(id: string, width: int, height: int): void`.
- Produces: `Manager.updatePinned(id: string, pinned: bool): void`.

- [ ] **Step 1: Rewrite `saveSticker` in `src/code/storage.js` to take a sticker object**

Change:
```js
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
```
to:
```js
function saveSticker(sticker) {
    ensureDir()

    let stickers = loadAllStickers()
    let idx = stickers.findIndex(s => s.id === sticker.id)

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

    if (idx >= 0) {
        record.created = stickers[idx].created
        stickers[idx] = record
    } else {
        stickers.push(record)
    }

    let indexPath = getStickersDir() + "/stickers.json"
    let json = JSON.stringify({stickers: stickers}, null, 2)

    if (!App.FileStorage.writeFile(indexPath, json)) {
        console.error("No se puede escribir:", indexPath)
        return false
    }

    return true
}
```

- [ ] **Step 2: Backfill defaults for old records in `loadAllStickers`**

Change:
```js
    try {
        let json = JSON.parse(data)
        return json.stickers || []
    } catch (e) {
        console.error("Error parsing JSON:", e)
        return []
    }
```
to:
```js
    try {
        let json = JSON.parse(data)
        let stickers = json.stickers || []
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
    } catch (e) {
        console.error("Error parsing JSON:", e)
        return []
    }
```

- [ ] **Step 3: Update `src/qml/StickerManager.js` to match the new `saveSticker` signature, add `updateSize`/`updatePinned`**

Replace the whole file with:

```js
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
```

- [ ] **Step 4: Build and manually verify — regression + new-field write-path + backward compat**

```bash
cmake --build build
./scripts/test-sticker.sh
```
`test-sticker.sh` writes the *old* JSON format (no `width`/`height`/`pinned` fields) — this is exactly the backward-compat case to check.

```bash
./build/kde-stickers &
```
Expected: all 3 stickers appear and behave exactly as before (regression — this task changes no UI). Change sticker `#001`'s color via the existing 🎨 palette (untouched feature, exercises the new `saveSticker` object-param path). Then:
```bash
cat ~/.stickers/stickers.json | jq '.stickers[] | select(.id=="001")'
```
Expected: `#001`'s record now includes `"width": 300, "height": 250, "pinned": false`. Kill the process, relaunch, confirm all 3 stickers (including the two untouched ones, still in old-format-on-disk) still load without error — proving `loadAllStickers`'s backfill works for records never re-saved through the new path.

- [ ] **Step 5: Commit**

```bash
git add src/code/storage.js src/qml/StickerManager.js
git commit -m "feat: add width, height, pinned fields to sticker data model"
```

---

## Task 2: Resize from bottom-right corner

**Files:**
- Modify: `src/qml/StickerWindow.qml`
- Modify: `src/qml/Main.qml`

**Interfaces:**
- Consumes: `Manager.updateSize(id: string, width: int, height: int): void` (Task 1).
- Produces: `StickerWindow` gains initial properties `posWidth: int`, `posHeight: int` (mirroring the existing `posX`/`posY` pattern), consumed by `Main.qml`'s `createStickerWindow`.

- [ ] **Step 1: Add resizable width/height properties to `src/qml/StickerWindow.qml`**

Change:
```qml
    property string stickerId: "001"
    property string stickerText: "Nuevo sticker..."
    property string stickerColor: "#FFD700"
    property int posX: 100
    property int posY: 100
```
to:
```qml
    property string stickerId: "001"
    property string stickerText: "Nuevo sticker..."
    property string stickerColor: "#FFD700"
    property int posX: 100
    property int posY: 100
    property int posWidth: 300
    property int posHeight: 250
```

Change:
```qml
    width: 300
    height: 250
    x: posX
    y: posY
```
to:
```qml
    width: posWidth
    height: posHeight
    x: posX
    y: posY
```

- [ ] **Step 2: Add the resize handle inside `stickerContainer`, after the `ColumnLayout`**

Change:
```qml
    Rectangle {
        id: stickerContainer
        anchors.fill: parent
        color: stickerColor
        radius: 8

        ColumnLayout {
            anchors.fill: parent
            spacing: 0
```
to:
```qml
    Rectangle {
        id: stickerContainer
        anchors.fill: parent
        color: stickerColor
        radius: 8

        MouseArea {
            id: resizeArea
            width: 14
            height: 14
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            z: 10
            cursorShape: Qt.SizeFDiagCursor
            property point pressPos: Qt.point(0, 0)
            property int startWidth: 0
            property int startHeight: 0

            onPressed: (mouse) => {
                pressPos = Qt.point(mouse.x, mouse.y)
                startWidth = mainWindow.width
                startHeight = mainWindow.height
            }
            onPositionChanged: (mouse) => {
                if (!pressed) return
                var newWidth = startWidth + (mouse.x - pressPos.x)
                var newHeight = startHeight + (mouse.y - pressPos.y)
                mainWindow.width = Math.max(150, newWidth)
                mainWindow.height = Math.max(120, newHeight)
            }
            onReleased: {
                Manager.updateSize(stickerId, mainWindow.width, mainWindow.height)
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0
```

- [ ] **Step 3: Pass initial size in `src/qml/Main.qml`**

Change:
```qml
    function createStickerWindow(sticker) {
        var w = stickerWindowComponent.createObject(root, {
            stickerId: sticker.id,
            stickerText: sticker.text,
            stickerColor: sticker.color,
            posX: sticker.x,
            posY: sticker.y,
            appRoot: root
        })
```
to:
```qml
    function createStickerWindow(sticker) {
        var w = stickerWindowComponent.createObject(root, {
            stickerId: sticker.id,
            stickerText: sticker.text,
            stickerColor: sticker.color,
            posX: sticker.x,
            posY: sticker.y,
            posWidth: sticker.width,
            posHeight: sticker.height,
            appRoot: root
        })
```

- [ ] **Step 4: Build and manually verify resizing actually works on screen**

```bash
cmake --build build
./scripts/test-sticker.sh
./build/kde-stickers &
```
Drag from the bottom-right corner of a sticker (real synthetic input — reuse this project's established `/dev/uinput`+`evdev` tooling, or genuine mouse input if available). Confirm via screenshot and/or a KWin `workspace.windowList()` geometry query (ground truth, not just the QML property) that the window's on-screen size actually changed — resizing a client-owned Wayland top-level is expected to work normally (unlike position), but verify it, don't assume it. Try shrinking below 150×120 and confirm it clamps there. Release, then:
```bash
cat ~/.stickers/stickers.json | jq '.stickers[] | select(.id=="001")'
```
Expected: `width`/`height` reflect the new size. Kill the process, relaunch, confirm the sticker reopens at the persisted size.

- [ ] **Step 5: Commit**

```bash
git add src/qml/StickerWindow.qml src/qml/Main.qml
git commit -m "feat: add resize handle at bottom-right corner"
```

---

## Task 3: Retire the global KWin rule, give each window a unique title

**Files:**
- Modify: `scripts/install.sh`
- Modify: `src/qml/StickerWindow.qml`

**Interfaces:**
- Produces: each `StickerWindow`'s `title` property is `"Sticker " + stickerId` (e.g. `"Sticker 001"`) — unique per window, consumed by Tasks 5-7 for KWin rule matching.

- [ ] **Step 1: Give each `StickerWindow` a unique title**

Change:
```qml
    width: posWidth
    height: posHeight
    x: posX
    y: posY
    visible: true
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
```
to:
```qml
    width: posWidth
    height: posHeight
    x: posX
    y: posY
    visible: true
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    // Unique per window so KWin window rules can address one specific
    // sticker (matched by wmclass + title together) instead of every
    // window this app creates — needed now that "all desktops" becomes
    // a per-sticker opt-in (pin) instead of an app-wide static rule.
    title: "Sticker " + stickerId
```

- [ ] **Step 2: Remove the global rule installation from `scripts/install.sh`, add a one-time migration that retires it if present**

Change:
```bash
echo "📦 Registrando regla de KWin (todos los escritorios)"
EXISTING_RULES="$(kreadconfig6 --file kwinrulesrc --group General --key rules 2>/dev/null || true)"
if [[ ",$EXISTING_RULES," != *",$KWIN_RULE_ID,"* ]]; then
    NEW_RULES="${EXISTING_RULES:+$EXISTING_RULES,}$KWIN_RULE_ID"
    kwriteconfig6 --file kwinrulesrc --group General --key rules "$NEW_RULES"
fi
kwriteconfig6 --file kwinrulesrc --group "$KWIN_RULE_ID" --key wmclass "org.kde.stickers"
kwriteconfig6 --file kwinrulesrc --group "$KWIN_RULE_ID" --key wmclassmatch 2
kwriteconfig6 --file kwinrulesrc --group "$KWIN_RULE_ID" --key wmclasscomplete false
kwriteconfig6 --file kwinrulesrc --group "$KWIN_RULE_ID" --key types 1
kwriteconfig6 --file kwinrulesrc --group "$KWIN_RULE_ID" --key desktops ""
kwriteconfig6 --file kwinrulesrc --group "$KWIN_RULE_ID" --key desktopsrule 2
if ! qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null; then
    echo "⚠ No se pudo recargar KWin en caliente; la regla se aplicará en tu próxima sesión"
fi
```
to:
```bash
echo "📦 Migrando: retirando la regla global de todos-los-escritorios (ahora es por sticker, vía pin)"
EXISTING_RULES="$(kreadconfig6 --file kwinrulesrc --group General --key rules 2>/dev/null || true)"
if [[ ",$EXISTING_RULES," == *",$KWIN_RULE_ID,"* ]]; then
    NEW_RULES="$(echo ",$EXISTING_RULES," | sed "s/,$KWIN_RULE_ID,/,/" | sed 's/^,//;s/,$//')"
    kwriteconfig6 --file kwinrulesrc --group General --key rules "$NEW_RULES"
    if ! qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null; then
        echo "⚠ No se pudo recargar KWin en caliente tras retirar la regla global; se aplicará en tu próxima sesión"
    fi
    echo "✓ Regla global '$KWIN_RULE_ID' retirada de la lista activa"
fi
```

(`KWIN_RULE_ID="kdestickers-alldesktops"` at the top of the file already exists — leave that variable declaration in place, it's still used by this migration block.)

- [ ] **Step 3: Build and manually verify on this dev machine (which currently has the global rule active from the original MVP)**

```bash
cmake --build build
```
Confirm the rule is currently present:
```bash
kreadconfig6 --file kwinrulesrc --group General --key rules
```
Expected: includes `kdestickers-alldesktops`. Now run:
```bash
./scripts/install.sh
```
Expected: prints the migration message, and:
```bash
kreadconfig6 --file kwinrulesrc --group General --key rules
```
no longer includes `kdestickers-alldesktops` (other unrelated rule ids, if any, are preserved). Run `install.sh` a second time — expected: no migration message this time (already removed, idempotent no-op).

Then:
```bash
./scripts/test-sticker.sh
./build/kde-stickers &
```
Use a KWin scripting query (`workspace.windowList()`, same method used throughout this project) to confirm each of the 3 sticker windows now has a distinct `caption` matching `"Sticker 001"` / `"Sticker 002"` / `"Sticker 003"`.

- [ ] **Step 4: Commit**

```bash
git add scripts/install.sh src/qml/StickerWindow.qml
git commit -m "feat: retire global KWin rule, give each sticker a unique window title"
```

---

## Task 4: `KWinBridge` C++ component — skeleton and rule-list management

**Files:**
- Create: `src/kwinbridge.h`
- Create: `src/kwinbridge.cpp`
- Modify: `src/main.cpp`
- Modify: `CMakeLists.txt`
- Modify: `src/qml/StickerManager.js`

**Interfaces:**
- Produces: QML singleton `KWinBridge` under module URI `Stickers.KWin` (import as `.import Stickers.KWin 1.0 as KWin`, mirroring `FileStorage`'s `Stickers.Storage` pattern — same reason: avoiding a cyclic self-import from `StickerManager.js`, which is itself part of the `StickersApp` module).
- Produces: `Q_INVOKABLE void KWinBridge::removeRules(const QString &stickerId) const` — removes sticker id's rule group id from `kwinrulesrc`'s `[General] rules=` list (safe no-op if absent) and reconfigures KWin.
- Produces (private, reused by Tasks 6/7): a shared "add/remove a rule id from the `[General] rules=` comma-list" helper pattern, matching `scripts/install.sh`'s already-proven approach, implemented via `QProcess` calls to `kreadconfig6`/`kwriteconfig6`/`qdbus6` rather than a new ini-parsing dependency.

- [ ] **Step 1: Write `src/kwinbridge.h`**

```cpp
#pragma once

#include <QObject>
#include <QString>

// C++ bridge for per-window KWin window-rule management at runtime.
//
// Mirrors, in C++, the same kwriteconfig6/kreadconfig6/qdbus6 shell-out
// pattern already proven in scripts/install.sh for the (now retired) global
// multi-desktop rule -- applied per-window here instead, matched by a
// window's unique title (see StickerWindow.qml's "title" property, Task 3)
// in addition to the app's shared wmclass, since a KWin rule otherwise
// can't distinguish between this app's own multiple windows.
class KWinBridge : public QObject
{
    Q_OBJECT

public:
    explicit KWinBridge(QObject *parent = nullptr);

    // Removes any KWin rule associated with a sticker id from the active
    // rules list (both the "all desktops" pin rule and the position rule,
    // added in later tasks, share one rule group id per sticker:
    // "kdestickers-sticker-<id>"). Safe to call even if no rule exists for
    // that id -- a no-op in that case. Called when a sticker is deleted.
    Q_INVOKABLE void removeRules(const QString &stickerId) const;

protected:
    // Exposed protected (not private) so later tasks in this same class
    // can add setPinned()/updatePositionRule() methods that reuse these
    // without duplicating the rules-list edit logic.
    static QString ruleGroupName(const QString &stickerId);
    void removeRuleIdFromList(const QString &ruleId) const;
    void addRuleIdToList(const QString &ruleId) const;
    bool reconfigureKWin() const;
};
```

- [ ] **Step 2: Write `src/kwinbridge.cpp`**

```cpp
#include "kwinbridge.h"

#include <QProcess>
#include <QStringList>

KWinBridge::KWinBridge(QObject *parent) : QObject(parent) {}

QString KWinBridge::ruleGroupName(const QString &stickerId)
{
    return QStringLiteral("kdestickers-sticker-%1").arg(stickerId);
}

void KWinBridge::removeRuleIdFromList(const QString &ruleId) const
{
    QProcess readProcess;
    readProcess.start(QStringLiteral("kreadconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), QStringLiteral("General"),
         QStringLiteral("--key"), QStringLiteral("rules")});
    readProcess.waitForFinished();
    const QString existing = QString::fromUtf8(readProcess.readAllStandardOutput()).trimmed();

    QStringList ids = existing.split(QLatin1Char(','), Qt::SkipEmptyParts);
    ids.removeAll(ruleId);
    const QString updated = ids.join(QLatin1Char(','));

    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), QStringLiteral("General"),
         QStringLiteral("--key"), QStringLiteral("rules"), updated});
}

void KWinBridge::addRuleIdToList(const QString &ruleId) const
{
    QProcess readProcess;
    readProcess.start(QStringLiteral("kreadconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), QStringLiteral("General"),
         QStringLiteral("--key"), QStringLiteral("rules")});
    readProcess.waitForFinished();
    const QString existing = QString::fromUtf8(readProcess.readAllStandardOutput()).trimmed();

    QStringList ids = existing.split(QLatin1Char(','), Qt::SkipEmptyParts);
    if (!ids.contains(ruleId)) {
        ids.append(ruleId);
    }
    const QString updated = ids.join(QLatin1Char(','));

    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), QStringLiteral("General"),
         QStringLiteral("--key"), QStringLiteral("rules"), updated});
}

bool KWinBridge::reconfigureKWin() const
{
    return QProcess::execute(QStringLiteral("qdbus6"),
        {QStringLiteral("org.kde.KWin"), QStringLiteral("/KWin"),
         QStringLiteral("org.kde.KWin.reconfigure")}) == 0;
}

void KWinBridge::removeRules(const QString &stickerId) const
{
    removeRuleIdFromList(ruleGroupName(stickerId));
    reconfigureKWin();
}
```

- [ ] **Step 3: Register `KWinBridge` in `src/main.cpp`**

Change:
```cpp
#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlEngine>

#include "filestorage.h"
```
to:
```cpp
#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlEngine>

#include "filestorage.h"
#include "kwinbridge.h"
```

Change:
```cpp
    qmlRegisterSingletonType<FileStorage>(
        "Stickers.Storage", 1, 0, "FileStorage",
        [](QQmlEngine *, QJSEngine *) -> QObject * { return new FileStorage(); });
```
to:
```cpp
    qmlRegisterSingletonType<FileStorage>(
        "Stickers.Storage", 1, 0, "FileStorage",
        [](QQmlEngine *, QJSEngine *) -> QObject * { return new FileStorage(); });

    qmlRegisterSingletonType<KWinBridge>(
        "Stickers.KWin", 1, 0, "KWinBridge",
        [](QQmlEngine *, QJSEngine *) -> QObject * { return new KWinBridge(); });
```

- [ ] **Step 4: Add the new files to `CMakeLists.txt`**

Change:
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
)
```
to:
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

- [ ] **Step 5: Wire `removeRules` into sticker deletion in `src/qml/StickerManager.js`**

Change:
```js
.pragma library
.import "../code/storage.js" as Storage
```
to:
```js
.pragma library
.import "../code/storage.js" as Storage
.import Stickers.KWin 1.0 as KWin
```

Change:
```js
function removeSticker(id) {
    stickers = stickers.filter(function(s) { return s.id !== id })
    Storage.deleteSticker(id)
}
```
to:
```js
function removeSticker(id) {
    stickers = stickers.filter(function(s) { return s.id !== id })
    Storage.deleteSticker(id)
    KWin.KWinBridge.removeRules(id)
}
```

- [ ] **Step 6: Build and manually verify `removeRules` actually edits the rules list**

```bash
cmake --build build
```
Manually seed a fake rule entry for a real sticker id before testing (this dev machine has stickers `001`/`002`/`003` from `test-sticker.sh` — use one of those ids):
```bash
./scripts/test-sticker.sh
EXISTING="$(kreadconfig6 --file kwinrulesrc --group General --key rules)"
kwriteconfig6 --file kwinrulesrc --group General --key rules "${EXISTING:+$EXISTING,}kdestickers-sticker-002"
kreadconfig6 --file kwinrulesrc --group General --key rules
```
Expected: the list now includes `kdestickers-sticker-002`. Now run the app and delete sticker `#002` via its ✕ button (real click, this project's established `/dev/uinput` input-simulation tooling or genuine input):
```bash
./build/kde-stickers &
```
After deleting `#002`:
```bash
kreadconfig6 --file kwinrulesrc --group General --key rules
```
Expected: `kdestickers-sticker-002` is gone; any other pre-existing entries are untouched. Also confirm via `journalctl --user` that no errors occurred, and confirm `~/.stickers/stickers.json` no longer contains `002` (existing delete behavior, unaffected by this change).

- [ ] **Step 7: Commit**

```bash
git add src/kwinbridge.h src/kwinbridge.cpp src/main.cpp CMakeLists.txt src/qml/StickerManager.js
git commit -m "feat: add KWinBridge C++ component, wire rule cleanup into sticker deletion"
```

---

## Task 5: SPIKE — verify per-window live rule application, build real geometry reading

**This is the highest-risk task in this plan** (per spec: gates Tasks 6 and 7). It both investigates and — if the investigation succeeds — delivers the two hardest pieces of `KWinBridge` as real, tested code, not throwaway. If any of the three checks below fails, **stop and report to the user before proceeding to Task 6** — do not build the pin/position features on an unverified mechanism.

**Files:**
- Modify: `src/kwinbridge.h`
- Modify: `src/kwinbridge.cpp`
- Modify: `CMakeLists.txt` (add `Qt6::DBus`)

**Interfaces:**
- Produces (if successful): `Q_INVOKABLE QPointF KWinBridge::queryRealGeometry(const QString &windowTitle)` — returns the window's real on-screen position, or `QPointF(-1, -1)` on failure/timeout.
- Produces (if successful): confirmation that `positionrule=Force`, applied live via `reconfigure` to an already-mapped window matched by `wmclass`+`title`, actually moves it — the load-bearing assumption Task 7 depends on.
- Produces (if successful): confirmation that `wmclass`+`title` matching reliably scopes a rule to exactly one window among several sharing the same `wmclass` — the load-bearing assumption Tasks 6 and 7 both depend on.

### Part A: Does `wmclass`+`title` matching scope a live-reconfigured rule to exactly one window?

- [ ] **Step 1: Build and run 3 sticker windows with distinct titles (already true as of Task 3)**

```bash
cmake --build build
./scripts/test-sticker.sh
./build/kde-stickers &
```
Confirm via `workspace.windowList()` (KWin scripting, same method used throughout this project) that all 3 windows currently report `desktop: []`-style "not forced" state (none pinned yet — pin doesn't exist until Task 6) and have distinct captions `"Sticker 001"` / `"Sticker 002"` / `"Sticker 003"`.

- [ ] **Step 2: Write a rule matching wmclass+title for ONE sticker, reconfigure live, check ONLY that window changed**

```bash
kwriteconfig6 --file kwinrulesrc --group General --key rules "spike-test-rule"
kwriteconfig6 --file kwinrulesrc --group spike-test-rule --key wmclass "org.kde.stickers"
kwriteconfig6 --file kwinrulesrc --group spike-test-rule --key wmclassmatch 2
kwriteconfig6 --file kwinrulesrc --group spike-test-rule --key wmclasscomplete false
kwriteconfig6 --file kwinrulesrc --group spike-test-rule --key title "Sticker 002"
kwriteconfig6 --file kwinrulesrc --group spike-test-rule --key titlematch 2
kwriteconfig6 --file kwinrulesrc --group spike-test-rule --key types 1
kwriteconfig6 --file kwinrulesrc --group spike-test-rule --key desktops ""
kwriteconfig6 --file kwinrulesrc --group spike-test-rule --key desktopsrule 2
qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure
```
Query `workspace.windowList()` again. **Expected:** only the window titled `"Sticker 002"` now reports the all-desktops state; `"Sticker 001"` and `"Sticker 003"` are unchanged. Confirm by switching virtual desktops and checking visibility, same ground-truth method as the original MVP's Task 1.

**If ALL THREE windows became pinned (title match not actually scoping anything, `wmclass` alone doing the work):** the `title`/`titlematch` keys aren't behaving as expected. Try alternate key names/values (check `kwin --replace`'s own rule editor UI via `kcmshell6 kwinrules` if available for the exact key names KWin 6.7 actually uses, or grep installed KWin headers/docs for the `RuleBook`/`Rules` class's property list) before concluding this doesn't work at all.

**If NEITHER worked (rule had no effect on any window):** re-verify against the exact key set that worked for the original MVP's global rule (Task 1's report, `wmclass`/`wmclassmatch`/`wmclasscomplete`/`types`/`desktops`/`desktopsrule`) — confirm nothing about adding `title`/`titlematch` broke the baseline.

Clean up the test rule before moving on:
```bash
kwriteconfig6 --file kwinrulesrc --group General --key rules ""
qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure
```

### Part B: Does `positionrule=Force` behave the same way live?

- [ ] **Step 3: Same setup, testing position instead of desktops**

```bash
kwriteconfig6 --file kwinrulesrc --group General --key rules "spike-test-rule"
kwriteconfig6 --file kwinrulesrc --group spike-test-rule --key wmclass "org.kde.stickers"
kwriteconfig6 --file kwinrulesrc --group spike-test-rule --key wmclassmatch 2
kwriteconfig6 --file kwinrulesrc --group spike-test-rule --key wmclasscomplete false
kwriteconfig6 --file kwinrulesrc --group spike-test-rule --key title "Sticker 002"
kwriteconfig6 --file kwinrulesrc --group spike-test-rule --key titlematch 2
kwriteconfig6 --file kwinrulesrc --group spike-test-rule --key types 1
kwriteconfig6 --file kwinrulesrc --group spike-test-rule --key position "600,600"
kwriteconfig6 --file kwinrulesrc --group spike-test-rule --key positionrule 2
qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure
```
Query `workspace.windowList()`'s geometry for `"Sticker 002"` before and after. **Expected:** its `x`/`y` become `600`/`600` (or close, accounting for any frame/decoration offset) without recreating the window.

**If the position does NOT change:** `positionrule=Force` does not apply live the way `desktopsrule=Force` does (it may only apply at window-map time). This is a real, load-bearing finding — try once more by fully closing and relaunching the sticker (does the rule apply at *creation* time, just not live?). If it only works at creation time, that's still usable for Task 7 (write the rule, and the position takes effect on the *next* launch — which is exactly what's needed for "restore position on restart"; it doesn't need to move the window instantly mid-session). Record which behavior was actually observed — Task 7's design depends on knowing this precisely.

**If it doesn't work at all, even at creation time:** this is the STOP condition. Report to the user with the evidence gathered; do not proceed to Task 7 (position) — Task 6 (pin) can still proceed independently if Part A succeeded, since it doesn't depend on this result.

Clean up the test rule (same as Step 2) before moving on.

### Part C: Build a real geometry-reading mechanism

- [ ] **Step 4: Add the D-Bus service infrastructure to `KWinBridge`**

This is the primary candidate mechanism: the app exposes its own D-Bus method; a KWin script (loaded/run via `org.kde.kwin.Scripting`) finds the target window and calls back into the app with its real geometry, turning an inherently async KWin-script callback into a synchronous-looking Qt call via a local blocking event loop with a timeout. This exact mechanism has NOT been tried anywhere in this project before — unlike the rule-writing approach (which reuses proven techniques), this needs real, careful empirical verification of each piece. Test incrementally; don't assume any single piece works until you've checked it.

Change (in `src/kwinbridge.h` — this inserts the new declarations into the existing `public:` block, ahead of the already-present `protected:` section, so there is only ever one `public:` block in the whole class; Task 6 and Task 7 append further methods to this same block later):
```cpp
    Q_INVOKABLE void removeRules(const QString &stickerId) const;

protected:
```
to:
```cpp
    Q_INVOKABLE void removeRules(const QString &stickerId) const;
    Q_INVOKABLE QPointF queryRealGeometry(const QString &windowTitle);

    // Exposed for the KWin script (via callDBus) to call back into. Not
    // meant to be called directly from QML.
    Q_SCRIPTABLE void receiveGeometry(const QString &windowTitle, double x, double y);

signals:
    void geometryReported(const QString &windowTitle, double x, double y);

protected:
```

Change (also in `src/kwinbridge.h`):
```cpp
#pragma once

#include <QObject>
#include <QString>
```
to:
```cpp
#pragma once

#include <QObject>
#include <QPointF>
#include <QString>
```

Add to `src/kwinbridge.cpp`:
```cpp
#include <QDBusConnection>
#include <QEventLoop>
#include <QTemporaryFile>
#include <QTextStream>
#include <QTimer>
```

```cpp
void KWinBridge::receiveGeometry(const QString &windowTitle, double x, double y)
{
    emit geometryReported(windowTitle, x, y);
}

QPointF KWinBridge::queryRealGeometry(const QString &windowTitle)
{
    QPointF result(-1, -1);
    bool received = false;

    QEventLoop loop;
    QTimer timeoutTimer;
    timeoutTimer.setSingleShot(true);
    QObject::connect(&timeoutTimer, &QTimer::timeout, &loop, &QEventLoop::quit);

    QMetaObject::Connection conn = QObject::connect(this, &KWinBridge::geometryReported,
        this, [&](const QString &title, double x, double y) {
            if (title == windowTitle) {
                result = QPointF(x, y);
                received = true;
                loop.quit();
            }
        });

    QTemporaryFile scriptFile(QStringLiteral("/tmp/kde-stickers-geom-XXXXXX.js"));
    scriptFile.setAutoRemove(false); // removed manually below, after KWin has read it
    if (scriptFile.open()) {
        QTextStream stream(&scriptFile);
        stream << QStringLiteral(
            "var wins = workspace.windowList();\n"
            "for (var i = 0; i < wins.length; i++) {\n"
            "    if (wins[i].caption === \"%1\") {\n"
            "        var g = wins[i].frameGeometry;\n"
            "        callDBus(\"org.kde.stickers\", \"/KWinBridge\", "
            "\"org.kde.stickers.KWinBridge\", \"receiveGeometry\", "
            "\"%1\", g.x, g.y);\n"
            "        break;\n"
            "    }\n"
            "}\n"
        ).arg(windowTitle);
        scriptFile.close();

        QProcess loadProcess;
        loadProcess.start(QStringLiteral("qdbus6"),
            {QStringLiteral("org.kde.KWin"), QStringLiteral("/Scripting"),
             QStringLiteral("org.kde.kwin.Scripting.loadScript"),
             scriptFile.fileName(), QStringLiteral("kde-stickers-geom-query")});
        loadProcess.waitForFinished();
        const QString scriptPath = QString::fromUtf8(loadProcess.readAllStandardOutput()).trimmed();

        if (!scriptPath.isEmpty()) {
            QProcess::execute(QStringLiteral("qdbus6"),
                {QStringLiteral("org.kde.KWin"), scriptPath,
                 QStringLiteral("org.kde.kwin.Script.run")});
        }
    }

    timeoutTimer.start(2000);
    loop.exec();
    QObject::disconnect(conn);
    QFile::remove(scriptFile.fileName());

    return received ? result : QPointF(-1, -1);
}
```

Register the D-Bus service in `src/main.cpp`. Change:
```cpp
#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlEngine>

#include "filestorage.h"
#include "kwinbridge.h"
```
to:
```cpp
#include <QApplication>
#include <QDBusConnection>
#include <QQmlApplicationEngine>
#include <QQmlEngine>

#include "filestorage.h"
#include "kwinbridge.h"
```

Change:
```cpp
    qmlRegisterSingletonType<KWinBridge>(
        "Stickers.KWin", 1, 0, "KWinBridge",
        [](QQmlEngine *, QJSEngine *) -> QObject * { return new KWinBridge(); });
```
to:
```cpp
    auto *kwinBridge = new KWinBridge();
    QDBusConnection::sessionBus().registerService(QStringLiteral("org.kde.stickers"));
    QDBusConnection::sessionBus().registerObject(
        QStringLiteral("/KWinBridge"), QStringLiteral("org.kde.stickers.KWinBridge"),
        kwinBridge, QDBusConnection::ExportScriptableSlots);

    qmlRegisterSingletonType<KWinBridge>(
        "Stickers.KWin", 1, 0, "KWinBridge",
        [kwinBridge](QQmlEngine *, QJSEngine *) -> QObject * {
            QQmlEngine::setObjectOwnership(kwinBridge, QQmlEngine::CppOwnership);
            return kwinBridge;
        });
```

Add `Qt6::DBus` to `CMakeLists.txt`. Change:
```cmake
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Widgets)
```
to:
```cmake
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Widgets DBus)
```
Change:
```cmake
target_link_libraries(kde-stickers
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Quick
        Qt6::Widgets
)
```
to:
```cmake
target_link_libraries(kde-stickers
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Quick
        Qt6::Widgets
        Qt6::DBus
)
```

- [ ] **Step 5: Verify each piece incrementally, adapt as needed**

Build first:
```bash
cmake --build build
```
If `callDBus`, `loadScript`'s exact signature, `frameGeometry`, or any other assumed KWin scripting API detail turns out wrong, this is exactly what a spike is for — inspect what's actually available (e.g. grep installed KWin scripting API type definitions/headers, or existing community KWin scripts on the system if any exist, for the real property/function names) and adapt the script text and/or the C++ side accordingly. Do not silently give up after one failed attempt; do not silently paper over a failure with a fabricated "it works" claim either.

Verify the app's own D-Bus service is reachable at all, independent of KWin:
```bash
./scripts/test-sticker.sh
./build/kde-stickers &
qdbus6 org.kde.stickers /KWinBridge org.kde.stickers.KWinBridge.receiveGeometry "test" 100 200
```
Check `journalctl --user` for the app's own debug output (temporarily add a `qDebug()` inside `receiveGeometry` if needed to confirm it's actually being invoked) — this isolates "does D-Bus reach the app" from "does the KWin script side work," so a failure in one doesn't get misdiagnosed as the other.

Then test the full path — call `queryRealGeometry` for a real sticker window (e.g. temporarily wire a throwaway QML button or `Component.onCompleted` call to invoke `KWin.KWinBridge.queryRealGeometry("Sticker 002")` and log the result) and confirm it returns real, correct coordinates matching what `workspace.windowList()`'s ground truth reports for that window — not `(-1, -1)` (timeout/failure) and not stale/wrong values.

**If the D-Bus-callback approach cannot be made to work after real, honest troubleshooting:** fall back to the log-scraping technique already proven throughout this project (Tasks 1-9 of the original MVP): load and run the same kind of KWin script via `org.kde.kwin.Scripting`, have it `console.log()` the geometry instead of calling back via D-Bus, then read the result from `journalctl --user` filtered to the relevant timeframe/PID, parsing the logged value. Slower and uglier, but known to work. Rewrite `queryRealGeometry` to use this approach instead if needed, and remove the unused D-Bus service registration/`receiveGeometry` method if abandoning that path entirely.

- [ ] **Step 6: Clean up any temporary test wiring, then commit**

Remove any throwaway `Component.onCompleted`/button test calls added purely for Step 5's verification — they are not part of this task's deliverable.

```bash
git add src/kwinbridge.h src/kwinbridge.cpp src/main.cpp CMakeLists.txt
git commit -m "spike: verify per-window KWin rule matching, build real geometry query"
```

Record in the commit message body (or your task report) exactly what was verified for Parts A, B, and C, and which geometry-reading mechanism ended up shipping — Tasks 6 and 7 need this.

---

## Task 6: Pin button — per-sticker "all desktops"

**Files:**
- Modify: `src/qml/StickerWindow.qml`
- Modify: `src/qml/Main.qml`

**Interfaces:**
- Consumes: `Manager.updatePinned(id: string, pinned: bool): void` (Task 1).
- Consumes: `KWinBridge` rule-list helpers (Task 4/5) — this task adds `setPinned` using them.
- Produces: `Q_INVOKABLE void KWinBridge::setPinned(const QString &stickerId, const QString &windowTitle, bool pinned) const`.

- [ ] **Step 1: Add `setPinned` (and its `unpinLiveWindow` helper) to `KWinBridge`**

> **Revision note (post-Task-5-spike):** the spike confirmed `title`+`wmclass` matching with `desktopsrule=Force` genuinely scopes to one window and applies live exactly as needed for pin — that part of this task's original draft was right. But it also found two things the original draft got wrong, both reflected below: (1) `titlematch` must be `1` (ExactMatch), not `2` (SubstringMatch — `"Sticker 002"` would incorrectly match a hypothetical `"Sticker 0021"`); (2) removing the rule does **not** un-pin a window that's currently pinned — `Force` sets state that persists once the rule is gone, so un-pinning needs an explicit second step that live-edits the window itself, and that step must run **after** the rule removal has fully taken effect (a still-active rule silently re-forces the window back to pinned on the next desktop-state write otherwise — this would look exactly like a flaky KWin bug, not an ordering bug, if hit). Full detail in the spike's report if you want the underlying evidence.

Add to `src/kwinbridge.h`, in the `public:` section:
```cpp
    Q_INVOKABLE void setPinned(const QString &stickerId, const QString &windowTitle, bool pinned) const;
```

Add to `src/kwinbridge.h`, in the `protected:` section, alongside the other helpers:
```cpp
    void unpinLiveWindow(const QString &windowTitle) const;
```

Add to `src/kwinbridge.cpp`:
```cpp
void KWinBridge::unpinLiveWindow(const QString &windowTitle) const
{
    // Fire-and-forget: unlike queryRealGeometry, this script doesn't call
    // back into the app (no callDBus, no return value needed), so there's
    // no risk of the callback deadlocking against a blocked event loop --
    // a plain blocking QProcess::execute for both run() and the unload
    // afterward is safe here.
    QTemporaryFile scriptFile(QDir::tempPath() + QStringLiteral("/kde-stickers-unpin-XXXXXX.js"));
    if (!scriptFile.open()) {
        return;
    }
    QTextStream stream(&scriptFile);
    stream << QStringLiteral(
        "var wins = workspace.windowList();\n"
        "for (var i = 0; i < wins.length; i++) {\n"
        "    if (wins[i].caption === \"%1\") {\n"
        "        wins[i].onAllDesktops = false;\n"
        "        break;\n"
        "    }\n"
        "}\n"
    ).arg(jsQuote(windowTitle));
    stream.flush();
    scriptFile.close();

    const QString pluginName = QStringLiteral("kde-stickers-unpin");

    // Same unload-before-load pattern as queryRealGeometry, same reason:
    // KWin refuses loadScript() under an already-registered plugin name.
    QProcess::execute(QStringLiteral("qdbus6"),
        {QStringLiteral("org.kde.KWin"), QStringLiteral("/Scripting"),
         QStringLiteral("org.kde.kwin.Scripting.unloadScript"), pluginName});

    QProcess loadProcess;
    loadProcess.start(QStringLiteral("qdbus6"),
        {QStringLiteral("org.kde.KWin"), QStringLiteral("/Scripting"),
         QStringLiteral("org.kde.kwin.Scripting.loadScript"),
         scriptFile.fileName(), pluginName});
    loadProcess.waitForFinished();
    const QString scriptId = QString::fromUtf8(loadProcess.readAllStandardOutput()).trimmed();

    bool idOk = false;
    const int id = scriptId.toInt(&idOk);
    if (idOk && id >= 0) {
        QProcess::execute(QStringLiteral("qdbus6"),
            {QStringLiteral("org.kde.KWin"),
             QStringLiteral("/Scripting/Script%1").arg(id),
             QStringLiteral("org.kde.kwin.Script.run")});
        QProcess::execute(QStringLiteral("qdbus6"),
            {QStringLiteral("org.kde.KWin"), QStringLiteral("/Scripting"),
             QStringLiteral("org.kde.kwin.Scripting.unloadScript"), pluginName});
    }
}

void KWinBridge::setPinned(const QString &stickerId, const QString &windowTitle, bool pinned) const
{
    const QString ruleId = ruleGroupName(stickerId);

    if (!pinned) {
        // Order matters: remove the rule and let reconfigure fully land
        // BEFORE touching the live window, or the still-active Force rule
        // silently re-pins it out from under the script (Task 5 finding).
        removeRuleIdFromList(ruleId);
        reconfigureKWin();
        unpinLiveWindow(windowTitle);
        return;
    }

    addRuleIdToList(ruleId);
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("wmclass"), QStringLiteral("org.kde.stickers")});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("wmclassmatch"), QStringLiteral("2")});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("wmclasscomplete"), QStringLiteral("false")});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("title"), windowTitle});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("titlematch"), QStringLiteral("1")});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("types"), QStringLiteral("1")});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("desktops"), QStringLiteral("")});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("desktopsrule"), QStringLiteral("2")});

    reconfigureKWin();
}
```

`jsQuote` is the static escaping helper Task 5 already added at the top of `src/kwinbridge.cpp` (above `queryRealGeometry`) — reuse it as-is, don't redefine it.

This new mechanism (fire-and-forget KWin script execution with no D-Bus callback) hasn't been used anywhere in this project before `unpinLiveWindow` — the reasoning above is sound, but verify it empirically in Step 4 rather than trusting it blindly, consistent with how every other task in this plan has treated its own claims.

- [ ] **Step 2: Add the pin property and button to `src/qml/StickerWindow.qml`**

Add the import near the top, alongside the existing ones:
```qml
import "StickerManager.js" as Manager
```
becomes:
```qml
import "StickerManager.js" as Manager
import Stickers.KWin as KWin
```

Add a property alongside `posWidth`/`posHeight`:
```qml
    property int posWidth: 300
    property int posHeight: 250
```
becomes:
```qml
    property int posWidth: 300
    property int posHeight: 250
    property bool stickerPinned: false
```

Add the pin button to the header, before the "+" button:
```qml
                    Button {
                        text: "+"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: mainWindow.appRoot.createNewSticker(mainWindow.x, mainWindow.y)
                    }
```
becomes:
```qml
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
```

- [ ] **Step 3: Pass initial pin state in `src/qml/Main.qml`**

Change:
```qml
            posWidth: sticker.width,
            posHeight: sticker.height,
            appRoot: root
```
to:
```qml
            posWidth: sticker.width,
            posHeight: sticker.height,
            stickerPinned: sticker.pinned,
            appRoot: root
```

- [ ] **Step 4: Build and manually verify pin actually controls multi-desktop visibility per sticker**

```bash
cmake --build build
./scripts/test-sticker.sh
./build/kde-stickers &
```
Click 📍 on sticker `#001` to pin it (real click). Confirm via `journalctl`/screenshot the icon changes to 📌. Switch virtual desktops (Pager or `Meta+Ctrl+Right`, or the KWin D-Bus method used throughout this project). **Expected:** `#001` remains visible on every desktop; `#002` and `#003` (unpinned) do NOT — they stay on the desktop where they were created. Check `~/.stickers/stickers.json`: `#001`'s `pinned` is `true`, the others `false`.

Unpin `#001` (click 📌 again). Confirm it becomes 📍. **This is the step to check most carefully** — per Task 5's finding, removing the rule alone does not actually un-pin a live window, so it's not enough to see the icon change. Switch desktops again (real switch, ground-truth KWin query) and confirm `#001` genuinely stops following — it should now only be visible on the single desktop it's on, exactly like `#002`/`#003`. If it's still visible on every desktop after unpinning, the `unpinLiveWindow` ordering or mechanism has a real problem — don't accept "the icon changed" as sufficient evidence. Confirm `~/.stickers/stickers.json` reflects `pinned: false`.

Kill the process, relaunch. Confirm `#001` (if you left it pinned) — or whichever stickers had `pinned: true` at last save — are still visible on all desktops immediately, without needing to re-click the pin (the rule persisted in `kwinrulesrc` and gets reapplied automatically since the window is created with the same matching title).

- [ ] **Step 5: Commit**

```bash
git add src/kwinbridge.h src/kwinbridge.cpp src/qml/StickerWindow.qml src/qml/Main.qml
git commit -m "feat: add per-sticker pin button for opt-in all-desktops visibility"
```

---

## Task 7: Real position persistence

**Files:**
- Modify: `src/qml/StickerWindow.qml`

**Interfaces:**
- Consumes: `KWinBridge.queryRealGeometry(windowTitle: string): QPointF` (Task 5).
- Produces: `Q_INVOKABLE void KWinBridge::updatePositionRule(const QString &stickerId, const QString &windowTitle, int x, int y) const` (added to `KWinBridge` in this task).

- [ ] **Step 1: Add `updatePositionRule` to `KWinBridge`**

Add to `src/kwinbridge.h`:
```cpp
    Q_INVOKABLE void updatePositionRule(const QString &stickerId, const QString &windowTitle, int x, int y) const;
```

> **Revision note (post-Task-5-spike):** the spike confirmed `positionrule=Force` (`2`) DOES apply live — but it also makes the window **undraggable** (`movable=false`), which would break this app's core drag feature for any sticker with a known position. The correct mode is `positionrule=Apply` (`3`): it only takes effect at window-*creation* time, not live — which is exactly what "restore position on the next launch" needs, and the window stays draggable. `titlematch` is also corrected to `1` (ExactMatch) here for the same reason as Task 6. The code below already reflects both fixes — this is not the brief's original literal draft.

Add to `src/kwinbridge.cpp`:
```cpp
void KWinBridge::updatePositionRule(const QString &stickerId, const QString &windowTitle, int x, int y) const
{
    const QString ruleId = ruleGroupName(stickerId);

    addRuleIdToList(ruleId);
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("wmclass"), QStringLiteral("org.kde.stickers")});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("wmclassmatch"), QStringLiteral("2")});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("wmclasscomplete"), QStringLiteral("false")});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("title"), windowTitle});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("titlematch"), QStringLiteral("1")});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("types"), QStringLiteral("1")});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("position"),
         QStringLiteral("%1,%2").arg(x).arg(y)});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("positionrule"), QStringLiteral("3")});

    reconfigureKWin();
}
```

Note this writes to the *same* rule group id (`kdestickers-sticker-<id>`) that `setPinned` (Task 6) may also write to — a sticker that is both pinned and has a known position ends up with one rule group carrying both `desktops`/`desktopsrule` and `position`/`positionrule` keys, which is valid KWin rule syntax (a single rule group can force multiple properties at once). `kwriteconfig6` only touches the specific key given each call, so writing position keys here doesn't clobber `setPinned`'s desktop keys already in the same group, or vice versa.

**Important consequence of using `Apply` instead of `Force`:** since `Apply` only takes effect at window-creation time, dragging a sticker will **not** move it to the new position immediately in the same session in any KWin-rule sense — the drag itself already works (via the existing `startSystemMove()` mechanism), and this rule only determines where the window opens on the *next* launch. Step 3's verification below reflects this — don't expect the live drag to visibly "snap" anywhere via the rule; the rule's effect is only observable after a kill+relaunch.

- [ ] **Step 2: Rewire the existing drag-persistence logic in `src/qml/StickerWindow.qml` to use real geometry**

The current `persistTimer` (added in the original MVP's Task 3, before real position reading was possible) persists `mainWindow.x`/`y` directly — known broken, documented as best-effort-only in the surrounding comment block. Replace it now that `queryRealGeometry` exists.

Change:
```qml
    // Persist position on change, debounced. startSystemMove() (see the
    // header MouseArea below) hands the interactive move grab off to the
    // compositor for the whole gesture -- there is no onReleased to hook
    // a persist call to -- so we watch x/y instead and persist a short
    // idle period after they stop changing.
    //
    // IMPORTANT (best-effort only, not fully functional here): per the
    // accepted Wayland limitation documented in the spec's "Modelo de datos
    // y persistencia" section, mainWindow.x/y never reflects this window's
    // real on-screen position on this Qt6/KWin/Wayland stack -- Wayland's
    // xdg-toplevel protocol gives clients no absolute-position feedback at
    // all, and KWin does not honor the persisted x/y as a restore position
    // on the next launch either (it applies its own placement policy
    // instead). This whole mechanism is harmless to keep -- it would work
    // correctly on X11 or a compositor that does report real position, and
    // costs nothing to leave running -- but on this stack it mostly persists
    // a value that does not correspond to where the sticker actually ended
    // up on screen. Kept as documented, intentional best-effort, not a bug.
    //
    // settled guards against a real startup artifact (Task 3 empirical
    // finding, reproduced with a minimal standalone QtQuick.Window too, so
    // it is a Qt6-Wayland-QPA platform behavior, not specific to this app's
    // dynamic window creation): x/y read back the correct posX/posY for one
    // tick, then the Wayland QPA plugin resets them to (0, 0) shortly after
    // the surface is actually mapped, since xdg-toplevel's configure event
    // carries no position -- Wayland gives clients no absolute-position
    // feedback at all. Without this guard, that reset would fire
    // onXChanged/onYChanged and silently overwrite the loaded position with
    // (0, 0) in storage before the user ever touches the window.
    property bool positionDirty: false
    property bool settled: false

    Timer {
        interval: 1000
        running: true
        onTriggered: settled = true
    }

    onXChanged: {
        if (!settled) return
        positionDirty = true
        persistTimer.restart()
    }
    onYChanged: {
        if (!settled) return
        positionDirty = true
        persistTimer.restart()
    }

    Timer {
        id: persistTimer
        interval: 300
        onTriggered: {
            if (positionDirty) {
                Manager.updatePosition(stickerId, mainWindow.x, mainWindow.y)
                positionDirty = false
            }
        }
    }
```
to:
```qml
    // Persist real position on change, debounced. startSystemMove() (see
    // the header MouseArea below) hands the interactive move grab off to
    // the compositor for the whole gesture -- there is no onReleased to
    // hook a persist call to -- so we watch x/y as a "something moved,
    // check again shortly" trigger, then query KWin for the window's real
    // on-screen position (mainWindow.x/y itself is not reliable -- see
    // KWinBridge.queryRealGeometry's own documentation) and persist that,
    // plus write a KWin position rule so the window opens there again on
    // the next launch.
    //
    // settled guards against a real startup artifact (original MVP's Task 3
    // empirical finding): x/y read back the correct posX/posY for one tick,
    // then the Wayland QPA plugin resets its cached value shortly after the
    // surface is actually mapped. Without this guard, that reset would fire
    // onXChanged/onYChanged and trigger a spurious geometry query/persist
    // before the user ever touches the window.
    property bool positionDirty: false
    property bool settled: false

    Timer {
        interval: 1000
        running: true
        onTriggered: settled = true
    }

    onXChanged: {
        if (!settled) return
        positionDirty = true
        persistTimer.restart()
    }
    onYChanged: {
        if (!settled) return
        positionDirty = true
        persistTimer.restart()
    }

    Timer {
        id: persistTimer
        interval: 300
        onTriggered: {
            if (positionDirty) {
                var realPos = KWin.KWinBridge.queryRealGeometry(mainWindow.title)
                if (realPos.x >= 0 && realPos.y >= 0) {
                    Manager.updatePosition(stickerId, realPos.x, realPos.y)
                    KWin.KWinBridge.updatePositionRule(stickerId, mainWindow.title, realPos.x, realPos.y)
                }
                positionDirty = false
            }
        }
    }
```

(The `import Stickers.KWin as KWin` needed here was already added in Task 6, Step 2 — no further import changes needed.)

- [ ] **Step 3: Build and manually verify position actually survives a restart**

```bash
cmake --build build
./scripts/test-sticker.sh
./build/kde-stickers &
```
Drag sticker `#001` (via `startSystemMove()`, already working since the original MVP) to a visibly different position — confirm via screenshot/`workspace.windowList()` that it actually moved (ground truth, not just the QML property). Wait for the debounce to settle (~1.5s after the move ends). Check:
```bash
cat ~/.stickers/stickers.json | jq '.stickers[] | select(.id=="001")'
```
Expected: `x`/`y` reflect the real dragged-to position (matching what `workspace.windowList()` reported), not stale/zero values. Also check:
```bash
kreadconfig6 --file kwinrulesrc --group kdestickers-sticker-001 --key position
kreadconfig6 --file kwinrulesrc --group kdestickers-sticker-001 --key positionrule
```
Expected: `position` matches the dragged-to coordinates, `positionrule` is `3` (Apply — not `2`/Force, which the Task 5 spike found makes the window undraggable).

Also confirm the sticker is still draggable after this rule is written — drag it again and verify it visibly moves (a regression check that `Apply` really doesn't lock the window the way `Force` would have).

Kill the process, relaunch:
```bash
./build/kde-stickers &
```
Confirm via screenshot/`workspace.windowList()` that sticker `#001` reopens at (or very close to) the position it was dragged to — the real fix this task exists to deliver. This is the single most important manual check in this whole plan; do not skip it or accept a partial/inconclusive result.

- [ ] **Step 4: Commit**

```bash
git add src/kwinbridge.h src/kwinbridge.cpp src/qml/StickerWindow.qml
git commit -m "feat: persist and restore real sticker position via KWin position rule"
```

---

## Task 8: Orphaned-rule sweep, docs update

**Files:**
- Modify: `scripts/install.sh`
- Modify: `docs/QUICKSTART.md`
- Modify: `docs/QA_CHECKLIST.md`
- Modify: `docs/superpowers/specs/2026-08-18-sticker-pin-position-resize-design.md`

- [ ] **Step 1: Add an orphaned-rule sweep to `scripts/install.sh`**

Per the spec's error-handling section: if a sticker's deletion is ever interrupted mid-way (crash, killed process) after `removeRules` was supposed to run but before it completed, its KWin rule id could be left listed in `[General] rules=` with no corresponding sticker in `stickers.json` — harmless (an orphaned rule id just means KWin tries to match a window that never appears), but worth sweeping on reinstall, matching the spec's stated cleanup point.

Change:
```bash
mkdir -p "$HOME/.stickers"

echo "✓ kde-stickers instalado en $BIN_PATH"
```
to:
```bash
mkdir -p "$HOME/.stickers"

if command -v jq >/dev/null 2>&1; then
    echo "📦 Limpiando reglas KWin huérfanas de stickers ya eliminados"
    STICKERS_JSON="$HOME/.stickers/stickers.json"
    STICKER_IDS="$( [ -f "$STICKERS_JSON" ] && jq -r '.stickers[].id' "$STICKERS_JSON" 2>/dev/null || true)"
    EXISTING_RULES="$(kreadconfig6 --file kwinrulesrc --group General --key rules 2>/dev/null || true)"
    IFS=',' read -ra RULE_ARRAY <<< "$EXISTING_RULES"
    NEW_RULE_LIST=""
    SWEPT_ANY=0
    for rule in "${RULE_ARRAY[@]}"; do
        if [[ "$rule" =~ ^kdestickers-sticker-(.+)$ ]]; then
            rule_sticker_id="${BASH_REMATCH[1]}"
            if ! echo "$STICKER_IDS" | grep -qx "$rule_sticker_id"; then
                SWEPT_ANY=1
                continue
            fi
        fi
        NEW_RULE_LIST="${NEW_RULE_LIST:+$NEW_RULE_LIST,}$rule"
    done
    if [ "$SWEPT_ANY" = "1" ]; then
        kwriteconfig6 --file kwinrulesrc --group General --key rules "$NEW_RULE_LIST"
        qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null || true
        echo "✓ Reglas huérfanas retiradas de la lista activa"
    fi
else
    echo "⚠ jq no disponible — se omite la limpieza de reglas huérfanas (no crítico)"
fi

echo "✓ kde-stickers instalado en $BIN_PATH"
```

- [ ] **Step 2: Build and manually verify the sweep**

```bash
cmake --build build
./scripts/test-sticker.sh
```
Manually seed an orphaned rule (an id with no matching sticker in the freshly-written 3-sticker seed data):
```bash
EXISTING="$(kreadconfig6 --file kwinrulesrc --group General --key rules)"
kwriteconfig6 --file kwinrulesrc --group General --key rules "${EXISTING:+$EXISTING,}kdestickers-sticker-999"
./scripts/install.sh
kreadconfig6 --file kwinrulesrc --group General --key rules
```
Expected: `kdestickers-sticker-999` is gone; any real rule ids for stickers `001`/`002`/`003` (if pinned/positioned by earlier tasks' testing) are preserved.

- [ ] **Step 3: Update `docs/QUICKSTART.md`'s position-persistence caveat**

Change:
```markdown
Deberías ver un icono en la bandeja del sistema ("KDE Stickers") y,
si ya tienes stickers guardados en `~/.stickers/stickers.json`,
sus ventanas aparecerán (en la posición que decida KWin — la posición exacta no se restaura entre sesiones, ver limitación conocida en la sección "Movimiento" de `docs/QA_CHECKLIST.md`).
```
to:
```markdown
Deberías ver un icono en la bandeja del sistema ("KDE Stickers") y,
si ya tienes stickers guardados en `~/.stickers/stickers.json`,
sus ventanas aparecerán en su última posición real (persistida vía
una regla de KWin por sticker — ver `docs/QA_CHECKLIST.md`).
```

Add a new section after "## Editar":
```markdown
## Pin (todos los escritorios) y resize

- Botón 📍/📌 en el header: alterna si el sticker es visible en todos
  los escritorios virtuales (📌) o solo en el suyo (📍). Por defecto,
  todo sticker nuevo empieza sin pin.
- Arrastra desde la esquina inferior derecha para redimensionar.
```

- [ ] **Step 4: Update `docs/QA_CHECKLIST.md`**

Change:
```markdown
## Movimiento

- [ ] Arrastrar un sticker por su header lo mueve visualmente (vía `Window.startSystemMove()`)
- [ ] `~/.stickers/stickers.json` sigue siendo válido tras arrastrar (no se corrompe a `x:0, y:0`)

**Limitación conocida y aceptada (ver spec, sección "Modelo de datos y persistencia"):** por una limitación del protocolo Wayland, la app no puede leer la posición real de una ventana tras moverla, así que la posición arrastrada **no** se persiste con precisión, y al reiniciar la app cada sticker abre en la posición que decida la política de colocación de KWin — **no** en su última posición arrastrada. Esto es intencional para este MVP, no un bug a reportar.
```
to:
```markdown
## Movimiento

- [ ] Arrastrar un sticker por su header lo mueve visualmente (vía `Window.startSystemMove()`)
- [ ] Al soltar, la posición real (no la de Qt, la reportada por KWin) se persiste en `~/.stickers/stickers.json`
- [ ] Al reiniciar la app, el sticker abre en su última posición real (vía regla de KWin por ventana, `kdestickers-sticker-<id>`)

## Pin (todos los escritorios por sticker)

- [ ] Botón 📍/📌 alterna el estado de pin visualmente
- [ ] Con pin activo (📌), el sticker es visible en todos los escritorios virtuales
- [ ] Sin pin (📍), el sticker solo existe en el escritorio donde se creó o se movió
- [ ] El estado del pin persiste en `~/.stickers/stickers.json` y sobrevive a un reinicio de la app
- [ ] Nuevo sticker creado: empieza sin pin (📍) por defecto

## Resize

- [ ] Arrastrar desde la esquina inferior derecha redimensiona el sticker visualmente
- [ ] No se puede encoger por debajo de ~150×120px
- [ ] El tamaño persiste en `~/.stickers/stickers.json` y se restaura al reiniciar la app
```

**Resolved by the Task 5 spike:** the checklist text above already matches what was actually found — `positionrule=Apply` (not `Force`, which the spike found makes windows undraggable) applies at window-*creation* time, so "al soltar, la posición se persiste en el JSON" (immediate, via `queryRealGeometry` on drag-release) and "al reiniciar, el sticker abre en su última posición real" (via the rule, effective on next launch) are both accurate as written — no wording change needed here.

- [ ] **Step 5: Mark the spec as implemented**

Change:
```markdown
**Estado:** Aprobado, pendiente de plan de implementación
```
to:
```markdown
**Estado:** Implementado.
```

(If Task 5's spike partially failed and a fallback/limitation was accepted instead of the full design, describe that outcome here instead — this line should always reflect what actually shipped, not what was originally planned.)

- [ ] **Step 6: Commit**

```bash
git add scripts/install.sh docs/QUICKSTART.md docs/QA_CHECKLIST.md docs/superpowers/specs/2026-08-18-sticker-pin-position-resize-design.md
git commit -m "feat: sweep orphaned KWin rules on install; docs: update for pin, position, resize"
```
