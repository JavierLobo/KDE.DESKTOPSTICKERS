# Desktop Stickers - Schnellstart

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
cd <repo-pfad>  # ins Verzeichnis wechseln, in das du das Repository geklont hast
chmod +x scripts/install.sh
./scripts/install.sh
```

Kompiliert die Qt6-Binärdatei (`build/desktop-stickers`), installiert sie
nach `~/.local/bin/desktop-stickers` und registriert den Autostart in
`~/.config/autostart/io.github.javierlobo.desktopstickers.desktop`.

## Erster Start

Die App startet automatisch bei deiner nächsten Plasma-Sitzung. Um sie
sofort auszuprobieren, ohne dich abzumelden:

```bash
~/.local/bin/desktop-stickers &
```

Du solltest ein Symbol im Systembereich ("Desktop Stickers") sehen, und
falls bereits Sticker in `~/.stickers/stickers.json` gespeichert sind,
erscheinen deren Fenster an ihrer letzten tatsächlichen Position
(gespeichert über eine KWin-Regel pro Sticker — siehe
`QA_CHECKLIST.md`).

## Deinen ersten Sticker erstellen

- Klick auf das Tray-Symbol → "Nuevo sticker", oder
- Klick auf die "+"-Schaltfläche eines vorhandenen Stickers

## Bearbeiten

Klick in den Sticker, um ihn in Markdown zu bearbeiten. Klick außerhalb,
um zur gerenderten Vorschau zurückzukehren.

## Pin (alle Arbeitsflächen) und Größe ändern

- Schaltfläche 📍/📌 im Kopfbereich: schaltet um, ob der Sticker auf
  allen virtuellen Arbeitsflächen sichtbar ist (📌) oder nur auf seiner
  eigenen (📍). Neue Sticker starten standardmäßig ohne Pin.
- Von der unteren rechten Ecke aus ziehen, um die Größe zu ändern.

## Testdaten

⚠️ Dieses Skript **überschreibt** `~/.stickers/stickers.json` — falls du
bereits Sticker erstellt hast, gehen sie verloren. Nur bei einer
Neuinstallation verwenden, oder wenn es dir nichts ausmacht, die
aktuellen Daten zu verlieren.

```bash
chmod +x scripts/test-sticker.sh
./scripts/test-sticker.sh
```

Erstellt 3 Beispiel-Sticker in `~/.stickers/stickers.json`.

## Vollständige Überprüfung

Siehe `QA_CHECKLIST.md` für die manuelle Prüfliste aller Funktionen.

## Fehlerbehebung

**Die Binärdatei lässt sich nicht kompilieren:**
- Prüfe, ob Qt6 (`Core`, `Gui`, `Qml`, `Quick`, `Widgets`, `DBus`) installiert ist
- Sieh dir die Ausgabe von `cmake -B build -S .` für das fehlende Paket an

**Ein Sticker erscheint nicht auf allen Arbeitsflächen:**
- "Alle Arbeitsflächen" ist ein Opt-in **pro Sticker** über die
  Pin-Schaltfläche (📍/📌) im Kopfbereich, keine app-weite Regel — prüfe
  zuerst, ob bei diesem Sticker der Pin aktiv ist (📌).
- Falls der Pin aktiv ist, der Sticker dir aber weiterhin nicht zwischen
  Arbeitsflächen folgt, prüfe die spezifische KWin-Regel dieses
  Stickers:
  `kreadconfig6 --file kwinrulesrc --group desktopstickers-sticker-<id> --key desktopsrule`
  sollte `2` (Force) zurückgeben. Falls `1` oder leer zurückkommt, wurde
  der Pin nicht geschrieben — klicke erneut auf 📌.
- Prüfe auch, ob die Gruppe gelistet ist:
  `kreadconfig6 --file kwinrulesrc --group General --key rules` sollte
  `desktopstickers-sticker-<id>` enthalten.
- Falls die Werte korrekt sind, aber nicht live wirken, erzwinge ein
  Neuladen: `qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure`
- Vollständige Details zum Mechanismus (eine KWin-Regel pro Sticker,
  gemeinsam genutzt von Pin und Position) in
  `superpowers/specs/2026-08-18-sticker-pin-position-resize-design.md`,
  Abschnitt "Arquitectura: de regla global a reglas por-ventana"

**Logs:**
```bash
journalctl --user -f
```
(die App ist ein eigenständiger Prozess, nicht Teil von plasmashell,
daher landen ihre Meldungen im Log der Benutzersitzung;
`~/.local/bin/desktop-stickers` direkt aus einem Terminal auszuführen, um
die Live-Konsolenausgabe zu sehen, bleibt die zuverlässigste Option)
