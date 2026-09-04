import 'package:shared_preferences/shared_preferences.dart';

/// Clé de favori : identifie une chaîne au sein d'une source.
abstract final class FavoriteKey {
  static String of(String sourceId, String channelId) =>
      '$sourceId::$channelId';
}

/// Persistance des favoris (ensemble de clés `"{sourceId}::{channelId}"`).
class FavoritesRepository {
  static const _key = 'favorites_v1';

  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  Future<void> save(Set<String> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, favorites.toList());
  }
}
