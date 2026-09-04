import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/avis_service.dart';

final avisServiceProvider = Provider((ref) => AvisService());

/// Intervalle de rafraîchissement automatique en arrière-plan.
const _avisTtl = Duration(minutes: 20);

/// Avis clients récupérés depuis le site (accueil). `keepAlive` + timer
/// d'auto-invalidation : sans ça, un avis posté après le lancement de
/// l'app n'apparaissait jamais tant que l'app restait ouverte (desktop —
/// peut tourner des heures). Se rafraîchit aussi manuellement via le
/// bouton « Rafraîchir » de la barre du haut (voir `refreshPlaylist`).
final avisProvider = FutureProvider<Avis>((ref) {
  ref.keepAlive();
  final timer = Timer(_avisTtl, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.watch(avisServiceProvider).fetch();
});
