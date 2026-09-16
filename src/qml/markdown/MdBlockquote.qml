import QtQuick

// Plain blockquote for now (Task 5 adds an MdCallout branch when
// node.calloutType is set). Already written as a Loader that binds
// `node: root.node` on its content, not an imperative onLoaded assignment,
// so Task 5's added branch stays correctly reactive.
Loader {
    id: root
    property var node: null
    signal editRequested()
    signal anchorRequested(string slug)

    width: parent ? parent.width : 0
    sourceComponent: plainComp

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
