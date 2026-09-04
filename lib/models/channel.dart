/// Nature d'un flux : chaîne en direct, film (VOD) ou épisode de série.
enum MediaKind { live, movie, series }

/// Un élément lisible : chaîne TV en direct ou contenu VOD.
class Channel {
  const Channel({
    required this.id,
    required this.name,
    required this.url,
    this.number,
    this.logo,
    this.group,
    this.epgChannelId,
    this.streamId,
    this.kind = MediaKind.live,
    this.rating,
    this.year,
    this.addedAt,
    this.plot,
    this.genre,
  });

  /// Identifiant stable au sein d'une source (stream id Xtream, ou url hashée
  /// pour le M3U). Sert aux favoris et à la reprise de lecture.
  final String id;
  final String name;
  final String url;

  /// Numéro de chaîne (`tvg-chno` en M3U, `num` en Xtream), si fourni.
  final int? number;
  final String? logo;

  /// Catégorie / groupe (`group-title` en M3U, nom de catégorie en Xtream).
  final String? group;

  /// Identifiant de chaîne pour l'EPG XMLTV (`tvg-id`).
  final String? epgChannelId;

  /// `stream_id` Xtream brut (pour `get_short_epg`, `get_vod_info`).
  final String? streamId;

  final MediaKind kind;

  final double? rating;
  final int? year;
  final DateTime? addedAt;

  /// Synopsis (VOD). Souvent absent de la liste `get_vod_streams` : rempli
  /// seulement quand le panel le fournit.
  final String? plot;

  /// Genre(s) (VOD), si fourni par le panel.
  final String? genre;

  String get groupOrDefault => group ?? 'Non classé';
  bool get isLive => kind == MediaKind.live;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'number': number,
        'logo': logo,
        'group': group,
        'epgChannelId': epgChannelId,
        'streamId': streamId,
        'kind': kind.name,
        'rating': rating,
        'year': year,
        'addedAt': addedAt?.millisecondsSinceEpoch,
        'plot': plot,
        'genre': genre,
      };

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
        id: json['id'] as String,
        name: json['name'] as String,
        url: json['url'] as String,
        number: json['number'] as int?,
        logo: json['logo'] as String?,
        group: json['group'] as String?,
        epgChannelId: json['epgChannelId'] as String?,
        streamId: json['streamId'] as String?,
        kind: MediaKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => MediaKind.live,
        ),
        rating: (json['rating'] as num?)?.toDouble(),
        year: json['year'] as int?,
        addedAt: json['addedAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(json['addedAt'] as int),
        plot: json['plot'] as String?,
        genre: json['genre'] as String?,
      );

  Channel copyWith({String? group}) => Channel(
        id: id,
        name: name,
        url: url,
        number: number,
        logo: logo,
        group: group ?? this.group,
        epgChannelId: epgChannelId,
        streamId: streamId,
        kind: kind,
        rating: rating,
        year: year,
        addedAt: addedAt,
        plot: plot,
        genre: genre,
      );
}
