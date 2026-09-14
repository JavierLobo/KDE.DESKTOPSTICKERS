# Desktop Stickers - Guida rapida

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

## Installazione

```bash
cd <percorso-repo>  # vai nella directory dove hai clonato il repository
chmod +x scripts/install.sh
./scripts/install.sh
```

Questo compila il binario Qt6 (`build/desktop-stickers`), lo installa
in `~/.local/bin/desktop-stickers` e registra l'avvio automatico in
`~/.config/autostart/io.github.javierlobo.desktopstickers.desktop`.

## Primo avvio

L'app si avvierà automaticamente alla tua prossima sessione di Plasma.
Per provarla subito senza disconnetterti:

```bash
~/.local/bin/desktop-stickers &
```

Dovresti vedere un'icona nel vassoio di sistema ("Desktop Stickers") e,
se hai già sticker salvati, le loro finestre appariranno nella loro
ultima posizione reale (salvata tramite una regola di KWin per sticker
— vedi `QA_CHECKLIST.md`). I dati risiedono in
`$XDG_DATA_HOME/desktop-stickers/stickers.json` (tipicamente
`~/.local/share/desktop-stickers/`), non in una cartella sparsa nella
home.

La lingua dell'interfaccia segue quanto salvato nelle Impostazioni
(spagnolo per impostazione predefinita). Per cambiarla: click destro
sull'icona nel vassoio → **Opzioni → Impostazioni → Lingue**.

## Crea il tuo primo sticker

- Click sull'icona nel vassoio → "Nuevo sticker", oppure
- Click sul pulsante "+" di qualsiasi sticker esistente

## Modifica

Click all'interno di uno sticker per modificarlo in Markdown — la
barra degli strumenti di formattazione (grassetto, titoli, elenchi,
tabelle, link...) appare sopra l'area di testo. Click all'esterno per
tornare all'anteprima renderizzata.

## Pin (tutti i desktop) e ridimensionamento

- Pulsante 📍/📌 nell'intestazione: alterna se lo sticker è visibile su
  tutti i desktop virtuali (📌) o solo sul proprio (📍). Per
  impostazione predefinita, i nuovi sticker partono senza pin
  (configurabile nelle Impostazioni).
- Trascina dall'angolo in basso a destra per ridimensionare.

## Pannello delle Impostazioni

Click destro sull'icona nel vassoio → **Opzioni → Impostazioni** apre
il pannello, con quattro sezioni:

- **Aspetto**: colore predefinito per i nuovi sticker (casuale,
  accento di sistema o fisso), elenco di preferenza dei caratteri e
  dimensione del carattere
- **Comportamento**: visibilità predefinita della barra degli
  strumenti Markdown, conferma di eliminazione, azione del click
  sinistro sul vassoio
- **Sistema**: avvio automatico attivo/disattivo, percorso dei dati
  (con pulsante "apri cartella"), backup di esportazione/importazione
- **Lingue**: selettore della lingua dell'interfaccia

Il resto del sottomenu **Opzioni** contiene Aiuto (documentazione su
GitHub), Dona (sostieni lo sviluppatore), Visualizza licenza e
Informazioni.

## Pannello degli Sticker

Click sinistro sull'icona nel vassoio (o "Panel de Stickers" nel menu)
apre l'elenco completo: ricerca per testo, ordinamento per
recenti/alfabetico/colore, click per aprire una nota, un menu
contestuale (apri, rinomina, duplica) e selezione multipla per
eliminarne più di una alla volta.

## Dati di prova

⚠️ Questo script **sovrascrive** il tuo `stickers.json` — se hai già
sticker creati, andranno persi. Usalo solo su un'installazione nuova,
o se non ti importa perdere i dati attuali.

```bash
chmod +x scripts/test-sticker.sh
./scripts/test-sticker.sh
```

Crea 3 sticker di esempio.

## Verifica completa

Vedi `QA_CHECKLIST.md` per la checklist manuale che copre tutte le
funzionalità.

## Risoluzione dei problemi

**Il binario non compila:**
- Verifica di avere Qt6 (`Core`, `Gui`, `Qml`, `Quick`, `Widgets`, `DBus`) installato
- Controlla l'output di `cmake -B build -S .` per il pacchetto mancante

**Uno sticker non appare su tutti i desktop:**
- "Tutti i desktop" è un opt-in **per sticker** tramite il pulsante di
  pin (📍/📌) dell'intestazione, non una regola globale dell'app —
  verifica prima che lo sticker in questione abbia il pin attivo (📌).
- Se il pin è attivo ma lo sticker continua a non seguirti tra i
  desktop, verifica la regola di KWin specifica di quello sticker:
  `kreadconfig6 --file kwinrulesrc --group desktopstickers-sticker-<id> --key desktopsrule`
  deve restituire `2` (Force). Se restituisce `1` o è vuoto, il pin
  non è stato scritto — riprova a cliccare 📌.
- Verifica anche che il gruppo sia elencato:
  `kreadconfig6 --file kwinrulesrc --group General --key rules` deve
  includere `desktopstickers-sticker-<id>`.
- Se i valori sono corretti ma non si applica dal vivo, forza il
  ricaricamento: `qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure`

**Una nuova lingua che ho aggiunto in `src/i18n/` non compare:**
- Deve avere esattamente le stesse chiavi di `src/i18n/es.json`
  (incluse `Language.name` e `Language.flag`).
- Devi ricompilare (`cmake --build build`) — l'elenco dei dizionari
  viene rilevato di nuovo solo in fase di configurazione/build, non
  all'avvio dell'app già installata.

**Log:**
```bash
journalctl --user -f
```
(l'app è un processo standalone, non parte di plasmashell, quindi i
suoi messaggi finiscono nel log della sessione utente; eseguire
`~/.local/bin/desktop-stickers` direttamente da un terminale per
vedere il suo output console dal vivo resta l'opzione più affidabile)
