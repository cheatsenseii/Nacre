# NACRE / Dernière Porte

Jeu d’horreur et d’exploration solo développé avec **Godot 4**. Le projet fonctionne localement : il n’utilise actuellement ni compte joueur, ni backend, ni authentification réseau.

## Lancer le projet

1. Installer Godot 4.4.x.
2. Ouvrir `project.godot`.
3. Appuyer sur **F5** pour lancer le jeu, ou **F6** pour tester la scène courante.
4. **F3** affiche le diagnostic technique en jeu.

Le preset `export_presets.cfg` permet également un export Windows Desktop x86_64.

## Commandes principales

- **ZQSD / WASD / flèches** : déplacement
- **Souris** : regarder
- **E** : interagir
- **F** : lampe torche
- **Ctrl** : courir
- **Maj** : s’accroupir
- **Espace** : sauter
- **Échap / F1** : pause et commandes
- **R** : reprendre au dernier point de reprise
- **F2** : éditeur de test
- **F3** : diagnostic / FPS / références
- **M** : musique

## Structure du projet

- `project.godot` : configuration principale Godot.
- `main.tscn` / `main.gd` : scène racine et assemblage des systèmes.
- `front_end.gd` : écran d’accueil, nouvelle partie et reprise.
- `checkpoints.gd` : sauvegarde locale et restauration de progression.
- `controls_menu.gd` : commandes et paramètres.
- `labyrinth.gd`, `combat.gd`, `silence.gd`, `torture.gd`, `horreurs.gd` : principales séquences de gameplay.
- `audio_mix.gd`, `foley.gd`, `character_voice.gd` : audio et voix.
- `docs/` : notes de conception et documentation de fonctionnalités.

Les fichiers `.gd.uid` sont conservés volontairement : Godot les utilise pour stabiliser les identifiants de ressources.

## Sauvegardes locales

La progression principale est stockée dans :

```text
user://progression.cfg
```

Sous Windows, les données `user://` se trouvent dans le dossier de données utilisateur Godot. Les sauvegardes ne sont pas versionnées dans Git.

## Dépôt propre

Les caches Godot, exports Windows, archives ZIP, logs, fichiers temporaires, réglages IDE et fichiers `.env` locaux sont ignorés par Git.

Ne committez pas un ZIP complet du projet : Git contient déjà chaque fichier source individuellement et l’archive ne ferait que dupliquer tout le dépôt.

## Documentation

Voir [`docs/README.md`](docs/README.md) pour l’index des notes de conception. Les anciennes notes très détaillées ont été conservées sous `docs/legacy/` afin de ne pas encombrer la racine du projet.
