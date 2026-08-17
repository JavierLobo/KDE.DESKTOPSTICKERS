# Multi-Desktop Markdown Stickers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild KDE Stickers as a standalone Qt6/QML+C++ application (dropping the inconsistent `Plasma/Applet` packaging) where sticky notes are draggable, visible on every virtual desktop, editable in Markdown with click-to-edit/blur-to-preview, colorable from a palette, and creatable/deletable via tray icon and per-sticker buttons.

**Architecture:** A single background process (autostarted, no visible main window) owns a `StickerManager.js` singleton that loads/persists stickers via the existing `storage.js` JSON module and dynamically instantiates one independent top-level `StickerWindow` per sticker. Each window self-registers as visible on all virtual desktops through a minimal C++ bridge (`DesktopHelper`) wrapping KDE's `KWindowSystem::setOnAllDesktops()` — the only C++ needed, since this API isn't reliably exposed to QML directly.

**Tech Stack:** Qt6 (Core, Gui, Qml, Quick), KDE Frameworks 6 (`KF6::WindowSystem`), CMake, QML/JavaScript, `Qt.labs.platform` (SystemTrayIcon, ColorDialog), Bash (install script).

**Spec:** `docs/superpowers/specs/2026-08-17-multidesktop-markdown-stickers-design.md`

## Global Constraints

- Target environment: Plasma 6.7.4, confirmed **Wayland** session (`XDG_SESSION_TYPE=wayland`).
- Qt6 only — QML imports use unversioned syntax (`import QtQuick`, not `import QtQuick 2.15`).
- `KWindowSystem` (KF6) is required; CMake links `KF6::WindowSystem`. It abstracts X11/Wayland internally — no per-platform code branches.
- No automated test framework. Verification is compile success + documented manual QA (explicit spec decision, not a gap).
- Single persistence file `~/.stickers/stickers.json`; JSON schema (`id`, `text`, `color`, `x`, `y`, `created`, `modified`) is unchanged from the current `storage.js`.
- Sticker position is global (same `x`/`y` on every virtual desktop) — there is no per-desktop position concept.
- No confirmation dialog on delete (YAGNI, per spec).
- Global keyboard shortcut for sticker creation is explicitly out of scope (deferred to V2).
- Fixed color palette, exact hex values: `#FFD700`, `#87CEEB`, `#FFB6C1`, `#FFA07A`, `#98FB98`, `#DDA0DD`.
- `metadata.json` and the `Plasma/Applet` packaging model are removed; the app becomes standalone with freedesktop autostart.

---

## Task 1: Build skeleton + multi-desktop risk verification

This is the highest-risk item in the whole project (per spec): confirm `KWindowSystem::setOnAllDesktops()` actually keeps a window visible across virtual desktops under this Wayland/KWin session, before building anything else on top of it. If this fails, **stop and report to the user** — do not proceed to Task 2.

**Files:**
- Create: `CMakeLists.txt`
- Create: `src/main.cpp`
- Create: `src/desktophelper.h`
- Create: `src/desktophelper.cpp`
- Create: `src/qml/main.qml` (temporary content, fully replaced in Task 2)

**Interfaces:**
- Produces: C++ type `DesktopHelper` registered as a QML singleton (`QML_SINGLETON`) under module URI `StickersApp`, with `Q_INVOKABLE void setOnAllDesktops(QWindow *window, bool onAll)`.
- Produces: executable target `kde-stickers`, buildable via `cmake -B build && cmake --build build`.

- [ ] **Step 1: Write `CMakeLists.txt`**

```cmake
cmake_minimum_required(VERSION 3.16)
project(kde-stickers VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick)
find_package(KF6WindowSystem REQUIRED)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(kde-stickers
    src/main.cpp
    src/desktophelper.cpp
    src/desktophelper.h
)

qt_add_qml_module(kde-stickers
    URI StickersApp
    VERSION 1.0
    QML_FILES
        src/qml/main.qml
)

target_link_libraries(kde-stickers
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Quick
        KF6::WindowSystem
)

install(TARGETS kde-stickers DESTINATION ${CMAKE_INSTALL_PREFIX}/bin)
```

- [ ] **Step 2: Write `src/desktophelper.h`**

```cpp
#pragma once

#include <QObject>
#include <QWindow>
#include <qqmlintegration.h>

class DesktopHelper : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit DesktopHelper(QObject *parent = nullptr);

    Q_INVOKABLE void setOnAllDesktops(QWindow *window, bool onAll);
};
```

