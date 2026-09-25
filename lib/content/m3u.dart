import 'dart:convert';
import 'dart:isolate';

import '../core/http.dart';
import '../core/models.dart';
import 'content_source.dart';

/// Source M3U / M3U8 : la playlist est téléchargée une fois puis analysée
/// en tâche de fond. Classement :
///  - URL contenant `/movie/` ou fichier vidéo (.mp4, .mkv…) → film ;
///  - URL contenant `/series/` → épisode, regroupé par série grâce au
///    motif « S01 E02 » du nom ;
///  - le reste → chaîne en direct.
class M3uContent implements ContentSource {
  M3uContent(this.source);

  final Source source;
  final _data = Memo<M3uCatalog>();

  /// Vérifie qu'une URL renvoie bien une playlist exploitable.
  static Future<int> verify(Source source) async {
    final catalog = await M3uContent(source)._load();
    final total =
        catalog.channels.length + catalog.movies.length + catalog.series.length;
    if (total == 0) {
      throw AppException('Aucune chaîne trouvée dans cette playlist.');
    }
    return total;
  }

  Future<M3uCatalog> _load() => _data(() async {
    final url = source.m3uUrl?.trim() ?? '';
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw AppException('URL de playlist invalide.');
    }
    final res = await httpGet(uri, timeout: const Duration(seconds: 120));
    if (res.statusCode != 200) {
      throw AppException(
        'Le serveur a répondu une erreur (${res.statusCode}).',
      );
    }
    return _parseInBackground(res.bodyBytes);
  });

  @override
  Future<List<Category>> liveCategories() async =>
      (await _load()).liveCategories;
  @override
  Future<List<LiveChannel>> liveChannels() async => (await _load()).channels;
  @override
  Future<List<Category>> movieCategories() async =>
      (await _load()).movieCategories;
  @override
  Future<List<Movie>> movies() async => (await _load()).movies;
  @override
  Future<MovieDetails?> movieDetails(Movie movie) async => null;
  @override
  Future<List<Category>> seriesCategories() async =>
      (await _load()).seriesCategories;
  @override
  Future<List<Series>> series() async => (await _load()).series;
  @override
  Future<List<Season>> seasons(Series series) async =>
      groupSeasons(series.episodes ?? const []);
}

class M3uCatalog {
  M3uCatalog({
    required this.liveCategories,
    required this.channels,
    required this.movieCategories,
    required this.movies,
    required this.seriesCategories,
    required this.series,
  });

  final List<Category> liveCategories;
  final List<LiveChannel> channels;
  final List<Category> movieCategories;
  final List<Movie> movies;
  final List<Category> seriesCategories;
  final List<Series> series;
}

/// Fonction de premier niveau : la closure envoyée à l'isolate ne capture
/// que les octets (jamais l'objet source et ses Future, non transférables).
Future<M3uCatalog> _parseInBackground(List<int> bytes) =>
    Isolate.run(() => parseM3u(utf8.decode(bytes, allowMalformed: true)));

final _attr = RegExp(r'([\w-]+)="([^"]*)"');
final _episodeTag = RegExp(
  r'^(.*?)[\s._-]*S(\d{1,2})[\s._-]*E(\d{1,3})\b',
  caseSensitive: false,
);
final _videoFile = RegExp(
  r'\.(mp4|mkv|avi|mov|wmv|m4v)(\?|$)',
  caseSensitive: false,
);

M3uCatalog parseM3u(String text) {
  final liveCats = <String>{}, movieCats = <String>{}, seriesCats = <String>{};
  final channels = <LiveChannel>[];
  final movies = <Movie>[];
  final seriesMap = <String, _SeriesAcc>{};

  String? name, logo, group;
  var index = 0;

  for (final raw in const LineSplitter().convert(text)) {
    final line = raw.trim();
    if (line.isEmpty) continue;

    if (line.startsWith('#EXTINF')) {
      final attrs = {
        for (final m in _attr.allMatches(line))
          m.group(1)!.toLowerCase(): m.group(2)!,
      };
      final lastQuote = line.lastIndexOf('"');
      final comma = line.indexOf(',', lastQuote < 0 ? 0 : lastQuote);
      name = comma < 0 ? null : line.substring(comma + 1).trim();
      if (name == null || name.isEmpty) name = attrs['tvg-name'];
      logo = attrs['tvg-logo'];
      group = attrs['group-title'];
      continue;
    }
    if (line.startsWith('#EXTGRP:')) {
      group ??= line.substring(8).trim();
      continue;
    }
    if (line.startsWith('#')) continue;

    // Ligne d'URL : termine l'entrée en cours.
    final url = line;
    final title = (name == null || name.isEmpty) ? 'Sans nom' : name;
    final cat = (group == null || group.isEmpty) ? 'Autres' : group;
    final id = '${index++}';
    final lower = url.toLowerCase();

    if (lower.contains('/series/')) {
      seriesCats.add(cat);
      final m = _episodeTag.firstMatch(title);
      final show = (m?.group(1)?.trim().isNotEmpty ?? false)
          ? m!.group(1)!.trim()
          : title;
      final acc = seriesMap.putIfAbsent(
        '$cat|$show',
        () => _SeriesAcc(show, cat, logo),
      );
      acc.episodes.add(
        Episode(
          id: id,
          title: title,
          season: int.tryParse(m?.group(2) ?? '') ?? 1,
          number: int.tryParse(m?.group(3) ?? '') ?? acc.episodes.length + 1,
          url: url,
        ),
      );
    } else if (lower.contains('/movie/') || _videoFile.hasMatch(lower)) {
      movieCats.add(cat);
      movies.add(
        Movie(id: id, name: title, categoryId: cat, url: url, poster: logo),
      );
    } else {
      liveCats.add(cat);
      channels.add(
        LiveChannel(id: id, name: title, categoryId: cat, url: url, logo: logo),
      );
    }
    name = logo = group = null;
  }

  var seriesIndex = 0;
  return M3uCatalog(
    liveCategories: [for (final c in liveCats) Category(c, c)],
    channels: channels,
    movieCategories: [for (final c in movieCats) Category(c, c)],
    movies: movies,
    seriesCategories: [for (final c in seriesCats) Category(c, c)],
    series: [
      for (final s in seriesMap.values)
        Series(
          id: 's${seriesIndex++}',
          name: s.name,
          categoryId: s.category,
          cover: s.cover,
          episodes: s.episodes,
        ),
    ],
  );
}

class _SeriesAcc {
  _SeriesAcc(this.name, this.category, this.cover);
  final String name;
  final String category;
  final String? cover;
  final List<Episode> episodes = [];
}
