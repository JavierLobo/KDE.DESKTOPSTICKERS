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

            Label {
                anchors.centerIn: parent
                visible: listView.count === 0
                text: "No hay stickers todavía."
                opacity: 0.6
                font.italic: true
            }

            delegate: Item {
                id: rowItem
                required property var modelData
                required property int index
                width: listView.width
                height: 52

                readonly property bool renaming: panelWindow.renamingId === modelData.id

                Rectangle {
                    anchors.fill: parent
                    color: rowMouse.containsMouse ? pal.alternateBase : "transparent"
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
                            contextMenu.popup()
                        } else if (!rowItem.renaming) {
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
                            if (!activeFocus && rowItem.renaming) {
                                appRoot.renameSticker(rowItem.modelData.id, text)
                                panelWindow.renamingId = ""
                            }
                        }
                    }

                    RowLayout {
                        spacing: 2
                        // Visible on hover OR keyboard focus (Tab still
                        // reaches these buttons even without the panel's
                        // own up/down row navigation, which is separate,
                        // later work) -- never while renaming, the text
                        // field takes that space instead.
                        visible: (rowMouse.containsMouse || pinButton.activeFocus || deleteButton.activeFocus)
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
            height: 1
            color: pal.mid
        }

        Label {
            Layout.margins: 10
            text: filteredList.length + (filteredList.length === 1 ? " sticker" : " stickers")
            opacity: 0.6
            font.pixelSize: 11
        }
    }
}
