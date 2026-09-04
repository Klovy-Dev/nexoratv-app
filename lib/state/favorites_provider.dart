import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage/favorites_repository.dart';
import 'providers.dart';

export '../services/storage/favorites_repository.dart' show FavoriteKey;

class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier(this._ref) : super(const {}) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    state = await _ref.read(favoritesRepositoryProvider).load();
  }

  bool isFavorite(String sourceId, String channelId) =>
      state.contains(FavoriteKey.of(sourceId, channelId));

  Future<void> toggle(String sourceId, String channelId) async {
    final key = FavoriteKey.of(sourceId, channelId);
    final next = {...state};
    if (!next.remove(key)) next.add(key);
    state = next;
    await _ref.read(favoritesRepositoryProvider).save(next);
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>(
  (ref) => FavoritesNotifier(ref),
);
