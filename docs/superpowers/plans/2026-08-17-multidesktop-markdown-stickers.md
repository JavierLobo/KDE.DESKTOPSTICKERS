# Multi-Desktop Markdown Stickers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild KDE Stickers as a standalone Qt6/QML+C++ application (dropping the inconsistent `Plasma/Applet` packaging) where sticky notes are draggable, visible on every virtual desktop, editable in Markdown with click-to-edit/blur-to-preview, colorable from a palette, and creatable/deletable via tray icon and per-sticker buttons.

**Architecture:** A single background process (autostarted, no visible main window) owns a `StickerManager.js` singleton that loads/persists stickers via the existing `storage.js` JSON module and dynamically instantiates one independent top-level `StickerWindow` per sticker. Multi-desktop visibility is achieved via a **KWin window rule** (`~/.config/kwinrulesrc`, forcing `desktopsrule=Force` for any window matching the app's `WM_CLASS`), installed once by `scripts/install.sh` and applied compositor-side — not by any C++/QML code the app runs per-window. (Revision note: the original design used a C++ `DesktopHelper` wrapping `KWindowSystem::setOnAllDesktops()`; Task 1's spike proved that API is X11-only in KF6 and a no-op under this Wayland session. See the spec's "Multi-desktop: mecánica exacta" section for the empirical findings.)

**Tech Stack:** Qt6 (Core, Gui, Qml, Quick, **Widgets**), CMake, QML/JavaScript, `Qt.labs.platform` (SystemTrayIcon, ColorDialog), Bash (install script, KWin rule installation via `kwriteconfig6`/D-Bus). (Revision note: `Widgets` and `QApplication`, not `QGuiApplication`, were added in Task 5 — `Qt.labs.platform`'s `ColorDialog` has no portal-backed native implementation on this system and falls back to a QtWidgets-based dialog, which requires `QApplication`. `QApplication` is a strict superset of `QGuiApplication`; nothing else changes.)

**Spec:** `docs/superpowers/specs/2026-08-17-multidesktop-markdown-stickers-design.md`

## Global Constraints

- Target environment: Plasma 6.7.4, KWin 6.7.4, confirmed **Wayland** session (`XDG_SESSION_TYPE=wayland`).
- Qt6 only — QML imports use unversioned syntax (`import QtQuick`, not `import QtQuick 2.15`).
- No `KWindowSystem`/`KF6::WindowSystem` dependency anywhere — multi-desktop is handled entirely by a KWin window rule, not app code. (Revision note: Task 2's fix loop found that Qt6's QtCore QML module does not expose `QDir`/`QFile`/`QIODevice` as QML-instantiable types at all — only `StandardPaths` is exported — so the original plan's assumption that `storage.js` could call `new QDir()`/`new QFile()` directly from QML JS was never actually valid. A minimal C++ singleton, `FileStorage` (`src/filestorage.h`/`.cpp`), was added to provide the four file-system primitives `storage.js` needs. This is unrelated to multi-desktop/KWindowSystem — it's a pre-existing latent bug in the original scaffold's storage design, unmasked once the app was actually run. `src/main.cpp` and `src/filestorage.h`/`.cpp` are the only C++ files in the project.)
- QML entry-point files that must be loadable via `qt_add_qml_module`/`loadFromModule` need an **uppercase-leading filename** (`Main.qml`, not `main.qml`) — Qt's QML module tooling only registers uppercase-named files as module types. (Discovered during Task 1's spike.)
- No automated test framework. Verification is compile success + documented manual QA (explicit spec decision, not a gap).
- Single persistence file `~/.stickers/stickers.json`; JSON schema (`id`, `text`, `color`, `x`, `y`, `created`, `modified`) is unchanged from the current `storage.js`.
- Sticker position is global (same `x`/`y` on every virtual desktop) — there is no per-desktop position concept.
- No confirmation dialog on delete (YAGNI, per spec).
- Global keyboard shortcut for sticker creation is explicitly out of scope (deferred to V2).
- Fixed color palette, exact hex values: `#FFD700`, `#87CEEB`, `#FFB6C1`, `#FFA07A`, `#98FB98`, `#DDA0DD`.
- `metadata.json` and the `Plasma/Applet` packaging model are removed; the app becomes standalone with freedesktop autostart.

---

## Task 1: Build skeleton + multi-desktop risk verification (REVISED)

> **Revision note:** this task was originally written around a C++ `DesktopHelper` wrapping `KWindowSystem::setOnAllDesktops()`. A first dispatch of this task proved that API is X11-only in KF6 and a confirmed no-op under this Wayland session (see ledger). A follow-up research spike then empirically verified a working replacement: a **KWin window rule** in `~/.config/kwinrulesrc` forcing `desktopsrule=Force` for windows matching the app's `WM_CLASS`, applied live via the `org.kde.KWin.reconfigure` D-Bus call — no app-side C++ needed at all. This revised task reflects that finding. The GATE (Step 8) is still the highest-risk item in the project: confirm the KWin-rule mechanism actually keeps a window visible across virtual desktops, before building anything else on top of it. If it fails, **stop and report to the user** — do not proceed to Task 2.

**Files:**
- Create: `CMakeLists.txt`
- Create: `src/main.cpp`
- Create: `src/qml/Main.qml` (temporary content, fully replaced in Task 2 — note the uppercase filename, required by `qt_add_qml_module`)
- Create: `.gitignore` (did not exist in this worktree — see ruling below)

**Interfaces:**
- Produces: executable target `kde-stickers`, buildable via `cmake -B build && cmake --build build`.
- Produces: a live KWin window rule (in the user's `~/.config/kwinrulesrc`, not a repo file) matching `wmclass=org.kde.stickers`, forcing all-desktops. This rule is the actual production mechanism (not a throwaway spike-only artifact) — leave it in place; Task 8 formalizes writing it into `scripts/install.sh` for future installs.

**Pre-flight ruling carried into this dispatch:** `.gitignore` does not exist anywhere in this worktree's git history (it was untracked in the original repo). Create it fresh as part of this task with the content shown in Step 1.

- [ ] **Step 1: Create `.gitignore`**

```
# Build
build/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store

# Runtime
*.qmlc
*.jsc
.qmake.stash

# Temporal
*.tmp
*.bak
```

- [ ] **Step 2: Write `CMakeLists.txt`**

```cmake
cmake_minimum_required(VERSION 3.16)
project(kde-stickers VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(kde-stickers
    src/main.cpp
)

qt_add_qml_module(kde-stickers
    URI StickersApp
    VERSION 1.0
    QML_FILES
        src/qml/Main.qml
)

target_link_libraries(kde-stickers
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Quick
)

install(TARGETS kde-stickers DESTINATION ${CMAKE_INSTALL_PREFIX}/bin)
```

- [ ] **Step 3: Write `src/main.cpp`**

```cpp
#include <QGuiApplication>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName("kde-stickers");
    app.setOrganizationName("org.kde.stickers");
    // The Wayland app-id / X11 WM_CLASS, used by the KWin window rule
    // (installed separately, see Step 6 and Task 8) to identify which
    // windows should be forced onto all virtual desktops.
    app.setDesktopFileName("org.kde.stickers");
    // Sticker windows come and go independently; the app must only quit
    // via the tray icon's "Salir", not when the last sticker closes.
    app.setQuitOnLastWindowClosed(false);

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("StickersApp", "Main");

    return app.exec();
}
```

- [ ] **Step 4: Write temporary `src/qml/Main.qml`**

```qml
import QtQuick
import QtQuick.Window

Window {
    id: testWindow
    width: 200
    height: 200
    visible: true
    color: "orange"
    title: "kde-stickers spike"
}
```

- [ ] **Step 5: Configure and build**

Run:
```bash
cmake -B build -S . -DCMAKE_BUILD_TYPE=Debug
cmake --build build
```
Expected: build succeeds, `build/kde-stickers` executable exists, no errors (an author warning about `QTP0004` policy is harmless and expected).

- [ ] **Step 6: Install the KWin window rule (the actual production mechanism, not a throwaway)**

Ensure a section exists in `~/.config/kwinrulesrc` with these semantics (exact key-writing method — `kwriteconfig6` or careful direct file edit — is your call; verify the result by reading the file back):

- A unique, stable rule id (suggested: `kdestickers-alldesktops`) added to `[General]`'s `rules=` value — **append** to any existing comma-separated list, never overwrite it (other rules may already exist for unrelated apps).
- A section named after that id containing:
  - `wmclass=org.kde.stickers`
  - `wmclassmatch=2` (exact match)
  - `wmclasscomplete=false`
  - `types=1` (normal window)
  - `desktops=` (empty)
  - `desktopsrule=2` (Force)

This step is **idempotent** — if a rule with this id already exists (e.g., you're re-running this task after a partial attempt), don't duplicate it.

After writing, apply it live without restarting anything:
```bash
qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure
```
(If `qdbus6` isn't available, `busctl --user call org.kde.KWin /KWin org.kde.KWin org.kde.KWin.reconfigure` is the D-Bus equivalent.)

- [ ] **Step 7: Run the spike**

```bash
./build/kde-stickers
```
An orange 200x200 window titled "kde-stickers spike" appears.

- [ ] **Step 8: Manually verify multi-desktop behavior (GATE — do not skip)**

Note which virtual desktop the window is on. Switch to a different virtual desktop — use the Pager widget if present on your panel, or the default Plasma shortcut `Ctrl+F2` (desktop 2) / `Meta+Ctrl+Right Arrow` (next desktop).

**Expected:** the orange window remains visible after switching desktops.

**If it does NOT remain visible:** stop implementation here. This means the KWin-rule mechanism has no effect under this specific configuration either — the core multi-desktop requirement cannot be satisfied as currently designed, and this must be reported back before any further task is attempted. Do not attempt further workarounds (e.g. forcing XWayland) — that decision belongs to the human.

Leave the spike process running or press `Ctrl+C` to quit it — your choice, it has no bearing on the KWin rule (which persists independently in `kwinrulesrc`, applying to any future window with the same `wmclass`, including the real app built in later tasks).

- [ ] **Step 9: Commit**

```bash
git add .gitignore CMakeLists.txt src/main.cpp src/qml/Main.qml
git commit -m "feat: bootstrap Qt6 build; multi-desktop via KWin window rule, not C++"
```

Note: the KWin rule itself lives in `~/.config/kwinrulesrc` (outside the repo) and is not part of this commit — Task 8 adds the `scripts/install.sh` logic that writes it automatically for future installs.

---

## Task 2: StickerManager + load/display stickers on startup (COMPLETE — see revision note)

> **Revision note (post-completion):** the code blocks below are the ORIGINAL plan text; they turned out to be non-functional as written (Qt6's QtCore QML module doesn't expose `QDir`/`QFile`/`QIODevice` as QML types, `import QtCore` isn't valid classic-script syntax, and `drag.target: mainWindow` is a type error since `Window` isn't a `QQuickItem`). A two-round fix loop found and corrected six compounding bugs — see `.superpowers/sdd/2026-08-17-multidesktop-markdown-stickers/task-2-report.md` for the full technical narrative and the ledger for the review trail. **The actual shipped code differs from what's shown below** in these ways: `src/code/storage.js` uses `.import QtCore 6.2 as QC` + `.import Stickers.Storage 1.0 as App` and delegates file I/O to a new `src/filestorage.h`/`.cpp` C++ singleton (function names/signatures/JSON schema unchanged); `CMakeLists.txt` registers `StickerManager.js`/`storage.js` via `qt_target_qml_sources(... NO_CACHEGEN)` instead of `SOURCES`, and adds `filestorage.h`/`.cpp`; `src/qml/Main.qml`'s `createStickerWindow()` calls `w.show()` after `createObject()`; `src/qml/StickerWindow.qml`'s header `MouseArea` uses manual `onPressed`/`onPositionChanged` position tracking instead of `drag.target`/`drag.axis` (this last one is itself superseded again in Task 3 below — see that task's revision note). **Tasks 4, 5, and 7 below are unaffected** — their `StickerWindow.qml` edits target the content area and the ✕ button, neither of which changed.

**Files:**
- Create: `src/qml/StickerManager.js`
- Create: `src/qml/StickerWindow.qml`
- Modify: `src/qml/Main.qml` (replace spike content)
- Modify: `CMakeLists.txt` (register new QML_FILES/SOURCES)
- Delete: `src/ui/main.qml` (superseded by `StickerWindow.qml`; `src/ui/` becomes empty and can be removed)

**Interfaces:**
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

    // No per-window multi-desktop registration needed here — the KWin
    // window rule installed in Task 1 (matched by the app's WM_CLASS)
    // covers every window this app creates automatically.

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

- [ ] **Step 3: Replace `src/qml/Main.qml` with the real entry point**

```qml
import QtQuick
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
        src/qml/Main.qml
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
Expected: three sticker windows appear, positioned at (100,100), (450,150), (250,400) matching `~/.stickers/stickers.json`, each showing its `#00N` id and its saved text. Switch virtual desktops (as in Task 1 Step 8) and confirm all three remain visible — this should work automatically via the KWin rule installed in Task 1, with zero per-window code. Press `Ctrl+C` to quit.

- [ ] **Step 7: Commit**

```bash
git add src/qml/StickerManager.js src/qml/StickerWindow.qml src/qml/Main.qml CMakeLists.txt
git commit -m "feat: load and display persisted stickers as independent multi-desktop windows"
```

---

## Task 3: Persist position on drag release (REVISED — includes drag-mechanism verification)

> **Revision note:** Task 2's fix loop replaced the original `drag.target`/`drag.axis` MouseArea (a type error — `Window` isn't a `QQuickItem`, so it crashed window creation) with manual `onPressed`/`onPositionChanged` position-property assignment, just to unblock windows from appearing at all. That fix was never verified to actually *move* a window on screen, and Task 2's re-review flagged real reason to doubt it does: assigning `Window.x`/`Window.y` on an already-mapped `xdg-toplevel` surface is a well-known Wayland limitation that most compositors (including KWin, for plain client-requested repositioning) simply ignore — positioning an already-shown top-level is compositor-controlled under Wayland, unlike X11. This task's actual job — persist position on drag release — is meaningless if dragging doesn't visually work, so this task now includes verifying that, and fixing it via `Window.startSystemMove()` (the standard, compositor-cooperative way to interactively move a Wayland top-level) if the current approach turns out not to work. This requires real empirical verification, not just code review — assign a capable model, not a cheap transcription-tier one.

**Files:**
- Modify: `src/qml/StickerWindow.qml` (header `MouseArea`, add import)
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

- [ ] **Step 2: Verify empirically whether the current drag mechanism actually moves the window**

The current `src/qml/StickerWindow.qml` header `MouseArea` (as Task 2's fix left it) is:

```qml
                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    // drag.target requires a QQuickItem; mainWindow is a
                    // Window (not an Item), so it cannot be a drag target
                    // directly ("Unable to assign ... to QQuickItem" at
                    // component creation, which aborts the whole window).
                    // Track the press position and move the window manually
                    // instead -- the standard pattern for dragging a
                    // frameless Window by a header MouseArea.
                    property point pressPos: Qt.point(0, 0)

                    onPressed: (mouse) => {
                        pressPos = Qt.point(mouse.x, mouse.y)
                    }
                    onPositionChanged: (mouse) => {
                        mainWindow.x += mouse.x - pressPos.x
                        mainWindow.y += mouse.y - pressPos.y
                    }
                }
```

Build and run the app (`cmake --build build`, `./scripts/test-sticker.sh`, `./build/kde-stickers`). Get the real, on-screen geometry of a sticker window via a KWin script querying `workspace.windowList()` (the same ground-truth method used in Tasks 1 and 2 — `org.kde.kwin.Scripting` D-Bus interface). Simulate a drag on the header (a pointer press + move + release — use whatever input-simulation tool is available in this environment, e.g. `ydotool`/`dotool`/`wtype` for Wayland, or a KWin scripting-console-driven synthetic event; if none is reliably available, moving the mouse and checking geometry before/after a manual `onPositionChanged` trigger via a short KWin script is an acceptable substitute — the point is to get the window's *actual compositor-reported position* before and after an attempted drag, not just QML's own `mainWindow.x` property, since those two can diverge exactly when this Wayland limitation is in play). Compare before/after geometry from `workspace.windowList()`.

**If the window's real on-screen position changes to follow the drag:** the current mechanism works. Proceed to Step 3 as originally planned — just add the `onReleased` handler:

```qml
                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    property point pressPos: Qt.point(0, 0)

                    onPressed: (mouse) => {
                        pressPos = Qt.point(mouse.x, mouse.y)
                    }
                    onPositionChanged: (mouse) => {
                        mainWindow.x += mouse.x - pressPos.x
                        mainWindow.y += mouse.y - pressPos.y
                    }
                    onReleased: Manager.updatePosition(stickerId, mainWindow.x, mainWindow.y)
                }
```

**If the window's real on-screen position does NOT change** (this is the expected outcome per the revision note above): replace the whole `MouseArea` with the compositor-driven move approach instead:

```qml
                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    onPressed: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            mainWindow.startSystemMove()
                        }
                    }
                }
```

`startSystemMove()` hands the interactive move off to the compositor (the `xdg_toplevel::move` request) — there is no `onReleased` in this MouseArea to hook a persist call to, since the compositor owns the grab for the whole gesture. Instead, persist via position-change notification with a short debounce, added to the `Window` itself (near the top, alongside the existing `property` declarations):

```qml
    property bool positionDirty: false

    onXChanged: {
        positionDirty = true
        persistTimer.restart()
    }
    onYChanged: {
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
```

(`Timer` needs `import QtQml` — Qt6 unversioned; add it alongside the file's other imports if not already present via `QtQuick`'s own re-exports — check whether it's needed by attempting the build first, since `Timer` is commonly available through `QtQuick` alone in Qt6.)

Whichever path you take, this is a real empirical decision based on what you observe on this machine, not a preference — pick the one that actually works, and say in your report which one you used and what evidence led you there.

- [ ] **Step 3: Add the import**

Add near the top of `src/qml/StickerWindow.qml`, alongside the existing imports:

```qml
import "StickerManager.js" as Manager
```

- [ ] **Step 4: Build and manually verify persistence end-to-end**

Run:
```bash
cmake --build build
./scripts/test-sticker.sh
./build/kde-stickers
```
Drag sticker `#001` by its header to a visibly different position (confirm via screenshot or `workspace.windowList()` that it actually moved — not just that no error occurred). Wait for the drag/move gesture to fully end (release, or for the debounce timer if you used the `startSystemMove()` path). Then check:
```bash
cat ~/.stickers/stickers.json | jq '.stickers[] | select(.id=="001")'
```
Expected: `x`/`y` reflect the new, actually-moved-to position (matching what you observed on screen, not the original seed values), and `modified` is a newer timestamp than `created`. Kill the process, relaunch `./build/kde-stickers`, and confirm sticker `#001` opens at the dragged position.

- [ ] **Step 5: Commit**

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
        src/qml/Main.qml
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
        src/qml/Main.qml
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
        src/qml/Main.qml
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
        src/qml/Main.qml
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
- Modify: `src/qml/Main.qml` (add `SystemTrayIcon`, `createNewSticker`)
- Modify: `src/qml/StickerWindow.qml` (add "+" button)
- Modify: `src/qml/StickerManager.js` (add `createSticker`)

**Interfaces:**
- Consumes: `Storage.newStickerId(): string` (existing `storage.js`).
- Consumes: `root.createStickerWindow(sticker): StickerWindow` (Task 2, in `Main.qml`).
- Produces: `Manager.createSticker(originX: int, originY: int): {id, text, color, x, y}`.
- Produces: `root.createNewSticker(originX: int, originY: int): void` (in `Main.qml`, callable from any `StickerWindow` via `mainWindow.parent.createNewSticker(...)`).

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

- [ ] **Step 2: Add the tray icon and `createNewSticker` to `src/qml/Main.qml`**

> **Revision note:** Task 2's fix loop found that a dynamically-created `Window` needs an explicit `.show()` call after `createObject()` — its declarative `visible: true` binding doesn't take effect otherwise. The replacement below carries that fix forward (it would otherwise silently regress it, since this step replaces the whole file).

Replace the whole file with:

```qml
import QtQuick
import Qt.labs.platform as Platform
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
        var w = stickerWindowComponent.createObject(root, {
            stickerId: sticker.id,
            stickerText: sticker.text,
            stickerColor: sticker.color,
            posX: sticker.x,
            posY: sticker.y
        })
        if (w) {
            w.show()
        }
        return w
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
git add src/qml/Main.qml src/qml/StickerWindow.qml src/qml/StickerManager.js
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

## Task 8: Autostart packaging (REVISED)

> **Revision note:** Task 1 already installed a working KWin window rule by hand on this dev machine (see Task 1 Step 6) and confirmed it via the GATE. This task formalizes that same mechanism into `scripts/install.sh` so it also works on a fresh install (this machine after a config reset, or a different machine). The `.gitignore` step originally planned here is dropped — Task 1 created `.gitignore` fresh in this worktree (it never existed before), with no obsolete Plasma/Applet lines to clean up.

**Files:**
- Delete: `metadata.json`
- Create: `data/org.kde.stickers.desktop`
- Modify: `scripts/install.sh`

**Interfaces:**
- Produces: installed binary at `~/.local/bin/kde-stickers`.
- Produces: autostart entry at `~/.config/autostart/org.kde.stickers.desktop`.
- Produces: idempotent KWin window rule installation (same mechanism as Task 1 Step 6, now scripted).

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

Use the exact same `kwinrulesrc`-writing method Task 1 Step 6 empirically verified works on this system for the rule-writing block below — if Task 1's actual implementation used a different but equivalent method (check its commit/report), match that proven method here instead of the one shown, to avoid two different untested variants existing in the project.

```bash
#!/bin/bash
# kde-stickers: compila el binario Qt6, registra autostart y la regla de KWin
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$REPO_DIR/build"
BIN_INSTALL_DIR="$HOME/.local/bin"
AUTOSTART_DIR="$HOME/.config/autostart"
BIN_PATH="$BIN_INSTALL_DIR/kde-stickers"
KWIN_RULE_ID="kdestickers-alldesktops"

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

echo "📦 Registrando regla de KWin (todos los escritorios)"
EXISTING_RULES="$(kreadconfig6 --file kwinrulesrc --group General --key rules 2>/dev/null || true)"
if [[ ",$EXISTING_RULES," != *",$KWIN_RULE_ID,"* ]]; then
    NEW_RULES="${EXISTING_RULES:+$EXISTING_RULES,}$KWIN_RULE_ID"
    kwriteconfig6 --file kwinrulesrc --group General --key rules "$NEW_RULES"
fi
kwriteconfig6 --file kwinrulesrc --group "$KWIN_RULE_ID" --key wmclass "org.kde.stickers"
kwriteconfig6 --file kwinrulesrc --group "$KWIN_RULE_ID" --key wmclassmatch 2
kwriteconfig6 --file kwinrulesrc --group "$KWIN_RULE_ID" --key wmclasscomplete false
kwriteconfig6 --file kwinrulesrc --group "$KWIN_RULE_ID" --key types 1
kwriteconfig6 --file kwinrulesrc --group "$KWIN_RULE_ID" --key desktops ""
kwriteconfig6 --file kwinrulesrc --group "$KWIN_RULE_ID" --key desktopsrule 2
qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null || true

mkdir -p "$HOME/.stickers"

echo "✓ kde-stickers instalado en $BIN_PATH"
echo "✓ Autostart registrado en $AUTOSTART_DIR/org.kde.stickers.desktop"
echo "✓ Regla de KWin '$KWIN_RULE_ID' registrada (todos los escritorios)"
echo ""
echo "Se iniciará automáticamente en tu próxima sesión de Plasma."
echo "Para lanzarlo ahora mismo:"
echo "  $BIN_PATH &"
```

- [ ] **Step 4: Run and manually verify**

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```
Expected: build succeeds, `~/.local/bin/kde-stickers` exists and is executable, `~/.config/autostart/org.kde.stickers.desktop` exists with `Exec=` resolved to the real path (no literal `__KDE_STICKERS_BIN__` left), `kreadconfig6 --file kwinrulesrc --group General --key rules` includes `kdestickers-alldesktops`. Run the script a second time — expected: no duplicate rule id appended (idempotent). Run `$HOME/.local/bin/kde-stickers &`; expected: tray icon appears, previously-saved stickers load correctly and stay visible across virtual desktop switches.

- [ ] **Step 5: Commit**

```bash
git add data/org.kde.stickers.desktop scripts/install.sh
git commit -m "feat: package as standalone app with freedesktop autostart and scripted KWin all-desktops rule"
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
- [ ] Botón "+" de un sticker existente crea uno nuevo con id incremental (la posición la decide KWin, ver limitación conocida en "Movimiento")
- [ ] Cada sticker creado obtiene un id incremental único

## Movimiento

- [ ] Arrastrar un sticker por su header lo mueve visualmente (vía `Window.startSystemMove()`)
- [ ] `~/.stickers/stickers.json` sigue siendo válido tras arrastrar (no se corrompe a `x:0, y:0`)

**Limitación conocida y aceptada (ver spec, sección "Modelo de datos y persistencia"):** por una limitación del protocolo Wayland, la app no puede leer la posición real de una ventana tras moverla, así que la posición arrastrada **no** se persiste con precisión, y al reiniciar la app cada sticker abre en la posición que decida la política de colocación de KWin — **no** en su última posición arrastrada. Esto es intencional para este MVP, no un bug a reportar.

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
- [ ] Todos los stickers previamente creados aparecen con su texto y color correctos (la posición sigue la limitación conocida de la sección "Movimiento" arriba)

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
sus ventanas aparecerán (en la posición que decida KWin — la posición
exacta no se restaura entre sesiones, ver limitación conocida en el
spec, sección "Modelo de datos y persistencia").

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
- Verifica que tienes Qt6 (`Core`, `Gui`, `Qml`, `Quick`, `Widgets`) instalado
- Revisa el output de `cmake -B build -S .` para el paquete faltante

**Los stickers no aparecen en todos los escritorios:**
- El mecanismo es una regla de KWin, no código de la app — verifica que existe:
  `kreadconfig6 --file kwinrulesrc --group General --key rules` debe incluir `kdestickers-alldesktops`
- Si falta, vuelve a correr `./scripts/install.sh` (la escribe de forma idempotente)
- Si existe pero no aplica, fuerza la recarga: `qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure`
- Detalle completo del mecanismo en
  `docs/superpowers/specs/2026-08-17-multidesktop-markdown-stickers-design.md`, sección "Multi-desktop: mecánica exacta"

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
