import QtQuick

// Bullet/ordered items normally; a checkbox marker instead when the item
// carries `task` (set by markdownParser.js for "- [ ]"/"- [x]" items).
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

            Loader {
                id: markerLoader
                sourceComponent: modelData.task ? checkboxComp : bulletComp
            }

            Component {
                id: bulletComp
                Text {
                    text: root.node.ordered ? (root.node.start + index) + "." : "•"
                    font.pixelSize: 13
                    color: "#222"
                }
            }

            Component {
                id: checkboxComp
                Text {
                    text: modelData.task.checked ? "☑" : "☐"
                    font.pixelSize: 13
                    color: modelData.task.checked ? "#1a7f37" : "#222"
                }
            }

            MdBlockList {
                width: itemRow.width - markerLoader.width - itemRow.spacing
                blocks: modelData.blocks
                onEditRequested: root.editRequested()
                onAnchorRequested: (slug) => root.anchorRequested(slug)
            }
        }
    }
}