- [ ] **Step 3: Write `src/desktophelper.cpp`**

```cpp
#include "desktophelper.h"

#include <KWindowSystem>

DesktopHelper::DesktopHelper(QObject *parent)
    : QObject(parent)
{
}

void DesktopHelper::setOnAllDesktops(QWindow *window, bool onAll)
{
    if (!window) {
        return;
    }
    KWindowSystem::setOnAllDesktops(window->winId(), onAll);
}
```

- [ ] **Step 4: Write `src/main.cpp`**

```cpp
#include <QGuiApplication>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName("kde-stickers");
    app.setOrganizationName("org.kde.stickers");
    // Sticker windows come and go independently; the app must only quit
    // via the tray icon's "Salir", not when the last sticker closes.
    app.setQuitOnLastWindowClosed(false);

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("StickersApp", "main");

    return app.exec();
}
```

- [ ] **Step 5: Write temporary `src/qml/main.qml`**

```qml
import QtQuick
import QtQuick.Window
import StickersApp

Window {
    id: testWindow
    width: 200
    height: 200
    visible: true
    color: "orange"
    title: "kde-stickers spike"

    Component.onCompleted: {
        DesktopHelper.setOnAllDesktops(testWindow, true)
    }
}
```

- [ ] **Step 6: Configure and build**

Run:
```bash
cmake -B build -S . -DCMAKE_BUILD_TYPE=Debug
cmake --build build
```
Expected: build succeeds, `build/kde-stickers` executable exists. If `find_package(KF6WindowSystem REQUIRED)` fails, the KDE Frameworks 6 `kwindowsystem` development package is missing — install it before continuing (package name varies; on Arch it is typically `kwindowsystem`, confirm with `pacman -Ss kwindowsystem`).

- [ ] **Step 7: Manually verify multi-desktop behavior (GATE — do not skip)**

Run:
```bash
./build/kde-stickers
```
An orange 200x200 window titled "kde-stickers spike" appears. Note which virtual desktop it's on. Switch to a different virtual desktop — use the Pager widget if present on your panel, or the default Plasma shortcut `Ctrl+F2` (desktop 2) / `Meta+Ctrl+Right Arrow` (next desktop).

**Expected:** the orange window remains visible after switching desktops.

**If it does NOT remain visible:** stop implementation here. This means `KWindowSystem::setOnAllDesktops()` has no effect under this specific KWin/Wayland configuration — the core multi-desktop requirement cannot be satisfied as designed, and this must be reported back before any further task is attempted.

Press `Ctrl+C` in the terminal to quit the spike app.

- [ ] **Step 8: Commit**

```bash
git add CMakeLists.txt src/main.cpp src/desktophelper.h src/desktophelper.cpp src/qml/main.qml
git commit -m "feat: bootstrap Qt6/C++ build with multi-desktop DesktopHelper"
```

---

## Task 2: StickerManager + load/display stickers on startup

**Files:**
- Create: `src/qml/StickerManager.js`
- Create: `src/qml/StickerWindow.qml`
- Modify: `src/qml/main.qml` (replace spike content)
- Modify: `CMakeLists.txt` (register new QML_FILES/SOURCES)
- Delete: `src/ui/main.qml` (superseded by `StickerWindow.qml`; `src/ui/` becomes empty and can be removed)

**Interfaces:**
- Consumes: `DesktopHelper.setOnAllDesktops(window: QWindow, onAll: bool): void` (Task 1).
- Consumes: `Storage.loadAllStickers(): Array<{id, text, color, x, y, created, modified}>` (existing `src/code/storage.js`, unchanged).
- Produces: `Manager.loadStickers(): Array<sticker>` and `Manager.stickers` (shared array), for use by later tasks.
- Produces: `StickerWindow` QML type with properties `stickerId: string`, `stickerText: string`, `stickerColor: string`, `posX: int`, `posY: int`.

- [ ] **Step 1: Write `src/qml/StickerManager.js`**

```js
.pragma library
.import "../code/storage.js" as Storage

var stickers = []

function loadStickers() {
    stickers = Storage.loadAllStickers()
    return stickers
}
```

- [ ] **Step 2: Write `src/qml/StickerWindow.qml`**

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import StickersApp

