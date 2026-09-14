import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Markdown formatting toolbar for StickerWindow's edit TextArea (see
// Version-1.1.0.md's "Barra de herramientas Markdown" section). Every
// action operates on `target` (the TextArea) via its own
// insert()/remove()/select() -- not by reassigning `target.text` wholesale
// -- to keep the TextArea's native undo stack and cursor/selection
// tracking intact instead of fighting them.
//
// Toggle semantics (spec: "si el texto ya tiene el formato, al pulsar se
// quita"): inline markers (bold/italic/strike/code) check the two
// characters immediately surrounding the selection; block/line prefixes
// (headings/quote/lists) check every selected line already has the prefix.
// Both strip on match, apply otherwise. Code block toggling checks whether
// the selection itself is exactly ``` ... ``` fenced.
Item {
    id: root

    property TextArea target: null
    // The overflow Menu (compact mode's "▾") is a Popup and legitimately
    // takes focus away from `target` while it's open -- exposed so the
    // caller (StickerWindow.qml) can tell "focus left because this menu is
    // still open, waiting for a pick" apart from "focus left for real".
    //
    // Aliased to `visible`, not Popup's own `opened` property: `opened`
    // only flips true once the popup's *opening transition finishes*, not
    // when popup() is called -- editArea's focus is already lost by then
    // (synchronously, as part of that same popup() call), so checking
    // `opened` left a real window where focus had left but this still read
    // false, and the caller's guard did nothing (confirmed: this is
    // exactly why clicking "▾" itself closed editing). `visible` flips
    // true synchronously at the same moment popup() is called.
    readonly property alias overflowMenuOpen: overflowMenu.visible
    // Below this width the full button row doesn't fit a typical sticker
    // (17 buttons + separators need ~550px; the app's own minimum sticker
    // width is 210px) -- the roadmap explicitly describes this as the
    // expected common case ("Versión reducida (comentarios, campos
    // pequeños)"), not a rare edge case.
    readonly property int compactThreshold: 480
    readonly property bool compact: width < compactThreshold

    implicitHeight: 34

    SystemPalette { id: pal }

    function hasFocusTarget() {
        return target !== null
    }

    // -- Inline marker toggle (bold/italic/strikethrough/inline code) -------

    function toggleInline(marker) {
        if (!target) return
        var start = target.selectionStart
        var end = target.selectionEnd
        var full = target.text
        if (start === end) {
            target.insert(start, marker + marker)
            target.cursorPosition = start + marker.length
            target.forceActiveFocus()
            return
        }
        var selected = full.substring(start, end)
        var beforeCtx = full.substring(Math.max(0, start - marker.length), start)
        var afterCtx = full.substring(end, Math.min(full.length, end + marker.length))
        if (beforeCtx === marker && afterCtx === marker) {
            target.remove(end, end + marker.length)
            target.remove(start - marker.length, start)
            target.select(start - marker.length, end - marker.length)
        } else {
            target.remove(start, end)
            target.insert(start, marker + selected + marker)
            target.select(start, end + marker.length * 2)
        }
        target.forceActiveFocus()
    }

    // -- Per-line prefix toggle (quote, bullet list, task list) -------------

    function selectedLineRange() {
        var full = target.text
        var start = target.selectionStart
        var end = target.selectionEnd
        var lineStart = full.lastIndexOf("\n", start - 1) + 1
        var lineEnd = full.indexOf("\n", end > start ? end - 1 : end)
        if (lineEnd === -1) lineEnd = full.length
        return { lineStart: lineStart, lineEnd: lineEnd }
    }

    function toggleLinePrefix(prefix) {
        if (!target) return
        var full = target.text
        var range = selectedLineRange()
        var block = full.substring(range.lineStart, range.lineEnd)
        var lines = block.split("\n")
        var allHavePrefix = lines.every(function(l) { return l.indexOf(prefix) === 0 })
        var newLines = lines.map(function(l) {
            if (allHavePrefix) return l.substring(prefix.length)
            return l.indexOf(prefix) === 0 ? l : prefix + l
        })
        var newBlock = newLines.join("\n")
        target.remove(range.lineStart, range.lineEnd)
        target.insert(range.lineStart, newBlock)
        target.select(range.lineStart, range.lineStart + newBlock.length)
        target.forceActiveFocus()
    }

    function toggleNumberedList() {
        if (!target) return
        var full = target.text
        var range = selectedLineRange()
        var block = full.substring(range.lineStart, range.lineEnd)
        var lines = block.split("\n")
        var re = /^\d+\.\s/
        var allNumbered = lines.every(function(l) { return re.test(l) })
        var newLines
        if (allNumbered) {
            newLines = lines.map(function(l) { return l.replace(re, "") })
        } else {
            var n = 1
            newLines = lines.map(function(l) { return (n++) + ". " + l.replace(re, "") })
        }
        var newBlock = newLines.join("\n")
        target.remove(range.lineStart, range.lineEnd)
        target.insert(range.lineStart, newBlock)
        target.select(range.lineStart, range.lineStart + newBlock.length)
        target.forceActiveFocus()
    }

    // Cycles/replaces rather than stacking: applying H2 to an H1 line
    // replaces the "# " with "## " instead of producing "# ## ".
    function toggleHeading(level) {
        if (!target) return
        var prefix = "#".repeat(level) + " "
        var full = target.text
        var range = selectedLineRange()
        var block = full.substring(range.lineStart, range.lineEnd)
        var lines = block.split("\n")
        var headingRe = /^#{1,6}\s+/
        var allMatch = lines.every(function(l) { return l.indexOf(prefix) === 0 })
        var newLines = lines.map(function(l) {
            var stripped = l.replace(headingRe, "")
            return allMatch ? stripped : (prefix + stripped)
        })
        var newBlock = newLines.join("\n")
        target.remove(range.lineStart, range.lineEnd)
        target.insert(range.lineStart, newBlock)
        target.select(range.lineStart, range.lineStart + newBlock.length)
        target.forceActiveFocus()
    }

    // -- Fenced code block ----------------------------------------------------

    function toggleCodeBlock() {
        if (!target) return
        var start = target.selectionStart
        var end = target.selectionEnd
        var full = target.text
        var selected = full.substring(start, end)
        if (selected.length >= 6 && selected.indexOf("```") === 0 && selected.lastIndexOf("```") === selected.length - 3) {
            var inner = selected.replace(/^```\n?/, "").replace(/\n?```$/, "")
            target.remove(start, end)
            target.insert(start, inner)
            target.select(start, start + inner.length)
        } else if (start === end) {
            target.insert(start, "```\n\n```")
            target.cursorPosition = start + 4
        } else {
            target.remove(start, end)
            target.insert(start, "```\n" + selected + "\n```")
            target.select(start, start + selected.length + 8)
        }
        target.forceActiveFocus()
    }

    function insertHorizontalRule() {
        if (!target) return
        var pos = target.cursorPosition
        var full = target.text
        var needsNewlineBefore = pos > 0 && full.charAt(pos - 1) !== "\n"
        target.insert(pos, (needsNewlineBefore ? "\n" : "") + "---\n")
        target.forceActiveFocus()
    }

    // -- Insertions: link, image, table --------------------------------------

    function insertLink() {
        if (!target) return
        var start = target.selectionStart
        var end = target.selectionEnd
        var full = target.text
        if (start === end) {
            target.insert(start, "[texto](url)")
            target.select(start + 1, start + 6)
        } else {
            var selected = full.substring(start, end)
            target.remove(start, end)
            target.insert(start, "[" + selected + "](url)")
            var urlStart = start + selected.length + 3
            target.select(urlStart, urlStart + 3)
        }
        target.forceActiveFocus()
    }

    function insertImage() {
        if (!target) return
        var start = target.selectionStart
        var end = target.selectionEnd
        var full = target.text
        if (start === end) {
            target.insert(start, "![alt](url)")
            target.select(start + 2, start + 5)
        } else {
            var selected = full.substring(start, end)
            target.remove(start, end)
            target.insert(start, "![" + selected + "](url)")
            var urlStart = start + selected.length + 4
            target.select(urlStart, urlStart + 3)
        }
        target.forceActiveFocus()
    }

    function insertTable(rows, cols) {
        if (!target) return
        var header = "|"
        var sep = "|"
        for (var c = 0; c < cols; c++) {
            header += " Col " + (c + 1) + " |"
            sep += " --- |"
        }
        var lines = [header, sep]
        for (var r = 0; r < rows; r++) {
            var row = "|"
            for (var c2 = 0; c2 < cols; c2++) row += "     |"
            lines.push(row)
        }
        var table = lines.join("\n") + "\n"
        var pos = target.cursorPosition
        var full = target.text
        var needsNewlineBefore = pos > 0 && full.charAt(pos - 1) !== "\n"
        target.insert(pos, (needsNewlineBefore ? "\n" : "") + table)
        target.forceActiveFocus()
    }

    // -- Keyboard shortcuts ---------------------------------------------------
    // Only the three the roadmap names explicitly (Ctrl+B/I/K) have a fixed
    // convention to match; the rest are this component's own reasonable,
    // non-conflicting picks. All scoped to this window only, and only live
    // while the toolbar itself is actually showing.

    Shortcut { sequence: "Ctrl+B"; enabled: root.visible; onActivated: root.toggleInline("**") }
    Shortcut { sequence: "Ctrl+I"; enabled: root.visible; onActivated: root.toggleInline("*") }
    Shortcut { sequence: "Ctrl+Shift+X"; enabled: root.visible; onActivated: root.toggleInline("~~") }
    Shortcut { sequence: "Ctrl+Shift+C"; enabled: root.visible; onActivated: root.toggleInline("`") }
    Shortcut { sequence: "Ctrl+K"; enabled: root.visible; onActivated: root.insertLink() }
    Shortcut { sequence: "Ctrl+Alt+1"; enabled: root.visible; onActivated: root.toggleHeading(1) }
    Shortcut { sequence: "Ctrl+Alt+2"; enabled: root.visible; onActivated: root.toggleHeading(2) }
    Shortcut { sequence: "Ctrl+Alt+3"; enabled: root.visible; onActivated: root.toggleHeading(3) }
    Shortcut { sequence: "Ctrl+Shift+8"; enabled: root.visible; onActivated: root.toggleLinePrefix("- ") }
    Shortcut { sequence: "Ctrl+Shift+7"; enabled: root.visible; onActivated: root.toggleNumberedList() }
    Shortcut { sequence: "Ctrl+Shift+9"; enabled: root.visible; onActivated: root.toggleLinePrefix("- [ ] ") }
    Shortcut { sequence: "Ctrl+Shift+."; enabled: root.visible; onActivated: root.toggleLinePrefix("> ") }
    Shortcut { sequence: "Ctrl+Shift+K"; enabled: root.visible; onActivated: root.toggleCodeBlock() }
    Shortcut { sequence: "Ctrl+Shift+H"; enabled: root.visible; onActivated: root.insertHorizontalRule() }

    // -- UI ---------------------------------------------------------------------

    // Definition table for every action -- both the full and compact rows,
    // plus the overflow menu, are built from this single list instead of
    // three separately hand-written button sets that could drift out of
    // sync with each other.
    readonly property var actions: [
        { id: "bold", label: "B", bold: true, tip: "Negrita (Ctrl+B)", compact: true, run: function() { toggleInline("**") } },
        { id: "italic", label: "I", italic: true, tip: "Cursiva (Ctrl+I)", compact: true, run: function() { toggleInline("*") } },
        { id: "strike", label: "S", strike: true, tip: "Tachado (Ctrl+Shift+X)", compact: false, run: function() { toggleInline("~~") } },
        { id: "sep1", separator: true },
        { id: "h1", label: "H1", tip: "Encabezado 1 (Ctrl+Alt+1)", compact: false, run: function() { toggleHeading(1) } },
        { id: "h2", label: "H2", tip: "Encabezado 2 (Ctrl+Alt+2)", compact: false, run: function() { toggleHeading(2) } },
        { id: "h3", label: "H3", tip: "Encabezado 3 (Ctrl+Alt+3)", compact: false, run: function() { toggleHeading(3) } },
        { id: "sep2", separator: true },
        { id: "bullets", label: "•", tip: "Viñetas (Ctrl+Shift+8)", compact: false, run: function() { toggleLinePrefix("- ") } },
        { id: "numbered", label: "1.", tip: "Numerada (Ctrl+Shift+7)", compact: false, run: function() { toggleNumberedList() } },
        { id: "tasks", label: "☑", tip: "Tareas (Ctrl+Shift+9)", compact: false, run: function() { toggleLinePrefix("- [ ] ") } },
        { id: "sep3", separator: true },
        { id: "link", label: "🔗", tip: "Enlace (Ctrl+K)", compact: true, run: function() { insertLink() } },
        { id: "image", label: "🖼", tip: "Imagen", compact: false, run: function() { insertImage() } },
        { id: "code", label: "</>", tip: "Código en línea (Ctrl+Shift+C)", compact: true, run: function() { toggleInline("`") } },
        { id: "quote", label: "❝", tip: "Cita (Ctrl+Shift+.)", compact: true, run: function() { toggleLinePrefix("> ") } },
        { id: "sep4", separator: true },
        { id: "codeblock", label: "{ }", tip: "Bloque de código (Ctrl+Shift+K)", compact: false, run: function() { toggleCodeBlock() } },
        { id: "hr", label: "―", tip: "Línea horizontal (Ctrl+Shift+H)", compact: false, run: function() { insertHorizontalRule() } },
        { id: "table", label: "⊞", tip: "Tabla", compact: false, run: function() { tablePopup.open() } }
    ]

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 2

        Repeater {
            model: root.actions

            delegate: Loader {
                required property var modelData
                sourceComponent: modelData.separator ? sepComp : buttonComp
                visible: !root.compact || modelData.separator || modelData.compact === true
                onLoaded: {
                    if (!modelData.separator) {
                        item.buttonData = modelData
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }

        Button {
            text: "▾"
            flat: true
            visible: root.compact
            implicitWidth: 26
            implicitHeight: 26
            // Clicking this button must not steal keyboard focus away from
            // the edit TextArea -- StickerWindow.qml's editArea treats any
            // focus loss as "the user is done editing" and saves+closes on
            // it, which fired on every toolbar click before this.
            focusPolicy: Qt.NoFocus
            onClicked: overflowMenu.popup()
            Accessible.name: "Más opciones de formato"
            ToolTip.visible: hovered
            ToolTip.text: "Más opciones"
            ToolTip.delay: 400
        }
    }

    Component {
        id: sepComp
        Rectangle {
            width: 1
            height: 20
            Layout.alignment: Qt.AlignVCenter
            color: pal.mid
        }
    }

    Component {
        id: buttonComp
        Button {
            id: actionButton
            property var buttonData: null
            text: buttonData ? buttonData.label : ""
            flat: true
            implicitWidth: 28
            implicitHeight: 26
            font.bold: buttonData ? !!buttonData.bold : false
            font.italic: buttonData ? !!buttonData.italic : false
            font.strikeout: buttonData ? !!buttonData.strike : false
            enabled: root.target !== null
            // See the "▾" button's own comment above -- same reason.
            focusPolicy: Qt.NoFocus
            onClicked: if (buttonData) buttonData.run()
            Accessible.name: buttonData ? buttonData.tip : ""
            ToolTip.visible: hovered
            ToolTip.text: buttonData ? buttonData.tip : ""
            ToolTip.delay: 400
        }
    }

    Menu {
        id: overflowMenu
        Repeater {
            model: root.actions.filter(function(a) { return !a.separator && !a.compact })
            delegate: MenuItem {
                required property var modelData
                text: modelData.label + "  " + modelData.tip.replace(/\s*\([^)]*\)/, "")
                onTriggered: modelData.run()
            }
        }
    }

    Popup {
        id: tablePopup
        x: (root.width - width) / 2
        y: root.height
        modal: true
        focus: true

        ColumnLayout {
            spacing: 8

            Label { text: "Insertar tabla" ; font.bold: true }

            RowLayout {
                spacing: 8
                Label { text: "Filas" }
                SpinBox { id: rowsSpin; from: 1; to: 20; value: 2 }
                Label { text: "Columnas" }
                SpinBox { id: colsSpin; from: 1; to: 10; value: 2 }
            }

            Button {
                Layout.alignment: Qt.AlignRight
                text: "Insertar"
                highlighted: true
                onClicked: {
                    root.insertTable(rowsSpin.value, colsSpin.value)
                    tablePopup.close()
                }
            }
        }
    }
}
