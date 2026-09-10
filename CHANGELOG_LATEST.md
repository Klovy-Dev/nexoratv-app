Lecteur : gros buffer + plus de mémoire (approche IBOGOLD)

- Mise en cache large et lecture ~30 s d'avance : encaisse les à-coups réseau et les serveurs qui limitent le débit
- En sous-alimentation : courte pause nette le temps de refaire une réserve, puis lecture fluide — au lieu d'un hoquet permanent
- Tampon par défaut passé de 32 à 64 Mo
- Plus de mémoire allouée à l'app (largeHeap), comme les apps TV natives
- Inclut 1.4.2 (reconnexion auto des lives) et 1.4.1 (décodage matériel, bleu nuit)
