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

Frei schwebende Klebezettel für den KDE-Plasma-Desktop. Eine eigenständige
Qt6/QML-Anwendung (kein Plasmoid), die wie ein gewöhnliches Programm mit
Autostart installiert wird — jeder Sticker ist ein unabhängiges Fenster
ohne Fensterdekoration, mit dauerhaft gespeicherter Position und Größe
sowie optionaler, pro Sticker einzeln aktivierbarer Sichtbarkeit auf
allen virtuellen Arbeitsflächen (Pin).

<p align="center">
  <img src="../img/screenshot-desktop.png" alt="Schwebende Sticker auf dem KDE-Plasma-Desktop" width="720">
</p>

## Voraussetzungen

- Plasma 6.x (getestet mit 6.7.4) und KWin, Wayland-Sitzung
- Qt 6.4+ (`Core`, `Gui`, `Qml`, `Quick`, `Widgets`, `DBus`)
- CMake, Bash

## Installation

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

Kompiliert die Binärdatei, installiert sie nach
`~/.local/bin/desktop-stickers` und richtet den Autostart ein. Die
vollständige Anleitung (erster Start, Beispieldaten, Fehlerbehebung)
findest du in [QUICKSTART-DE.md](QUICKSTART-DE.md), die manuelle
Prüfliste in `QA_CHECKLIST.md`.

## Funktionen

- Sticker über das Tray-Symbol oder die "+"-Schaltfläche eines
  vorhandenen Stickers erstellen (erscheint gestaffelt, versetzt zu dem
  Sticker, aus dem er erstellt wurde), mit fortlaufender ID
- Über den Desktop ziehen (echte Bewegung via
  `Window.startSystemMove()`), wobei die tatsächliche Position (von
  KWin gemeldet, nicht von Qt) nach jedem Ziehen gespeichert und beim
  Neustart wiederhergestellt wird, über eine KWin-Fensterregel pro
  Sticker (`desktopstickers-sticker-<id>`)
- Größe von der unteren rechten Ecke aus ändern, wobei die Größe auf
  dieselbe Weise wie die Position gespeichert und wiederhergestellt wird
- Pin pro Sticker (Schaltfläche 📍/📌): einzeln aktivierbar, damit
  dieser Sticker gleichzeitig auf allen virtuellen Arbeitsflächen
  sichtbar ist, über dieselbe KWin-Fensterregel des Stickers; ohne Pin
  existiert der Sticker nur auf der Arbeitsfläche, auf der er erstellt
  oder auf die er verschoben wurde. Der Standardwert ist in den
  Einstellungen (Arbeitsflächen) konfigurierbar; ab Werk starten neue
  Sticker ohne Pin
- Textbearbeitung in **vollständigem Markdown** (Überschriften,
  Tabellen, Code, Zitate, Listen, Fett/Kursiv, Links, Checkboxen), mit
  automatischem Wechsel: Klicken zum Bearbeiten, Fokusverlust für die
  Rückkehr zur gerenderten Vorschau
- **Markdown-Formatierungsleiste** während der Bearbeitung: Fett,
  Kursiv, Durchgestrichen, Überschriften H1-H3, Aufzählungsliste,
  nummerierte Liste, Aufgabenliste, Link, Bild, Inline-Code, Zitat,
  Codeblock, horizontale Linie und Tabelle (mit Zeilen-/Spaltenauswahl)
  — jede Schaltfläche wirkt auf die aktuelle Auswahl und hat ihr eigenes
  Tastaturkürzel. Wird der Sticker schmaler, klappen niedriger
  priorisierte Schaltflächen von rechts nach links nach und nach hinter
  eine "Weitere Optionen"-Schaltfläche; die gesamte Leiste lässt sich
  über den Sticker-Kopfbereich ausblenden oder standardmäßig über die
  Einstellungen
- In der Vorschau sind Links anklickbar (öffnen über den URL-Handler
  des Systems), und eingezäunte Codeblöcke werden in einem Kasten mit
  abgesetztem Hintergrund dargestellt
- Scrollbarer Inhalt: eine lange Notiz läuft nie über den Sticker
  hinaus, und der Bearbeitungsbereich scrollt beim Tippen automatisch
  mit, damit der Cursor sichtbar bleibt
- Hintergrundfarbe: zufällig, System-Akzentfarbe (folgt dem aktuell
  aktiven Plasma-Theme) oder eine feste, selbst gewählte Farbe —
  konfigurierbar in den Einstellungen (Erscheinungsbild)
