# Dialogues de la salle du champignon

Les consignes du narrateur, le remerciement du champignon et sa phrase
« Quel délice ! » partagent la file de lecture de `character_voice.gd`.
Les sources AudioStreamPlayer3D du champignon restent positionnées dans la salle
et conservent leur timbre, leur volume et le bus Voix.

Une phrase libère la file sur son signal `finished`, avec une pause de 0,35 s
avant la suivante. Une exclamation de victoire attend la fin de la phrase en cours.
Les pauses ne sont pas assimilées à une fin de réplique.

`feeding.gd` enregistre ses deux sources avec `register_spatial` et demande
leur lecture avec `say`. La récompense et l'ouverture de la porte restent
indépendantes du son. Les sous-titres et la bouche suivent la lecture réelle.
Le mode sans voix conserve les textes du champignon.

`experience.gd` conserve l'objectif Le Repas pendant que le joueur reste
devant le champignon. Les consignes de la chambre du silence ne sont demandées
qu'à son entrée. Bouptilop vérifie aussi les phrases en attente avant de parler.

`stop_all` annule les voix en cours et en attente lors d'un chargement,
d'une inspection, d'une mort ou du début de la Salle des horreurs.
`cancel_line` permet de réinitialiser le repas sans perturber les autres phrases.

`tests/test_mushroom_dialogue.gd` lit les WAV d'origine et vérifie l'ordre,
l'absence de deux lecteurs vocaux actifs simultanément, la fin naturelle des
phrases, les pauses entre répliques, les sous-titres, le menu, l'éditeur, la voix
désactivée, l'inspection, la reprise et la protection contre les cris de Bouptilop.
