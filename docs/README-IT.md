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
  <a href="README-RU.md"><img alt="RU" src="https://img.shields.io/badge/lang-RU-blueviolet.svg"></a>
  <a href="README-CN.md"><img alt="CN" src="https://img.shields.io/badge/lang-CN-yellow.svg"></a>
  <a href="README-JP.md"><img alt="JP" src="https://img.shields.io/badge/lang-JP-lightgrey.svg"></a>
</p>

Sticky notes fluttuanti per il desktop di KDE Plasma. Applicazione
standalone Qt6/QML (non un plasmoide) installata come programma normale
con avvio automatico — ogni sticker è una finestra indipendente, senza
decorazioni, con posizione e dimensione persistenti, e visibilità su
tutti i desktop virtuali come opzione per singolo sticker (pin).

<p align="center">
  <img src="../img/screenshot-desktop.png" alt="Sticker fluttuanti sul desktop di KDE Plasma" width="720">
</p>

## Requisiti

- Plasma 6.x (verificato con 6.7.4) e KWin, sessione Wayland
- Qt 6.5+ (`Core`, `Gui`, `Qml`, `Quick`, `Widgets`, `DBus`)
- CMake, Bash

## Installazione

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

Compila il binario, lo installa in `~/.local/bin/desktop-stickers` e
registra l'avvio automatico. Vedi [QUICKSTART-IT.md](QUICKSTART-IT.md)
per la guida completa (primo avvio, dati di prova, risoluzione dei
problemi) e `QA_CHECKLIST.md` per la checklist di verifica manuale.

## Funzionalità

- Crea sticker dall'icona nel vassoio di sistema o dal pulsante "+" di uno
  sticker esistente (appare a cascata, spostato rispetto a quello di
  origine), con id incrementale
- Trascina sul desktop (movimento reale tramite
  `Window.startSystemMove()`), con la posizione reale (riportata da
  KWin, non da Qt) salvata dopo ogni trascinamento e ripristinata al
  riavvio, tramite una regola finestra di KWin per sticker
  (`desktopstickers-sticker-<id>`)
- Ridimensiona dall'angolo in basso a destra, con la dimensione salvata
  e ripristinata come la posizione
- Pin per sticker (pulsante 📍/📌): opt-in individuale per rendere quello
  sticker visibile su tutti i desktop virtuali contemporaneamente,
  tramite la stessa regola finestra di KWin dello sticker; senza pin, lo
  sticker esiste solo nel desktop in cui è stato creato o spostato. Per
  impostazione predefinita, ogni nuovo sticker parte senza pin
- Modifica del testo in **Markdown completo** (titoli, tabelle, codice,
  citazioni, elenchi, grassetto/corsivo, link, checkbox), con
  alternanza automatica: click per modificare, perdita del focus per
  tornare all'anteprima renderizzata
- Nell'anteprima i link sono cliccabili (si aprono con il gestore URL di
  sistema) e i blocchi di codice vengono mostrati in un riquadro con
  sfondo differenziato
- Contenuto con scroll: una nota lunga non fuoriesce mai dallo sticker, e
  l'area di modifica scorre automaticamente per mantenere visibile il
  cursore durante la digitazione
- Colore di sfondo: tavolozza fissa di 6 toni pastello (assegnata
  casualmente a ogni nuovo sticker) o selettore di colore libero
- Nome per sticker, modificabile dal Pannello degli Sticker: se non
  impostato, viene derivato automaticamente dalla prima riga con
  contenuto del testo (senza i simboli `#` di titolo). Troncato a 30
  caratteri sia nell'intestazione dello sticker (`#<id> | <nome o
  fallback>`) sia nel menu del vassoio / Pannello
- L'icona nel vassoio di sistema elenca le 10 note modificate più di
  recente (senza paginazione) — ogni riga apre o riporta in primo piano
  quella nota. Il "Pannello degli Sticker" nello stesso menu apre una
  finestra con l'elenco completo, senza limiti: apri, rinomina ed
  elimina (con conferma) ogni nota
- Il pulsante "✕" dello sticker chiude solo la sua finestra — la nota
  continua a esistere e può essere riaperta dal menu del vassoio.
  Eliminare una nota è un'azione separata, raggiungibile solo dal
  Pannello degli Sticker, e chiede sempre conferma; eliminandola viene
  rimossa anche la sua regola finestra di KWin
- Persistenza in `~/.stickers/stickers.json`
- Istanza singola: se l'app è già in esecuzione, avviarla di nuovo non
  apre una copia duplicata
- Ripristino automatico se KWin si riavvia a metà sessione (un crash, o
  `kwin_wayland --replace`): la persistenza della posizione si ricollega
  da sola, senza bisogno di riavviare l'app
- Il programma di installazione ripulisce le regole KWin orfane lasciate
  da sticker eliminati in sessioni precedenti
- Avvio automatico tramite voce `.desktop` freedesktop standard (non i
  "Servizi in background" di Plasma)

<p align="center">
  <img src="../img/Desktop-stickers-markdown.png" alt="Esempio di sticker con Markdown renderizzato: titoli, tabelle e blocchi di codice" width="720">
</p>

## Archiviazione

Gli sticker vengono salvati in `~/.stickers/stickers.json`:

```json
{
  "stickers": [
    {
      "id": "001",
      "name": "",
      "text": "Contenido en Markdown",
      "color": "#FFD700",
      "x": 100,
      "y": 200,
      "width": 300,
      "height": 250,
      "pinned": false,
      "created": "2026-08-17T10:30:00Z",
      "modified": "2026-08-17T15:45:00Z"
    }
  ]
}
```

## Download

Tutte le versioni pubblicate sono nella pagina delle
[Release](https://github.com/JavierLobo/KDE.DESKTOPSTICKERS/releases)
del repository, ciascuna con il proprio codice sorgente e le note di
versione.

## Licenza

GPL-3.0
