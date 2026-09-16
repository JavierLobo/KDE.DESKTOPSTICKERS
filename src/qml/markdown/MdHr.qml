import QtQuick

Rectangle {
    id: root
    property var node: null // unused (hr carries no data), kept for delegate-loading uniformity
    signal editRequested()
    signal anchorRequested(string slug)

    width: parent ? parent.width : 0
    height: 1
    color: "#33000000"
}
