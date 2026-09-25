import 'dart:convert';
import 'dart:isolate';

import '../core/http.dart';
import '../core/models.dart';
import 'content_source.dart';

/// Client de l'API « player_api.php » des panels Xtream Codes.
class XtreamContent implements ContentSource {
  XtreamContent(this.source)
      : _base = normalizeBase(source.serverUrl ?? ''),
        _user = source.username ?? '',
        _pass = source.password ?? '';

  final Source source;
  final String _base;
  final String _user;
  final String _pass;

  final _liveCats = Memo<List<Category>>();
  final _live = Memo<List<LiveChannel>>();
  final _movieCats = Memo<List<Category>>();
  final _movies = Memo<List<Movie>>();
  final _seriesCats = Memo<List<Category>>();
  final _series = Memo<List<Series>>();

  static String normalizeBase(String url) {
    var u = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (u.isNotEmpty && !u.startsWith(RegExp(r'https?://'))) u = 'http://$u';
    return u.replaceAll(RegExp(r'/(player_api|get)\.php.*$'), '');
  }

  /// Vérifie les identifiants auprès du serveur (ajout d'une source).
  static Future<void> verify(Source source) async {
    final bytes = await XtreamContent(source)._fetch(const {});
    if (!await _decodeAuth(bytes)) {
      throw AppException('Identifiants refusés par le serveur.');
    }
  }

  _UrlParts get _parts => _UrlParts(_base, Uri.encodeComponent(_user), Uri.encodeComponent(_pass));

  Future<List<int>> _fetch(Map<String, String> params) async {
    if (_base.isEmpty) throw AppException('Adresse du serveur manquante.');
    final uri = Uri.parse('$_base/player_api.php').replace(queryParameters: {
      'username': _user,
      'password': _pass,
      ...params,
    });
    final res = await httpGet(uri, timeout: const Duration(seconds: 90));
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw AppException('Identifiants refusés par le serveur.');
    }
    if (res.statusCode != 200) {
      throw AppException('Le serveur a répondu une erreur (${res.statusCode}).');
    }
    return res.bodyBytes;
  }

  Future<List<T>> _list<T>(String action, _Mapper<T> map) async =>
      _decodeList(await _fetch({'action': action}), map, _parts);

  @override
  Future<List<Category>> liveCategories() =>
      _liveCats(() => _list('get_live_categories', _category));

  @override
  Future<List<LiveChannel>> liveChannels() => _live(() => _list('get_live_streams', _channel));

  @override
  Future<List<Category>> movieCategories() =>
      _movieCats(() => _list('get_vod_categories', _category));

  @override
  Future<List<Movie>> movies() => _movies(() => _list('get_vod_streams', _movie));

  @override
  Future<MovieDetails?> movieDetails(Movie movie) async =>
      _decodeDetails(await _fetch({'action': 'get_vod_info', 'vod_id': movie.id}));

  @override
  Future<List<Category>> seriesCategories() =>
      _seriesCats(() => _list('get_series_categories', _category));

  @override
  Future<List<Series>> series() => _series(() => _list('get_series', _oneSeries));

  @override
  Future<List<Season>> seasons(Series series) async {
    final bytes = await _fetch({'action': 'get_series_info', 'series_id': series.id});
    return groupSeasons(await _decodeEpisodes(bytes, _parts));
  }
}

/* ------------------------------------------------------------------ */
/*  Décodage en tâche de fond                                          */
/*  Fonctions de premier niveau : les closures envoyées aux isolates  */
/*  ne capturent que des valeurs simples (jamais le client et ses     */
/*  Future, non transférables).                                        */
/* ------------------------------------------------------------------ */

class _UrlParts {
  const _UrlParts(this.base, this.user, this.pass);
  final String base;
  final String user;
  final String pass;
}

typedef _Mapper<T> = T? Function(Map<String, Object?> e, _UrlParts p);

Object? _json(List<int> bytes) => jsonDecode(utf8.decode(bytes, allowMalformed: true));

Future<bool> _decodeAuth(List<int> bytes) => Isolate.run(() {
      final data = _json(bytes);
      final info = data is Map ? data['user_info'] : null;
      return info is Map && (info['auth'] == 1 || info['auth'] == '1');
    });

