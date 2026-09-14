import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A titled group of SettingsRow instances (or other content) inside a
// bordered, rounded container -- the vertical building block of the
// Settings window. Spacing follows the redesign's scale: 12px between rows
// (handled by each row's own height/separator), 24px is left to the caller
// between sections (ColumnLayout.spacing on the parent).
ColumnLayout {
    id: section

    property string title: ""
    property string subtitle: ""
    default property alias rows: rowsColumn.data

    SystemPalette { id: pal }

    Layout.fillWidth: true
    spacing: 6

    Label {
        text: section.title
        font.bold: true
        font.pixelSize: 15
    }
    Label {
        text: section.subtitle
        visible: section.subtitle.length > 0
        font.pixelSize: 12
        opacity: 0.65
        Layout.fillWidth: true
        wrapMode: Text.Wrap
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 4
        implicitHeight: rowsColumn.implicitHeight
        radius: 8
        // Subtle card depth against the window background (mockup's
        // surface-1/surface-2 contrast) -- was fully transparent, which
        // made every section read as flat, borderless text on the same
        // background as the window itself.
        color: pal.base
        border.width: 1
        border.color: pal.mid
        clip: true

        ColumnLayout {
            id: rowsColumn
            width: parent.width
            spacing: 0
        }
    }
}
