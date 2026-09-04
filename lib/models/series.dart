/// Une série (Xtream VOD séries). Non lisible directement : il faut charger
/// ses saisons / épisodes via `PlaylistService.loadEpisodes`.
class Series {
  const Series({
    required this.id,
    required this.seriesId,
    required this.name,
    this.cover,
    this.backdrop,
    this.group,
    this.plot,
    this.genre,
    this.cast,
    this.director,
    this.rating,
    this.year,
    this.addedAt,
  });

  final String id;
  final String seriesId;
  final String name;
  final String? cover;
  final String? backdrop;
  final String? group;
  final String? plot;
  final String? genre;
  final String? cast;
  final String? director;
  final double? rating;
  final int? year;
  final DateTime? addedAt;

  String get groupOrDefault => group ?? 'Non classé';

  Map<String, dynamic> toJson() => {
        'id': id,
        'seriesId': seriesId,
        'name': name,
        'cover': cover,
        'backdrop': backdrop,
        'group': group,
        'plot': plot,
        'genre': genre,
        'cast': cast,
        'director': director,
        'rating': rating,
        'year': year,
        'addedAt': addedAt?.millisecondsSinceEpoch,
      };

  factory Series.fromJson(Map<String, dynamic> j) => Series(
        id: j['id'] as String,
        seriesId: j['seriesId'] as String,
        name: j['name'] as String,
        cover: j['cover'] as String?,
        backdrop: j['backdrop'] as String?,
        group: j['group'] as String?,
        plot: j['plot'] as String?,
        genre: j['genre'] as String?,
        cast: j['cast'] as String?,
        director: j['director'] as String?,
        rating: (j['rating'] as num?)?.toDouble(),
        year: j['year'] as int?,
        addedAt: j['addedAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(j['addedAt'] as int),
      );
}
