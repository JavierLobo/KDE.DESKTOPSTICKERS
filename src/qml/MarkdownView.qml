import QtQuick

// Text.MarkdownText (Qt6's native, md4c-backed Markdown renderer) handles
// headings/links/tables correctly on its own (confirmed by real, isolated
// rendering tests), but gives fenced code blocks no visual distinction --
// no background box, just plain monospace text indistinguishable from the
// surrounding prose. Neither Text nor TextEdit differ here; it's a genuine
// engine limitation, not a component choice. Splitting the source into
// prose/code segments and rendering code segments as their own styled
// Rectangle is the workaround: prose segments still go through
// Text.MarkdownText (so tables/links/headings keep working exactly as
// before), only code segments get special treatment.
Column {
    id: root
    property string text: ""
    signal editRequested()

    spacing: 6

    function splitIntoSegments(src) {
        var result = []
        var re = /```[^\n`]*\n([\s\S]*?)```/g
        var lastIndex = 0
        var m
        while ((m = re.exec(src)) !== null) {
            if (m.index > lastIndex) {
                result.push({ code: false, content: src.substring(lastIndex, m.index) })
            }
            result.push({ code: true, content: m[1].replace(/\n$/, "") })
            lastIndex = re.lastIndex
        }
        if (lastIndex < src.length) {
            result.push({ code: false, content: src.substring(lastIndex) })
        }
        return result
    }

    Repeater {
        model: root.splitIntoSegments(root.text)

        // Components defined at file scope (proseComp/codeComp below) do
        // NOT see modelData through the Loader automatically -- confirmed
        // via real testing (journalctl showed "ReferenceError: modelData
        // is not defined" inside both, even though modelData resolves fine
        // here in the delegate itself). The Loader's own scope has
        // modelData; the loaded item's scope does not inherit it. Passing
        // the content explicitly via onLoaded, into a property each
        // Component declares for exactly this purpose, is what actually
        // works.
        delegate: Loader {
            width: root.width
            sourceComponent: modelData.code ? codeComp : proseComp
            onLoaded: item.segContent = modelData.content
        }
    }

    Component {
        id: proseComp
        Text {
            property string segContent: ""
            width: root.width
            textFormat: Text.MarkdownText
            wrapMode: Text.Wrap
            text: segContent
            color: "#222"
            font.pixelSize: 13
            padding: 10

            MouseArea {
                anchors.fill: parent
                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: (mouse) => {
                    var link = parent.linkAt(mouse.x, mouse.y)
                    if (link) {
                        Qt.openUrlExternally(link)
                    } else {
                        root.editRequested()
                    }
                }
            }
        }
    }

    Component {
        id: codeComp
        Rectangle {
            property string segContent: ""
            width: root.width
            height: codeText.implicitHeight + 16
            // QML's alpha-hex color format is #AARRGGBB (alpha FIRST) --
            // "#00000022" (real bug, caught via a real screenshot pixel
            // sample showing no fill at all) parsed as alpha=0x00, i.e.
            // fully transparent. This is alpha=0x33 (~20%) black, which
            // reads as a subtle darkening box on any sticker color.
            color: "#33000000"
            radius: 4

            Text {
                id: codeText
                anchors.fill: parent
                anchors.margins: 8
                text: segContent
                font.family: "monospace"
                font.pixelSize: 12
                wrapMode: Text.Wrap
                color: "#222"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.editRequested()
            }
        }
    }
}
