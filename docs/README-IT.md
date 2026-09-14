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
- Qt 6.4+ (`Core`, `Gui`, `Qml`, `Quick`, `Widgets`, `DBus`)
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

- Crea sticker dall'icona nel vassoio di sistema o dal pulsante "+" di
  uno sticker esistente (appare a cascata, spostato rispetto a quello
  di origine), con id incrementale
- Trascina sul desktop (movimento reale tramite
  `Window.startSystemMove()`), con la posizione reale (riportata da
  KWin, non da Qt) salvata dopo ogni trascinamento e ripristinata al
  riavvio, tramite una regola finestra di KWin per sticker
  (`desktopstickers-sticker-<id>`)
- Ridimensiona dall'angolo in basso a destra, con la dimensione salvata
  e ripristinata come la posizione
- Pin per sticker (pulsante 📍/📌): opt-in individuale per rendere
  quello sticker visibile su tutti i desktop virtuali
  contemporaneamente, tramite la stessa regola finestra di KWin dello
  sticker; senza pin, lo sticker esiste solo nel desktop in cui è
  stato creato o spostato. Valore predefinito configurabile in
  Impostazioni (Desktop); di serie, i nuovi sticker partono senza pin
- Modifica del testo in **Markdown completo** (titoli, tabelle, codice,
  citazioni, elenchi, grassetto/corsivo, link, checkbox), con
  alternanza automatica: click per modificare, perdita del focus per
  tornare all'anteprima renderizzata
- **Barra degli strumenti di formattazione Markdown** durante la
  modifica: grassetto, corsivo, barrato, titoli H1-H3, elenco puntato,
  elenco numerato, elenco di attività, link, immagine, codice inline,
  citazione, blocco di codice, riga orizzontale e tabella (con
  selettore di righe/colonne) — ogni pulsante alterna la selezione e ha
  la propria scorciatoia da tastiera. Quando lo sticker si restringe, i
  pulsanti a priorità più bassa si comprimono progressivamente da
  destra a sinistra dietro un pulsante "altre opzioni"; l'intera barra
  può essere nascosta dall'intestazione dello sticker o, in modo
  predefinito, dalle Impostazioni
- Nell'anteprima i link sono cliccabili (si aprono con il gestore URL
  di sistema) e i blocchi di codice vengono mostrati in un riquadro con
  sfondo differenziato
- Contenuto con scroll: una nota lunga non fuoriesce mai dallo sticker,
  e l'area di modifica scorre automaticamente per mantenere visibile
  il cursore durante la digitazione
- Colore di sfondo: casuale, colore di accento di sistema (segue il
  tema di Plasma in tempo reale) o un colore fisso a scelta —
  configurabile in Impostazioni (Aspetto)
- Famiglia e dimensione del carattere configurabili dalle Impostazioni:
  un elenco ordinato di preferenze (ad es. "Times New Roman" →
  "Liberation Serif") risolto alla prima famiglia effettivamente
  installata sulla macchina, più una dimensione in punti configurabile
- Nome per sticker, modificabile dal Pannello degli Sticker: se non
  impostato, viene derivato automaticamente dalla prima riga non vuota
  del testo (senza i simboli `#` di titolo). Troncato a 30 caratteri
  sia nell'intestazione dello sticker (`#<id> | <nome o fallback>`)
  sia nel menu del vassoio / Pannello
- **Pannello degli Sticker**: l'elenco completo, senza limiti, con
  ricerca, ordinamento (recenti/alfabetico/colore), click per aprire,
  un menu contestuale (apri, rinomina, duplica), selezione multipla ed
  eliminazione con conferma opzionale più un'opzione di annullamento
  di qualche secondo
- L'icona nel vassoio di sistema elenca le 10 note modificate più di
  recente (senza paginazione) — ogni riga apre o riporta in primo
  piano quella nota
- Il pulsante "✕" dello sticker chiude solo la sua finestra — la nota
  continua a esistere e può essere riaperta dal menu del vassoio o dal
  Pannello. Eliminare una nota è un'azione separata, sempre con
  un'opzione di annullamento
- **Pannello delle Impostazioni** (click destro sull'icona nel vassoio
  → Opzioni → Impostazioni): aspetto (colore/caratteri), comportamento
  (visibilità predefinita della barra Markdown, conferma di
  eliminazione, azione del click sinistro sul vassoio), sistema (avvio
  automatico, percorso dei dati con pulsante "apri cartella", backup
  di esportazione/importazione) e lingue
- **Interfaccia multilingua**: selettore della lingua nelle
  Impostazioni, con il nome di ogni lingua scritto nella lingua stessa
  (ad es. "Español", non "Spagnolo") accanto alla propria bandiera.
  Distribuita con spagnolo, inglese, francese e russo — ogni lingua è
  un file JSON autonomo sotto `src/i18n/`, rilevato automaticamente
  sia in fase di build sia in fase di esecuzione
- **Sottomenu "Opzioni"** nel menu del vassoio: Aiuto (documentazione
  su GitHub), Dona (sostieni lo sviluppatore), Visualizza licenza,
  Impostazioni e Informazioni
- Istanza singola: se l'app è già in esecuzione, avviarla di nuovo non
  apre una copia duplicata
- Ripristino automatico se KWin si riavvia a metà sessione (un crash, o
  `kwin_wayland --replace`): la persistenza della posizione si
  ricollega da sola, senza bisogno di riavviare l'app
- Il programma di installazione ripulisce le regole KWin orfane
  lasciate da sticker eliminati in sessioni precedenti
- Avvio automatico tramite una voce `.desktop` freedesktop standard
  (non i "Servizi in background" di Plasma), attivabile/disattivabile
  dalle Impostazioni

<p align="center">
  <img src="../img/Desktop-stickers-markdown.png" alt="Esempio di sticker con Markdown renderizzato: titoli, tabelle e blocchi di codice" width="720">
</p>

## Archiviazione

Desktop Stickers segue lo standard **XDG Base Directory** — nulla
risiede più in una cartella propria e sparsa nella home.

Gli sticker vengono salvati in
`$XDG_DATA_HOME/desktop-stickers/stickers.json` (tipicamente
`~/.local/share/desktop-stickers/stickers.json`):

```json
{
  "stickers": [
    {
      "id": "001",
      "name": "",
      "text": "Contenuto Markdown",
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

Le preferenze dell'app sono salvate separatamente, in
`$XDG_CONFIG_HOME/desktop-stickers/settings.json` (tipicamente
`~/.config/desktop-stickers/settings.json`) — aspetto, comportamento,
avvio automatico e lingua.

> Stai aggiornando da un'installazione precedente alla v1.1.0? La
> prima volta che esegui il nuovo binario, i tuoi dati vengono
> migrati automaticamente e silenziosamente dal vecchio percorso
> `~/.stickers/` ai due percorsi XDG indicati sopra. Non è richiesta
> alcuna azione manuale.

## Download

Tutte le versioni pubblicate sono nella pagina delle
[Release](https://github.com/JavierLobo/KDE.DESKTOPSTICKERS/releases)
del repository, ciascuna con il proprio codice sorgente e le note di
versione.

## Licenza

GPL-3.0
