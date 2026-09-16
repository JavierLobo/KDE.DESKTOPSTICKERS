import QtQuick

// Plain blockquote, or an MdCallout when node.calloutType is set (GitHub
// "> [!NOTE]"-style, detected during parsing -- see markdownParser.js).
//
// The inner components bind `node: root.node` (a live property binding),
// NOT an imperative `onLoaded: item.node = ...` -- Loader.onLoaded only
// fires when the component actually (re)loads, so for whichever branch
// loads first with node still null, an onLoaded-time assignment would never
// re-run once `node` is set moments later unless that also happens to
// trigger a reload. A direct binding stays live regardless.
Loader {
    id: root
    property var node: null
    signal editRequested()
    signal anchorRequested(string slug)

    width: parent ? parent.width : 0
    sourceComponent: node && node.calloutType ? calloutComp : plainComp

    Component {
        id: calloutComp
        MdCallout {
            node: root.node
            onEditRequested: root.editRequested()
            onAnchorRequested: (slug) => root.anchorRequested(slug)
        }
    }

    Component {
        id: plainComp
        Item {
            id: plain
            readonly property var node: root.node
            height: content.implicitHeight + 16

            Rectangle {
                anchors.fill: parent
                color: "#11000000"
                radius: 4
            }
            Rectangle {
                width: 3
                height: parent.height
                color: "#55000000"
            }
            MdBlockList {
                id: content
                x: 12
                y: 8
                width: plain.width - 24
                blocks: plain.node ? plain.node.blocks : []
                onEditRequested: root.editRequested()
                onAnchorRequested: (slug) => root.anchorRequested(slug)
            }
        }
    }
}