Window {
    id: mainWindow

    property string stickerId: "001"
    property string stickerText: "Nuevo sticker..."
    property string stickerColor: "#FFD700"
    property int posX: 100
    property int posY: 100

    width: 300
    height: 250
    x: posX
    y: posY
    visible: true
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"

    Component.onCompleted: {
        DesktopHelper.setOnAllDesktops(mainWindow, true)
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
                    drag.target: mainWindow
                    drag.axis: Drag.XAndYAxis
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
                        text: "✕"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: mainWindow.close()
                    }
                }
            }

            TextEdit {
                id: textArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: stickerText
                wrapMode: TextEdit.Wrap
                padding: 10
            }
        }
    }
}
```

- [ ] **Step 3: Replace `src/qml/main.qml` with the real entry point**

```qml
import QtQuick
import StickersApp
import "StickerManager.js" as Manager

Item {
    id: root

    Component {
        id: stickerWindowComponent
        StickerWindow {}
    }

    Component.onCompleted: {
        var loaded = Manager.loadStickers()
        for (var i = 0; i < loaded.length; i++) {
            createStickerWindow(loaded[i])
        }
    }

    function createStickerWindow(sticker) {
        return stickerWindowComponent.createObject(root, {
            stickerId: sticker.id,
            stickerText: sticker.text,
            stickerColor: sticker.color,
            posX: sticker.x,
            posY: sticker.y
        })
    }
}
```

- [ ] **Step 4: Update `CMakeLists.txt`**

Replace the `qt_add_qml_module` block:

```cmake
qt_add_qml_module(kde-stickers
    URI StickersApp
    VERSION 1.0
    QML_FILES
        src/qml/main.qml
        src/qml/StickerWindow.qml
    SOURCES
        src/qml/StickerManager.js
        src/code/storage.js
)
```

- [ ] **Step 5: Remove the superseded old UI file**

```bash
git rm src/ui/main.qml
rmdir src/ui 2>/dev/null || true
```

- [ ] **Step 6: Build and manually verify**

Run:
```bash
cmake --build build
chmod +x scripts/test-sticker.sh
./scripts/test-sticker.sh
./build/kde-stickers
```
Expected: three sticker windows appear, positioned at (100,100), (450,150), (250,400) matching `~/.stickers/stickers.json`, each showing its `#00N` id and its saved text. Switch virtual desktops (as in Task 1 Step 7) and confirm all three remain visible. Press `Ctrl+C` to quit.

- [ ] **Step 7: Commit**

```bash
git add src/qml/StickerManager.js src/qml/StickerWindow.qml src/qml/main.qml CMakeLists.txt
git commit -m "feat: load and display persisted stickers as independent multi-desktop windows"
```

---

## Task 3: Persist position on drag release

**Files:**
- Modify: `src/qml/StickerWindow.qml` (drag `MouseArea`, add import)
- Modify: `src/qml/StickerManager.js` (add `updatePosition`)

**Interfaces:**
- Consumes: `Storage.saveSticker(id: string, text: string, color: string, x: int, y: int): bool` (existing `storage.js`).
- Produces: `Manager.updatePosition(id: string, x: int, y: int): void`.

- [ ] **Step 1: Add `updatePosition` to `src/qml/StickerManager.js`**

Append to the file:

```js
function updatePosition(id, x, y) {
    var sticker = stickers.find(function(s) { return s.id === id })
    if (!sticker) return
    sticker.x = x
    sticker.y = y
    Storage.saveSticker(sticker.id, sticker.text, sticker.color, x, y)
}
```

- [ ] **Step 2: Wire the drag release in `src/qml/StickerWindow.qml`**

Add the import near the top, alongside the existing imports:

```qml
import "StickerManager.js" as Manager
```

Change:
```qml
                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    drag.target: mainWindow
                    drag.axis: Drag.XAndYAxis
                }
```
to:
```qml
                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    drag.target: mainWindow
                    drag.axis: Drag.XAndYAxis
                    onReleased: Manager.updatePosition(stickerId, mainWindow.x, mainWindow.y)
                }
```

- [ ] **Step 3: Build and manually verify persistence**

Run:
```bash
cmake --build build
./scripts/test-sticker.sh
./build/kde-stickers
```
Drag sticker `#001` by its header to a new position. Press `Ctrl+C` to quit. Run:
```bash
cat ~/.stickers/stickers.json | jq '.stickers[] | select(.id=="001")'
```
Expected: `x`/`y` reflect the new dragged position, and `modified` is a newer timestamp than `created`. Relaunch `./build/kde-stickers` and confirm sticker `#001` opens at the dragged position.

