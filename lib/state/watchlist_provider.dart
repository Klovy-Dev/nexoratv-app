import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/channel.dart';
import '../models/series.dart';
import '../services/storage/watchlist_repository.dart';
import 'providers.dart';

class WatchlistNotifier extends AsyncNotifier<List<WatchlistItem>> {
  @override
  Future<List<WatchlistItem>> build() =>
      ref.watch(watchlistRepositoryProvider).load();

  bool contains(String sourceId, String id) =>
      (state.value ?? const []).any((e) => e.key == '$sourceId::$id');

  Future<void> toggleMovie(String sourceId, Channel movie) async {
    final repo = ref.read(watchlistRepositoryProvider);
    if (contains(sourceId, movie.id)) {
      await repo.remove(sourceId, movie.id);
    } else {
      await repo.add(WatchlistItem(
        sourceId: sourceId,
        id: movie.id,
        name: movie.name,
        url: movie.url,
        logo: movie.logo,
        kind: MediaKind.movie,
      ));
    }
    state = AsyncData(await repo.load());
  }

  Future<void> toggleSeries(String sourceId, Series s) async {
    final repo = ref.read(watchlistRepositoryProvider);
    if (contains(sourceId, s.id)) {
      await repo.remove(sourceId, s.id);
    } else {
      await repo.add(WatchlistItem(
        sourceId: sourceId,
        id: s.id,
        name: s.name,
        url: '',
        logo: s.cover,
        kind: MediaKind.series,
        seriesId: s.seriesId,
      ));
    }
    state = AsyncData(await repo.load());
  }

  Future<void> removeKey(String sourceId, String id) async {
    final repo = ref.read(watchlistRepositoryProvider);
    await repo.remove(sourceId, id);
    state = AsyncData(await repo.load());
  }
}

final watchlistProvider =
    AsyncNotifierProvider<WatchlistNotifier, List<WatchlistItem>>(
        WatchlistNotifier.new);
