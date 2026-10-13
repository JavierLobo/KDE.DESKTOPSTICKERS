import QtQuick

// Shared rich-text leaf used by every delegate that displays compiled inline
// Markdown (MdParagraph, MdHeading, table cells, list item text, blockquote
// paragraphs). Centralizes the link-vs-internal-anchor-vs-edit click logic
// that used to be duplicated per component in the old MarkdownView.qml.
//
// A read-only TextEdit rather than a Text so the preview's text can be
// selected with the mouse and copied (Ctrl+C) -- a Text item has no
// selection at all. Clicks are read by a TapHandler instead of a MouseArea:
// a MouseArea on top would swallow the press the TextEdit needs to start a
// selection, while a TapHandler only takes a passive grab, so a drag still
// selects and only a click that stays within the drag threshold counts as a
// tap (open link / follow anchor / enter edit mode).
TextEdit {
    id: root
    property string richText: ""
    signal editRequested()
    signal anchorRequested(string slug)

    readOnly: true
    selectByMouse: true
    textFormat: TextEdit.RichText
    wrapMode: TextEdit.Wrap
    text: root.richText
    color: "#222"
    // "Sans Serif" only, not a fallback chain: QML's `font` grouped property
    // has no `families` member (that is C++ QFont API), so the previous
    // ["Inter", "Segoe UI", ...] preference list was a hard error -- "Cannot
    // assign to non-existent property families" -- that broke every text leaf.
    // QML has no fallback-list mechanism at all, so the "Inter first" intent
    // is lost; fontconfig resolves "Sans Serif" to the system default sans.
    font.family: "Sans Serif"
    font.pixelSize: 14

    HoverHandler {
        cursorShape: root.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor
    }

    TapHandler {
        onTapped: (eventPoint) => {
            var link = root.linkAt(eventPoint.position.x, eventPoint.position.y)
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
