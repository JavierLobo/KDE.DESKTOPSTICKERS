import QtQuick

// GitHub-style callout: a blockquote whose node.calloutType is set (see
// markdownParser.js's blockquote parsing). Uses the same semi-transparent
// overlay pattern as every other box in this renderer (never an opaque flat
// color) because a sticker's background is an arbitrary user-chosen color,
// not a light/dark system theme.
Item {
    id: root
    property var node: null
    signal editRequested()
    signal anchorRequested(string slug)

    readonly property var meta: ({
        NOTE:      { icon: "ℹ️", label: "Note",      color: "#0550ae" },
        TIP:       { icon: "💡", label: "Tip",       color: "#1a7f37" },
        IMPORTANT: { icon: "❗",       label: "Important", color: "#8250df" },
        WARNING:   { icon: "⚠️", label: "Warning",   color: "#9a6700" },
        CAUTION:   { icon: "🛑", label: "Caution",   color: "#cf222e" }
    })
    readonly property var current: node ? meta[node.calloutType] : null

    width: parent ? parent.width : 0
    height: column.implicitHeight + 16

    Rectangle {
        anchors.fill: parent
        color: "#14000000"
        radius: 6
    }

    Rectangle {
        width: 4
        height: parent.height
        radius: 2
        color: root.current ? root.current.color : "#888"
    }

    Column {
        id: column
        x: 14
        y: 8
        width: root.width - 26
        spacing: 4

        Row {
            spacing: 6
            Text {
                text: root.current ? root.current.icon : ""
                font.pixelSize: 14
            }
            Text {
                text: root.current ? root.current.label : ""
                font.pixelSize: 13
                font.bold: true
                color: root.current ? root.current.color : "#222"
            }
        }

        MdBlockList {
            width: column.width
            blocks: root.node ? root.node.blocks : []
            onEditRequested: root.editRequested()
            onAnchorRequested: (slug) => root.anchorRequested(slug)
        }
    }
}
