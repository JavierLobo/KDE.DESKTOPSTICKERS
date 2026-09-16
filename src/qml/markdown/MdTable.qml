import QtQuick
import "../../code/markdownParser.js" as MarkdownParser

// Two sibling Repeaters (header cells, then every body cell flattened
// row-major) inside one Grid: QML's Grid treats a Repeater's generated items
// as ordinary in-place children, so the header's `columns` items fill the
// first row and the body repeater's items continue filling subsequent rows
// -- no manual row bookkeeping needed.
Rectangle {
    id: root
    property var node: null
    signal editRequested()
    signal anchorRequested(string slug)

    readonly property int columns: node && node.head.length > 0 ? node.head.length : 1
    readonly property var flatCells: {
        var out = []
        if (node) {
            for (var r = 0; r < node.rows.length; r++) {
                out = out.concat(node.rows[r])
            }
        }
        return out
    }

    function alignFor(i) {
        if (!node || !node.align[i]) return Text.AlignLeft
        if (node.align[i] === "center") return Text.AlignHCenter
        if (node.align[i] === "right") return Text.AlignRight
        return Text.AlignLeft
    }

    width: parent ? parent.width : 0
    height: grid.implicitHeight + 2
    color: "transparent"
    border.color: "#33000000"
    border.width: 1
    radius: 4

    Grid {
        id: grid
        columns: root.columns
        width: root.width - 2
        x: 1
        y: 1

        Repeater {
            model: root.node ? root.node.head : []
            delegate: Rectangle {
                width: grid.width / root.columns
                height: headCell.implicitHeight + 12
                color: "#22000000"
                MdRichText {
                    id: headCell
                    anchors.fill: parent
                    anchors.margins: 6
                    richText: "<b>" + MarkdownParser.renderInline(modelData) + "</b>"
                    horizontalAlignment: root.alignFor(index)
                    onEditRequested: root.editRequested()
                    onAnchorRequested: (slug) => root.anchorRequested(slug)
                }
            }
        }

        Repeater {
            model: root.flatCells
            delegate: Rectangle {
                width: grid.width / root.columns
                height: bodyCell.implicitHeight + 12
                color: (Math.floor(index / root.columns) % 2 === 1) ? "#11000000" : "transparent"
                MdRichText {
                    id: bodyCell
                    anchors.fill: parent
                    anchors.margins: 6
                    richText: MarkdownParser.renderInline(modelData)
                    horizontalAlignment: root.alignFor(index % root.columns)
                    onEditRequested: root.editRequested()
                    onAnchorRequested: (slug) => root.anchorRequested(slug)
                }
            }
        }
    }
}
