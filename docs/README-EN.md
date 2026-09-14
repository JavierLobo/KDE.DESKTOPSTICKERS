<p align="center">
  <img src="../img/logo-sticker.png" alt="Desktop Stickers logo" width="120">
</p>

<h1 align="center">Desktop Stickers</h1>

<p align="center">
  <a href="../LICENSE"><img alt="License: GPL-3.0" src="https://img.shields.io/badge/License-GPL--3.0-blue.svg"></a>
  <a href="README-SP.md"><img alt="ES" src="https://img.shields.io/badge/lang-ES-red.svg"></a>
  <a href="README-IT.md"><img alt="IT" src="https://img.shields.io/badge/lang-IT-green.svg"></a>
  <a href="README-EN.md"><img alt="EN" src="https://img.shields.io/badge/lang-EN-blue.svg"></a>
  <a href="README-DE.md"><img alt="DE" src="https://img.shields.io/badge/lang-DE-orange.svg"></a>
  <a href="README-FR.md"><img alt="FR" src="https://img.shields.io/badge/lang-FR-9cf.svg"></a>
  <a href="README-RU.md"><img alt="RU" src="https://img.shields.io/badge/lang-RU-blueviolet.svg"></a>
  <a href="README-CN.md"><img alt="CN" src="https://img.shields.io/badge/lang-CN-yellow.svg"></a>
  <a href="README-JP.md"><img alt="JP" src="https://img.shields.io/badge/lang-JP-lightgrey.svg"></a>
</p>

Floating sticky notes for the KDE Plasma desktop. A standalone Qt6/QML
application (not a plasmoid) installed like a regular program with
autostart — each sticker is an independent, undecorated window, with
persistent position and size, and per-sticker opt-in visibility across
all virtual desktops (pin).

<p align="center">
  <img src="../img/screenshot-desktop.png" alt="Floating stickers on the KDE Plasma desktop" width="720">
</p>

## Requirements

- Plasma 6.x (verified with 6.7.4) and KWin, Wayland session
- Qt 6.4+ (`Core`, `Gui`, `Qml`, `Quick`, `Widgets`, `DBus`)
- CMake, Bash

## Installation

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

Builds the binary, installs it to `~/.local/bin/desktop-stickers`, and
registers autostart. See [QUICKSTART-EN.md](QUICKSTART-EN.md) for the
full guide (first launch, sample data, troubleshooting) and
`QA_CHECKLIST.md` for the manual verification checklist.

## Features

- Create stickers from the tray icon or the "+" button on an existing
  sticker (appears cascaded, offset from the one it was created from),
  with an incrementing id
- Drag across the desktop (real movement via `Window.startSystemMove()`),
  with the real position (reported by KWin, not Qt) persisted after
  every drag and restored on restart, via a per-sticker KWin window rule
  (`desktopstickers-sticker-<id>`)
- Resize from the bottom-right corner, with size persisted and restored
  the same way as position
- Per-sticker pin (📍/📌 button): opt in individually so that sticker is
  visible on all virtual desktops at once, via the same sticker's KWin
  window rule; without pin, the sticker only exists on the desktop where
  it was created or moved to. Configurable default in Settings
  (Desktops); out of the box, new stickers start unpinned
- Text editing in **full Markdown** (headings, tables, code, quotes,
  lists, bold/italics, links, checkboxes), with automatic toggling:
  click to edit, lose focus to return to the rendered preview
- **Markdown formatting toolbar** while editing: bold, italic,
  strikethrough, H1-H3 headings, bullet list, numbered list, task list,
  link, image, inline code, quote, code block, horizontal rule, and table
  (with a row/column picker) — every button toggles the selection and has
  its own keyboard shortcut. As the sticker shrinks, lower-priority
  buttons progressively collapse right-to-left behind a "more options"
  button; the whole toolbar can be hidden from the sticker header or by
  default from Settings
