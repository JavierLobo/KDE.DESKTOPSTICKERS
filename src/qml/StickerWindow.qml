import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "StickerManager.js" as Manager
import Stickers.KWin as KWin

Window {
    id: mainWindow

    property string stickerId: "001"
    property string stickerName: ""
    property string stickerText: "Nuevo sticker..."
    property string stickerColor: "#FFD700"
    property int posX: 100
    property int posY: 100
    property int posWidth: 300
    property int posHeight: 250
    property bool stickerPinned: false
    // Drives which of the two ScrollViews below (preview vs edit) is shown.
    // Replaces the old "editArea.visible" flag now that editArea lives
    // inside a ScrollView -- toggling a ScrollView's own child's visible
    // property does not affect the ScrollView's rendering, so the flag has
    // to live one level up and drive both ScrollViews' visible bindings.
    property bool editing: false
    onEditingChanged: if (editing) editArea.forceActiveFocus()
    // Sticker windows are ordinary managed KWin toplevels, closable via
    // Alt+F4, KWin's window-operations menu, or a task switcher -- not just
    // this app's own "✕" button. Any of those must also unregister the
    // window from Main.qml's openWindows registry, or a stale (but truthy)
    // entry is left behind and the next "Abrir" from the tray finds a
    // window that's no longer visible, silently failing to reopen it. This
    // fires in addition to the "✕" button's own explicit unregisterWindow
    // call and the delete dialog's explicit call; calling unregisterWindow
    // twice for the same id is harmless (it's just `delete openWindows[id]`,
    // idempotent).
    onClosing: if (appRoot) appRoot.unregisterWindow(stickerId)
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

    // Persist real position when a drag ends, then write a KWin position
    // rule so the window opens there again on the next launch.
    //
    // startSystemMove() (see the header MouseArea below) hands the whole
    // interactive-move gesture off to the compositor -- there is no
    // onReleased on that MouseArea to hook a persist call to. The original
    // plan here (see git history / task brief) was to watch this Window's
    // x/y as a "something moved, check again shortly" trigger instead, the
    // same way the original MVP's best-effort mechanism did. Real-drag
    // testing during this task (a genuine synthetic hardware-level drag,
    // cross-checked against KWin's own frameGeometry as ground truth)
    // falsified that plan: mainWindow.x/y never changes at all after the
    // window is first mapped, not even across a drag that KWin confirms
    // really moved the window on screen. Wayland gives clients no absolute-
    // position feedback, and -- unlike the one-time startup artifact the
    // original code guarded against -- nothing ever updates x/y again
    // afterward on this Qt6/KWin/Wayland stack. So there is no Qt/QML-side
    // signal at all to hook a "the drag just ended" trigger to; onXChanged/
    // onYChanged simply never fire post-startup, and neither does
    // onReleased.
    //
    // KWin.KWinBridge.moveFinished fixes this from the KWin side instead of
    // the Qt side: KWinBridge (see kwinbridge.h/.cpp's startPositionWatch()
    // and receiveMoveFinished()) runs a small persistent KWin script that
    // connects to interactiveMoveResizeFinished on every sticker window --
    // a signal KWin itself fires when an interactive move/resize grab ends,
    // independent of Wayland's client-facing protocol, confirmed by direct
    // signal-probing plus a real drag during this task's verification. That
    // script calls back over D-Bus, which KWinBridge re-emits as
    // moveFinished(windowTitle) for QML to listen to here.
    property bool positionDirty: false

    Connections {
        target: KWin.KWinBridge
        function onMoveFinished(windowTitle) {
            if (windowTitle !== mainWindow.title) return
            positionDirty = true
            persistTimer.restart()
        }
    }

    Timer {
        id: persistTimer
        interval: 300
        onTriggered: {
            if (positionDirty) {
                var realPos = KWin.KWinBridge.queryRealGeometry(mainWindow.title)
                // KWinBridge::queryRealGeometry() (src/kwinbridge.cpp) uses
                // QPointF(-1, -1) as its one and only *failure* sentinel --
                // every early-return path there (query already in flight,
                // script file failed to open, loadScript() returned a bad
                // id, or the 2s timeout elapsed with no receiveGeometry()
                // callback) falls through to that same `return received ?
                // result : QPointF(-1, -1);`. A sign-based check here
                // (`realPos.x >= 0 && realPos.y >= 0`) was wrong: on a real
                // multi-monitor layout where a screen sits left of or above
                // the primary monitor, KWin's frameGeometry legitimately
                // reports negative x/y for windows on that screen, so a
                // sign check would silently reject every real (successful)
                // geometry read there too, and that sticker would never
                // persist a position or get a position rule at all. Compare
                // against the sentinel value exactly instead of testing
                // sign. (A real, successful read could coincidentally be
                // exactly (-1,-1) only in the practically-impossible case of
                // a window whose true position is that exact pixel -- not
                // worth guarding further, and matches how the C++ side
                // already treats (-1,-1) as the one and only sentinel.)
                if (realPos.x !== -1 || realPos.y !== -1) {
                    Manager.updatePosition(stickerId, realPos.x, realPos.y)
                    KWin.KWinBridge.updatePositionRule(stickerId, mainWindow.title, realPos.x, realPos.y)
                }
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
                        font.pixelSize: 12
                    }

                    Text {
                        text: "|"
                        color: "#333"
                        font.pixelSize: 12
                    }

                    Text {
                        text: Manager.displayName({ name: stickerName, text: stickerText })
                        color: "#333"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Button {
                        text: "+"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: mainWindow.appRoot.createNewSticker(mainWindow.x, mainWindow.y)
                    }

                    Button {
                        text: stickerPinned ? "📌" : "📍"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: {
                            var newPinned = !stickerPinned
                            stickerPinned = newPinned
                            Manager.updatePinned(stickerId, newPinned)
                            KWin.KWinBridge.setPinned(stickerId, mainWindow.title, newPinned)
                        }
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
                            // "✕" only closes the window now -- the note
                            // itself is NOT deleted (stickers.json keeps the
                            // record, so it can be reopened from the tray
                            // menu's note list). Deleting is a separate,
                            // confirmed action reachable only from that
                            // menu (see Main.qml's confirmDeleteSticker).
                            mainWindow.appRoot.unregisterWindow(stickerId)
                            // close() alone only hides the window -- the QML
                            // object, its persistTimer above, and the
                            // Connections to KWinBridge.moveFinished stay
                            // alive for the rest of the process lifetime
                            // otherwise, a small per-deletion leak in this
                            // long-running autostart daemon. destroy()
                            // actually frees it.
                            mainWindow.close()
                            mainWindow.destroy()
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // Long pasted text (or a note with a big table/code block)
                // used to overflow the sticker's fixed-size bounds with no
                // scrollbar and no clipping, visually spilling out past the
                // sticker's rounded rectangle onto the desktop behind it.
                // ScrollView (wrapping both the preview and the edit area)
                // gives real scrolling plus a scrollbar, and TextArea
                // (unlike a raw TextEdit) auto-scrolls its ScrollView to
                // keep the cursor visible while typing/navigating.
                ScrollView {
                    id: previewScroll
                    anchors.fill: parent
                    visible: !mainWindow.editing
                    clip: true

                    MarkdownView {
                        id: preview
                        width: previewScroll.availableWidth
                        text: stickerText
                        onEditRequested: mainWindow.editing = true
                    }
                }

                ScrollView {
                    id: editScroll
                    anchors.fill: parent
                    visible: mainWindow.editing
                    clip: true

                    TextArea {
                        id: editArea
                        width: editScroll.availableWidth
                        text: stickerText
                        wrapMode: TextArea.Wrap
                        padding: 10

                        onActiveFocusChanged: {
                            if (!activeFocus && mainWindow.editing) {
                                stickerText = text
                                Manager.updateText(stickerId, text)
                                if (mainWindow.appRoot) {
                                    mainWindow.appRoot.refreshNoteList()
                                }
                                mainWindow.editing = false
                            }
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