Future<List<T>> _decodeList<T>(List<int> bytes, _Mapper<T> map, _UrlParts parts) =>
    Isolate.run(() {
      final data = _json(bytes);
      if (data is! List) return <T>[];
      return <T>[
        for (final e in data)
          if (e is Map<String, Object?>) ?map(e, parts),
      ];
    });

Future<MovieDetails?> _decodeDetails(List<int> bytes) => Isolate.run(() {
      final data = _json(bytes);
      final info = data is Map ? data['info'] : null;
      if (info is! Map) return null;
      final backdrops = info['backdrop_path'];
      return MovieDetails(
        plot: jsonStr(info['plot'] ?? info['description']),
        genre: jsonStr(info['genre']),
        cast: jsonStr(info['cast'] ?? info['actors']),
        director: jsonStr(info['director']),
        duration: jsonStr(info['duration']),
        releaseDate: jsonStr(info['releasedate'] ?? info['release_date']),
        backdrop: backdrops is List && backdrops.isNotEmpty ? jsonStr(backdrops.first) : null,
      );
    });

Future<List<Episode>> _decodeEpisodes(List<int> bytes, _UrlParts p) => Isolate.run(() {
      final data = _json(bytes);
      final raw = data is Map ? data['episodes'] : null;
      // Selon les panels : { "1": [...], "2": [...] } ou une liste de listes.
      final groups = raw is Map ? raw.values : (raw is List ? raw : const []);
      final out = <Episode>[];
      for (final group in groups) {
        if (group is! List) continue;
        for (final e in group) {
          if (e is! Map) continue;
          final id = jsonStr(e['id']);
          if (id == null) continue;
          final info = e['info'] is Map ? e['info'] as Map : const {};
          final ext = jsonStr(e['container_extension']) ?? 'mp4';
          final number = int.tryParse(jsonStr(e['episode_num']) ?? '') ?? 0;
          out.add(Episode(
            id: id,
            title: jsonStr(e['title']) ?? 'Épisode $number',
            season: int.tryParse(jsonStr(e['season']) ?? '') ?? 1,
            number: number,
            url: '${p.base}/series/${p.user}/${p.pass}/$id.$ext',
            plot: jsonStr(info['plot']),
            image: jsonStr(info['movie_image']),
            duration: jsonStr(info['duration']),
          ));
        }
      }
      return out;
    });

Category? _category(Map<String, Object?> e, _UrlParts _) {
  final id = jsonStr(e['category_id']);
  return id == null ? null : Category(id, jsonStr(e['category_name']) ?? 'Sans nom');
}

LiveChannel? _channel(Map<String, Object?> e, _UrlParts p) {
  final id = jsonStr(e['stream_id']);
  if (id == null) return null;
  return LiveChannel(
    id: id,
    name: jsonStr(e['name']) ?? 'Chaîne $id',
    categoryId: jsonStr(e['category_id']) ?? '',
    url: '${p.base}/live/${p.user}/${p.pass}/$id.ts',
    logo: jsonStr(e['stream_icon']),
    number: int.tryParse(jsonStr(e['num']) ?? ''),
  );
}

Movie? _movie(Map<String, Object?> e, _UrlParts p) {
  final id = jsonStr(e['stream_id']);
  if (id == null) return null;
  final ext = jsonStr(e['container_extension']) ?? 'mp4';
  return Movie(
    id: id,
    name: jsonStr(e['name']) ?? 'Film $id',
    categoryId: jsonStr(e['category_id']) ?? '',
    url: '${p.base}/movie/${p.user}/${p.pass}/$id.$ext',
    poster: jsonStr(e['stream_icon']),
    rating: jsonNum(e['rating']),
    year: jsonStr(e['year']),
  );
}

Series? _oneSeries(Map<String, Object?> e, _UrlParts _) {
  final id = jsonStr(e['series_id']);
  if (id == null) return null;
  return Series(
    id: id,
    name: jsonStr(e['name']) ?? 'Série $id',
    categoryId: jsonStr(e['category_id']) ?? '',
    cover: jsonStr(e['cover']),
    plot: jsonStr(e['plot']),
    rating: jsonNum(e['rating']),
    year: jsonStr(e['releaseDate'] ?? e['release_date'])?.split('-').first,
  );
}
