import QtQuick
import Qt.labs.platform as Platform
import "StickerManager.js" as Manager
import "SettingsManager.js" as Settings
import Stickers.KWin as KWin

Item {
    id: root

    property var openWindows: ({})
    property var noteList: []
    property var trayNotes: []
    readonly property int maxTrayNotes: 10

    // Live binding to Plasma/Qt's current theme accent color, used as the
    // "accent" option for appearance.defaultColorMode -- a QML item
    // property, so it must be read here (StickerManager.js is a .pragma
    // library and cannot instantiate a QML SystemPalette itself) and passed
    // into Manager.createSticker(). Automatically follows theme changes
    // since it's a live binding, not a cached value.
    SystemPalette {
        id: sysPalette
        colorGroup: SystemPalette.Active
    }

    Component {
        id: stickerWindowComponent
        StickerWindow {}
    }

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
            stickerName: sticker.name,
            stickerText: sticker.text,
            stickerColor: sticker.color,
            posX: sticker.x,
            posY: sticker.y,
            posWidth: sticker.width,
            posHeight: sticker.height,
            stickerPinned: sticker.pinned,
            stickerFontFamily: sticker.fontFamily,
            stickerFontSize: sticker.fontSize,
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
        var sticker = Manager.createSticker(originX, originY, sysPalette.highlight.toString())
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
            // Defense in depth: onClosing (StickerWindow.qml) keeps this
            // registry self-maintaining for every close path, but if some
            // path ever slips through without firing it, a stale entry
            // would point at a window that's no longer visible -- show()
            // it back before raising/activating rather than silently
            // no-oping.
            if (!win.visible) {
                win.show()
            }
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
            return {
                id: s.id,
                name: s.name,
                text: s.text,
                label: Manager.displayName(s),
                hasTitle: Manager.hasTitle(s),
                snippet: Manager.contentSnippet(s),
                color: s.color,
                pinned: s.pinned,
                modified: s.modified
            }
        })
        trayNotes = recentTrayNotes()
    }

    // Tray menu has no pagination -- just the maxTrayNotes most recently
    // modified stickers, newest first. modified is an ISO 8601 string, so
    // plain string comparison sorts chronologically; '' is the fallback for
    // any pre-existing record missing the field, sorting it last.
    function recentTrayNotes() {
        var sorted = noteList.slice().sort(function(a, b) {
            var am = a.modified || ""
            var bm = b.modified || ""
            if (am === bm) return 0
            return am < bm ? 1 : -1
        })
        return sorted.slice(0, maxTrayNotes)
    }

    // Callable from the Stickers Panel (no open window required) as well
    // as from an already-open StickerWindow's own pin button -- KWin rules
    // are matched by the "Sticker " + id title string, so this works
    // whether or not that window actually exists right now.
    function togglePinned(id) {
        var sticker = Manager.stickers.find(function(s) { return s.id === id })
        if (!sticker) return
        var newPinned = !sticker.pinned
        Manager.updatePinned(id, newPinned)
        var win = openWindows[id]
        if (win) {
            win.stickerPinned = newPinned
        }
        KWin.KWinBridge.setPinned(id, "Sticker " + id, newPinned)
        refreshNoteList()
    }

    // Panel context menu's "Duplicar" -- mirrors createNewSticker()'s own
    // create-then-open-a-window pattern, the convention every other
    // sticker-creation path in this app already follows.
    function duplicateSticker(id) {
        var copy = Manager.duplicateSticker(id)
        if (!copy) return
        createStickerWindow(copy)
        refreshNoteList()
    }

    function renameSticker(id, name) {
        Manager.updateName(id, name)
        var win = openWindows[id]
        if (win) {
            win.stickerName = name
        }
        refreshNoteList()
    }

    property var activeDeleteDialog: null

    // Kept as a thin compatibility wrapper -- every existing call site
    // (the panel's hover delete icon, its context menu, anywhere else that
    // already knew a single id+label) still works unchanged; it's just a
    // 1-element deleteStickers() call now.
    function confirmDeleteSticker(id, label) {
        deleteStickers([id], label)
    }

    // Closes and destroys each id's open window (if any) and removes it
    // from the model/storage. Pure mechanics, no dialog/undo decision --
    // deleteStickers() below and the confirm dialog's onYesClicked both
    // funnel through here. Returns deep-copied snapshots of what was
    // removed, for the undo toast to restore later.
    function performDelete(ids) {
        var removed = []
        for (var i = 0; i < ids.length; i++) {
            var id = ids[i]
            var sticker = Manager.stickers.find(function(s) { return s.id === id })
            if (sticker) {
                removed.push(JSON.parse(JSON.stringify(sticker)))
            }
            var win = root.openWindows[id]
            if (win) {
                root.unregisterWindow(id)
                win.close()
                win.destroy()
            }
            Manager.removeSticker(id)
        }
        root.refreshNoteList()
        return removed
    }

    property var lastDeletedSnapshot: []
    property string undoMessage: ""
    property bool undoVisible: false

    Timer {
        id: undoTimer
        interval: 6000
        onTriggered: root.undoVisible = false
    }

    function undoDelete() {
        undoVisible = false
        undoTimer.stop()
        for (var i = 0; i < lastDeletedSnapshot.length; i++) {
            Manager.restoreSticker(lastDeletedSnapshot[i])
        }
        lastDeletedSnapshot = []
        refreshNoteList()
    }

    // ids: one or more sticker ids. singleLabel is only used for the
    // confirm dialog's/toast's wording when ids has exactly one entry (a
    // batch delete gets a generic "N stickers" message instead) -- pass
    // anything (even "") for a real multi-id batch.
    //
    // "Confirmar antes de eliminar" ON keeps the old confirm-dialog flow
    // exactly as it always worked. OFF is the new behavior this redesign
    // adds: delete immediately, no dialog, but show an undo toast for a
    // few seconds instead of just silently losing the item with no safety
    // net at all (which is what the OFF path used to do).
    function deleteStickers(ids, singleLabel) {
        if (ids.length === 0) return
        // The tray menu is drawn by plasmashell over DBusMenu, not by this
        // app's own process -- an app-side modal MessageDialog cannot block
        // input to that other process's menu. A user really can reopen the
        // tray menu and trigger a second delete while this dialog is still
        // open; ignore it rather than silently spawning a second one (which
        // would either drop the first request or delete the wrong item
        // while still showing the first request's label).
        if (activeDeleteDialog !== null) {
            return
        }
        if (Settings.get().behavior.askBeforeDeleting) {
            var text = ids.length === 1
                ? "¿Eliminar \"" + singleLabel + "\"? Esta acción no se puede deshacer."
                : "¿Eliminar " + ids.length + " stickers? Esta acción no se puede deshacer."
            // A fresh Platform.MessageDialog per request, destroyed right
            // after it's answered -- reusing one persistent instance across
            // separate delete confirmations left its native standard
            // buttons (Sí/No) stacking up on each successive open() instead
            // of resetting, so a 2nd delete in the same session showed 4
            // buttons, a 3rd showed 6, etc.
            activeDeleteDialog = deleteConfirmDialogComponent.createObject(root, {
                pendingIds: ids,
                text: text
            })
            activeDeleteDialog.open()
            return
        }
        lastDeletedSnapshot = performDelete(ids)
        undoMessage = ids.length === 1
            ? ("\"" + singleLabel + "\" eliminado.")
            : (ids.length + " stickers eliminados.")
        undoVisible = true
        undoTimer.restart()
    }

    Component {
        id: deleteConfirmDialogComponent
        Platform.MessageDialog {
            id: dlg
            property var pendingIds: []
            buttons: Platform.MessageDialog.Yes | Platform.MessageDialog.No
            onYesClicked: {
                root.performDelete(pendingIds)
                root.activeDeleteDialog = null
                dlg.destroy()
            }
            onNoClicked: {
                root.activeDeleteDialog = null
                dlg.destroy()
            }
        }
    }

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

    function openSettingsWindow() {
        settingsWindow.show()
        settingsWindow.raise()
        settingsWindow.requestActivate()
    }

    SettingsWindow {
        id: settingsWindow
        visible: false
        appRoot: root
    }

    Platform.SystemTrayIcon {
        id: trayIcon
        visible: true
        icon.name: "document-properties"
        tooltip: "Desktop Stickers"

        // Only Trigger (single left-click) is handled here -- Context
        // (right-click) already opens `menu:` below automatically and must
        // not be touched; DoubleClick/MiddleClick/Unknown are no-ops.
        onActivated: function(reason) {
            if (reason !== Platform.SystemTrayIcon.Trigger) return
            if (Settings.get().behavior.trayLeftClickAction === "newSticker") {
                root.createNewSticker(100, 100)
            } else {
                root.openStickerPanel()
            }
        }

        menu: Platform.Menu {
            id: trayMenu
            Platform.MenuItem {
                text: "Nuevo sticker"
                onTriggered: root.createNewSticker(100, 100)
            }
            Platform.MenuSeparator { visible: root.noteList.length > 0 }
            // model is the constant maxTrayNotes, not trayNotes -- the
            // Instantiator's row count never changes after the initial
            // maxTrayNotes objects are created, so onObjectAdded/
            // onObjectRemoved (and thus trayMenu.insertItem()/removeItem())
            // never fire again on create/rename/delete. Only each
            // delegate's visible/text properties change, which -- per the
            // README's "Problemas conocidos" -- does not trigger Plasma's
            // spurious tray-menu popup (only structural insert/remove does).
            Instantiator {
                model: root.maxTrayNotes
                delegate: Platform.MenuItem {
                    readonly property int slotIndex: index
                    readonly property bool hasNote: slotIndex < root.trayNotes.length
                    visible: hasNote
                    text: hasNote ? root.trayNotes[slotIndex].label : ""
                    onTriggered: if (hasNote) root.openOrFocusSticker(root.trayNotes[slotIndex].id)
                }
                onObjectAdded: (index, object) => trayMenu.insertItem(index + 2, object)
                onObjectRemoved: (index, object) => trayMenu.removeItem(object)
            }
            Platform.MenuSeparator { visible: root.noteList.length > 0 }
            Platform.MenuItem {
                text: "Panel de Stickers"
                onTriggered: root.openStickerPanel()
            }
            Platform.MenuSeparator {}
            Platform.MenuItem {
                text: "Configuración…"
                onTriggered: root.openSettingsWindow()
            }
            Platform.MenuSeparator {}
            Platform.MenuItem {
                text: "Salir"
                onTriggered: Qt.quit()
            }
        }
    }
}