- Schriftart und -größe über die Einstellungen konfigurierbar: eine
  geordnete Präferenzliste (z. B. "Times New Roman" → "Liberation
  Serif"), die auf die erste tatsächlich auf dem Rechner installierte
  Schriftfamilie aufgelöst wird, sowie eine einstellbare Punktgröße
- Name pro Sticker, bearbeitbar über das Sticker-Panel: falls nicht
  gesetzt, wird er automatisch aus der ersten nicht leeren Textzeile
  abgeleitet (führende `#`-Überschriftenzeichen werden entfernt). Auf
  30 Zeichen gekürzt, sowohl im Sticker-Kopfbereich
  (`#<id> | <Name oder Ersatzwert>`) als auch im Tray-Menü / Panel
- **Sticker-Panel**: die vollständige, unbegrenzte Liste mit Suche,
  Sortierung (zuletzt geändert/alphabetisch/Farbe), Öffnen per Klick,
  einem Kontextmenü (öffnen, umbenennen, duplizieren), Mehrfachauswahl
  sowie Löschen mit optionaler Bestätigung und einigen Sekunden Zeit
  zum Rückgängigmachen
- Das Symbol im Systembereich listet die 10 zuletzt geänderten Notizen
  auf (ohne Seitennummerierung) — jede Zeile öffnet die Notiz oder holt
  sie in den Vordergrund
- Die Schaltfläche "✕" eines Stickers schließt nur dessen Fenster — die
  Notiz besteht weiterhin und kann über das Tray-Menü oder das Panel
  wieder geöffnet werden. Das Löschen einer Notiz ist eine eigene
  Aktion, stets mit einer Rückgängig-Option
- **Einstellungsfenster** (Rechtsklick auf das Tray-Symbol → Optionen
  → Einstellungen): Erscheinungsbild (Farbe/Schriftarten), Verhalten
  (Standard-Sichtbarkeit der Markdown-Leiste, Löschbestätigung, Aktion
  bei Linksklick auf das Tray-Symbol), System (Autostart, Datenpfad mit
  einer "Ordner öffnen"-Schaltfläche, Backup exportieren/importieren)
  sowie Sprachen
- **Mehrsprachige Oberfläche**: Sprachauswahl in den Einstellungen,
  wobei der Name jeder Sprache in sich selbst geschrieben ist (z. B.
  "Español", nicht "Spanisch") neben ihrer Flagge. Wird mit Spanisch,
  Englisch, Französisch und Russisch ausgeliefert — jede Sprache ist
  eine eigenständige JSON-Datei unter `src/i18n/`, sowohl beim
  Kompilieren als auch zur Laufzeit automatisch erkannt
- **"Optionen"-Untermenü** im Tray-Menü: Hilfe (Dokumentation auf
  GitHub), Spenden (den Entwickler unterstützen), Lizenz anzeigen,
  Einstellungen und Info
- Einzelinstanz: Läuft die App bereits, öffnet ein erneuter Start keine
  doppelte Kopie
- Automatische Wiederherstellung, falls KWin während der Sitzung neu
  startet (Absturz oder `kwin_wayland --replace`): die
  Positions-Persistenz verbindet sich von selbst neu, ohne dass die App
  neu gestartet werden muss
- Das Installationsskript entfernt verwaiste KWin-Regeln, die von in
  früheren Sitzungen gelöschten Stickern übrig geblieben sind
- Autostart über einen Standard-freedesktop-`.desktop`-Eintrag (nicht
  über Plasmas "Hintergrunddienste"), über die Einstellungen
  ein-/ausschaltbar

<p align="center">
  <img src="../img/Desktop-stickers-markdown.png" alt="Beispiel für einen Sticker mit gerendertem Markdown: Überschriften, Tabellen und Codeblöcke" width="720">
</p>

## Speicherung

Desktop Stickers folgt dem **XDG-Base-Directory**-Standard — nichts
liegt mehr in einem eigenen losen Ordner in deinem Home-Verzeichnis.

Sticker werden in `$XDG_DATA_HOME/desktop-stickers/stickers.json`
gespeichert (typischerweise
`~/.local/share/desktop-stickers/stickers.json`):

```json
{
  "stickers": [
    {
      "id": "001",
      "name": "",
      "text": "Markdown-Inhalt",
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

Die App-Einstellungen werden separat gespeichert, in
`$XDG_CONFIG_HOME/desktop-stickers/settings.json` (typischerweise
`~/.config/desktop-stickers/settings.json`) — Erscheinungsbild,
Verhalten, Autostart und Sprache.

> Aktualisierung von einer Installation vor v1.1.0? Beim ersten Start
> der neuen Binärdatei werden deine Daten automatisch und unauffällig
> vom alten Pfad `~/.stickers/` in die beiden oben genannten XDG-Pfade
> migriert. Keine manuellen Schritte nötig.

## Downloads

Alle veröffentlichten Versionen stehen auf der
[Releases](https://github.com/JavierLobo/KDE.DESKTOPSTICKERS/releases)-Seite
des Repositorys, jede mit ihrem Quellcode und den Versionshinweisen.

## Lizenz

GPL-3.0
</content>
