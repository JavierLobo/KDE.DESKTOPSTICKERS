import QtQuick
import "../../code/markdownParser.js" as MarkdownParser

Column {
    id: root
    property var node: null
    signal editRequested()

    spacing: 2

    Repeater {
        model: root.node ? root.node.items : []
        delegate: Column {
            width: root.width
            spacing: 2

            MdRichText {
                width: parent.width
                richText: "<b>" + MarkdownParser.renderInline(modelData.term) + "</b>"
                onEditRequested: root.editRequested()
            }

            Repeater {
                model: modelData.defs
                delegate: MdRichText {
                    x: 16
                    width: parent.width - 16
                    richText: MarkdownParser.renderInline(modelData)
                    onEditRequested: root.editRequested()
                }
            }
        }
    }
}
