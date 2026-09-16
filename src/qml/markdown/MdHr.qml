import QtQuick

Rectangle {
    id: root
    property var node: null // unused (hr carries no data), kept for delegate-loading uniformity
    // DEPRECATED: never emitted -- a horizontal rule has no interactivity.
    // Candidate for removal in a future cleanup.
    signal editRequested()
    // DEPRECATED: never emitted, same reason as editRequested above.
    // Candidate for removal in a future cleanup.
    signal anchorRequested(string slug)

    width: parent ? parent.width : 0
    height: 1
    color: "#33000000"
}