- [ ] **Step 4: Commit**

```bash
git add src/qml/StickerManager.js src/qml/StickerWindow.qml
git commit -m "feat: persist sticker position on drag release"
```

---

## Task 4: Markdown edit/preview toggle

**Files:**
- Create: `src/qml/MarkdownView.qml`
- Modify: `src/qml/StickerWindow.qml` (replace content area)
- Modify: `src/qml/StickerManager.js` (add `updateText`)
- Modify: `CMakeLists.txt` (add `MarkdownView.qml` to `QML_FILES`)

**Interfaces:**
- Produces: `MarkdownView` QML type — a `Text` element with `textFormat: Text.MarkdownText`, property `text: string`.
- Produces: `Manager.updateText(id: string, text: string): void`.

- [ ] **Step 1: Write `src/qml/MarkdownView.qml`**

```qml
import QtQuick

Text {
    id: markdownText
    textFormat: Text.MarkdownText
    wrapMode: Text.Wrap
    padding: 10
    font.pixelSize: 13
    color: "#222"
}
```

- [ ] **Step 2: Add `updateText` to `src/qml/StickerManager.js`**

Append to the file:

```js
function updateText(id, text) {
    var sticker = stickers.find(function(s) { return s.id === id })
    if (!sticker) return
    sticker.text = text
    Storage.saveSticker(sticker.id, text, sticker.color, sticker.x, sticker.y)
}
```

- [ ] **Step 3: Replace the content area in `src/qml/StickerWindow.qml`**

Change:
```qml
            TextEdit {
                id: textArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: stickerText
                wrapMode: TextEdit.Wrap
                padding: 10
            }
```
to:
```qml
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
```

- [ ] **Step 4: Update `CMakeLists.txt`**

Change:
```cmake
qt_add_qml_module(kde-stickers
    URI StickersApp
    VERSION 1.0
    QML_FILES
        src/qml/main.qml
        src/qml/StickerWindow.qml
    SOURCES
        src/qml/StickerManager.js
        src/code/storage.js
)
```
to:
```cmake
qt_add_qml_module(kde-stickers
    URI StickersApp
    VERSION 1.0
    QML_FILES
        src/qml/main.qml
        src/qml/StickerWindow.qml
        src/qml/MarkdownView.qml
    SOURCES
        src/qml/StickerManager.js
        src/code/storage.js
)
```

- [ ] **Step 5: Build and manually verify**

Run:
```bash
cmake --build build
./scripts/test-sticker.sh
./build/kde-stickers
```
Click inside a sticker's content area — it switches to plain-text editing showing the raw saved text. Select all, replace with:
```
**bold** and a list:
- one
- two

> a quote

`inline code`
```
Click outside the sticker (on the desktop background) to blur. Expected: the sticker switches back to preview, rendering bold text, a bullet list, a blockquote, and inline code with visual styling (not raw Markdown syntax). Run `cat ~/.stickers/stickers.json | jq '.stickers[] | select(.id=="001")'` and confirm `text` holds the raw Markdown and `modified` updated.

- [ ] **Step 6: Commit**

```bash
git add src/qml/MarkdownView.qml src/qml/StickerManager.js src/qml/StickerWindow.qml CMakeLists.txt
git commit -m "feat: add click-to-edit / blur-to-preview Markdown rendering"
```

---

## Task 5: Color palette + custom picker

**Files:**
- Create: `src/qml/ColorPalette.qml`
- Modify: `src/qml/StickerWindow.qml` (add 🎨 button + popup)
- Modify: `src/qml/StickerManager.js` (add `updateColor`)
- Modify: `CMakeLists.txt` (add `ColorPalette.qml` to `QML_FILES`)

**Interfaces:**
- Produces: `ColorPalette` QML type — emits `signal colorSelected(color selectedColor)`.
- Produces: `Manager.updateColor(id: string, color: string): void`.

- [ ] **Step 1: Write `src/qml/ColorPalette.qml`**

