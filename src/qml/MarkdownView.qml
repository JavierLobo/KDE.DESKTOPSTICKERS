import QtQuick
import "../code/markdownParser.js" as MarkdownParser

// Rewritten on top of a hand-rolled parser (src/code/markdownParser.js) and
// a delegate per block type (src/qml/markdown/) instead of Qt's
// Text.MarkdownText -- see docs/superpowers/specs/2026-09-16-native-markdown-renderer-design.md
// for why. Public interface (text / editRequested) is unchanged from before
// this rewrite, so StickerWindow.qml needs no edits for this task.
Column {
    id: root
    property string text: ""
    signal editRequested()

    spacing: 6

    readonly property var doc: MarkdownParser.parse(root.text)

    MdBlockList {
        id: blockList
        width: root.width
        blocks: root.doc.blocks
        onEditRequested: root.editRequested()
    }
}
