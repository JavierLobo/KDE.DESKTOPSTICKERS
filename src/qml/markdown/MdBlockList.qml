import QtQuick

// Renders an array of block AST nodes as a vertical stack of the right
// delegate per node.type. This is the single dispatch table for the whole
// renderer -- MarkdownView.qml (top level), MdBlockquote.qml, MdList.qml
// (each item's content) and MdHtmlBlock.qml (<details> content) all recurse
// through this same component instead of each keeping their own copy of the
// type -> delegate mapping.
Column {
    id: root
    property var blocks: []
    signal editRequested()
    signal anchorRequested(string slug)

    spacing: 6

    // Used by MarkdownView.qml to scroll to a specific top-level block (a
    // heading anchor, or the block containing a footnote reference) -- see
    // its scrollToSlug()/scrollToFootnoteRef() (Task 6). Repeater.itemAt()
    // is the documented way to get the Nth generated delegate; the Column
    // positions each one, so its `y` is exactly the offset to scroll to.
    function yForIndex(idx) {
        var item = blockRepeater.itemAt(idx)
        return item ? item.y : -1
    }

    // Returns a delegate URL, *not* a Component. This is deliberate and load
    // bearing: MdList/MdBlockquote/MdCallout/MdHtmlBlock each recurse back
    // into MdBlockList (nested list items, quote/callout bodies, <details>
    // content), so naming those types here -- even inside a `Component {}`
    // wrapper, which does NOT defer type resolution far enough -- makes Qt's
    // type resolver see a cycle and fail the whole module with
    // "Cyclic dependency detected" / "MdBlockList is not a type", taking
    // Main.qml down with it. Loading by URL through `Loader.source` resolves
    // the delegate at runtime instead, so no static cycle exists.
    // The cost is that signals can no longer be wired declaratively; see
    // wireItem() below.
    function urlFor(type) {
        switch (type) {
            case "heading": return Qt.resolvedUrl("MdHeading.qml")
            case "paragraph": return Qt.resolvedUrl("MdParagraph.qml")
            case "hr": return Qt.resolvedUrl("MdHr.qml")
            case "code": return Qt.resolvedUrl("MdCodeBlock.qml")
            case "math_block": return Qt.resolvedUrl("MdCodeBlock.qml")
            case "list": return Qt.resolvedUrl("MdList.qml")
            case "blockquote": return Qt.resolvedUrl("MdBlockquote.qml")
            case "table": return Qt.resolvedUrl("MdTable.qml")
            case "deflist": return Qt.resolvedUrl("MdDeflist.qml")
            case "html_block": return Qt.resolvedUrl("MdHtmlBlock.qml")
            default: return Qt.resolvedUrl("MdParagraph.qml")
        }
    }

    // Imperative replacement for the old declarative
    // `Component { MdList { onEditRequested: ... } }` wrapping. Not every
    // delegate declares every signal (MdHr has neither, MdCodeBlock and
    // MdDeflist have only editRequested), so each is probed before connecting.
    function wireItem(item, node) {
        if (!item)
            return
        item.node = node
        if (item.editRequested)
            item.editRequested.connect(root.editRequested)
        if (item.anchorRequested)
            item.anchorRequested.connect(root.anchorRequested)
    }

    Repeater {
        id: blockRepeater
        model: root.blocks
        delegate: Loader {
            width: root.width
            source: root.urlFor(modelData.type)
            onLoaded: root.wireItem(item, modelData)
        }
    }
}