```qml
import QtQuick
import QtQuick.Layouts
import Qt.labs.platform as Platform

Item {
    id: root

    signal colorSelected(color selectedColor)

    readonly property var swatchColors: [
        "#FFD700", "#87CEEB", "#FFB6C1",
        "#FFA07A", "#98FB98", "#DDA0DD"
    ]

    implicitWidth: swatchRow.implicitWidth
    implicitHeight: swatchRow.implicitHeight

    RowLayout {
        id: swatchRow
        spacing: 6

        Repeater {
            model: root.swatchColors
            delegate: Rectangle {
                width: 24
                height: 24
                radius: 12
                color: modelData
                border.color: "#555"
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.colorSelected(modelData)
                }
            }
        }

        Rectangle {
            width: 24
            height: 24
            radius: 12
            color: "transparent"
            border.color: "#555"
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "+"
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                onClicked: customColorDialog.open()
            }
        }
    }

    Platform.ColorDialog {
        id: customColorDialog
        onAccepted: root.colorSelected(color)
    }
}
```

- [ ] **Step 2: Add `updateColor` to `src/qml/StickerManager.js`**

Append to the file:

```js
function updateColor(id, color) {
    var sticker = stickers.find(function(s) { return s.id === id })
    if (!sticker) return
    sticker.color = color
    Storage.saveSticker(sticker.id, sticker.text, color, sticker.x, sticker.y)
}
```

- [ ] **Step 3: Add the color button and popup in `src/qml/StickerWindow.qml`**

Change:
```qml
                    Button {
                        text: "✕"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: mainWindow.close()
                    }
```
to:
```qml
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
                        onClicked: mainWindow.close()
                    }
```

