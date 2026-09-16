import QtQuick

// Footnotes section appended at the end of the document. Each entry shows
// its own source id (e.g. "[1]", "[nota]") rather than a renumbered
// sequential index -- simpler, and every inline footnote_ref already shows
// that same id (see markdownParser.js's renderRun), so they always match.
Column {
    id: root
    property var footnotes: ({})
    signal editRequested()
    signal backrefRequested(string id)

    readonly property var ids: Object.keys(root.footnotes)

    spacing: 8
    topPadding: ids.length > 0 ? 12 : 0

    Rectangle {
        visible: root.ids.length > 0
        width: parent.width
        height: 1
        color: "#33000000"
    }

    Repeater {
        model: root.ids
        delegate: Column {
            width: root.width
            spacing: 2

            Row {
                spacing: 10
                Text {
                    text: "[" + modelData + "]"
                    font.pixelSize: 11
                    color: "#666"
                }
                Text {
                    text: "↩ volver"
                    font.pixelSize: 11
                    color: "#0550ae"
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.backrefRequested(modelData)
                    }
                }
            }

            MdBlockList {
                x: 16
                width: parent.width - 16
                blocks: root.footnotes[modelData]
                onEditRequested: root.editRequested()
            }
        }
    }
}
