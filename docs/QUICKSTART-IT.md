# Desktop Stickers - Guida rapida

<p align="center">
  <a href="QUICKSTART-SP.md"><img alt="ES" src="https://img.shields.io/badge/lang-ES-red.svg"></a>
  <a href="QUICKSTART-IT.md"><img alt="IT" src="https://img.shields.io/badge/lang-IT-green.svg"></a>
  <a href="QUICKSTART-EN.md"><img alt="EN" src="https://img.shields.io/badge/lang-EN-blue.svg"></a>
  <a href="QUICKSTART-DE.md"><img alt="DE" src="https://img.shields.io/badge/lang-DE-orange.svg"></a>
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

Compila il binario Qt6 (`build/desktop-stickers`), lo installa in
`~/.local/bin/desktop-stickers` e registra l'avvio automatico in
`~/.config/autostart/io.github.javierlobo.desktopstickers.desktop`.

## Primo avvio

L'app si avvierà automaticamente alla tua prossima sessione di Plasma.
Per provarla subito senza riavviare la sessione:

```bash
~/.local/bin/desktop-stickers &
```

Dovresti vedere un'icona nel vassoio di sistema ("Desktop Stickers") e, se
hai già sticker salvati in `~/.stickers/stickers.json`, le loro finestre
appariranno nella loro ultima posizione reale (salvata tramite una
regola di KWin per sticker — vedi `QA_CHECKLIST.md`).

## Crea il tuo primo sticker

- Click sull'icona nel vassoio → "Nuevo sticker", oppure
- Click sul pulsante "+" di qualsiasi sticker esistente

## Modifica

Click all'interno dello sticker per modificarlo in Markdown. Click
all'esterno per tornare all'anteprima renderizzata.

## Pin (tutti i desktop) e ridimensionamento

- Pulsante 📍/📌 nell'intestazione: alterna se lo sticker è visibile su
  tutti i desktop virtuali (📌) o solo sul proprio (📍). Per impostazione
  predefinita, ogni nuovo sticker parte senza pin.
- Trascina dall'angolo in basso a destra per ridimensionare.

## Dati di prova

⚠️ Questo script **sovrascrive** `~/.stickers/stickers.json` — se hai già
sticker creati, andranno persi. Usalo solo su un'installazione nuova o
se non ti importa perdere i dati attuali.

```bash
chmod +x scripts/test-sticker.sh
./scripts/test-sticker.sh
```

Crea 3 sticker di esempio in `~/.stickers/stickers.json`.

## Verifica completa

Vedi `QA_CHECKLIST.md` per la checklist manuale di tutte le
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
  deve restituire `2` (Force). Se restituisce `1` o è vuoto, il pin non
  è stato scritto — riprova a cliccare 📌.
- Verifica anche che il gruppo sia elencato:
  `kreadconfig6 --file kwinrulesrc --group General --key rules` deve
  includere `desktopstickers-sticker-<id>`.
- Se i valori sono corretti ma non si applica dal vivo, forza il
  ricaricamento: `qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure`
- Dettaglio completo del meccanismo (una regola di KWin per sticker,
  condivisa tra pin e posizione) in
  `superpowers/specs/2026-08-18-sticker-pin-position-resize-design.md`,
  sezione "Arquitectura: de regla global a reglas por-ventana"

**Log:**
```bash
journalctl --user -f
```
(l'app è un processo standalone, non parte di plasmashell, quindi i
suoi messaggi finiscono nel log della sessione utente; eseguire
`~/.local/bin/desktop-stickers` direttamente da un terminale per vedere il
suo output console dal vivo resta l'opzione più affidabile)
