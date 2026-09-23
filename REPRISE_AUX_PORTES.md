# Reprise à la dernière porte franchie

La mort par le monstre du champignon, les créatures de combat ou l'ombre utilise
la même séquence : 0 PV, arrêt des commandes, courte chute et fondu, puis retour
automatique à la dernière porte franchie avec 100 PV.

Les armes, les objets, les nœuds et les épreuves terminées sont conservés.
Une tentative de combat inachevée recommence avec les ennemis réinitialisés.
Les coups sont neutralisés deux secondes après la reprise ; l'ombre conserve
ses six secondes de répit avant réapparition.

## Portes

`door_return.gd` suit le franchissement des entrées des salles. Il retient la
dernière porte et le sens du passage. La reprise se situe deux mètres après
le seuil, orientée vers la salle où le joueur vient d'entrer. Un retour en
arrière change aussi le côté de reprise. La première salle utilise l'arrivée
du toboggan, puisqu'elle ne dispose pas de porte d'entrée classique.

L'ouverture d'une porte ne suffit pas à changer ce point. Les positions sont
définies par la géométrie du jeu : aucun vecteur arbitraire n'est chargé depuis
la sauvegarde. L'éditeur et les pauses ne déclenchent pas de nouveau passage.

## Sauvegarde et inspection

La version 1 accepte deux champs optionnels : `return_door` (entier 0–7,
jamais supérieur à la progression) et `return_back` (booléen). Les anciens
fichiers conservent leur reprise habituelle et initialisent ensuite le suivi.

`player_death.gd` utilise l'état de progression courant au moment de la mort.
`checkpoints.gd` restaure ensuite cet état et replace le joueur à sa porte.
L'inspection conserve son propre état sans remplacer la vraie sauvegarde.

`tests/test_door_return.gd` couvre les attaques mortelles des deux combats,
la mort générique à 0 PV, les passages dans les deux sens, la sauvegarde,
les armes et nœuds, les huit positions de reprise, les anciens fichiers,
les valeurs invalides et l'inspection.
