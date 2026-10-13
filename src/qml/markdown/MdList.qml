import QtQuick

// Bullet/ordered items normally; a checkbox marker instead when the item
// carries `task` (set by markdownParser.js for "- [ ]"/"- [x]" items).
// Recurses into MdBlockList per item, so nested lists, quotes, and code
// blocks inside a list item work through the same dispatch as everything
// else.
//
// Nested lists (listDepth > 0) are drawn differently from top-level ones:
// - a bullet list's sub-items use "-" instead of "•", indented by the width
//   of 4 spaces;
// - an ordered list nested in an ordered item continues its parent's number
//   path instead of restarting at "1.": "1." > "1.1" > "1.2.1" ...
// listDepth/listPath are set by the enclosing MdBlockList (see its wireItem()).
Column {
    id: root
    property var node: null
    property int listDepth: 0
    // Number path of the enclosing ordered item ("1", "1.2"), or "" when the
    // parent isn't an ordered item -- then numbering restarts as usual.
    property string listPath: ""
    signal editRequested()
    signal anchorRequested(string slug)

    spacing: 4
    leftPadding: root.listDepth > 0 ? indentMetrics.advanceWidth : 0

    TextMetrics {
        id: indentMetrics
        font.family: "Sans Serif"
        font.pixelSize: 14
        text: "    "
    }

    function itemPath(index) {
        var n = root.node.start + index
        return root.listPath !== "" ? root.listPath + "." + n : String(n)
    }

    function markerFor(index) {
        if (!root.node.ordered) return root.listDepth > 0 ? "-" : "•"
        // Top level keeps the trailing dot ("1."), nested paths don't ("1.1").
        return root.listPath !== "" ? itemPath(index) : itemPath(index) + "."
    }

    Repeater {
        model: root.node ? root.node.items : []
        delegate: Row {
            id: itemRow
            width: root.width - root.leftPadding
            spacing: 6

            Loader {
                id: markerLoader
                sourceComponent: modelData.task ? checkboxComp : bulletComp
            }

            Component {
                id: bulletComp
                Text {
                    text: root.markerFor(index)
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
                listDepth: root.listDepth + 1
                listPath: root.node.ordered ? root.itemPath(index) : ""
                onEditRequested: root.editRequested()
                onAnchorRequested: (slug) => root.anchorRequested(slug)
            }
        }
    }
}
