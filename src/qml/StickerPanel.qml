import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

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

                Text {
                    visible: appRoot && appRoot.noteList.length === 0
                    text: "No hay stickers todavía."
                    color: "#666"
                    font.italic: true
                }

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
                                    appRoot.renameSticker(modelData.id, text)
                                    row.renaming = false
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
