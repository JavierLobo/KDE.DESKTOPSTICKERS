import QtQuick
import Qt.labs.platform as Platform
import "StickerManager.js" as Manager

Item {
    id: root

    property var openWindows: ({})
    property var noteList: []
    property int notePage: 0
    readonly property int notePageSize: 10

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
            return { id: s.id, name: s.name, label: Manager.displayName(s), color: s.color }
        })
        var maxPage = Math.max(0, Math.ceil(noteList.length / notePageSize) - 1)
        if (notePage > maxPage) {
            notePage = maxPage
        }
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

    function confirmDeleteSticker(id, label) {
        // The tray menu is drawn by plasmashell over DBusMenu, not by this
        // app's own process -- an app-side modal MessageDialog cannot block
        // input to that other process's menu. A user really can reopen the
        // tray menu and trigger a second delete while this dialog is still
        // open; ignore it rather than silently overwriting pendingId (which
        // would either drop the first request or make "Sí" delete the
        // wrong note while still showing the first note's label).
        if (deleteConfirmDialog.pendingId !== "") {
            return
        }
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
            pendingId = ""
        }
        onNoClicked: pendingId = ""
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
}
