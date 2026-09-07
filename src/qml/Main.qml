import QtQuick
import Qt.labs.platform as Platform
import "StickerManager.js" as Manager

Item {
    id: root

    property var openWindows: ({})
    property var noteList: []
    property var trayNotes: []
    readonly property int maxTrayNotes: 10

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
            return { id: s.id, name: s.name, label: Manager.displayName(s), color: s.color, modified: s.modified }
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

    function renameSticker(id, name) {
        Manager.updateName(id, name)
        var win = openWindows[id]
        if (win) {
            win.stickerName = name
        }
        refreshNoteList()
    }

    property var activeDeleteDialog: null

    function confirmDeleteSticker(id, label) {
        // The tray menu is drawn by plasmashell over DBusMenu, not by this
        // app's own process -- an app-side modal MessageDialog cannot block
        // input to that other process's menu. A user really can reopen the
        // tray menu and trigger a second delete while this dialog is still
        // open; ignore it rather than silently spawning a second one (which
        // would either drop the first request or make "Sí" delete the
        // wrong note while still showing the first note's label).
        if (activeDeleteDialog !== null) {
            return
        }
        // A fresh Platform.MessageDialog per request, destroyed right after
        // it's answered -- reusing one persistent instance across separate
        // delete confirmations left its native standard buttons (Sí/No)
        // stacking up on each successive open() instead of resetting, so a
        // 2nd delete in the same session showed 4 buttons, a 3rd showed 6,
        // etc. (see bug report: repeated deletes -> growing rows of Sí/No).
        activeDeleteDialog = deleteConfirmDialogComponent.createObject(root, {
            pendingId: id,
            text: "¿Eliminar \"" + label + "\"? Esta acción no se puede deshacer."
        })
        activeDeleteDialog.open()
    }

    Component {
        id: deleteConfirmDialogComponent
        Platform.MessageDialog {
            id: dlg
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
                text: "Salir"
                onTriggered: Qt.quit()
            }
        }
    }
}
