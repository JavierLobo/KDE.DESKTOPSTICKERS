# Desktop Stickers - Guide rapide

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
cd <chemin-du-depot>  # allez dans le dossier où vous avez cloné le dépôt
chmod +x scripts/install.sh
./scripts/install.sh
```

Ceci compile le binaire Qt6 (`build/desktop-stickers`), l'installe dans
`~/.local/bin/desktop-stickers`, et enregistre le démarrage automatique
dans `~/.config/autostart/io.github.javierlobo.desktopstickers.desktop`.

## Premier lancement

L'application démarrera automatiquement à votre prochaine session
Plasma. Pour l'essayer tout de suite sans vous déconnecter :

```bash
~/.local/bin/desktop-stickers &
```

Vous devriez voir une icône dans la zone de notification (« Desktop
Stickers ») et, si vous avez déjà des stickers enregistrés, leurs
fenêtres apparaîtront à leur dernière position réelle (persistée via une
règle KWin par sticker — voir `QA_CHECKLIST.md`). Les données se
trouvent sous `$XDG_DATA_HOME/desktop-stickers/stickers.json`
(généralement `~/.local/share/desktop-stickers/`), pas dans un dossier
isolé du répertoire personnel.

La langue de l'interface suit celle enregistrée dans les Paramètres
(français ou une autre langue selon votre choix, espagnol par défaut).
Pour la changer : clic droit sur l'icône de la zone de notification →
**Options → Paramètres → Langues**.

## Créer votre premier sticker

- Cliquez sur l'icône de la zone de notification → « Nuevo sticker », ou
- Cliquez sur le bouton « + » d'un sticker existant

## Modifier

Cliquez à l'intérieur d'un sticker pour l'éditer en Markdown — la barre
de formatage (gras, titres, listes, tableaux, liens...) apparaît
au-dessus de la zone de texte. Cliquez à l'extérieur pour revenir à
l'aperçu rendu.

## Épingle (tous les bureaux) et redimensionnement

- Bouton 📍/📌 dans l'en-tête : bascule la visibilité du sticker entre
  tous les bureaux virtuels (📌) ou seulement le sien (📍). Les nouveaux
  stickers démarrent sans épingle par défaut (configurable dans les
  Paramètres).
- Faites glisser depuis le coin inférieur droit pour redimensionner.

## Panneau des Paramètres

Clic droit sur l'icône de la zone de notification → **Options →
Paramètres** ouvre le panneau, avec quatre sections :

- **Apparence** : couleur par défaut des nouveaux stickers (aléatoire,
  accentuation du système, ou fixe), liste de préférence des polices, et
  taille de police
- **Comportement** : visibilité par défaut de la barre Markdown,
  confirmation de suppression, action du clic gauche sur l'icône
- **Système** : démarrage automatique on/off, chemin des données (avec
  un bouton « ouvrir le dossier »), export/import de sauvegarde
- **Langues** : sélecteur de langue de l'interface

Le reste du sous-menu **Options** propose Aide (documentation sur
GitHub), Faire un don (soutenir le développeur), Voir la licence, et À
propos.

## Panneau des stickers

Clic gauche sur l'icône de la zone de notification (ou « Panel de
Stickers » dans le menu) ouvre la liste complète : recherche par texte,
tri par récents/alphabétique/couleur, clic pour ouvrir une note, un menu
contextuel (ouvrir, renommer, dupliquer), et sélection multiple pour en
supprimer plusieurs à la fois.

## Données de test

⚠️ Ce script **écrase** votre `stickers.json` — si vous avez déjà des
stickers créés, ils seront perdus. À utiliser uniquement sur une
installation neuve, ou si perdre les données actuelles ne vous dérange
pas.

```bash
chmod +x scripts/test-sticker.sh
./scripts/test-sticker.sh
```

Crée 3 stickers d'exemple.

## Vérification complète

Voir `QA_CHECKLIST.md` pour la checklist manuelle couvrant toutes les
fonctionnalités.

## Dépannage

**Le binaire ne compile pas :**
- Vérifiez que vous avez Qt6 (`Core`, `Gui`, `Qml`, `Quick`, `Widgets`, `DBus`) installé
- Regardez la sortie de `cmake -B build -S .` pour le paquet manquant

**Un sticker n'apparaît pas sur tous les bureaux :**
- « Tous les bureaux » est une option **par sticker** via le bouton
  d'épingle (📍/📌) de l'en-tête, pas une règle globale de l'application
  — vérifiez d'abord que le sticker en question a bien l'épingle active
  (📌).
- Si l'épingle est active mais que le sticker ne vous suit toujours pas
  entre les bureaux, vérifiez la règle KWin spécifique à ce sticker :
  `kreadconfig6 --file kwinrulesrc --group desktopstickers-sticker-<id> --key desktopsrule`
  doit renvoyer `2` (Force). Si elle renvoie `1` ou est vide, l'épingle
  n'a jamais été écrite — recliquez sur 📌.
- Vérifiez aussi que le groupe est listé :
  `kreadconfig6 --file kwinrulesrc --group General --key rules` doit
  inclure `desktopstickers-sticker-<id>`.
- Si les valeurs sont correctes mais que ça ne s'applique pas en direct,
  forcez un rechargement :
  `qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure`

**Une nouvelle langue que j'ai ajoutée dans `src/i18n/` n'apparaît pas :**
- Elle doit avoir exactement les mêmes clés que `src/i18n/es.json` (y
  compris `Language.name` et `Language.flag`).
- Il faut recompiler (`cmake --build build`) — la liste des
  dictionnaires n'est redétectée qu'à la configuration/compilation, pas
  au démarrage de l'application déjà installée.

**Journaux :**
```bash
journalctl --user -f
```
(l'application est un processus autonome, pas une partie de plasmashell,
donc ses messages vont dans le journal de session utilisateur ; lancer
`~/.local/bin/desktop-stickers` directement depuis un terminal pour voir
sa sortie console en direct reste l'option la plus fiable)
