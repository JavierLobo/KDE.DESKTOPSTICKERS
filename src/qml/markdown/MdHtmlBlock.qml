import QtQuick
import "../../code/markdownParser.js" as MarkdownParser

// Renders the two "html_block" tags the parser produces (a raw HTML
// <table> is converted straight to a "table" node instead, so it never
// reaches here -- see markdownParser.js's parseHtmlTable). <details> is a
// real expand/collapse; <div align="..."> is just its inline content,
// aligned.
Item {
    id: root
    property var node: null
    property bool expanded: false
    signal editRequested()
    signal anchorRequested(string slug)

    readonly property bool isDetails: node && node.tag === "details"

    width: parent ? parent.width : 0
    height: isDetails ? detailsColumn.implicitHeight : (node ? divText.implicitHeight + 16 : 0)

    Column {
        id: detailsColumn
        visible: root.isDetails
        width: root.width
        spacing: 6

        Rectangle {
            width: parent.width
            height: summaryText.implicitHeight + 12
            color: "#22000000"
            radius: 4

            Row {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 6

                Text {
                    text: root.expanded ? "▼" : "▶"
                    font.pixelSize: 12
                    color: "#222"
                }
                MdRichText {
                    id: summaryText
                    width: parent.width - 20
                    // Guarded on isDetails, not just on `node`: a <div> node is
                    // truthy but carries `inline`, not `summaryInline`, so the
                    // unguarded form called renderInline(undefined) and threw
                    // "Cannot call method 'map' of undefined" for every <div>.
                    richText: root.isDetails ? "<b>" + MarkdownParser.renderInline(root.node.summaryInline) + "</b>" : ""
                    onEditRequested: root.editRequested()
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.expanded = !root.expanded
            }
        }

        MdBlockList {
            width: detailsColumn.width
            visible: root.expanded
            blocks: root.isDetails ? root.node.children : []
            onEditRequested: root.editRequested()
            onAnchorRequested: (slug) => root.anchorRequested(slug)
        }
    }

    MdRichText {
        id: divText
        visible: !root.isDetails
        // left/right/top, never `fill`: root.height depends on
        // divText.implicitHeight, so filling the parent would make the height
        // depend on itself ("Binding loop detected"). Same pattern as
        // MdCodeBlock.qml's Column.
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        horizontalAlignment: root.node && root.node.attrs && root.node.attrs.align === "center" ? Text.AlignHCenter : Text.AlignLeft
        richText: !root.isDetails && root.node ? MarkdownParser.renderInline(root.node.inline) : ""
        onEditRequested: root.editRequested()
    }
}
