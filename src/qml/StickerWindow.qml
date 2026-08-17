import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Window {
    id: mainWindow

    property string stickerId: "001"
    property string stickerText: "Nuevo sticker..."
    property string stickerColor: "#FFD700"
    property int posX: 100
    property int posY: 100

    width: 300
    height: 250
    x: posX
    y: posY
    visible: true
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"

    // No per-window multi-desktop registration needed here — the KWin
    // window rule installed in Task 1 (matched by the app's WM_CLASS)
    // covers every window this app creates automatically.

    Rectangle {
        id: stickerContainer
        anchors.fill: parent
        color: stickerColor
        radius: 8

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                id: header
                Layout.fillWidth: true
                Layout.preferredHeight: 35
                color: Qt.darker(stickerColor, 1.3)
                radius: 8

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    // drag.target requires a QQuickItem; mainWindow is a
                    // Window (not an Item), so it cannot be a drag target
                    // directly ("Unable to assign ... to QQuickItem" at
                    // component creation, which aborts the whole window).
                    // Track the press position and move the window manually
                    // instead -- the standard pattern for dragging a
                    // frameless Window by a header MouseArea.
                    property point pressPos: Qt.point(0, 0)

                    onPressed: (mouse) => {
                        pressPos = Qt.point(mouse.x, mouse.y)
                    }
                    onPositionChanged: (mouse) => {
                        mainWindow.x += mouse.x - pressPos.x
                        mainWindow.y += mouse.y - pressPos.y
                    }
                }

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
                        text: "✕"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: mainWindow.close()
                    }
                }
            }

            TextEdit {
                id: textArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: stickerText
                wrapMode: TextEdit.Wrap
                padding: 10
            }
        }
    }
}
