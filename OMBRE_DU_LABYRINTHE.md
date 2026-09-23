# L’ombre du labyrinthe

L’ombre poursuit le joueur et provoque une mort au contact dans le cœur du
labyrinthe. Les nœuds activés sont conservés et la reprise se fait à l’entrée
du labyrinthe, avec 100 PV. Les anciennes sauvegardes restent compatibles.

| Réglage | Valeur |
| --- | --- |
| Vitesse à 0 / 1 / 2 / 3 nœuds | 1,50 / 1,85 / 2,25 / 2,85 m/s |
| Marche / course du joueur | 2,60 / 4,60 m/s |
| Distance minimale d’apparition | 4 m |
| Délai avant poursuite et capture | 1,4 s |
| Rayon de capture, sans obstacle | 0,85 m |
| Écart vertical maximal pour la capture | 1,2 m |
| Durée de la séquence de mort | 2,4 s |
| Protection à l’entrée et après la reprise | 6 s |

## Mise en œuvre

- `horror_events.gd` : pression par nœud, apparition, poursuite, vérification
  du contact. Une ombre active accélère sans se téléporter à l’activation d’un nœud.
- `shadow_navigation.gd` : graphe AStar3D des couloirs permanents, détours autour
  des socles, raccourcis autorisés uniquement lorsque la capsule passe.
  Chaque mouvement est vérifié par balayage physique.
- `labyrinth.gd` : une membrane ne se referme pas sur l’ombre en mouvement.
- `player_death.gd` : arrêt du joueur, son, chute, fondu, puis application du
  point de reprise. Le menu et l’éditeur suspendent cette séquence.
- `checkpoints.gd` : une restauration annule proprement la séquence de mort.
  En inspection, la reprise utilise l’état inspecté et préserve la sauvegarde réelle.
- `audio_mix.gd` : le son de capture reste audible pendant le gel du monde,
  mais respecte le volume des apparitions, le mode nuit et la pause des menus.

La capture utilise une ligne de vue entre l’ombre et le personnage, et non la
caméra à la troisième personne. La salle de repos et les autres salles sont
exclues. L’apparition distincte de la Salle des horreurs conserve son comportement.

## Vérification

`tests/test_shadow_death.gd` vérifie la navigation physique autour des obstacles,
les 81 cellules, le contact, les protections, l’évolution de la pression,
la reprise, le mixage de la mort, les menus et l’inspection.
`tests/test_shadow_runtime.gd` vérifie aussi la poursuite et la reprise
pendant une partie complète, avec les mises à jour normales de la scène.

Les tests utilisent Godot 4.4.1 sans interface ; les captures utilisent son
rendu OpenGL sous Linux. Le lancement et les performances natives Windows
restent à vérifier sur une machine Windows.
