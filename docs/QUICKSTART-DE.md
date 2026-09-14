# Desktop Stickers - Schnellstart

<p align="center">
  <a href="QUICKSTART-SP.md"><img alt="ES" src="https://img.shields.io/badge/lang-ES-red.svg"></a>
  <a href="QUICKSTART-IT.md"><img alt="IT" src="https://img.shields.io/badge/lang-IT-green.svg"></a>
  <a href="QUICKSTART-EN.md"><img alt="EN" src="https://img.shields.io/badge/lang-EN-blue.svg"></a>
  <a href="QUICKSTART-DE.md"><img alt="DE" src="https://img.shields.io/badge/lang-DE-orange.svg"></a>
  <a href="QUICKSTART-FR.md"><img alt="FR" src="https://img.shields.io/badge/lang-FR-9cf.svg"></a>
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

Dies kompiliert die Qt6-Binärdatei (`build/desktop-stickers`),
installiert sie nach `~/.local/bin/desktop-stickers` und registriert
den Autostart in
`~/.config/autostart/io.github.javierlobo.desktopstickers.desktop`.

## Erster Start

Die App startet automatisch bei deiner nächsten Plasma-Sitzung. Um sie
sofort auszuprobieren, ohne dich abzumelden:

```bash
~/.local/bin/desktop-stickers &
```

Du solltest ein Symbol im Systembereich sehen ("Desktop Stickers"),
und falls bereits Sticker gespeichert sind, erscheinen deren Fenster an
ihrer letzten tatsächlichen Position (gespeichert über eine KWin-Regel
pro Sticker — siehe `QA_CHECKLIST.md`). Die Daten liegen unter
`$XDG_DATA_HOME/desktop-stickers/stickers.json` (typischerweise
`~/.local/share/desktop-stickers/`), nicht mehr in einem losen Ordner
in deinem Home-Verzeichnis.

Die Sprache der Oberfläche richtet sich danach, was in den
Einstellungen gespeichert ist (standardmäßig Spanisch). Um sie zu
ändern: Rechtsklick auf das Tray-Symbol → **Optionen → Einstellungen →
Sprachen**.

## Deinen ersten Sticker erstellen

- Klick auf das Tray-Symbol → "Nuevo sticker", oder
- Klick auf die "+"-Schaltfläche eines vorhandenen Stickers

## Bearbeiten

Klicke in einen Sticker, um ihn in Markdown zu bearbeiten — die
Formatierungsleiste (fett, Überschriften, Listen, Tabellen, Links ...)
erscheint über dem Textbereich. Klicke außerhalb, um zur gerenderten
Vorschau zurückzukehren.

## Pin (alle Arbeitsflächen) und Größe ändern

- Schaltfläche 📍/📌 im Kopfbereich: schaltet um, ob der Sticker auf
  allen virtuellen Arbeitsflächen sichtbar ist (📌) oder nur auf seiner
  eigenen (📍). Neue Sticker starten standardmäßig ohne Pin (in den
  Einstellungen konfigurierbar).
- Von der unteren rechten Ecke aus ziehen, um die Größe zu ändern.

## Einstellungsfenster

Rechtsklick auf das Tray-Symbol → **Optionen → Einstellungen** öffnet
das Fenster mit vier Bereichen:

- **Erscheinungsbild**: Standardfarbe für neue Sticker (zufällig,
  System-Akzentfarbe oder fest), Schriftart-Präferenzliste und
  Schriftgröße
- **Verhalten**: Standard-Sichtbarkeit der Markdown-Leiste,
  Löschbestätigung, Aktion bei Linksklick auf das Tray-Symbol
- **System**: Autostart ein/aus, Datenpfad (mit einer "Ordner
  öffnen"-Schaltfläche), Backup exportieren/importieren
- **Sprachen**: Sprachauswahl für die Oberfläche

Der Rest des **Optionen**-Untermenüs enthält Hilfe (Dokumentation auf
GitHub), Spenden (den Entwickler unterstützen), Lizenz anzeigen und
Info.

## Sticker-Panel

Linksklick auf das Tray-Symbol (oder "Panel de Stickers" im Menü)
öffnet die vollständige Liste: Suche nach Text, Sortierung nach
zuletzt geändert/alphabetisch/Farbe, Klick zum Öffnen einer Notiz, ein
Kontextmenü (öffnen, umbenennen, duplizieren) sowie Mehrfachauswahl,
um mehrere auf einmal zu löschen.

## Testdaten

⚠️ Dieses Skript **überschreibt** deine `stickers.json` — falls du
bereits Sticker erstellt hast, gehen sie verloren. Verwende es nur bei
einer Neuinstallation oder wenn es dir nichts ausmacht, die aktuellen
Daten zu verlieren.

```bash
chmod +x scripts/test-sticker.sh
./scripts/test-sticker.sh
```

Erstellt 3 Beispiel-Sticker.

## Vollständige Überprüfung

Die manuelle Prüfliste für alle Funktionen findest du in
`QA_CHECKLIST.md`.

## Fehlerbehebung

**Die Binärdatei lässt sich nicht kompilieren:**
- Prüfe, ob Qt6 (`Core`, `Gui`, `Qml`, `Quick`, `Widgets`, `DBus`) installiert ist
- Sieh dir die Ausgabe von `cmake -B build -S .` an, um das fehlende Paket zu finden

**Ein Sticker erscheint nicht auf allen Arbeitsflächen:**
- "Alle Arbeitsflächen" ist ein Opt-in **pro Sticker** über die
  Pin-Schaltfläche (📍/📌) im Kopfbereich, keine app-weite Regel —
  prüfe zuerst, ob bei diesem Sticker der Pin aktiv ist (📌).
- Falls der Pin aktiv ist, der Sticker dir aber weiterhin nicht
  zwischen den Arbeitsflächen folgt, prüfe die spezifische KWin-Regel
  dieses Stickers:
  `kreadconfig6 --file kwinrulesrc --group desktopstickers-sticker-<id> --key desktopsrule`
  sollte `2` (Force) zurückgeben. Falls `1` oder ein leerer Wert
  zurückkommt, wurde der Pin nie geschrieben — klicke erneut auf 📌.
- Prüfe außerdem, ob die Gruppe gelistet ist:
  `kreadconfig6 --file kwinrulesrc --group General --key rules` sollte
  `desktopstickers-sticker-<id>` enthalten.
- Falls die Werte korrekt sind, sich aber nicht live auswirken,
  erzwinge ein Neuladen:
  `qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure`

**Eine neu von mir zu `src/i18n/` hinzugefügte Sprache wird nicht angezeigt:**
- Sie benötigt exakt dieselben Schlüssel wie `src/i18n/es.json`
  (einschließlich `Language.name` und `Language.flag`).
- Du musst neu kompilieren (`cmake --build build`) — die Liste der
  Sprachdateien wird nur beim Konfigurieren/Kompilieren neu erkannt,
  nicht wenn die bereits installierte App startet.

**Logs:**
```bash
journalctl --user -f
```
(die App ist ein eigenständiger Prozess, nicht Teil von plasmashell,
daher landen ihre Meldungen im Log der Benutzersitzung;
`~/.local/bin/desktop-stickers` direkt aus einem Terminal auszuführen,
um die Live-Konsolenausgabe zu sehen, bleibt die zuverlässigste Option)
</content>
