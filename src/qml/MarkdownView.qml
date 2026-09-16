import QtQuick
import "../code/markdownParser.js" as MarkdownParser

// Rewritten on top of a hand-rolled parser (src/code/markdownParser.js) and
// a delegate per block type (src/qml/markdown/) instead of Qt's
// Text.MarkdownText -- see docs/superpowers/specs/2026-09-16-native-markdown-renderer-design.md
// for why. Public interface (text / editRequested) is unchanged from before
// this rewrite; `scrollRequested` is new, for StickerWindow.qml to scroll
// its ScrollView when an internal anchor link or footnote backref is
// clicked (heading anchors and footnote backrefs only resolve for
// *top-level* blocks -- see MdBlockList.yForIndex()).
Column {
    id: root
    property string text: ""
    signal editRequested()
    signal scrollRequested(real y)

    spacing: 6

    readonly property var doc: MarkdownParser.parse(root.text)

    function scrollToSlug(slug) {
        for (var i = 0; i < root.doc.blocks.length; i++) {
            if (root.doc.blocks[i].type === "heading" && root.doc.blocks[i].slug === slug) {
                root.scrollRequested(blockList.yForIndex(i))
                return
            }
        }
    }

    function scrollToFootnoteRef(id) {
        var idx = MarkdownParser.findTopLevelBlockIndexForFootnoteRef(root.doc.blocks, id)
        if (idx !== -1) {
            root.scrollRequested(blockList.yForIndex(idx))
        }
    }

    // Front matter (--- ... --- at the very start of the source, see
    // extractFrontMatter()) is shown as a small metadata box instead of
    // leaking as literal "---\nkey: value\n---" text.
    Column {
        width: root.width
        visible: root.doc.frontMatter !== null
        spacing: 2

        Repeater {
            model: root.doc.frontMatter ? root.doc.frontMatter.split(/\r?\n/) : []
            delegate: Row {
                readonly property var parts: /^([A-Za-z0-9_-]+):\s*(.*)$/.exec(modelData)
                spacing: 6
                Text {
                    text: parts ? parts[1] + ":" : ""
                    font.bold: true
                    font.pixelSize: 12
                    color: "#666"
                }
                Text {
                    text: parts ? parts[2] : modelData
                    font.pixelSize: 12
                    color: "#666"
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: "#33000000"
        }
    }

    MdBlockList {
        id: blockList
        width: root.width
        blocks: root.doc.blocks
        onEditRequested: root.editRequested()
        onAnchorRequested: (slug) => root.scrollToSlug(slug)
    }

    MdFootnotes {
        width: root.width
        visible: Object.keys(root.doc.footnotes).length > 0
        footnotes: root.doc.footnotes
        onEditRequested: root.editRequested()
        onBackrefRequested: (id) => root.scrollToFootnoteRef(id)
    }
}
