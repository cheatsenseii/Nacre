# Nacre

Jeu d'horreur et d'exploration indépendant développé avec Godot 4.

## Lancer le projet

1. Ouvrir `project.godot` avec Godot 4.
2. Appuyer sur **F6** pour la scène courante ou **F5** pour lancer le jeu.
3. Utiliser **F3** pendant la partie pour afficher le diagnostic technique.

## Commandes principales

- **ZQSD / WASD** : se déplacer
- **Souris** : regarder
- **E** : interagir
- **F** : lampe torche
- **Ctrl** : courir
- **Maj** : s'accroupir
- **Espace** : sauter
- **Échap** : pause
- **R** : recommencer depuis le point de reprise
- **F1** : menu des commandes
- **F2** : éditeur de test
- **F3** : overlay debug / FPS / références
- **M** : musique

## Notes de développement

Le projet génère ses environnements et ses collisions en GDScript. Les fichiers `.import` sont recréés automatiquement par Godot. Le rendu utilise le mode **GL Compatibility** pour rester accessible sur davantage de machines.

Le diagnostic F3 est volontairement non intrusif : il vérifie les références principales, affiche la position du joueur et permet de repérer rapidement un problème sans modifier la sauvegarde.
