# Lune — widget macOS pour la photo du ciel profond

*Document de conception — 26 octobre 2026*

## Intention

L'auteur photographie des objets du ciel profond (DSO). Il veut un widget posé sur
le bureau du Mac, toujours visible comme l'horloge, qui lui dit d'un coup
d'œil **si la nuit qui vient est exploitable** : y a-t-il une vraie nuit
noire, et la lune la gâche-t-elle ?

Le widget ne remplace pas la météo : les nuages, il les regarde ailleurs.

## Objectifs

- Widget macOS natif, format **moyen** (`systemMedium`), affichable sur le
  bureau et dans le centre de notifications.
- Affiche, pour la position choisie :
  1. La **lune dessinée selon sa phase réelle**, le **nom de la phase** et le
     **% d'illumination**.
  2. ☾ **Lever et coucher de la lune**.
  3. ✦ **Début et fin de la nuit astronomique** (soleil à −18° sous
     l'horizon). Remplace le lever/coucher classique du soleil.
  4. **La fenêtre noire** : la partie de la nuit astronomique où la lune est
     sous l'horizon. En vert avec heures et durée s'il y en a une, en gris
     (« Pas de fenêtre noire ce soir ») sinon.
  5. Une ligne « prochaine phase » : entre la nouvelle lune et la pleine
     lune, la date de la prochaine **pleine lune** ; entre la pleine lune et
     la nouvelle lune, la date de la prochaine **nouvelle lune** (« dans
     N j (date) »).
- **Position** : celle du Mac par défaut (« Position actuelle »), modifiable
  en éditant le widget (clic droit → Modifier le widget) pour choisir une
  ville, comme le widget Météo d'Apple. Plusieurs widgets avec des villes
  différentes doivent pouvoir coexister.
- **Calculs entièrement locaux** : aucune connexion internet nécessaire pour
  les éphémérides, aucun compte.
- **Publication sur le Mac App Store** visée (l'auteur a un compte Apple
  Developer). Donc : App Sandbox, app compagnon, icône, texte d'usage de la
  position, aucune collecte de données.

## Non-objectifs

- Météo, couverture nuageuse, seeing, pollution lumineuse.
- Position des DSO, planétarium, altitude d'objets particuliers.
- Formats petit et grand (peut venir plus tard).
- iOS / iPadOS (peut venir plus tard).

## Anti-objectifs (échec même si « ça marche »)

- Des heures fausses de plus de quelques minutes : le widget sert à décider
  de sortir le matériel, il doit être fiable.
- Afficher une fenêtre noire alors qu'il n'y a pas de nuit astronomique
  (ex. Paris de fin mai à mi-juillet) ou que la lune est levée.
- Un widget qui ne se met pas à jour (heures de la veille affichées le
  lendemain).
- Une dépendance à un service en ligne pour l'essentiel de l'affichage.

## Maquette validée

Disposition moyenne : la lune à gauche (~100 pt), à droite de haut en bas :

```
Paris ➤                         99 %
Pleine lune
☾   ↑ 17:42        ↓ 07:15
✦   nuit 19:21     → 05:28
[ Pas de fenêtre noire ce soir ]          (gris)
● Nouvelle lune dans 14 j (9 nov.)
```

Exemple avec fenêtre :

```
Paris ➤                          2 %
Premier croissant
☾   ↑ 08:51        ↓ 17:33
✦   nuit 19:08     → 05:44
[ Fenêtre noire 19:08 → 05:44 (10 h 36) ]  (vert)
○ Pleine lune dans 14 j (24 nov.)
```

Fond sombre type « nuit », texte blanc, ligne nuit astro en bleu pâle,
fenêtre noire en vert quand elle existe. Interface en français.

## Règles de calcul

- **« La nuit » affichée** : la nuit astronomique en cours si on est dedans,
  sinon la prochaine (celle qui commence ce soir). Elle bascule à la fin de
  la nuit astronomique (aube astro).
- **Lever / coucher de lune** affichés : ceux qui encadrent la nuit
  affichée (le prochain lever et le prochain coucher à partir de midi du
  jour de la nuit), pour qu'ils soient lisibles en regard de la nuit.
- **Fenêtre noire** : intervalle(s) de la nuit astronomique où l'altitude du
  centre de la lune est sous l'horizon (−0,833°, réfraction et demi-diamètre
  inclus, convention standard du lever/coucher). Une nuit peut contenir deux
  fenêtres (avant le lever et après le coucher de la lune) : les afficher
  toutes les deux.
- **Pas de nuit astronomique** (soleil jamais à −18°, été aux latitudes
  moyennes et hautes) : afficher « Pas de nuit astronomique » à la place de
  la ligne ✦ et pas de fenêtre noire.
- **Lune qui ne se lève ou ne se couche pas** ce jour-là : afficher « — »
  pour l'heure manquante.
- **Heures** affichées dans le fuseau horaire **du lieu choisi** (comme
  Météo), format 24 h.
- **Phase** : 8 noms usuels en français (Nouvelle lune, Premier croissant,
  Premier quartier, Lune gibbeuse croissante, Pleine lune, Lune gibbeuse
  décroissante, Dernier quartier, Dernier croissant).
- **Dessin** : terminateur réel à partir de la fraction illuminée et du
  sens (croissante/décroissante), orienté pour l'hémisphère du lieu
  (côté éclairé à droite quand la lune croît dans l'hémisphère nord).
- **Précision visée** : ±2 min sur les heures par rapport à une référence
  (IMCCE ou USNO), vérifiée par des tests sur des dates et lieux connus.

## Comment c'est fait (choix déjà pris)

- Swift, SwiftUI, WidgetKit, Xcode (l'auteur est sur macOS 26 avec Xcode).
- Une app compagnon + une extension widget, comme l'exige Apple.
- Calculs astronomiques faits sur l'appareil.
- Configuration du widget par App Intents (paramètre « Lieu » : Position
  actuelle ou une ville recherchée par nom).
- Dépôt Git public sur GitHub : `albedo83/lune-widget`.

## Laissé au constructeur

- Version minimale de macOS (suggestion : macOS 14, première version avec
  les widgets sur le bureau).
- Implémenter les algorithmes soi-même (Meeus, *Astronomical Algorithms*)
  ou utiliser une bibliothèque Swift open source compatible avec une
  publication App Store.
- Comment obtenir la position actuelle depuis l'extension widget dans le
  bac à sable (CoreLocation dans l'extension, ou la dernière position
  enregistrée par l'app compagnon dans un App Group), et que faire si la
  permission est refusée (message invitant à choisir une ville).
- Comment rechercher une ville (MapKit / CLGeocoder, qui demandent le
  réseau seulement au moment de la configuration).
- Fréquence de rafraîchissement de la timeline (au minimum : à chaque
  événement affiché et à minuit local).
- Contenu de l'app compagnon (au minimum : explication, demande
  d'autorisation de position, aperçu des mêmes infos).
- Rendu en mode teinté / transparent de macOS 26.
- Nom définitif, icône, textes App Store, politique de confidentialité :
  à préparer au moment de la publication, avec l'auteur.
