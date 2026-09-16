import QtQuick
import "../../code/syntaxHighlight.js" as SyntaxHighlight

// Renders "code" nodes (fenced/indented, with syntax highlighting) and
// "math_block" nodes -- LaTeX ($$...$$) and Mermaid (a "code" node with
// lang === "mermaid") degrade to this same unhighlighted monospace box with
// a small label, since neither can be laid out as a real formula/diagram
// without an embedded web engine (see the design doc's rejected approaches).
Rectangle {
    id: root
    property var node: null
    signal editRequested()
    // DEPRECATED: never emitted -- code blocks carry no links. Candidate
    // for removal in a future cleanup.
    signal anchorRequested(string slug)

    readonly property string codeContent: node ? node.content : ""
    readonly property string codeLang: node && node.type === "code" ? node.lang : ""
    readonly property string degradeLabel: {
        if (!node) return ""
        if (node.type === "math_block") return "🧮 Fórmula LaTeX (vista previa no disponible)"
        if (node.type === "code" && node.lang === "mermaid") return "📊 Diagrama Mermaid (vista previa no disponible)"
        return ""
    }

    readonly property var tokenColors: ({
        keyword: "#8250df",
        string: "#0a7d3f",
        comment: "#6e7781",
        number: "#b35900",
        literal: "#0550ae",
        attr: "#0550ae",
        variable: "#8250df",
        type: "#0550ae",
        "diff-add": "#1a7f37",
        "diff-remove": "#cf222e",
        "diff-hunk": "#6e7781",
        plain: "#222222"
    })

    function escapeHtml(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }

    function highlightedHtml() {
        var tokens = SyntaxHighlight.highlight(root.codeContent, root.codeLang)
        var html = ""
        for (var i = 0; i < tokens.length; i++) {
            var t = tokens[i]
            var color = root.tokenColors[t.cls] || root.tokenColors.plain
            html += "<span style=\"color:" + color + "\">" + escapeHtml(t.text) + "</span>"
        }
        return html.replace(/\n/g, "<br>")
    }

    width: parent ? parent.width : 0
    height: (degradeLabel ? label.implicitHeight + 4 : 0) + codeText.implicitHeight + 16
    color: "#33000000"
    radius: 4

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 4

        Text {
            id: label
            visible: root.degradeLabel !== ""
            text: root.degradeLabel
            font.pixelSize: 11
            font.italic: true
            color: "#555"
        }

        Text {
            id: codeText
            width: parent.width
            textFormat: Text.RichText
            wrapMode: Text.Wrap
            // Single family, not a chain -- QML's `font` grouped property has
            // no `families` member; see the same note in MdRichText.qml.
            // fontconfig resolves "Monospace" to the system default mono font.
            font.family: "Monospace"
            font.pixelSize: 13 // ~0.9x MdRichText's 14px prose size, per the spec's code-sizing rule
            text: root.node ? root.highlightedHtml() : ""
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.editRequested()
    }
}
