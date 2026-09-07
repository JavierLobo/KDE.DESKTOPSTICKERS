# Desktop Stickers - Quick Start

<p align="center">
  <a href="QUICKSTART-SP.md"><img alt="ES" src="https://img.shields.io/badge/lang-ES-red.svg"></a>
  <a href="QUICKSTART-IT.md"><img alt="IT" src="https://img.shields.io/badge/lang-IT-green.svg"></a>
  <a href="QUICKSTART-EN.md"><img alt="EN" src="https://img.shields.io/badge/lang-EN-blue.svg"></a>
  <a href="QUICKSTART-DE.md"><img alt="DE" src="https://img.shields.io/badge/lang-DE-orange.svg"></a>
  <a href="QUICKSTART-RU.md"><img alt="RU" src="https://img.shields.io/badge/lang-RU-blueviolet.svg"></a>
  <a href="QUICKSTART-CN.md"><img alt="CN" src="https://img.shields.io/badge/lang-CN-yellow.svg"></a>
  <a href="QUICKSTART-JP.md"><img alt="JP" src="https://img.shields.io/badge/lang-JP-lightgrey.svg"></a>
</p>

## Installation

```bash
cd <repo-path>  # go to the directory where you cloned the repository
chmod +x scripts/install.sh
./scripts/install.sh
```

This builds the Qt6 binary (`build/desktop-stickers`), installs it to
`~/.local/bin/desktop-stickers`, and registers autostart in
`~/.config/autostart/io.github.javierlobo.desktopstickers.desktop`.

## First launch

The app will start automatically on your next Plasma session. To try it
right now without logging out:

```bash
~/.local/bin/desktop-stickers &
```

You should see an icon in the system tray ("Desktop Stickers") and, if you
already have stickers saved in `~/.stickers/stickers.json`, their windows
will appear at their last real position (persisted via a per-sticker KWin
rule — see `QA_CHECKLIST.md`).

## Create your first sticker

- Click the tray icon → "Nuevo sticker", or
- Click the "+" button on any existing sticker

## Editing

Click inside a sticker to edit it in Markdown. Click outside to return to
the rendered preview.

## Pin (all desktops) and resize

- 📍/📌 button in the header: toggles whether the sticker is visible on
  all virtual desktops (📌) or only on its own (📍). New stickers start
  unpinned by default.
- Drag from the bottom-right corner to resize.

## Sample data

⚠️ This script **overwrites** `~/.stickers/stickers.json` — if you already
have stickers created, they will be lost. Only use it on a fresh install,
or if you don't mind losing the current data.

```bash
chmod +x scripts/test-sticker.sh
./scripts/test-sticker.sh
```

Creates 3 sample stickers in `~/.stickers/stickers.json`.

## Full verification

See `QA_CHECKLIST.md` for the manual checklist covering all
functionality.

## Troubleshooting

**The binary doesn't build:**
- Verify you have Qt6 (`Core`, `Gui`, `Qml`, `Quick`, `Widgets`, `DBus`) installed
- Check the output of `cmake -B build -S .` for the missing package

**A sticker doesn't appear on all desktops:**
- "All desktops" is a **per-sticker** opt-in via the header's pin button
  (📍/📌), not an app-wide rule — first check that the sticker in
  question has pin active (📌).
- If pin is active but the sticker still doesn't follow you across
  desktops, check that sticker's specific KWin rule:
  `kreadconfig6 --file kwinrulesrc --group desktopstickers-sticker-<id> --key desktopsrule`
  should return `2` (Force). If it returns `1` or is empty, the pin
  never got written — retry clicking 📌.
- Also check that the group is listed:
  `kreadconfig6 --file kwinrulesrc --group General --key rules` should
  include `desktopstickers-sticker-<id>`.
- If the values are correct but it's not applying live, force a reload:
  `qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure`
- Full detail on the mechanism (one KWin rule per sticker, shared
  between pin and position) in
  `superpowers/specs/2026-08-18-sticker-pin-position-resize-design.md`,
  section "Arquitectura: de regla global a reglas por-ventana"

**Logs:**
```bash
journalctl --user -f
```
(the app is a standalone process, not part of plasmashell, so its
messages go to the user session log; running
`~/.local/bin/desktop-stickers` directly from a terminal to see its live
console output remains the most reliable option)
