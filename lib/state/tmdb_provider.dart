import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/tmdb_service.dart';
import 'settings_provider.dart';

final tmdbServiceProvider = Provider((ref) => TmdbService());

typedef TmdbQuery = ({String title, int? year, bool isSeries});

/// Métadonnées TMDB pour un titre (uniquement si une clé API est configurée).
final tmdbMetaProvider =
    FutureProvider.family<TmdbMeta?, TmdbQuery>((ref, q) async {
  final key = ref.watch(settingsValueProvider).tmdbApiKey;
  if (key.trim().isEmpty) return null;
  ref.keepAlive();
  return ref.watch(tmdbServiceProvider).lookup(
        apiKey: key,
        title: q.title,
        year: q.year,
        isSeries: q.isSeries,
      );
});
