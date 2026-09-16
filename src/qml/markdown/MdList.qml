import QtQuick

// Recurses into MdBlockList per item, so nested lists, quotes, and code
// blocks inside a list item work through the same dispatch as everything
// else.
Column {
    id: root
    property var node: null
    signal editRequested()
    signal anchorRequested(string slug)

    spacing: 4

    Repeater {
        model: root.node ? root.node.items : []
        delegate: Row {
            id: itemRow
            width: root.width
            spacing: 6

            Text {
                id: marker
                text: root.node.ordered ? (root.node.start + index) + "." : "•"
                font.pixelSize: 13
                color: "#222"
            }

            MdBlockList {
                width: itemRow.width - marker.implicitWidth - itemRow.spacing
                blocks: modelData.blocks
                onEditRequested: root.editRequested()
                onAnchorRequested: (slug) => root.anchorRequested(slug)
            }
        }
    }
}
