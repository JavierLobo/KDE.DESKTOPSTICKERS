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
    width: 320
    // Bound to this independent property, not to `height` itself on both
    // sides -- min/maxHeight tied directly to `height` created a binding
    // loop (Window clamps height into [min,max], which recomputed from the
    // now-different height, which reclamped, ...; confirmed via QML
    // "Binding loop detected for property minimumHeight" at runtime).
    readonly property real naturalHeight: content.implicitHeight + 48
    height: naturalHeight
    minimumWidth: 320
    minimumHeight: naturalHeight
    maximumWidth: 320
    maximumHeight: naturalHeight
    title: I18n.t("About.title")
    flags: Qt.Dialog

    SystemPalette { id: pal }

    readonly property string repoUrl: "https://github.com/JavierLobo/KDE.DESKTOPSTICKERS"

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

        Button {
            text: I18n.t("About.viewRepo")
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            onClicked: Qt.openUrlExternally(aboutWindow.repoUrl)
        }
    }
}
