import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/channel.dart';
import '../models/playlist_source.dart';
import '../services/playlist_service.dart';
import '../services/storage/playlist_cache.dart';
import 'providers.dart';
import 'settings_provider.dart';
import 'sources_provider.dart';

/// Filet de sécurité au-dessus du délai interne de PlaylistService.
const _hardDeadline = Duration(seconds: 130);

/// Charge la playlist d'une source. Stratégie *stale-while-revalidate* :
///
/// - cache frais            → rendu immédiat
/// - cache périmé           → rendu immédiat + rafraîchissement en arrière-plan
///   (la vue se met à jour quand c'est fini ; en cas d'échec on garde le cache)
/// - aucun cache            → chargement bloquant borné par [_hardDeadline]
final playlistForSourceProvider =
    FutureProvider.family<LoadedPlaylist, String>((ref, sourceId) async {
  ref.keepAlive();

  final sources = ref.watch(sourcesProvider).value?.sources ?? const [];
  final source = sources.firstWhere(
    (s) => s.id == sourceId,
    orElse: () => throw PlaylistException('Source introuvable.'),
  );

  final cache = ref.watch(playlistCacheProvider);
  final service = ref.watch(playlistServiceProvider);
  // .select : ne réexécute ce provider (re-décompresse le cache, ~34k
  // éléments) que si l'un de ces deux réglages change réellement — pas à
  // chaque réglage sans rapport (thème, MAJ, etc.), qui gelait l'UI le temps
  // de tout relire/décoder.
  final (cacheHours, autoRefreshOnStart) = ref.watch(settingsValueProvider
      .select((s) => (s.cacheHours, s.autoRefreshOnStart)));
  final cached = await cache.read(source);

  final maxAge = Duration(hours: cacheHours);
  final fresh = cached != null &&
      !autoRefreshOnStart &&
      DateTime.now().difference(cached.savedAt) < maxAge;

  if (fresh) return cached.playlist;

  if (cached != null) {
    // Périmé : on sert le cache tout de suite, on rafraîchit sans bloquer.
    unawaited(_refresh(ref, source, service, cache));
    return cached.playlist;
  }

  // Aucun cache : chargement bloquant, mais borné.
  try {
    return await _fetchAndStore(source, service, cache)
        .timeout(_hardDeadline);
  } on TimeoutException {
    await cache.writeDiag('délai dépassé (${_hardDeadline.inSeconds}s)\n');
    throw PlaylistException(
        'Le chargement prend trop de temps. Le serveur limite peut-être ton '
        'débit. Réessaie dans quelques minutes.');
  }
});

Future<void> _refresh(
  Ref ref,
  PlaylistSource source,
  PlaylistService service,
  PlaylistCache cache,
) async {
  try {
    await _fetchAndStore(source, service, cache).timeout(_hardDeadline);
    ref.invalidateSelf(); // relit le cache tout frais
  } catch (_) {
    // Échec : on garde le cache périmé déjà affiché.
  }
}

Future<LoadedPlaylist> _fetchAndStore(
  PlaylistSource source,
  PlaylistService service,
  PlaylistCache cache,
) async {
  final diag = StringBuffer('== ${DateTime.now().toIso8601String()} ==\n');
  void onDiag(String m) => diag
      .writeln('${DateTime.now().toIso8601String().substring(11, 19)}  $m');
  try {
    final loaded = await service.load(source, onDiag: onDiag);
    await cache.write(source, loaded);
    await cache.writeDiag('$diag');
    return loaded;
  } catch (e) {
    diag.writeln('ERREUR : $e');
    await cache.writeDiag('$diag');
    rethrow;
  }
}

/// Force un rechargement réseau (ignore le cache).
Future<void> refreshPlaylist(WidgetRef ref, PlaylistSource source) async {
  await ref.read(playlistCacheProvider).clear(source.id);
  ref.invalidate(playlistForSourceProvider(source.id));
}

/// Playlist de la source courante (ou `null` si aucune source).
final currentPlaylistProvider = Provider<AsyncValue<LoadedPlaylist>?>((ref) {
  final source = ref.watch(selectedSourceProvider);
  if (source == null) return null;
  return ref.watch(playlistForSourceProvider(source.id));
});

/// Épisodes d'une série (chargés à la demande, gardés en cache mémoire).
final episodesProvider = FutureProvider.family<List<Channel>,
    ({String sourceId, String seriesId})>((ref, args) async {
  ref.keepAlive();
  final sources = ref.watch(sourcesProvider).value?.sources ?? const [];
  final source = sources.firstWhere(
    (s) => s.id == args.sourceId,
    orElse: () => throw PlaylistException('Source introuvable.'),
  );
  return ref
      .watch(playlistServiceProvider)
      .loadEpisodes(source, args.seriesId)
      .timeout(const Duration(seconds: 45));
});
