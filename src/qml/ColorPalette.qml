import QtQuick
import QtQuick.Layouts
import Qt.labs.platform as Platform

Item {
    id: root

    signal colorSelected(color selectedColor)

    readonly property var swatchColors: [
        "#FFD700", "#87CEEB", "#FFB6C1",
        "#FFA07A", "#98FB98", "#DDA0DD"
    ]

    implicitWidth: swatchRow.implicitWidth
    implicitHeight: swatchRow.implicitHeight

    RowLayout {
        id: swatchRow
        spacing: 6

        Repeater {
            model: root.swatchColors
            delegate: Rectangle {
                width: 24
                height: 24
                radius: 12
                color: modelData
                border.color: "#555"
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.colorSelected(modelData)
                }
            }
        }

        Rectangle {
            width: 24
            height: 24
            radius: 12
            color: "transparent"
            border.color: "#555"
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "+"
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                onClicked: customColorDialog.open()
            }
        }
    }

    Platform.ColorDialog {
        id: customColorDialog
        onAccepted: root.colorSelected(color)
    }
}
