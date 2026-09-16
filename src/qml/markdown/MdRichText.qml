import QtQuick

// Shared rich-text leaf used by every delegate that displays compiled inline
// Markdown (MdParagraph, MdHeading, table cells, list item text, blockquote
// paragraphs). Centralizes the link-vs-internal-anchor-vs-edit click logic
// that used to be duplicated per component in the old MarkdownView.qml.
Text {
    id: root
    property string richText: ""
    signal editRequested()
    signal anchorRequested(string slug)

    textFormat: Text.RichText
    wrapMode: Text.Wrap
    text: root.richText
    color: "#222"
    font.pixelSize: 13

    MouseArea {
        anchors.fill: parent
        cursorShape: root.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: (mouse) => {
            var link = root.linkAt(mouse.x, mouse.y)
            if (link && link.indexOf("#") === 0) {
                root.anchorRequested(link.slice(1))
            } else if (link) {
                Qt.openUrlExternally(link)
            } else {
                root.editRequested()
            }
        }
    }
}
