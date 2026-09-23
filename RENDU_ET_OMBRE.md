# Ombre 3D et rendu — septembre 2026

## Personnage inspiré de la référence

`shadow_actor.gd` construit une interprétation stylisée en volume : cheveux noirs
balayés, barbe et moustache, yeux écarquillés, sourire ouvert et langue, boucle
d'oreille, tee-shirt bleu noué et jean. Le dos, les poches, les coutures, les
mains et les chaussures possèdent aussi de la géométrie. Il ne s'agit pas d'une
reproduction photoréaliste ni d'une image plaquée devant la caméra.

Les détails fixes sont regroupés par matériau et articulation. Le modèle compte
environ 66 000 triangles. La marche dépend du déplacement réellement effectué :
un poursuivant bloqué cesse de marcher. Les nœuds renforcent son regard. La
capsule de navigation a été élargie pour correspondre à la nouvelle silhouette.

Le même modèle sert à l'apparition du silence, à la poursuite et au sursaut final.
Ce dernier utilise un petit rendu 3D isolé, avec profondeur et éclairage propres,
pendant seulement une demi-seconde. Il reste visible devant un mur sans aplatir
le visage. Ce rendu s'arrête en pause et dès la disparition du personnage.

## Éclairage et matériaux

- Six plafonniers créent des repères de lumière dans les couloirs du labyrinthe.
- La sélection des lampes tient compte de leur portée et privilégie les proches.
  Les changements minimes de position ne redistribuent pas constamment les places.
  Les quatre modes limitent les lampes dynamiques à 4, 6, 7 et 8.
- Les surfaces organiques utilisent un volume intérieur simple pour projeter
  leurs ombres. La peau déformée n'imprime plus ses triangles sur elle-même.
  Les volumes suivent aussi les membranes mobiles, sans nouveau collider.
- Les doubles surfaces à la jonction silence/labyrinthe sont supprimées.
- Le grain, la brume et le halo lumineux sont plus discrets. Le décalage des
  couleurs n'apparaît que brièvement pendant les coups et sursauts.
- Le second vignettage a été désactivé. Un seul réglage central suit désormais
  le mode graphique. Le moteur reste Godot 4.4.1, GL Compatibility, hors ligne.

## Corrections de comportement

- La caméra contrôle aussi les collisions du déplacement ajouté par une secousse.
- Une chute accidentelle sous le décor déclenche le retour à la dernière porte.
- Un échec d'écriture disque ne bloque plus l'avancement gardé en mémoire pour
  la réapparition. La sauvegarde disque conserve son mécanisme de nouvelle tentative.
- La caméra animée du menu n'utilise plus une interpolation de physique inadaptée.
- Le retour à la porte, la protection après la mort et la file des dialogues du
  champignon de la version précédente restent actifs.

## Vérifications

Tests ciblés : `test_visual_fixes.gd`, `test_horreurs.gd`,
`test_shadow_death.gd`, `test_shadow_runtime.gd`, `test_labyrinth.gd`,
`test_third.gd`, `test_chase.gd`, `test_graphics.gd`, `test_door_return.gd`,
`test_silence.gd` et `test_mushroom_dialogue.gd`.

Les captures du dossier `Apercus` proviennent du moteur Godot avec rendu OpenGL
effectif. Le portrait utilise un éclairage de présentation ; les images des
salles montrent leur éclairage de jeu. La machine de vérification utilise un
rendu logiciel Linux : ces images ne constituent pas une mesure de FPS Windows.
Le lancement natif et le confort graphique sur le PC Windows final restent à
valider sur cette machine.
