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

Notes autocollantes flottantes pour le bureau KDE Plasma. Application
standalone Qt6/QML (pas un plasmoïde) installée comme un programme normal
avec démarrage automatique — chaque sticker est une fenêtre indépendante,
sans décoration, avec une position et une taille persistantes, et une
visibilité sur tous les bureaux virtuels en option, par sticker (épingle).

<p align="center">
  <img src="../img/screenshot-desktop.png" alt="Stickers flottants sur le bureau KDE Plasma" width="720">
</p>

## Prérequis

- Plasma 6.x (vérifié avec 6.7.4) et KWin, session Wayland
- Qt 6.4+ (`Core`, `Gui`, `Qml`, `Quick`, `Widgets`, `DBus`)
- CMake, Bash

## Installation

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

Compile le binaire, l'installe dans `~/.local/bin/desktop-stickers` et
enregistre le démarrage automatique. Voir [QUICKSTART-FR.md](QUICKSTART-FR.md)
pour le guide complet (premier lancement, données de test, dépannage) et
`QA_CHECKLIST.md` pour la checklist de vérification manuelle.

## Fonctionnalités

- Créer des stickers depuis l'icône de la zone de notification ou le
  bouton « + » d'un sticker existant (apparaît en cascade, décalé par
  rapport à celui d'origine), avec un identifiant incrémental
- Faire glisser sur le bureau (déplacement réel via
  `Window.startSystemMove()`), avec la position réelle (rapportée par
  KWin, pas par Qt) persistée après chaque déplacement et restaurée au
  redémarrage, via une règle de fenêtre KWin par sticker
  (`desktopstickers-sticker-<id>`)
- Redimensionner depuis le coin inférieur droit, avec la taille
  persistée et restaurée de la même façon que la position
- Épingle par sticker (bouton 📍/📌) : à activer individuellement pour
  que ce sticker soit visible sur tous les bureaux virtuels à la fois,
  via la même règle de fenêtre KWin du sticker ; sans épingle, le
  sticker n'existe que sur le bureau où il a été créé ou déplacé.
  Comportement par défaut configurable dans les Paramètres (Bureaux) ;
  par défaut, tout nouveau sticker démarre sans épingle
- Édition de texte en **Markdown complet** (titres, tableaux, code,
  citations, listes, gras/italique, liens, cases à cocher), avec bascule
  automatique : cliquer pour éditer, perdre le focus pour revenir à
  l'aperçu rendu
- **Barre de formatage Markdown** pendant l'édition : gras, italique,
  barré, titres H1-H3, liste à puces, liste numérotée, liste de tâches,
  lien, image, code en ligne, citation, bloc de code, ligne horizontale
  et tableau (avec un sélecteur de lignes/colonnes) — chaque bouton
  applique un *toggle* sur la sélection et possède son propre raccourci
  clavier. Quand le sticker rétrécit, les boutons les moins prioritaires
  se replient progressivement de droite à gauche derrière un bouton
  « plus d'options » ; la barre entière peut être masquée depuis l'en-tête
  du sticker ou par défaut depuis les Paramètres
- Dans l'aperçu, les liens sont cliquables (ouverts via le gestionnaire
  d'URL du système) et les blocs de code s'affichent dans un encadré au
  fond distinct
- Contenu défilant : une longue note ne déborde jamais du sticker, et la
  zone d'édition défile automatiquement pour garder le curseur visible
  pendant la saisie
- Couleur de fond : aléatoire, accentuation du système (suit le thème
  Plasma en direct) ou une couleur fixe choisie — configurable dans les
  Paramètres (Apparence)
- Police et taille de caractères configurables depuis les Paramètres :
  une liste de préférence ordonnée (ex. « Times New Roman » →
  « Liberation Serif ») résolue vers la première police réellement
  installée sur la machine, avec une taille en points également
  configurable
