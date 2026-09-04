import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/avis_service.dart';

final avisServiceProvider = Provider((ref) => AvisService());

/// Avis clients récupérés depuis le site (accueil). Gardé en vie pour la
/// session — pas besoin de recharger à chaque retour sur l'accueil.
final avisProvider = FutureProvider<Avis>((ref) {
  ref.keepAlive();
  return ref.watch(avisServiceProvider).fetch();
});
