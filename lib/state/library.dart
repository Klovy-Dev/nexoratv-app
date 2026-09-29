import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state.dart';
import 'settings.dart';

/// Type d'élément dans la bibliothèque (favoris, reprise de lecture).
enum MediaKind { live, movie, series, episode }

/// Où on s'est arrêté dans un film ou un épisode.
class WatchProgress {
  const WatchProgress({
    required this.kind,
    required this.id,
    required this.title,
    required this.position,
    required this.duration,
    required this.updatedAt,
    this.image,
    this.seriesId,
  });

  final MediaKind kind;
  final String id;
  final String title;
  final String? image;

  /// Série de l'épisode (pour rouvrir sa fiche).
  final String? seriesId;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;

  double get fraction => duration.inMilliseconds <= 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0, 1);

  String get key => '${kind.name}:$id';

  Map<String, Object?> toJson() => {
    'k': kind.name,
    'id': id,
    't': title,
    'img': image,
    's': seriesId,
    'p': position.inMilliseconds,
    'd': duration.inMilliseconds,
    'u': updatedAt.millisecondsSinceEpoch,
  };

  static WatchProgress? fromJson(Object? j) {
    if (j is! Map) return null;
    final kind = MediaKind.values.asNameMap()[j['k']];
    final id = j['id'];
    if (kind == null || id is! String) return null;
    return WatchProgress(
      kind: kind,
      id: id,
      title: j['t'] as String? ?? '',
      image: j['img'] as String?,
      seriesId: j['s'] as String?,
      position: Duration(milliseconds: (j['p'] as num?)?.toInt() ?? 0),
      duration: Duration(milliseconds: (j['d'] as num?)?.toInt() ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (j['u'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

class Library {
  const Library({this.favorites = const {}, this.progress = const {}});

  /// Clés « type:id » (voir [favoriteKey]).
  final Set<String> favorites;
  final Map<String, WatchProgress> progress;

  static String favoriteKey(MediaKind kind, String id) => '${kind.name}:$id';

  bool isFavorite(MediaKind kind, String id) =>
      favorites.contains(favoriteKey(kind, id));

  /// Ids favoris d'un type donné.
  Set<String> favoriteIds(MediaKind kind) => {
    for (final k in favorites)
      if (k.startsWith('${kind.name}:')) k.substring(kind.name.length + 1),
  };

  WatchProgress? progressFor(MediaKind kind, String id) =>
      progress['${kind.name}:$id'];

  /// « Continuer à regarder » : les plus récents d'abord.
  List<WatchProgress> get continueWatching =>
      progress.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}

/// Favoris et reprise de lecture de la source active (chaque source a les
/// siens : les identifiants de chaînes / films diffèrent d'un serveur à
/// l'autre).
class LibraryController extends Notifier<Library> {
  /// Moins que ça : pas la peine de proposer la reprise.
  static const minPosition = Duration(seconds: 30);

  /// Nombre maximal d'éléments « en cours » gardés.
  static const maxProgress = 40;

  String? _sourceId;

  String get _favKey => 'library.$_sourceId.favorites';
  String get _progressKey => 'library.$_sourceId.progress';

  @override
  Library build() {
    _sourceId = ref.watch(appProvider.select((s) => s.active?.id));
    if (_sourceId == null) return const Library();
    final prefs = ref.read(prefsProvider);
    final progress = <String, WatchProgress>{};
    try {
      final raw = prefs.getString(_progressKey);
      if (raw != null) {
        for (final j in jsonDecode(raw) as List) {
          final p = WatchProgress.fromJson(j);
          if (p != null) progress[p.key] = p;
        }
      }
    } catch (_) {}
    return Library(
      favorites: (prefs.getStringList(_favKey) ?? const []).toSet(),
      progress: progress,
    );
  }

  void toggleFavorite(MediaKind kind, String id) {
    if (_sourceId == null) return;
    final key = Library.favoriteKey(kind, id);
    final favorites = {...state.favorites};
    if (!favorites.remove(key)) favorites.add(key);
    ref.read(prefsProvider).setStringList(_favKey, favorites.toList());
    state = Library(favorites: favorites, progress: state.progress);
  }

  /// Enregistre l'avancement ; un film presque fini sort de la liste.
  void saveProgress(WatchProgress p) {
    if (_sourceId == null || p.duration <= Duration.zero) return;
    final progress = {...state.progress};
    final remaining = p.duration - p.position;
    if (p.fraction >= 0.95 || remaining < const Duration(seconds: 90)) {
      progress.remove(p.key);
    } else if (p.position >= minPosition) {
      progress[p.key] = p;
    } else {
      return;
    }
    final kept = progress.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final trimmed = {for (final e in kept.take(maxProgress)) e.key: e};
    ref
        .read(prefsProvider)
        .setString(
          _progressKey,
          jsonEncode([for (final e in trimmed.values) e.toJson()]),
        );
    state = Library(favorites: state.favorites, progress: trimmed);
  }

  void removeProgress(MediaKind kind, String id) {
    final progress = {...state.progress}..remove('${kind.name}:$id');
    ref
        .read(prefsProvider)
        .setString(
          _progressKey,
          jsonEncode([for (final e in progress.values) e.toJson()]),
        );
    state = Library(favorites: state.favorites, progress: progress);
  }
}

final libraryProvider = NotifierProvider<LibraryController, Library>(
  LibraryController.new,
);
