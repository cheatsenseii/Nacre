# Chambre 02 — Le Silence

## Parcours
Deux vannes bruyantes dans les alcôves gauche et droite. Elles peuvent être
fermées dans n'importe quel ordre, avec la touche Interagir et une ligne de vue.
Les boîtiers et les cloisons sont solides. La portée est limitée à 2,35 m.

Quand les deux vannes sont fermées, le joueur rejoint le cercle devant le sas.
Trois secondes d'immobilité au sol ouvrent la porte. Regarder autour de soi reste
possible. Marcher, sauter, frapper ou sortir du cercle remet le compteur à zéro,
sans annuler les vannes. La pause et l'éditeur suspendent le compteur.

## Présentation et son
Vannes à volant animées, tuyaux, témoins orange puis turquoise, indicateur de
pression, trois segments de progression et porte à lamelles qui se lève.
Les panneaux indiquent les actions ; aucun indice ne dépend uniquement du son.
Deux boucles de pompe spatialisées s'arrêtent progressivement après fermeture.
La musique baisse pendant la phase de silence. Les événements aléatoires ne
se déclenchent pas pendant cette phase. La réussite ne lit jamais le volume
réel ni le microphone. La quête utilise une voix Flite avec sous-titres français.

## Intégration
- `silence.gd` : décor, collisions, interactions, temporisation et état.
- `main.gd` : interaction et mise à jour avant le labyrinthe.
- `experience.gd` : objectif courant et annonce de quête.
- `audio_mix.gd` : routage des pompes et atténuation de la musique.
- `checkpoints.gd` : `silence_valves` (deux booléens), `silence_open` (booléen).

Le format de sauvegarde reste en version 1 : les nouveaux champs sont optionnels.
Une ancienne partie de stade 0–2 garde une épreuve non résolue ; au stade 3 ou
au-delà, les deux vannes sont déjà fermées et la porte est ouverte.
Le compteur temporaire de trois secondes n'est pas sauvegardé. Les visites via
F3 ou le menu d'inspection ne modifient pas la sauvegarde de la partie réelle.

## Validation
`godot --headless --path . --script res://tests/test_silence.gd`

Le test parcourt physiquement les deux alcôves, contrôle les interactions derrière
les obstacles, le sas fermé/ouvert, le décompte (y compris son coupé), les vannes
sauvegardées séparément, les anciennes parties et le retour depuis l'inspection.