- Nom par sticker, modifiable depuis le Panneau des stickers : s'il
  n'est pas défini, il est dérivé automatiquement de la première ligne
  non vide du texte (les `#` de titre sont retirés). Tronqué à 30
  caractères aussi bien dans l'en-tête du sticker (`#<id> | <nom ou
  repli>`) que dans le menu de la zone de notification et le Panneau
- **Panneau des stickers** : la liste complète, sans limite, avec
  recherche, tri (récents/alphabétique/couleur), clic pour ouvrir, un
  menu contextuel (ouvrir, renommer, dupliquer), sélection multiple, et
  suppression avec confirmation facultative plus quelques secondes pour
  annuler
- L'icône de la zone de notification liste les 10 notes modifiées le
  plus récemment (sans pagination) — chaque ligne ouvre ou réactive
  cette note
- Le bouton « ✕ » du sticker ferme seulement sa fenêtre — la note existe
  toujours et peut être rouverte depuis le menu de la zone de
  notification ou le Panneau. Supprimer une note est une action séparée,
  toujours avec une option d'annulation
- **Panneau des Paramètres** (clic droit sur l'icône de la zone de
  notification → Options → Paramètres) : apparence (couleur/polices),
  comportement (visibilité par défaut de la barre Markdown, confirmation
  de suppression, action du clic gauche sur l'icône), système (démarrage
  automatique, chemin des données avec un bouton « ouvrir le dossier »,
  export/import de sauvegarde), et langues
- **Interface multilingue** : sélecteur de langue dans les Paramètres,
  le nom de chaque langue étant écrit dans cette langue elle-même
  (ex. « Español », pas « Spanish »), à côté de son drapeau. Disponible
  de base en espagnol, anglais, français, russe, italien, allemand,
  chinois et japonais — chaque langue est un fichier JSON autonome sous
  `src/i18n/`, détecté automatiquement à la compilation comme à
  l'exécution
- **Sous-menu « Options »** dans le menu de la zone de notification :
  Aide (documentation sur GitHub), Faire un don (soutenir le
  développeur), Voir la licence, Paramètres, et À propos
- Instance unique : si l'application tourne déjà, un second lancement
  n'ouvre pas de copie en double
- Récupération automatique si KWin redémarre en cours de session (un
  crash, ou `kwin_wayland --replace`) : la persistance de la position se
  rétablit d'elle-même, sans avoir à redémarrer l'application
- L'installateur nettoie les règles KWin orphelines de stickers déjà
  supprimés lors de sessions précédentes
- Démarrage automatique via une entrée `.desktop` freedesktop standard
  (pas les « Services d'arrière-plan » de Plasma), activable/désactivable
  depuis les Paramètres

<p align="center">
  <img src="../img/Desktop-stickers-markdown.png" alt="Exemple de sticker avec du Markdown rendu : titres, tableaux et blocs de code" width="720">
</p>

## Stockage

Desktop Stickers suit la norme **XDG Base Directory** — rien n'est
stocké dans un dossier isolé du répertoire personnel.

Les stickers sont enregistrés dans
`$XDG_DATA_HOME/desktop-stickers/stickers.json` (généralement
`~/.local/share/desktop-stickers/stickers.json`) :

```json
{
  "stickers": [
    {
      "id": "001",
      "name": "",
      "text": "Contenu Markdown",
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

Les préférences de l'application sont enregistrées séparément, dans
`$XDG_CONFIG_HOME/desktop-stickers/settings.json` (généralement
`~/.config/desktop-stickers/settings.json`) — apparence, comportement,
démarrage automatique et langue.

> Vous mettez à jour depuis une version antérieure à v1.1.0 ? La première
> fois que vous lancez le nouveau binaire, vos données sont migrées
> automatiquement et silencieusement depuis l'ancien chemin
> `~/.stickers/` vers les deux chemins XDG ci-dessus. Aucune action
> manuelle n'est nécessaire.

## Téléchargements

Toutes les versions publiées se trouvent sur la page
[Releases](https://github.com/JavierLobo/KDE.DESKTOPSTICKERS/releases)
du dépôt, chacune avec son code source et ses notes de version.

## Licence

GPL-3.0
