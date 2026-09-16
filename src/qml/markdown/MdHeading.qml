import QtQuick
import "../../code/markdownParser.js" as MarkdownParser

Item {
    id: root
    property var node: null
    signal editRequested()
    signal anchorRequested(string slug)

    readonly property var sizes: [22, 19, 17, 15, 14, 13]
    readonly property real topSpacing: node && node.level <= 2 ? 16 : 8

    width: parent ? parent.width : 0
    height: topSpacing + heading.implicitHeight

    MdRichText {
        id: heading
        y: root.topSpacing
        width: root.width
        richText: root.node ? "<b>" + MarkdownParser.renderInline(root.node.inline) + "</b>" : ""
        font.pixelSize: root.node ? root.sizes[root.node.level - 1] : 14
        onEditRequested: root.editRequested()
        onAnchorRequested: (slug) => root.anchorRequested(slug)
    }
}
