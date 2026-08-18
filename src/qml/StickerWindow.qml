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
    property int posWidth: 300
    property int posHeight: 250
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

    width: posWidth
    height: posHeight
    x: posX
    y: posY
    visible: true
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    // Unique per window so KWin window rules can address one specific
    // sticker (matched by wmclass + title together) instead of every
    // window this app creates — needed now that "all desktops" becomes
    // a per-sticker opt-in (pin) instead of an app-wide static rule.
    title: "Sticker " + stickerId

    // Persist position on change, debounced. startSystemMove() (see the
    // header MouseArea below) hands the interactive move grab off to the
    // compositor for the whole gesture -- there is no onReleased to hook
    // a persist call to -- so we watch x/y instead and persist a short
    // idle period after they stop changing.
    //
    // IMPORTANT (best-effort only, not fully functional here): per the
    // accepted Wayland limitation documented in the spec's "Modelo de datos
    // y persistencia" section, mainWindow.x/y never reflects this window's
    // real on-screen position on this Qt6/KWin/Wayland stack -- Wayland's
    // xdg-toplevel protocol gives clients no absolute-position feedback at
    // all, and KWin does not honor the persisted x/y as a restore position
    // on the next launch either (it applies its own placement policy
    // instead). This whole mechanism is harmless to keep -- it would work
    // correctly on X11 or a compositor that does report real position, and
    // costs nothing to leave running -- but on this stack it mostly persists
    // a value that does not correspond to where the sticker actually ended
    // up on screen. Kept as documented, intentional best-effort, not a bug.
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

        MouseArea {
            id: resizeArea
            width: 14
            height: 14
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            z: 10
            cursorShape: Qt.SizeFDiagCursor

            // NOT a delta-from-press-position calculation (that was tried
            // first and empirically measured, via real synthetic drags
            // cross-checked against KWin's on-screen window geometry, to
            // grow the window at only ~50% of the actual cursor travel
            // distance). Root cause: this MouseArea is anchored to
            // parent.right/parent.bottom, so its own local origin moves
            // every time mainWindow.width/height changes -- QML re-evaluates
            // anchors synchronously, before the next input event is
            // processed. That makes mouse.x/mouse.y (local coordinates)
            // measured against a reference frame that has already shifted
            // by the resize applied on the previous event, so comparing
            // against the position captured at press time double-counts the
            // shift and the recursion converges to roughly half the true
            // delta. Using the CURRENT width/height instead of a press-time
            // snapshot cancels that shift algebraically: mouse.x is always
            // relative to the handle's current (already-shifted) origin, so
            // "current width + (mouse.x - handle width)" reconstructs the
            // absolute cursor position without compounding prior frames.
            onPositionChanged: (mouse) => {
                if (!pressed) return
                var newWidth = mainWindow.width + (mouse.x - resizeArea.width)
                var newHeight = mainWindow.height + (mouse.y - resizeArea.height)
                mainWindow.width = Math.max(150, newWidth)
                mainWindow.height = Math.max(120, newHeight)
            }
            onReleased: {
                Manager.updateSize(stickerId, mainWindow.width, mainWindow.height)
            }
        }

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
                            // close() alone only hides the window -- the QML
                            // object, its Timers (settled/persistTimer above)
                            // and property change handlers stay alive for
                            // the rest of the process lifetime otherwise, a
                            // small per-deletion leak in this long-running
                            // autostart daemon. destroy() actually frees it.
                            mainWindow.close()
                            mainWindow.destroy()
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
