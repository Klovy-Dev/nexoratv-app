import '../core/models.dart';
import 'm3u.dart';
import 'xtream.dart';

/// Catalogue d'une source : chaînes, films, séries. Les listes sont
/// chargées une fois puis gardées en mémoire (filtrage par catégorie côté
/// appli).
abstract class ContentSource {
  factory ContentSource.of(Source source) => switch (source.kind) {
    SourceKind.xtream => XtreamContent(source),
    SourceKind.m3u => M3uContent(source),
  };

  Future<List<Category>> liveCategories();
  Future<List<LiveChannel>> liveChannels();

  Future<List<Category>> movieCategories();
  Future<List<Movie>> movies();
  Future<MovieDetails?> movieDetails(Movie movie);

  Future<List<Category>> seriesCategories();
  Future<List<Series>> series();
  Future<List<Season>> seasons(Series series);
}

/// Regroupe des épisodes par saison, triés.
List<Season> groupSeasons(List<Episode> episodes) {
  final bySeason = <int, List<Episode>>{};
  for (final e in episodes) {
    bySeason.putIfAbsent(e.season, () => []).add(e);
  }
  final numbers = bySeason.keys.toList()..sort();
  return [
    for (final n in numbers)
      Season(n, bySeason[n]!..sort((a, b) => a.number.compareTo(b.number))),
  ];
}