Add the popup as a sibling of `stickerContainer` (inside the `Window`, after `stickerContainer`'s closing brace):

```qml
    Popup {
        id: colorPopup
        x: (mainWindow.width - width) / 2
        y: 40
        padding: 8

        ColorPalette {
            onColorSelected: function(selectedColor) {
                stickerColor = selectedColor
                Manager.updateColor(stickerId, selectedColor)
                colorPopup.close()
            }
        }
    }
```

- [ ] **Step 4: Update `CMakeLists.txt`**

Change:
```cmake
qt_add_qml_module(kde-stickers
    URI StickersApp
    VERSION 1.0
    QML_FILES
        src/qml/main.qml
        src/qml/StickerWindow.qml
        src/qml/MarkdownView.qml
    SOURCES
        src/qml/StickerManager.js
        src/code/storage.js
)
```
to:
```cmake
qt_add_qml_module(kde-stickers
    URI StickersApp
    VERSION 1.0
    QML_FILES
        src/qml/main.qml
        src/qml/StickerWindow.qml
        src/qml/MarkdownView.qml
        src/qml/ColorPalette.qml
    SOURCES
        src/qml/StickerManager.js
        src/code/storage.js
)
```

- [ ] **Step 5: Build and manually verify**

Run:
```bash
cmake --build build
./scripts/test-sticker.sh
./build/kde-stickers
```
Click 🎨 on a sticker, click the green swatch. Expected: header and background update to `#98FB98` immediately. Run `cat ~/.stickers/stickers.json | jq '.stickers[] | select(.id=="001")'` and confirm `color` updated. Click 🎨 again, click "+", pick an arbitrary color in the dialog, accept. Expected: that exact color applies and persists.

- [ ] **Step 6: Commit**

```bash
git add src/qml/ColorPalette.qml src/qml/StickerManager.js src/qml/StickerWindow.qml CMakeLists.txt
git commit -m "feat: add fixed color palette and custom color picker"
```

---

## Task 6: Sticker creation (tray icon + "+" button)

**Files:**
- Modify: `src/qml/main.qml` (add `SystemTrayIcon`, `createNewSticker`)
- Modify: `src/qml/StickerWindow.qml` (add "+" button)
- Modify: `src/qml/StickerManager.js` (add `createSticker`)

**Interfaces:**
- Consumes: `Storage.newStickerId(): string` (existing `storage.js`).
- Consumes: `root.createStickerWindow(sticker): StickerWindow` (Task 2, in `main.qml`).
- Produces: `Manager.createSticker(originX: int, originY: int): {id, text, color, x, y}`.
- Produces: `root.createNewSticker(originX: int, originY: int): void` (in `main.qml`, callable from any `StickerWindow` via `mainWindow.parent.createNewSticker(...)`).

- [ ] **Step 1: Add `createSticker` to `src/qml/StickerManager.js`**

Append to the file:

```js
function createSticker(originX, originY) {
    var id = Storage.newStickerId()
    var sticker = {
        id: id,
        text: "Nuevo sticker...",
        color: "#FFD700",
        x: originX + 30,
        y: originY + 30
    }
    stickers.push(sticker)
    Storage.saveSticker(sticker.id, sticker.text, sticker.color, sticker.x, sticker.y)
    return sticker
}
```

- [ ] **Step 2: Add the tray icon and `createNewSticker` to `src/qml/main.qml`**

Replace the whole file with:

```qml
import QtQuick
import Qt.labs.platform as Platform
import StickersApp
import "StickerManager.js" as Manager

Item {
    id: root

    Component {
        id: stickerWindowComponent
        StickerWindow {}
    }

    Component.onCompleted: {
        var loaded = Manager.loadStickers()
        for (var i = 0; i < loaded.length; i++) {
            createStickerWindow(loaded[i])
        }
    }

    function createStickerWindow(sticker) {
        return stickerWindowComponent.createObject(root, {
            stickerId: sticker.id,
            stickerText: sticker.text,
            stickerColor: sticker.color,
            posX: sticker.x,
            posY: sticker.y
        })
    }

    function createNewSticker(originX, originY) {
        var sticker = Manager.createSticker(originX, originY)
        createStickerWindow(sticker)
    }

    Platform.SystemTrayIcon {
        id: trayIcon
        visible: true
        icon.name: "document-properties"
        tooltip: "KDE Stickers"

        menu: Platform.Menu {
            Platform.MenuItem {
                text: "Nuevo sticker"
                onTriggered: root.createNewSticker(100, 100)
            }
            Platform.MenuItem {
                text: "Salir"
                onTriggered: Qt.quit()
            }
        }
    }
}
```

- [ ] **Step 3: Add the "+" button in `src/qml/StickerWindow.qml`**

Change:
```qml
                    Button {
                        text: "🎨"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: colorPopup.open()
                    }
```
to:
```qml
                    Button {
                        text: "+"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: mainWindow.parent.createNewSticker(mainWindow.x, mainWindow.y)
                    }

                    Button {
                        text: "🎨"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: colorPopup.open()
                    }
```

- [ ] **Step 4: Build and manually verify**

Run:
```bash
cmake --build build
./scripts/test-sticker.sh
./build/kde-stickers
```
Click the tray icon, select "Nuevo sticker". Expected: a new yellow sticker with placeholder text appears near (100,100), with a new incremented id (e.g. `#004`), persisted in `~/.stickers/stickers.json`. Click "+" on an existing sticker at position (x,y); expected: a new sticker appears at (x+30, y+30). Click the tray icon, select "Salir"; expected: the whole process exits — confirm with `pgrep kde-stickers` returning nothing.

- [ ] **Step 5: Commit**

```bash
git add src/qml/main.qml src/qml/StickerWindow.qml src/qml/StickerManager.js
git commit -m "feat: create new stickers from tray icon and per-sticker button"
```

---

## Task 7: Deletion persistence fix

**Files:**
- Modify: `src/qml/StickerWindow.qml` (✕ button)
- Modify: `src/qml/StickerManager.js` (add `removeSticker`)

**Interfaces:**
- Consumes: `Storage.deleteSticker(id: string): bool` (existing `storage.js`).
- Produces: `Manager.removeSticker(id: string): void`.

- [ ] **Step 1: Add `removeSticker` to `src/qml/StickerManager.js`**

Append to the file:

```js
function removeSticker(id) {
    stickers = stickers.filter(function(s) { return s.id !== id })
    Storage.deleteSticker(id)
}
```

- [ ] **Step 2: Fix the ✕ button in `src/qml/StickerWindow.qml`**

Change:
```qml
                    Button {
                        text: "✕"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: mainWindow.close()
                    }
```
to:
```qml
                    Button {
                        text: "✕"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: {
                            Manager.removeSticker(stickerId)
                            mainWindow.close()
                        }
                    }
```

- [ ] **Step 3: Build and manually verify**

Run:
```bash
cmake --build build
./scripts/test-sticker.sh
./build/kde-stickers
```
Click ✕ on sticker `#002`. Expected: the window closes. Run `cat ~/.stickers/stickers.json | jq '.stickers[].id'` — expected output is `"001"` and `"003"` only, no `"002"`. Press `Ctrl+C`, relaunch, confirm sticker `#002` does not reappear.

- [ ] **Step 4: Commit**

```bash
git add src/qml/StickerManager.js src/qml/StickerWindow.qml
git commit -m "fix: persist sticker deletion instead of only closing the window"
```

---

## Task 8: Autostart packaging

**Files:**
- Delete: `metadata.json`
- Create: `data/org.kde.stickers.desktop`
- Modify: `scripts/install.sh`
- Modify: `.gitignore` (drop obsolete Plasma/Applet entries)

**Interfaces:**
- Produces: installed binary at `~/.local/bin/kde-stickers`.
- Produces: autostart entry at `~/.config/autostart/org.kde.stickers.desktop`.

- [ ] **Step 1: Remove the obsolete Plasma/Applet manifest**

```bash
git rm metadata.json
```

- [ ] **Step 2: Write `data/org.kde.stickers.desktop`**

```ini
[Desktop Entry]
Type=Application
Name=KDE Stickers
Name[es]=KDE Stickers
Comment=Sticky notes flotantes en el escritorio
Comment[es]=Sticky notes flotantes en el escritorio
Exec=__KDE_STICKERS_BIN__
Icon=document-properties
Terminal=false
Categories=Utility;
X-KDE-autostart-phase=1
```

- [ ] **Step 3: Rewrite `scripts/install.sh`**

```bash
#!/bin/bash
# kde-stickers: compila el binario Qt6 y registra autostart
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$REPO_DIR/build"
BIN_INSTALL_DIR="$HOME/.local/bin"
AUTOSTART_DIR="$HOME/.config/autostart"
BIN_PATH="$BIN_INSTALL_DIR/kde-stickers"

echo "📦 Compilando kde-stickers..."
cmake -B "$BUILD_DIR" -S "$REPO_DIR" -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR"

echo "📦 Instalando binario en $BIN_PATH"
mkdir -p "$BIN_INSTALL_DIR"
cp "$BUILD_DIR/kde-stickers" "$BIN_PATH"

echo "📦 Registrando autostart"
mkdir -p "$AUTOSTART_DIR"
sed "s|__KDE_STICKERS_BIN__|$BIN_PATH|" \
    "$REPO_DIR/data/org.kde.stickers.desktop" \
    > "$AUTOSTART_DIR/org.kde.stickers.desktop"

mkdir -p "$HOME/.stickers"

echo "✓ kde-stickers instalado en $BIN_PATH"
echo "✓ Autostart registrado en $AUTOSTART_DIR/org.kde.stickers.desktop"
echo ""
echo "Se iniciará automáticamente en tu próxima sesión de Plasma."
echo "Para lanzarlo ahora mismo:"
echo "  $BIN_PATH &"
```

- [ ] **Step 4: Update `.gitignore`**

Change:
```
# Ignorar instalación local
~/.stickers/
~/.local/share/plasma/plasmoids/org.kde.stickers/
kde_install/
```
to:
```
# Ignorar instalación local
~/.stickers/
```

- [ ] **Step 5: Run and manually verify**

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```
Expected: build succeeds, `~/.local/bin/kde-stickers` exists and is executable, `~/.config/autostart/org.kde.stickers.desktop` exists with `Exec=` resolved to the real path (no literal `__KDE_STICKERS_BIN__` left). Run `$HOME/.local/bin/kde-stickers &`; expected: tray icon appears, previously-saved stickers load correctly.

- [ ] **Step 6: Commit**

```bash
git add data/org.kde.stickers.desktop scripts/install.sh .gitignore
git commit -m "feat: package as standalone app with freedesktop autostart, drop Plasma/Applet packaging"
```

---

## Task 9: Manual QA checklist + docs update

**Files:**
- Create: `docs/QA_CHECKLIST.md`
- Modify: `docs/QUICKSTART.md`

- [ ] **Step 1: Write `docs/QA_CHECKLIST.md`**

```markdown
# QA Checklist — KDE Stickers

Verificación manual repetible del MVP. No hay tests automatizados (decisión de diseño, ver `docs/superpowers/specs/2026-08-17-multidesktop-markdown-stickers-design.md`).

## Instalación

- [ ] `./scripts/install.sh` compila sin errores
- [ ] `~/.local/bin/kde-stickers` existe y es ejecutable
- [ ] `~/.config/autostart/org.kde.stickers.desktop` existe, `Exec=` apunta a una ruta real (no un placeholder)

## Creación

- [ ] Tray icon → "Nuevo sticker" crea un sticker amarillo con texto placeholder
- [ ] Botón "+" de un sticker existente crea uno nuevo desplazado (+30,+30)
- [ ] Cada sticker creado obtiene un id incremental único

## Movimiento

- [ ] Arrastrar un sticker por su header lo mueve visualmente
- [ ] Al soltar, la nueva posición se guarda en `~/.stickers/stickers.json`
- [ ] Al reiniciar la app, el sticker abre en la última posición guardada

## Multi-desktop

- [ ] Todos los stickers son visibles al cambiar de escritorio virtual (Pager o `Ctrl+F2`/`Meta+Ctrl+Right`)
- [ ] La posición de cada sticker es la misma sin importar el escritorio activo

## Markdown

- [ ] Click en el contenido de un sticker entra en modo edición (texto plano/Markdown crudo)
- [ ] Perder el foco (click fuera) vuelve a preview renderizado
- [ ] Negrita, cursiva, listas, citas y código inline se renderizan con estilo en preview
- [ ] El texto editado se persiste en `~/.stickers/stickers.json`

## Colores

- [ ] Botón 🎨 abre la paleta de 6 colores fijos
- [ ] Seleccionar un swatch cambia el color del sticker inmediatamente y lo persiste
- [ ] El botón "+" de la paleta abre un selector de color libre y aplica/persiste el color elegido

## Eliminación

- [ ] Botón "✕" cierra la ventana del sticker
- [ ] El sticker eliminado desaparece de `~/.stickers/stickers.json`
- [ ] Al reiniciar la app, el sticker eliminado no reaparece

## Persistencia entre sesiones

- [ ] Cerrar sesión de Plasma y volver a iniciar sesión levanta la app automáticamente (autostart)
- [ ] Todos los stickers previamente creados aparecen con su texto, color y posición correctos

## Salida

- [ ] Tray icon → "Salir" termina el proceso completo (verificar con `pgrep kde-stickers`)
```

- [ ] **Step 2: Rewrite `docs/QUICKSTART.md`**

```markdown
# KDE Stickers - Quick Start

## Instalación

```bash
cd ~/Repositorios/KDE.STICKERS
chmod +x scripts/install.sh
./scripts/install.sh
```

Esto compila el binario Qt6 (`build/kde-stickers`), lo instala en
`~/.local/bin/kde-stickers`, y registra el autostart en
`~/.config/autostart/org.kde.stickers.desktop`.

## Primer arranque

La app se lanzará automáticamente en tu próxima sesión de Plasma. Para
probarla ahora mismo sin reiniciar sesión:

```bash
~/.local/bin/kde-stickers &
```

Deberías ver un icono en la bandeja del sistema ("KDE Stickers") y,
si ya tienes stickers guardados en `~/.stickers/stickers.json`,
sus ventanas aparecerán en las posiciones guardadas.

## Crear tu primer sticker

- Click en el icono de la bandeja → "Nuevo sticker", o
- Click en el botón "+" de cualquier sticker existente

## Editar

Click dentro del sticker para editar en Markdown. Click fuera para
volver a la vista previa renderizada.

## Datos de prueba

```bash
chmod +x scripts/test-sticker.sh
./scripts/test-sticker.sh
```

Crea 3 stickers de ejemplo en `~/.stickers/stickers.json`.

## Verificación completa

Ver `docs/QA_CHECKLIST.md` para el checklist manual de todas las
funcionalidades.

## Troubleshooting

**El binario no compila:**
- Verifica que tienes Qt6 (`Core`, `Gui`, `Qml`, `Quick`) y KDE
  Frameworks 6 `kwindowsystem` instalados
- Revisa el output de `cmake -B build -S .` para el paquete faltante

**Los stickers no aparecen en todos los escritorios:**
- Confirma tu tipo de sesión: `echo $XDG_SESSION_TYPE`
- Es una limitación conocida y documentada del compositor bajo
  ciertas configuraciones Wayland — ver la sección de riesgos en
  `docs/superpowers/specs/2026-08-17-multidesktop-markdown-stickers-design.md`

**Logs:**
```bash
journalctl -u plasmashell -f
```
(o ejecuta `~/.local/bin/kde-stickers` directamente desde una
terminal para ver su salida de consola en vivo)
```

- [ ] **Step 3: Commit**

```bash
git add docs/QA_CHECKLIST.md docs/QUICKSTART.md
git commit -m "docs: add manual QA checklist and update quickstart for standalone app"
```
