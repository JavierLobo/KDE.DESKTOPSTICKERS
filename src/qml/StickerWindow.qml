import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "StickerManager.js" as Manager

Window {
    id: mainWindow

    property string stickerId: "001"
    property string stickerText: "Nuevo sticker..."
    property string stickerColor: "#FFD700"
    property int posX: 100
    property int posY: 100
    // Window (unlike Item) has no QML-visible "parent" property, so
    // mainWindow.parent.createNewSticker(...) -- the brief's literal "+"
    // button handler -- evaluates mainWindow.parent as undefined and
    // throws "TypeError: Cannot call method 'createNewSticker' of
    // undefined" (confirmed via journalctl when actually clicking "+").
    // createObject(root, {...}) in Main.qml only sets root as this
    // window's QObject parent for lifetime management, which QML does not
    // surface as a readable "parent" property on a Window. An explicit
    // reference, set from Main.qml at creation time, is required instead.
    property var appRoot: null

    width: 300
    height: 250
    x: posX
    y: posY
    visible: true
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"

    // No per-window multi-desktop registration needed here — the KWin
    // window rule installed in Task 1 (matched by the app's WM_CLASS)
    // covers every window this app creates automatically.

    // Persist position on change, debounced. startSystemMove() (see the
    // header MouseArea below) hands the interactive move grab off to the
    // compositor for the whole gesture -- there is no onReleased to hook
    // a persist call to -- so we watch x/y instead and persist a short
    // idle period after they stop changing.
    //
    // settled guards against a real startup artifact (Task 3 empirical
    // finding, reproduced with a minimal standalone QtQuick.Window too, so
    // it is a Qt6-Wayland-QPA platform behavior, not specific to this app's
    // dynamic window creation): x/y read back the correct posX/posY for one
    // tick, then the Wayland QPA plugin resets them to (0, 0) shortly after
    // the surface is actually mapped, since xdg-toplevel's configure event
    // carries no position -- Wayland gives clients no absolute-position
    // feedback at all. Without this guard, that reset would fire
    // onXChanged/onYChanged and silently overwrite the loaded position with
    // (0, 0) in storage before the user ever touches the window.
    property bool positionDirty: false
    property bool settled: false

    Timer {
        interval: 1000
        running: true
        onTriggered: settled = true
    }

    onXChanged: {
        if (!settled) return
        positionDirty = true
        persistTimer.restart()
    }
    onYChanged: {
        if (!settled) return
        positionDirty = true
        persistTimer.restart()
    }

    Timer {
        id: persistTimer
        interval: 300
        onTriggered: {
            if (positionDirty) {
                Manager.updatePosition(stickerId, mainWindow.x, mainWindow.y)
                positionDirty = false
            }
        }
    }

    Rectangle {
        id: stickerContainer
        anchors.fill: parent
        color: stickerColor
        radius: 8

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                id: header
                Layout.fillWidth: true
                Layout.preferredHeight: 35
                color: Qt.darker(stickerColor, 1.3)
                radius: 8

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    // drag.target requires a QQuickItem; mainWindow is a
                    // Window (not an Item), so it cannot be a drag target
                    // directly ("Unable to assign ... to QQuickItem" at
                    // component creation, which aborts the whole window).
                    // Manual onPressed/onPositionChanged assignment to
                    // mainWindow.x/y (the original workaround here) was
                    // empirically verified (Task 3) to be a no-op on this
                    // Wayland/KWin session -- assigning position on an
                    // already-mapped xdg-toplevel is not honored by the
                    // compositor, and even the QWindow's own x/y readback
                    // stayed unchanged. startSystemMove() hands the move
                    // off to the compositor instead, which is the
                    // standard, compositor-cooperative way to interactively
                    // move a Wayland top-level.
                    onPressed: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            mainWindow.startSystemMove()
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 8

                    Text {
                        text: "#" + stickerId
                        color: "#333"
                        font.bold: true
                        Layout.fillWidth: true
                        font.pixelSize: 12
                    }

                    Button {
                        text: "+"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: mainWindow.appRoot.createNewSticker(mainWindow.x, mainWindow.y)
                    }

                    Button {
                        text: "🎨"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: colorPopup.open()
                    }

                    Button {
                        text: "✕"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: {
                            Manager.removeSticker(stickerId)
                            mainWindow.close()
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                MarkdownView {
                    id: preview
                    anchors.fill: parent
                    text: stickerText
                    visible: !editArea.visible

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            editArea.visible = true
                            editArea.forceActiveFocus()
                        }
                    }
                }

                TextEdit {
                    id: editArea
                    anchors.fill: parent
                    text: stickerText
                    wrapMode: TextEdit.Wrap
                    padding: 10
                    visible: false

                    onActiveFocusChanged: {
                        if (!activeFocus) {
                            stickerText = text
                            Manager.updateText(stickerId, text)
                            visible = false
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: colorPopup
        x: (mainWindow.width - width) / 2
        y: 40
        padding: 8

        ColorPalette {
            onColorSelected: function(selectedColor) {
                // selectedColor arrives as a QML `color` value (the signal
                // parameter is typed `color`, so even the plain hex strings
                // from ColorPalette's swatchColors get converted to a color
                // object before this handler runs). Persisting that object
                // as-is makes JSON.stringify() serialize it as a full
                // {r,g,b,a,...} record instead of a "#rrggbb" string.
                // Storage round-trips through JSON.parse() on the next
                // launch, so Main.qml's createObject() then tries to set
                // the plain-object value onto stickerColor (a `property
                // string`), which QML cannot coerce -- verified empirically
                // as "Could not set initial property stickerColor" in the
                // log, with the sticker silently reverting to its default
                // color. Converting to a hex string here keeps both the
                // live property and the persisted JSON as plain strings.
                var colorStr = selectedColor.toString()
                stickerColor = colorStr
                Manager.updateColor(stickerId, colorStr)
                colorPopup.close()
            }
        }
    }
}
