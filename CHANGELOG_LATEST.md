Correctif crash Fire TV Stick (gros catalogues)

- Le décodage du catalogue (décompression + lecture de dizaines de milliers d'entrées) se fait maintenant en arrière-plan, hors du thread d'affichage. Sur les Fire TV Stick / vieux boîtiers, ce calcul bloquait l'app plusieurs dizaines de secondes après le chargement de l'accueil → Android la tuait pour non-réponse (écran blanc puis fermeture).
- Le rafraîchissement automatique du catalogue ne gèle plus l'accueil.
- Inclut aussi 1.3.8 (moteur Skia) et 1.3.7 (accueil films/séries qui défile, Retour → barre latérale, lecteur navigable au D-pad, Paramètres → Diagnostic).
