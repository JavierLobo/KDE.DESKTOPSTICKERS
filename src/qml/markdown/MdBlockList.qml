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

    function componentFor(type) {
        switch (type) {
            case "heading": return headingComp
            case "paragraph": return paragraphComp
            case "hr": return hrComp
            case "code": return codeComp
            case "math_block": return codeComp
            case "list": return listComp
            case "blockquote": return blockquoteComp
            case "table": return tableComp
            case "deflist": return deflistComp
            case "html_block": return htmlBlockComp
            default: return paragraphComp
        }
    }

    Repeater {
        id: blockRepeater
        model: root.blocks
        delegate: Loader {
            width: root.width
            sourceComponent: root.componentFor(modelData.type)
            onLoaded: item.node = modelData
        }
    }

    Component {
        id: headingComp
        MdHeading {
            onEditRequested: root.editRequested()
            onAnchorRequested: (slug) => root.anchorRequested(slug)
        }
    }
    Component {
        id: paragraphComp
        MdParagraph {
            onEditRequested: root.editRequested()
            onAnchorRequested: (slug) => root.anchorRequested(slug)
        }
    }
    Component { id: hrComp; MdHr {} }
    Component {
        id: codeComp
        MdCodeBlock { onEditRequested: root.editRequested() }
    }
    Component {
        id: listComp
        MdList {
            onEditRequested: root.editRequested()
            onAnchorRequested: (slug) => root.anchorRequested(slug)
        }
    }
    Component {
        id: blockquoteComp
        MdBlockquote {
            onEditRequested: root.editRequested()
            onAnchorRequested: (slug) => root.anchorRequested(slug)
        }
    }
    Component {
        id: tableComp
        MdTable {
            onEditRequested: root.editRequested()
            onAnchorRequested: (slug) => root.anchorRequested(slug)
        }
    }
    Component {
        id: deflistComp
        MdDeflist { onEditRequested: root.editRequested() }
    }
    Component {
        id: htmlBlockComp
        MdHtmlBlock {
            onEditRequested: root.editRequested()
            onAnchorRequested: (slug) => root.anchorRequested(slug)
        }
    }
}
