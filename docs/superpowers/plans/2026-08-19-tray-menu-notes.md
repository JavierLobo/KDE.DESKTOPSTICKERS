# Tray Menu Note List Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a paginated note list to the KDE Stickers tray menu (open/reopen any note, delete with confirmation), and change the sticker window's "✕" button to close-only instead of delete.

**Architecture:** `Main.qml` gains a window registry (id → live `StickerWindow` instance, to reopen without duplicating) and a flat, paginated view over `Manager.stickers` (10 notes per page, "▲ Anteriores"/"▼ Siguientes" as ordinary top-level menu items — no nested `Qt.labs.platform.Menu`, which crashes on this stack, confirmed in the design spike). The riskiest, previously-unverified assumptions (a flat `Instantiator`-built menu with ~20 items displays and responds to real clicks; a menu item that triggers a rebuild of its own containing menu behaves correctly; `Qt.labs.platform.MessageDialog` shows and responds without the same popup-grab problem found in nested `Menu`) are gated behind a spike (Task 2) that is also this plan's only source of the exact menu-wiring code for Tasks 3 and 4 — everything after it builds on what the spike actually proves, not on assumption.

**Tech Stack:** Qt6 (Quick, QML, Widgets via `QApplication` — already established), `Qt.labs.platform` (`SystemTrayIcon`, `Menu`, `MenuItem`, `MenuSeparator`, `MessageDialog`), QML `Instantiator`.

**Spec:** `docs/superpowers/specs/2026-08-19-tray-menu-notes-design.md`

## Global Constraints

