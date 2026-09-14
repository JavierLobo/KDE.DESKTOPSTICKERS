import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One labeled row inside a SettingsSection: a label (with an optional
// smaller, muted subtitle line below it) on the left, and one or more
// controls on the right, packed into a RowLayout so a row can hold e.g. a
// copy icon button next to an "Abrir" button. Draws its own bottom
// separator -- callers set `separator: false` on the last row in a group.
Item {
    id: row

    property string label: ""
    property string subtitle: ""
    property bool separator: true
    default property alias content: controlRow.data

    SystemPalette { id: pal }

    Layout.fillWidth: true
    implicitHeight: Math.max(labelColumn.implicitHeight, controlRow.implicitHeight) + 20

    RowLayout {
        id: mainRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        ColumnLayout {
            id: labelColumn
            Layout.fillWidth: true
            spacing: 2

            Label {
                text: row.label
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }
            Label {
                text: row.subtitle
                visible: row.subtitle.length > 0
                font.pixelSize: 11
                opacity: 0.65
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }
        }

        RowLayout {
            id: controlRow
            spacing: 8
            Layout.alignment: Qt.AlignVCenter
        }
    }

    Rectangle {
        visible: row.separator
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        height: 1
        color: pal.mid
    }
}
