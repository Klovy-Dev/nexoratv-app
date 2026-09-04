import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/playlist_service.dart';
import '../services/storage/account_info_repository.dart';
import '../services/storage/category_prefs_repository.dart';
import '../services/storage/favorites_repository.dart';
import '../services/storage/playlist_cache.dart';
import '../services/storage/search_history_repository.dart';
import '../services/storage/settings_repository.dart';
import '../services/storage/source_repository.dart';
import '../services/storage/watch_history_repository.dart';
import '../services/storage/watchlist_repository.dart';

/// Fournisseurs "socle" : services et dépôts sans état, injectables en test.
final sourceRepositoryProvider =
    Provider<SourceRepository>((ref) => SourceRepository());

final favoritesRepositoryProvider =
    Provider<FavoritesRepository>((ref) => FavoritesRepository());

final playlistCacheProvider = Provider<PlaylistCache>((ref) => PlaylistCache());

final playlistServiceProvider =
    Provider<PlaylistService>((ref) => PlaylistService());

final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => SettingsRepository());

final watchHistoryRepositoryProvider =
    Provider<WatchHistoryRepository>((ref) => WatchHistoryRepository());

final watchlistRepositoryProvider =
    Provider<WatchlistRepository>((ref) => WatchlistRepository());

final categoryPrefsRepositoryProvider =
    Provider<CategoryPrefsRepository>((ref) => CategoryPrefsRepository());

final searchHistoryRepositoryProvider =
    Provider<SearchHistoryRepository>((ref) => SearchHistoryRepository());

final accountInfoRepositoryProvider =
    Provider<AccountInfoRepository>((ref) => AccountInfoRepository());