- In the preview, links are clickable (open via the system's URL
  handler) and fenced code blocks render in a box with a distinct
  background
- Scrollable content: a long note never overflows the sticker, and the
  edit area auto-scrolls to keep the cursor visible while typing
- Background color: random, system accent (follows the live Plasma
  theme), or a fixed color you choose — configurable in Settings
  (Appearance)
- Configurable font family and size from Settings: an ordered preference
  list (e.g. "Times New Roman" → "Liberation Serif") resolved to the
  first family actually installed on the machine, plus a configurable
  point size
- Per-sticker name, editable from the Stickers Panel: if not set, it is
  derived automatically from the first non-empty line of the text
  (heading `#` markers stripped). Truncated to 30 characters both in
  the sticker header (`#<id> | <name or fallback>`) and in the tray
  menu / Panel
- **Stickers Panel**: the full, unlimited list, with search, sorting
  (recent/alphabetical/color), click to open, a context menu (open,
  rename, duplicate), multi-select, and delete with optional confirmation
  plus a few-second undo
- The system tray icon lists the 10 most recently modified notes (no
  pagination) — each row opens or refocuses that note
- The sticker's "✕" button only closes its window — the note still
  exists and can be reopened from the tray menu or the Panel. Deleting a
  note is a separate action, always with an undo option
- **Settings panel** (tray icon right-click → Options → Settings):
  appearance (color/fonts), behavior (default Markdown toolbar
  visibility, delete confirmation, tray left-click action), system
  (autostart, data path with an "open folder" button, export/import
  backup), and languages
- **Multi-language interface**: language selector in Settings, each
  language's name written in itself (e.g. "Español", not "Spanish")
  next to its flag. Ships with Spanish, English, French, and Russian —
  each language is a standalone JSON file under `src/i18n/`,
  auto-discovered both at build time and at runtime
- **"Options" submenu** in the tray menu: Help (documentation on
  GitHub), Donate (support the developer), View license, Settings, and
  About
- Single instance: if the app is already running, launching it again
  does not open a duplicate copy
- Automatic recovery if KWin restarts mid-session (a crash, or
  `kwin_wayland --replace`): position persistence reconnects on its
  own, with no need to restart the app
- The installer sweeps orphaned KWin rules left behind by stickers
  deleted in earlier sessions
- Autostart via a standard freedesktop `.desktop` entry (not Plasma's
  "Background Services"), toggleable from Settings

<p align="center">
  <img src="../img/Desktop-stickers-markdown.png" alt="Example of a sticker with rendered Markdown: headings, tables, and code blocks" width="720">
</p>

## Storage

Desktop Stickers follows the **XDG Base Directory** standard — nothing
lives in its own loose folder in your home directory.

Stickers are stored in `$XDG_DATA_HOME/desktop-stickers/stickers.json`
(typically `~/.local/share/desktop-stickers/stickers.json`):

```json
{
  "stickers": [
    {
      "id": "001",
      "name": "",
      "text": "Markdown content",
      "color": "#FFD700",
      "x": 100,
      "y": 200,
      "width": 300,
      "height": 250,
      "pinned": false,
      "fontFamily": "Liberation Serif",
      "fontSize": 10,
      "created": "2026-08-17T10:30:00Z",
      "modified": "2026-08-17T15:45:00Z"
    }
  ]
}
```

App preferences are stored separately, in
`$XDG_CONFIG_HOME/desktop-stickers/settings.json` (typically
`~/.config/desktop-stickers/settings.json`) — appearance, behavior,
autostart, and language.

> Upgrading from a pre-v1.1.0 install? The first time you run the new
> binary, your data is migrated automatically and silently from the old
> `~/.stickers/` path to the two XDG paths above. No manual steps needed.

## Downloads

Every published version is on the repository's
[Releases](https://github.com/JavierLobo/KDE.DESKTOPSTICKERS/releases)
page, each with its source code and release notes.

## License

GPL-3.0
