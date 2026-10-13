import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import StickersApp

// Plain Window, not Dialog/Popup -- same choice already made for
// SettingsWindow/StickerPanel (see their own comments): consistent native
// title bar and window-manager behavior across every secondary window this
// app opens.
Window {
    id: aboutWindow
    // 320 normally; wider only when the button row doesn't fit (its two
    // labels side by side -- Russian's are the longest). Measured off the
    // row, not `content`: the WordWrap description's implicitWidth is its
    // whole unwrapped line, which would stretch the window to fit it.
    readonly property real naturalWidth: Math.max(320, buttonsRow.implicitWidth + 48)
    width: naturalWidth
    // Bound to this independent property, not to `height` itself on both
    // sides -- min/maxHeight tied directly to `height` created a binding
    // loop (Window clamps height into [min,max], which recomputed from the
    // now-different height, which reclamped, ...; confirmed via QML
    // "Binding loop detected for property minimumHeight" at runtime).
    readonly property real naturalHeight: content.implicitHeight + 48
    height: naturalHeight
    minimumWidth: naturalWidth
    minimumHeight: naturalHeight
    maximumWidth: naturalWidth
    maximumHeight: naturalHeight
    title: I18n.t("About.title")
    flags: Qt.Dialog

    SystemPalette { id: pal }

    readonly property string repoUrl: "https://github.com/JavierLobo/KDE.DESKTOPSTICKERS"
    // Set by Main.qml, which owns the one copy of this URL (the tray's
    // Options → "Aportaciones" item uses it too).
    property string donateUrl: ""

    // Called by Main.qml right before show(). Only honored on X11: Wayland
    // gives clients no say over a toplevel's position, and KWin places the
    // window itself there (centered under Plasma 6's default placement).
    function centerOnScreen() {
        x = screen.virtualX + Math.round((screen.width - width) / 2)
        y = screen.virtualY + Math.round((screen.height - height) / 2)
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 24
        spacing: 8

        Label {
            text: I18n.t("Main.tray.tooltip")
            font.pixelSize: 18
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: Qt.application.version
            opacity: 0.6
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: I18n.t("About.description")
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            Layout.topMargin: 8
        }

        RowLayout {
            id: buttonsRow
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            spacing: 8

            Button {
                text: I18n.t("About.viewRepo")
                onClicked: Qt.openUrlExternally(aboutWindow.repoUrl)
            }

            Button {
                text: I18n.t("Main.trayMenu.donate")
                visible: aboutWindow.donateUrl !== ""
                onClicked: Qt.openUrlExternally(aboutWindow.donateUrl)
            }
        }
    }
}