- Qt6 only, unversioned QML imports (`import QtQuick`, not `import QtQuick 2.15`) — matches the rest of this codebase.
- No automated test framework. Verification is compile success + real manual runtime evidence (screenshots, real synthetic clicks via `/dev/uinput`, `journalctl` output, actual file contents) — this project's established, non-negotiable standard. "Should work" / code-reasoning-only is not acceptable evidence for any task in this plan.
- **No nested `Qt.labs.platform.Menu`.** Confirmed via an isolated test during design: a `Menu` declared as a child of another `Menu` triggers `"ERROR: No native Menu implementation available"` and crashes the process on this Qt 6.11 / KDE 6 / Wayland stack. Every task in this plan must keep the tray menu's `Menu` flat — one level, no `Platform.Menu` nested inside another `Platform.Menu`.
- Page size for the note list is fixed at 10 (not configurable).
- The "✕" button on a sticker window closes the window only. It must never call `Manager.removeSticker`. Deleting a note is only reachable from the tray menu's "🗑 Eliminar: `<título>`" entry, and always asks for confirmation first.
- If the spike (Task 2) finds that the flat menu or `MessageDialog` does not display/respond reliably even against a freshly-restarted Plasma session (see Task 2's own troubleshooting step), **stop and report to the user** — do not proceed to Tasks 3/4 with an unverified mechanism, matching how this project's two previous plans handled their own spike gates.

---

## Task 1: Window registry, non-destructive close, note list/pagination logic

**Files:**
- Modify: `src/qml/Main.qml`
- Modify: `src/qml/StickerWindow.qml`

**Interfaces:**
- Produces (all on `Main.qml`'s root `Item`, reachable as `root.<name>` from within `Main.qml` and as `mainWindow.appRoot.<name>` from `StickerWindow.qml`):
  - `property var openWindows: ({})` — map of sticker id (string) → live `StickerWindow` instance.
  - `function registerWindow(id, win)` — `openWindows[id] = win`.
  - `function unregisterWindow(id)` — `delete openWindows[id]`.
  - `function openOrFocusSticker(id)` — if `openWindows[id]` exists, `raise()` + `requestActivate()` it; otherwise look the sticker up in `Manager.stickers` and call `createStickerWindow(...)` if found.
  - `property var noteList: []` — array of `{id: string, label: string}`, one entry per sticker in `Manager.stickers`, in that same order.
  - `property int notePage: 0`.
  - `readonly property int notePageSize: 10`.
  - `function refreshNoteList()` — rebuilds `noteList` from `Manager.stickers`, clamps `notePage` so it never points past the last page.
  - `function noteLabel(text)` — returns a short display label for a sticker's raw text.
  - `function visibleNotes()` — returns the slice of `noteList` for the current `notePage`.
  - `function hasPrevPage()`, `function hasNextPage()`, `function goPrevPage()`, `function goNextPage()`.
- Consumes: `Manager.stickers` (existing, `StickerManager.js` module-level array), `Manager.loadStickers()` (existing), `Manager.removeSticker(id)` (existing, NOT called from this task — only wired in Task 4).

- [ ] **Step 1: Add the window registry to `Main.qml`**

In `src/qml/Main.qml`, the current file is:

```qml
import QtQuick
import Qt.labs.platform as Platform
import "StickerManager.js" as Manager

Item {
    id: root

    Component {
        id: stickerWindowComponent
        StickerWindow {}
    }

    Component.onCompleted: {
        var loaded = Manager.loadStickers()
        for (var i = 0; i < loaded.length; i++) {
            createStickerWindow(loaded[i])
        }
    }

    function createStickerWindow(sticker) {
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
        // StickerWindow declares "visible: true", but a Window instantiated
        // dynamically via createObject() -- parented to a plain Item, not
        // shown by the engine's own top-level-window startup path -- does
        // not actually become visible from that declarative binding alone
        // (confirmed by instrumentation: w.visible read back false
        // immediately after createObject(), even though x/y from the
        // initial-properties map were applied correctly). An explicit
        // show() is required for dynamically created sticker windows.
        if (w) {
            w.show()
        }
        return w
    }

    function createNewSticker(originX, originY) {
        var sticker = Manager.createSticker(originX, originY)
        createStickerWindow(sticker)
    }

    Platform.SystemTrayIcon {
        id: trayIcon
        visible: true
        icon.name: "document-properties"
        tooltip: "KDE Stickers"

        menu: Platform.Menu {
            Platform.MenuItem {
                text: "Nuevo sticker"
                onTriggered: root.createNewSticker(100, 100)
            }
            Platform.MenuItem {
                text: "Salir"
                onTriggered: Qt.quit()
            }
        }
    }
}
```

Change the `Item { id: root ... }` block: replace the `Component.onCompleted` block and `createStickerWindow`/`createNewSticker` functions with:

```qml
    property var openWindows: ({})
    property var noteList: []
    property int notePage: 0
    readonly property int notePageSize: 10

    Component.onCompleted: {
        var loaded = Manager.loadStickers()
        for (var i = 0; i < loaded.length; i++) {
            createStickerWindow(loaded[i])
        }
        refreshNoteList()
    }

    function createStickerWindow(sticker) {
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
        // StickerWindow declares "visible: true", but a Window instantiated
        // dynamically via createObject() -- parented to a plain Item, not
        // shown by the engine's own top-level-window startup path -- does
        // not actually become visible from that declarative binding alone
        // (confirmed by instrumentation: w.visible read back false
        // immediately after createObject(), even though x/y from the
        // initial-properties map were applied correctly). An explicit
        // show() is required for dynamically created sticker windows.
        if (w) {
            w.show()
            registerWindow(sticker.id, w)
        }
        return w
    }

    function createNewSticker(originX, originY) {
        var sticker = Manager.createSticker(originX, originY)
        createStickerWindow(sticker)
        refreshNoteList()
    }

    function registerWindow(id, win) {
        openWindows[id] = win
    }

    function unregisterWindow(id) {
        delete openWindows[id]
    }

    function openOrFocusSticker(id) {
        var win = openWindows[id]
        if (win) {
            win.raise()
            win.requestActivate()
            return
        }
        var sticker = Manager.stickers.find(function(s) { return s.id === id })
        if (sticker) {
            createStickerWindow(sticker)
        }
    }

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

    function visibleNotes() {
        var start = notePage * notePageSize
        return noteList.slice(start, start + notePageSize)
    }

    function hasPrevPage() {
        return notePage > 0
    }

    function hasNextPage() {
        return (notePage + 1) * notePageSize < noteList.length
    }

    function goPrevPage() {
        if (hasPrevPage()) {
            notePage -= 1
        }
    }

    function goNextPage() {
        if (hasNextPage()) {
            notePage += 1
        }
    }
```

Leave the `Component { id: stickerWindowComponent ... }` block and the `Platform.SystemTrayIcon { ... }` block (with its current 2-item menu) exactly as they are — the tray menu itself is Task 3's job, not this task's.

- [ ] **Step 2: Change the "✕" button in `StickerWindow.qml` to close-only**

In `src/qml/StickerWindow.qml`, find (around line 245-261):

```qml
                    Button {
                        text: "✕"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: {
                            Manager.removeSticker(stickerId)
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
```

Replace with:

```qml
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
```

- [ ] **Step 3: Build**

```bash
cmake --build build
```

Expected: clean build, no errors, no new warnings.

- [ ] **Step 4: Verify the "✕" button no longer deletes, with real evidence**

```bash
./scripts/test-sticker.sh   # resets ~/.stickers/stickers.json to 3 known stickers
pkill -9 -f "build/kde-stickers" 2>/dev/null; sleep 0.5
./build/kde-stickers &
sleep 1.5
```

Identify one sticker window's real on-screen geometry via a KWin script (the same ground-truth technique used throughout this project — `workspace.windowList()`, matched by `caption`), take a real synthetic click (`/dev/uinput`, `evdev.UInput`) on its "✕" button, then check:

```bash
cat ~/.stickers/stickers.json | jq '.stickers[].id'
```

Expected: **all 3 sticker ids are still present** (the one you clicked "✕" on is NOT gone from the file) — this is the actual point of this step, confirmed against the real file, not inferred from the window disappearing. Also confirm via a fresh KWin `workspace.windowList()` query that the clicked sticker's window is genuinely gone (real close happened, not a no-op).

- [ ] **Step 5: Verify `refreshNoteList()`/`noteLabel()`/pagination functions compute correctly, with real evidence**

These are pure data functions with no UI dependency yet (the tray menu isn't wired to them until Task 3), so verify them directly. Add a temporary one-line diagnostic, e.g. inside `Component.onCompleted` right after the existing `refreshNoteList()` call:

```qml
        console.warn("TASK1_CHECK noteList=" + JSON.stringify(noteList) + " notePage=" + notePage)
```

Rebuild, relaunch (`./scripts/test-sticker.sh` first, to get the known 3-fixture stickers with real text: "Primer sticker de prueba...", "Segundo sticker...", "TODO:..."), and check the real output:

```bash
journalctl --user -n 20 --no-pager -o cat 2>/dev/null | grep TASK1_CHECK
```

Expected: `noteList` has exactly 3 entries, each `{"id":"00N","label":"..."}` with `label` matching the first non-empty line of that sticker's actual text (e.g. `"Primer sticker de prueba"` for sticker `001`, truncated to 30 chars with `…` if the real first line is longer — none of the 3 fixture stickers' first lines are, so plain untruncated text is expected here). Remove the temporary `console.warn` line after confirming, rebuild once more to confirm the removal compiles clean.

- [ ] **Step 6: Commit**

```bash
git add src/qml/Main.qml src/qml/StickerWindow.qml
git commit -m "feat: add window registry and note list/pagination logic, close X non-destructively"
```

---

## Task 2 (SPIKE): Verify flat paginated menu and MessageDialog work for real

**Files:**
- Modify (temporarily, for the spike; revert before commit): `src/qml/Main.qml`
- No permanent file changes — this task's deliverable is a **report**, not shipped code. Revert every temporary change before Step 8's commit.

**Interfaces:**
- Consumes: nothing new from Task 1 (the spike tests a standalone temporary menu structure, not the real one, to keep this task's blast radius small and revertible).
- Produces: a written verdict (in the task report) on whether the flat `Instantiator`-based menu, its pagination items, and `Qt.labs.platform.MessageDialog` are safe to build Tasks 3/4 on — this verdict is what Tasks 3/4 are gated behind.

### Why this spike exists

Design-time testing (documented in the spec) found that a **nested** `Qt.labs.platform.Menu` crashes this stack outright. It also found that triggering the tray menu via `Menu.open()` or a direct D-Bus `ContextMenu()` call did not reliably show ANY menu during that testing session — including the app's own pre-existing, already-shipping 2-item menu — which points at the *test session itself* having left something in a bad state (heavy, repeated app restarts in quick succession), not at a fundamental problem with flat menus. This was never cleanly resolved. This task's job is to get a clean answer using real clicks on a real, correctly-identified tray icon, in a fresh session.

### Before you start: confirm you have a clean baseline

```bash
kquitapp6 plasmashell && kstart6 plasmashell &
sleep 3
```

This project's standard Plasma reload command (see `CLAUDE.md`). Run this FIRST, before any of your own testing, so you are not chasing a problem inherited from someone else's earlier session. If the tray menu still doesn't respond after this reload and a fresh app launch, that is a real finding — report it, do not keep restarting plasmashell hoping it clears.

- [ ] **Step 1: Identify the real tray icon**

```bash
pkill -9 -f "build/kde-stickers" 2>/dev/null; sleep 0.5
./build/kde-stickers &
sleep 1.5
qdbus6 org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher.RegisteredStatusNotifierItems
```

This lists all registered tray icons as `<service>/StatusNotifierItem` (there will be more than one — other apps register too). For each one that looks like it could be yours, confirm with:

```bash
qdbus6 <service> /StatusNotifierItem org.freedesktop.DBus.Properties.Get org.kde.StatusNotifierItem Title
```

The one whose `Title` is `kde-stickers` is yours. Remember its exact service name (e.g. `:1.NNN` — it changes every launch, re-run this each time you relaunch the app).

- [ ] **Step 2: Locate the icon's on-screen position and click it for real**

Take a screenshot (`spectacle -b -n -o <path>`), crop the system tray area of the panel, and hover the cursor (move via `/dev/uinput`, re-verify with a KWin script's `workspace.cursorPos`, the ground-truth technique used throughout this project) over candidate icons until a tooltip reading **"KDE Stickers"** appears in a screenshot taken after the hover — this is how you confirm you have the right icon before clicking (icons shift position between panel/session states; do not assume a fixed pixel offset). Once confirmed, perform a real synthetic left-click (`evdev.UInput`, press+release `BTN_LEFT`) at that exact position.

Take a screenshot immediately after. **Record whether the existing, unmodified 2-item menu ("Nuevo sticker" / "Salir") appears on screen.** This is your control check — if this fails, the problem is session/environment state (go back to "Before you start"), not anything about flat menus specifically.

- [ ] **Step 3: Add a temporary flat menu with ~20 items + pagination items**

In `src/qml/Main.qml`, temporarily replace the `menu: Platform.Menu { ... }` block inside `Platform.SystemTrayIcon` with:

```qml
        menu: Platform.Menu {
            id: trayMenu
            Platform.MenuItem {
                text: "Nuevo sticker"
                onTriggered: root.createNewSticker(100, 100)
            }
            Platform.MenuSeparator {}
            // TEMP SPIKE TEST -- revert before Step 8's commit
            property int spikePage: 0
            Platform.MenuItem {
                text: "▲ Anteriores"
                visible: trayMenu.spikePage > 0
                onTriggered: {
                    trayMenu.spikePage -= 1
                    console.warn("SPIKE2_PAGE " + trayMenu.spikePage)
                }
            }
            Instantiator {
                model: 20
                delegate: Platform.MenuItem {
                    text: "Item página " + trayMenu.spikePage + " número " + (index + 1)
                    onTriggered: console.warn("SPIKE2_CLICK page=" + trayMenu.spikePage + " index=" + index)
                }
                onObjectAdded: (index, object) => trayMenu.insertItem(index + 3, object)
                onObjectRemoved: (index, object) => trayMenu.removeItem(object)
            }
            Platform.MenuItem {
                text: "▼ Siguientes"
                visible: trayMenu.spikePage < 2
                onTriggered: {
                    trayMenu.spikePage += 1
                    console.warn("SPIKE2_PAGE " + trayMenu.spikePage)
                }
            }
            Platform.MenuSeparator {}
            Platform.MenuItem {
                text: "Salir"
                onTriggered: Qt.quit()
            }
        }
```

Build, relaunch (re-run Step 1 to get the new instance's tray service name), and repeat Step 2's identify-and-click process for real.

**Check A (flat menu with many items):** does the menu display, showing "Nuevo sticker", the 20 numbered items, "▼ Siguientes", separators, and "Salir"? Screenshot as evidence.

**Check B (pagination click behaves acceptably):** perform a real click on "▼ Siguientes" (locate its real on-screen position from the screenshot, same click technique). Then check `journalctl --user -n 10 --no-pager -o cat 2>/dev/null | grep SPIKE2_PAGE` for the real log line, AND take a screenshot to see what happened visually. Record precisely which of these occurred (this is exactly the open question the spec flagged and is the point of this check):
  - The menu stayed open and visibly rebuilt to show "Item página 1 número 1..20" and "▲ Anteriores" now visible — best case.
  - The menu closed after the click, but the state (`spikePage`) updated correctly (confirmed via the journal line) — acceptable, but note it: Tasks 3/4 will need to tell the user "click again to see the next page" rather than assuming the menu stays open.
  - The menu closed AND the click's effect is unclear/inconsistent across repeated tries — this is a real problem, not a UX nuance; treat it as a spike failure for pagination specifically (see Step 4's report contract for how to record a partial failure).

- [ ] **Step 4: Add a temporary `MessageDialog` and test it for real**

Still in the temporary `Main.qml` edit, add inside the root `Item`, alongside the existing `Component`/functions:

```qml
    // TEMP SPIKE TEST -- revert before Step 8's commit
    Platform.MessageDialog {
        id: spikeDialog
        text: "¿Confirmar acción de prueba?"
        buttons: Platform.MessageDialog.Yes | Platform.MessageDialog.No
        onYesClicked: console.warn("SPIKE2_DIALOG_YES")
        onNoClicked: console.warn("SPIKE2_DIALOG_NO")
    }
```

And add one more temporary top-level `Platform.MenuItem` to the spike menu (right after "Nuevo sticker") to trigger it:

```qml
            Platform.MenuItem {
                text: "TEST: abrir diálogo"
                onTriggered: spikeDialog.open()
            }
```

Build, relaunch, identify+click the tray icon for real, click "TEST: abrir diálogo" for real, then:

**Check C (dialog displays and responds):** does a real dialog appear on screen (screenshot as evidence)? Click "Sí" (or "No") for real (locate the button's real position, same technique) and confirm the corresponding `SPIKE2_DIALOG_YES`/`SPIKE2_DIALOG_NO` line appears in `journalctl`. If the dialog fails to appear or fails the same "No native ... / Failed to create grabbing popup" way `Menu` did when nested, that's a real, reportable failure for this check.

- [ ] **Step 5: Clean up test artifacts**

```bash
pkill -9 -f "build/kde-stickers" 2>/dev/null
./scripts/test-sticker.sh   # reset ~/.stickers/stickers.json to the known 3-fixture
```

- [ ] **Step 6: Revert the temporary `Main.qml` changes**

```bash
git checkout -- src/qml/Main.qml
```

Confirm via `git status --porcelain` that `src/qml/Main.qml` shows no changes (only Task 1's already-committed changes remain, if this is being run as a fresh checkout after Task 1's commit).

- [ ] **Step 7: Rebuild the clean tree and do one final smoke check**

```bash
cmake --build build
./build/kde-stickers &
sleep 1.5
```

Confirm via `pgrep -a kde-stickers` that it's running, then kill it (`pkill -9 -f "build/kde-stickers"`) — this just confirms the revert didn't leave the tree broken.

- [ ] **Step 8: Report — no commit for this task**

This task produces no shipped code (Step 6 reverted it), so there is nothing to commit. Write the full report (all three checks' real evidence: screenshots, exact journal lines, exact click coordinates and how they were confirmed) to the report file the controller specifies. State plainly, for each of Check A/B/C: PASS, PASS-WITH-CAVEAT (describe the caveat, e.g. "menu closes on pagination click"), or FAIL (describe exactly what was observed, including whether a plasmashell restart was tried and whether it changed anything).

**If Check A or Check C is a FAIL (not just a caveat): stop here and report to the controller — do not proceed to Tasks 3/4.** A FAIL on Check B (pagination) alone does not block Tasks 3/4 — record the caveat, and Task 3 adapts (e.g., the tray icon's tooltip or a menu item's text can say "haz click de nuevo para ver más" if the menu doesn't stay open across a pagination click).

---

## Task 3: Wire the real tray menu (flat, paginated, per the spike's findings)

**Files:**
- Modify: `src/qml/Main.qml`

**Interfaces:**
- Consumes: everything Task 1 produced (`openWindows`, `noteList`, `notePage`, `notePageSize`, `refreshNoteList`, `visibleNotes`, `hasPrevPage`, `hasNextPage`, `goPrevPage`, `goNextPage`, `openOrFocusSticker`), and Task 2's report (confirming the `Instantiator` + flat-menu approach is safe, and telling you whether pagination clicks keep the menu open or close it).
- Produces: the real "Abrir: `<título>`" entries in the tray menu; `Manager.removeSticker`/deletion itself is still NOT wired here (that's Task 4) — this task's "🗑 Eliminar: `<título>`" entries exist and are clickable but their handler is a `console.warn` placeholder that Task 4 replaces with the real confirmation flow. (This is not a forbidden "placeholder" in the plan-writing sense — it is a real, intentional interface seam between two tasks, matching how the spec itself splits menu-wiring from delete-confirmation-wiring.)

- [ ] **Step 1: Replace the tray menu in `Main.qml`**

Replace the `Platform.SystemTrayIcon { ... }` block (still the original 2-item version, since Task 1 didn't touch it and Task 2's changes were reverted) with:

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
            Platform.MenuSeparator {}
            Platform.MenuItem {
                text: "▲ Anteriores"
                visible: root.hasPrevPage()
                onTriggered: root.goPrevPage()
            }
            Instantiator {
                model: root.visibleNotes()
                delegate: Platform.MenuItem {
                    text: "Abrir: " + modelData.label
                    onTriggered: root.openOrFocusSticker(modelData.id)
                }
                onObjectAdded: (index, object) => trayMenu.insertItem(index + 3, object)
                onObjectRemoved: (index, object) => trayMenu.removeItem(object)
            }
            Instantiator {
                model: root.visibleNotes()
                delegate: Platform.MenuItem {
                    text: "🗑 Eliminar: " + modelData.label
                    onTriggered: console.warn("DELETE_PLACEHOLDER " + modelData.id)
                }
                onObjectAdded: (index, object) => trayMenu.insertItem(index + 3 + root.visibleNotes().length, object)
                onObjectRemoved: (index, object) => trayMenu.removeItem(object)
            }
            Platform.MenuItem {
                text: "▼ Siguientes"
                visible: root.hasNextPage()
                onTriggered: root.goNextPage()
            }
            Platform.MenuSeparator {}
            Platform.MenuItem {
                text: "Salir"
                onTriggered: Qt.quit()
            }
        }
    }
```

If Task 2's report found Check B was a FAIL or a PASS-WITH-CAVEAT describing something other than "menu stays open and rebuilds" or "menu closes but state updates correctly," adjust this step's approach to match what the spike actually found working — the spike's report is the authority here, not this literal snippet. If the report found the menu closes on any item click (including "Abrir"/"Eliminar", not just pagination), that is expected native-menu behavior and does not need a workaround; only the case where pagination clicking left `notePage` unclear/inconsistent needs special handling.

- [ ] **Step 2: Build**

```bash
cmake --build build
```

Expected: clean build.

- [ ] **Step 3: Verify with real evidence — menu shows real notes**

```bash
./scripts/test-sticker.sh
pkill -9 -f "build/kde-stickers" 2>/dev/null; sleep 0.5
./build/kde-stickers &
sleep 1.5
```

Using the same identify-icon (`qdbus6 org.kde.StatusNotifierWatcher ...`) and real-click technique established in Task 2, open the tray menu for real. Screenshot it. Expected: "Nuevo sticker", then (no "▲ Anteriores" — only 3 stickers, one page) three pairs of "Abrir: `<label>`" / "🗑 Eliminar: `<label>`" matching the 3 fixture stickers' real first-line text, then (no "▼ Siguientes"), "Salir".

- [ ] **Step 4: Verify with real evidence — "Abrir" reopens a closed note without duplicating**

Real-click one sticker's "✕" (confirm via KWin `workspace.windowList()` that its window is gone, per Task 1's Step 4 technique). Reopen the tray menu for real, real-click that same sticker's "Abrir: `<label>`" entry. Confirm via a fresh KWin `workspace.windowList()` query that exactly one window with that sticker's title exists (not zero, not two) and that it shows the sticker's real content (screenshot).

- [ ] **Step 5: Verify with real evidence — "Abrir" on an already-open note focuses it, does not duplicate**

With a sticker window still open (from the previous step or freshly relaunched), real-click its own tray menu "Abrir: `<label>`" entry again. Confirm via KWin `workspace.windowList()` that there is still exactly one window with that title (no duplicate created).

- [ ] **Step 6: Commit**

```bash
git add src/qml/Main.qml
git commit -m "feat: wire real paginated tray menu (open/reopen notes, no nested submenus)"
```

---

## Task 4: Delete confirmation dialog

**Files:**
- Modify: `src/qml/Main.qml`

**Interfaces:**
- Consumes: `root.openWindows`, `root.unregisterWindow` (Task 1), `Manager.removeSticker(id)` (existing, `StickerManager.js`), `root.refreshNoteList()` (Task 1), the "🗑 Eliminar: `<título>`" `Instantiator` delegate from Task 3 (its `console.warn` placeholder handler is replaced here).
- Produces: `function confirmDeleteSticker(id, label)` — opens the confirmation dialog for that sticker.

- [ ] **Step 1: Add the confirmation dialog and wire it in**

In `src/qml/Main.qml`, add inside the root `Item` (alongside the existing functions, e.g. right after `goNextPage`):

```qml
    function confirmDeleteSticker(id, label) {
        deleteConfirmDialog.pendingId = id
        deleteConfirmDialog.text = "¿Eliminar \"" + label + "\"? Esta acción no se puede deshacer."
        deleteConfirmDialog.open()
    }

    Platform.MessageDialog {
        id: deleteConfirmDialog
        property string pendingId: ""
        buttons: Platform.MessageDialog.Yes | Platform.MessageDialog.No
        onYesClicked: {
            var win = root.openWindows[pendingId]
            if (win) {
                root.unregisterWindow(pendingId)
                win.close()
                win.destroy()
            }
            Manager.removeSticker(pendingId)
            root.refreshNoteList()
        }
    }
```

Then change the "🗑 Eliminar" `Instantiator`'s delegate (added in Task 3) from:

```qml
                delegate: Platform.MenuItem {
                    text: "🗑 Eliminar: " + modelData.label
                    onTriggered: console.warn("DELETE_PLACEHOLDER " + modelData.id)
                }
```

to:

```qml
                delegate: Platform.MenuItem {
                    text: "🗑 Eliminar: " + modelData.label
                    onTriggered: root.confirmDeleteSticker(modelData.id, modelData.label)
                }
```

- [ ] **Step 2: Build**

```bash
cmake --build build
```

Expected: clean build.

- [ ] **Step 3: Confirm there is no path that destroys a window without unregistering it first**

The spec's error-handling section flags a theoretical race: if `openWindows[id]` ever pointed at an already-destroyed `StickerWindow`, `openOrFocusSticker`'s `win.raise()` would throw against an invalid QML object. This plan closes that by construction — every place that calls `mainWindow.destroy()` must call `unregisterWindow` first — but confirm it directly rather than assuming:

```bash
grep -n "\.destroy()" src/qml/StickerWindow.qml src/qml/Main.qml
```

Expected: exactly two call sites — the "✕" button in `StickerWindow.qml` (Task 1, already calls `mainWindow.appRoot.unregisterWindow(stickerId)` immediately before) and `deleteConfirmDialog.onYesClicked` in `Main.qml` (Step 1 above, already calls `root.unregisterWindow(pendingId)` immediately before). If `grep` finds any other `.destroy()` call site on a `StickerWindow` instance, that is a real gap — add the missing `unregisterWindow` call before it as part of this step, do not defer it.

- [ ] **Step 4: Verify with real evidence — confirmation dialog blocks accidental deletion**

```bash
./scripts/test-sticker.sh
pkill -9 -f "build/kde-stickers" 2>/dev/null; sleep 0.5
./build/kde-stickers &
sleep 1.5
```

Real-click the tray icon, real-click "🗑 Eliminar: `<label>`" for one sticker. Screenshot: confirm a real dialog appears showing that sticker's actual label in the confirmation text. Real-click "No" (locate its real position). Confirm via `cat ~/.stickers/stickers.json | jq '.stickers[].id'` that **all 3 stickers are still present** — "No" genuinely cancelled, nothing was deleted.

- [ ] **Step 5: Verify with real evidence — confirmed deletion actually deletes, closes the window if open, and updates the menu**

Real-click the tray icon, real-click "Abrir: `<label>`" for a different sticker (to have its window open), then real-click the tray icon again and real-click that same sticker's "🗑 Eliminar: `<label>`". Real-click "Sí" this time. Confirm, with real evidence:

```bash
cat ~/.stickers/stickers.json | jq '.stickers[].id'
```

Expected: that sticker's id is **gone** (only the other 2 remain). Also confirm via KWin `workspace.windowList()` that its window is gone (the dialog's `onYesClicked` closed it). Finally, real-click the tray icon one more time and screenshot: confirm that sticker's "Abrir"/"Eliminar" pair is **no longer in the menu** (proves `refreshNoteList()` ran and the `Instantiator`s picked up the change).

- [ ] **Step 6: Commit**

```bash
git add src/qml/Main.qml
git commit -m "feat: add delete confirmation dialog, wire into tray menu"
```
