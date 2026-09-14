import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "StickerManager.js" as Manager

Window {
    id: panelWindow
    width: 420
    height: 440
    title: "Panel de stickers"

    property var appRoot: null
    // Which row (by sticker id) is showing its inline rename TextField --
    // at most one at a time, mirrors the old Repeater-based panel's
    // per-row "renaming" flag but has to live here instead, since a
    // ListView delegate can be destroyed/recreated as it scrolls and would
    // lose a plain per-delegate property.
    property string renamingId: ""

    // Multi-select state: a plain JS object used as a set (id -> true),
    // since filteredList is a plain array with no selection-model
    // infrastructure of its own. lastClickedIndex anchors Shift-click
    // range selection.
    property var selectedIds: ({})
    property int lastClickedIndex: -1

    function isSelected(id) {
        return !!selectedIds[id]
    }
    function clearSelection() {
        selectedIds = {}
    }
    function toggleSelected(id) {
        var copy = Object.assign({}, selectedIds)
        if (copy[id]) {
            delete copy[id]
        } else {
            copy[id] = true
        }
        selectedIds = copy
    }
    function selectRange(fromIndex, toIndex) {
        var copy = Object.assign({}, selectedIds)
        var lo = Math.min(fromIndex, toIndex)
        var hi = Math.max(fromIndex, toIndex)
        for (var i = lo; i <= hi; i++) {
            if (filteredList[i]) {
                copy[filteredList[i].id] = true
            }
        }
        selectedIds = copy
    }

    // Entry point for both the keyboard Delete path (below) and anything
    // else that wants to delete "whatever is currently selected, or just
    // the focused row if nothing is". Looks up each id's label itself so
    // callers don't have to.
    function deleteSelectionOrCurrent() {
        var ids = Object.keys(selectedIds)
        if (ids.length === 0 && listView.currentIndex >= 0 && filteredList[listView.currentIndex]) {
            ids = [filteredList[listView.currentIndex].id]
        }
        if (ids.length === 0) return
        var label = ""
        if (ids.length === 1) {
            var found = filteredList.find(function(s) { return s.id === ids[0] })
            label = found ? found.label : ""
        }
        appRoot.deleteStickers(ids, label)
        clearSelection()
    }

    SystemPalette { id: pal }

    // Relative timestamps ("hace 2 h") need to keep advancing while the
    // panel stays open, purely from wall-clock time passing -- nothing
    // about the sticker list itself changes. Ticking this dummy counter
    // is what makes each row's date Label re-evaluate periodically.
    property int clockTick: 0
    Timer {
        interval: 60000
        running: panelWindow.visible
        repeat: true
        onTriggered: panelWindow.clockTick++
    }

    // Sizes to content up to a reasonable cap, then the ListView scrolls
    // instead of the window growing further -- recomputed each time the
    // panel is shown (not a continuous live binding on `height`, which
    // would fight a user's own manual resize mid-session) since that's
    // also the one moment a stale size from before stickers were
    // added/removed is guaranteed to have settled.
    readonly property int rowHeight: 52
    readonly property int maxVisibleRows: 8
    function idealHeight() {
        var toolbarH = 56
        var footerH = 34
        var rows = Math.max(1, Math.min(listView.count, maxVisibleRows))
        return toolbarH + rows * rowHeight + footerH
    }
    onVisibleChanged: if (visible) height = idealHeight()

    // Filtering/sorting is plain JS over the (small, in the hundreds at
    // most) noteList array rather than a QAbstractListModel + proxy --
    // this toolkit has no such proxy in place today (noteList is a plain
    // property array, not a real model) and building one would be a much
    // larger architectural change than this redesign calls for. A few
    // hundred string comparisons per keystroke is sub-millisecond work, so
    // a plain re-filter is not the performance risk the brief is warning
    // against; it just has to not be O(n²) or re-fetch from disk, which it
    // isn't -- it only ever reads the already-in-memory noteList.
    //
    // A genuine QML property binding (not an imperative refresh function)
    // so it automatically re-evaluates whenever any of its dependencies
    // (appRoot.noteList, the search text, the sort mode) change.
    property var filteredList: computeFilteredList()

    function computeFilteredList() {
        var list = appRoot ? appRoot.noteList : []
        var query = searchField.text.trim().toLowerCase()
        if (query.length > 0) {
            list = list.filter(function(s) {
                return (s.label && s.label.toLowerCase().indexOf(query) !== -1)
                    || (s.text && s.text.toLowerCase().indexOf(query) !== -1)
            })
        }
        var sorted = list.slice()
        if (sortCombo.currentIndex === 1) {
            sorted.sort(function(a, b) { return a.label.localeCompare(b.label) })
        } else if (sortCombo.currentIndex === 2) {
            sorted.sort(function(a, b) { return a.color.localeCompare(b.color) })
        } else {
            // "Recientes" (default): most recently modified first. Same
            // ordering Main.qml's own recentTrayNotes() uses for the tray
            // menu, just without that function's maxTrayNotes cap.
            sorted.sort(function(a, b) {
                var am = a.modified || ""
                var bm = b.modified || ""
                if (am === bm) return 0
                return am < bm ? 1 : -1
            })
        }
        return sorted
    }

    Shortcut {
        sequence: "Ctrl+F"
        onActivated: searchField.forceActiveFocus()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 10
            spacing: 8

            Label {
                text: "🔍"
                opacity: 0.6
            }
            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: "Buscar en los stickers"
                Keys.onEscapePressed: text = ""
            }
            ComboBox {
                id: sortCombo
                Layout.preferredWidth: 130
                model: ["Recientes", "Alfabético", "Color"]
            }
            Button {
                text: "+ Nuevo"
                highlighted: true
                onClicked: appRoot.createNewSticker(panelWindow.x, panelWindow.y)
                Accessible.name: "Crear un sticker nuevo"
            }
        }

        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: filteredList
            boundsBehavior: Flickable.StopAtBounds
            focus: true
            currentIndex: -1

            Keys.onUpPressed: currentIndex = currentIndex <= 0 ? 0 : currentIndex - 1
            Keys.onDownPressed: currentIndex = Math.min(count - 1, currentIndex + 1)
            Keys.onReturnPressed: {
                if (currentIndex >= 0 && filteredList[currentIndex]) {
                    appRoot.openOrFocusSticker(filteredList[currentIndex].id)
                }
            }
            Keys.onDeletePressed: panelWindow.deleteSelectionOrCurrent()

            // Two different empty states: a search that matched nothing
            // is not the same situation as there being no stickers at all.
            ColumnLayout {
                anchors.centerIn: parent
                visible: listView.count === 0
                spacing: 10
                width: Math.min(parent.width - 40, 260)

                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    opacity: 0.7
                    font.italic: true
                    text: (appRoot && appRoot.noteList.length === 0)
                        ? "No hay stickers todavía."
                        : "Sin resultados para «" + searchField.text + "»."
                }
                Button {
                    Layout.alignment: Qt.AlignHCenter
                    visible: appRoot && appRoot.noteList.length === 0
                    text: "Crear el primero"
                    highlighted: true
                    onClicked: appRoot.createNewSticker(panelWindow.x, panelWindow.y)
                }
                Button {
                    Layout.alignment: Qt.AlignHCenter
                    visible: appRoot && appRoot.noteList.length > 0
                    text: "Limpiar búsqueda"
                    flat: true
                    onClicked: searchField.text = ""
                }
            }

            delegate: Item {
                id: rowItem
                required property var modelData
                required property int index
                width: listView.width
                height: 52

                readonly property bool renaming: panelWindow.renamingId === modelData.id
                readonly property bool selected: panelWindow.isSelected(modelData.id)
                readonly property bool current: listView.currentIndex === index

                Rectangle {
                    anchors.fill: parent
                    color: rowItem.selected ? pal.highlight
                           : ((rowItem.current || rowMouse.containsMouse) ? pal.alternateBase : "transparent")
                    opacity: rowItem.selected ? 0.35 : 1.0
                }

                // 3px color stripe on the row's left edge, the sticker's
                // real color -- replaces the old round color dot.
                Rectangle {
                    width: 3
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    color: rowItem.modelData.color
                }

                // Declared BEFORE (so it sits behind, in hit-test terms)
                // the RowLayout's Buttons below -- a MouseArea occluded by
                // an interactive child Control reliably does not also see
                // that control's own clicks, which is what keeps "click
                // the delete icon" from also opening the sticker.
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            listView.currentIndex = rowItem.index
                            contextMenu.popup()
                            return
                        }
                        if (rowItem.renaming) return
                        listView.currentIndex = rowItem.index
                        if (mouse.modifiers & Qt.ControlModifier) {
                            panelWindow.toggleSelected(rowItem.modelData.id)
                            panelWindow.lastClickedIndex = rowItem.index
                        } else if ((mouse.modifiers & Qt.ShiftModifier) && panelWindow.lastClickedIndex >= 0) {
                            panelWindow.selectRange(panelWindow.lastClickedIndex, rowItem.index)
                        } else {
                            panelWindow.clearSelection()
                            panelWindow.lastClickedIndex = rowItem.index
                            appRoot.openOrFocusSticker(rowItem.modelData.id)
                        }
                    }

                    ToolTip.visible: containsMouse && !rowItem.renaming
                                      && !pinButton.hovered && !deleteButton.hovered
                    ToolTip.text: "#" + rowItem.modelData.id
                    ToolTip.delay: 600
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 15
                    anchors.rightMargin: 8
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        visible: !rowItem.renaming

                        Label {
                            text: rowItem.modelData.hasTitle ? rowItem.modelData.label : "Sin título"
                            font.italic: !rowItem.modelData.hasTitle
                            opacity: rowItem.modelData.hasTitle ? 1.0 : 0.6
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            // clockTick is read only to establish the
                            // re-evaluation dependency -- its value itself
                            // is unused.
                            text: {
                                panelWindow.clockTick
                                var date = Manager.formatRelativeDate(rowItem.modelData.modified)
                                var snippet = rowItem.modelData.snippet
                                return snippet.length > 0 ? (snippet + "  ·  " + date) : date
                            }
                            elide: Text.ElideRight
                            font.pixelSize: 11
                            opacity: 0.6
                            Layout.fillWidth: true
                        }
                    }

                    TextField {
                        id: renameField
                        visible: rowItem.renaming
                        Layout.fillWidth: true
                        text: rowItem.modelData.name

                        onAccepted: focus = false
                        onActiveFocusChanged: {
                            if (activeFocus || !rowItem.renaming) return
                            // renameSticker() calls Main.qml's
                            // refreshNoteList(), which reassigns noteList
                            // and, through filteredList's binding, this
                            // ListView's own `model` -- a plain-array model
                            // gets fully torn down and rebuilt on that, so
                            // calling it synchronously from THIS delegate's
                            // own handler destroys rowItem/renameField
                            // mid-execution, leaving the row stuck showing
                            // the edit field forever (confirmed: this is
                            // exactly what was happening). Turning off
                            // renaming first is safe -- it only affects
                            // this delegate's own visible/renaming
                            // bindings, not the model -- and deferring the
                            // model-touching call with Qt.callLater() lets
                            // this handler finish and the delegate settle
                            // before that rebuild happens.
                            var pendingId = rowItem.modelData.id
                            var pendingText = text
                            panelWindow.renamingId = ""
                            Qt.callLater(function() {
                                appRoot.renameSticker(pendingId, pendingText)
                            })
                        }
                    }

                    RowLayout {
                        spacing: 2
                        // Visible on hover, keyboard focus (Tab), or when
                        // this row is the ListView's current (arrow-key
                        // navigated) row -- never while renaming, the text
                        // field takes that space instead.
                        visible: (rowMouse.containsMouse || rowItem.current || pinButton.activeFocus || deleteButton.activeFocus)
                                 && !rowItem.renaming

                        Button {
                            id: pinButton
                            text: rowItem.modelData.pinned ? "📌" : "📍"
                            flat: true
                            implicitWidth: 26
                            implicitHeight: 26
                            onClicked: appRoot.togglePinned(rowItem.modelData.id)
                            Accessible.name: rowItem.modelData.pinned
                                ? "Quitar \"" + rowItem.modelData.label + "\" de todos los escritorios"
                                : "Fijar \"" + rowItem.modelData.label + "\" en todos los escritorios"
                            ToolTip.visible: hovered
                            ToolTip.text: rowItem.modelData.pinned ? "Quitar de todos los escritorios" : "Fijar en todos los escritorios"
                            ToolTip.delay: 400
                        }
                        Button {
                            id: deleteButton
                            text: "🗑"
                            flat: true
                            implicitWidth: 26
                            implicitHeight: 26
                            onClicked: appRoot.confirmDeleteSticker(rowItem.modelData.id, rowItem.modelData.label)
                            Accessible.name: "Eliminar \"" + rowItem.modelData.label + "\""
                            ToolTip.visible: hovered
                            ToolTip.text: "Eliminar"
                            ToolTip.delay: 400
                        }
                    }
                }

                Menu {
                    id: contextMenu

                    MenuItem {
                        text: "Abrir"
                        onTriggered: appRoot.openOrFocusSticker(rowItem.modelData.id)
                    }
                    MenuItem {
                        text: rowItem.modelData.pinned ? "Quitar de todos los escritorios" : "Fijar en todos los escritorios"
                        onTriggered: appRoot.togglePinned(rowItem.modelData.id)
                    }
                    MenuItem {
                        text: "Eliminar"
                        onTriggered: appRoot.confirmDeleteSticker(rowItem.modelData.id, rowItem.modelData.label)
                    }
                    MenuSeparator {}
                    MenuItem {
                        text: "Renombrar"
                        onTriggered: {
                            panelWindow.renamingId = rowItem.modelData.id
                            renameField.forceActiveFocus()
                            renameField.selectAll()
                        }
                    }
                    MenuItem {
                        text: "Duplicar"
                        onTriggered: appRoot.duplicateSticker(rowItem.modelData.id)
                    }
                    MenuSeparator {}
                    MenuItem {
                        enabled: false
                        text: "#" + rowItem.modelData.id
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: appRoot && appRoot.undoVisible
            color: pal.alternateBase
            implicitHeight: undoRow.implicitHeight + 12

            RowLayout {
                id: undoRow
                anchors.fill: parent
                anchors.margins: 8
                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: appRoot ? appRoot.undoMessage : ""
                }
                Button {
                    text: "Deshacer"
                    flat: true
                    onClicked: appRoot.undoDelete()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: pal.mid
        }

        Label {
            Layout.margins: 10
            text: filteredList.length + (filteredList.length === 1 ? " sticker" : " stickers")
                  + "  ·  Intro abre  ·  Supr elimina"
            opacity: 0.6
            font.pixelSize: 11
        }
    }
}
