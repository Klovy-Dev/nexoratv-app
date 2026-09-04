import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/account_info.dart';
import '../models/channel.dart';
import '../models/epg_entry.dart';
import '../models/playlist_source.dart';
import '../models/series.dart';
import 'net_config.dart';

/// Erreur remontée par [XtreamClient] (identifiants invalides, serveur
/// injoignable, réponse inattendue...).
class XtreamException implements Exception {
  XtreamException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Client de l'API Xtream Codes (`player_api.php`).
///
/// Beaucoup de panneaux renvoient le JSON avec un `Content-Type` erroné
/// (`text/html`) : on récupère donc la réponse en texte brut et on la décode
/// nous-mêmes.
class XtreamClient {
  XtreamClient(this.source, {Dio? dio, this.onDiag})
      : assert(source.kind == SourceKind.xtream),
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              // Délai entre deux paquets reçus : coupe un serveur qui traîne.
              receiveTimeout: const Duration(seconds: 40),
              sendTimeout: const Duration(seconds: 15),
              responseType: ResponseType.plain,
              headers: {
                // Certains panneaux filtrent les requêtes sans User-Agent connu.
                'User-Agent': runtimeUserAgent,
              },
            ));

  final PlaylistSource source;
  final Dio _dio;
  final _cancel = CancelToken();

  /// Interrompt toutes les requêtes en cours (appelé sur timeout global).
  void dispose() {
    if (!_cancel.isCancelled) _cancel.cancel('annulé');
  }

  /// Callback de diagnostic (écrit dans un fichier lisible ensuite).
  final void Function(String)? onDiag;
  void _log(String m) => onDiag?.call(m);

  String get _host => source.host!.replaceAll(RegExp(r'/+$'), '');
  String get _user => source.username!;
  String get _pass => source.password!;
  String get _liveExt =>
      source.xtreamOutput == XtreamOutput.m3u8 ? 'm3u8' : 'ts';

  Uri _api(Map<String, String> params) =>
      Uri.parse('$_host/player_api.php').replace(queryParameters: {
        'username': _user,
        'password': _pass,
        ...params,
      });

  /// Récupère le corps brut d'une requête (String JSON). Le décodage est fait
  /// plus tard, éventuellement dans un isolate.
  Future<String> _getRaw(Map<String, String> params) async {
    final action = params['action'] ?? 'auth';
    final Response<dynamic> res;
    try {
      res = await _dio.getUri(_api(params), cancelToken: _cancel);
    } on DioException catch (e) {
      _log('$action : ERREUR RESEAU ${e.type} — ${e.message}');
      throw XtreamException(_humanError(e));
    }
    final raw = res.data;
    // Si Dio a déjà décodé (Map/List), on ré-encode proprement en JSON.
    final body = raw is String ? raw : jsonEncode(raw);
    _log('$action : HTTP ${res.statusCode}, ${body.length} octets');
    if (body.trim().isEmpty) throw XtreamException('Réponse vide du serveur.');
    // Détecte une page d'erreur HTML (limite de connexions, blocage IP...).
    final head = body.trimLeft();
    final headLow = head.substring(0, head.length.clamp(0, 32)).toLowerCase();
    if (headLow.startsWith('<')) {
      _log('$action : réponse HTML — ${head.substring(0, head.length.clamp(0, 200))}');
      throw XtreamException(
          'Le serveur a renvoyé une page web au lieu de données — souvent la '
          'limite de connexions simultanées de l\'abonnement, ou un blocage '
          'temporaire. Ferme les autres lectures et réessaie dans un instant.');
    }
    return body;
  }

  Future<dynamic> _get(Map<String, String> params) async {
    final body = await _getRaw(params);
    try {
      final decoded = jsonDecode(body);
      if (decoded is! List) {
        _log('${params['action'] ?? 'auth'} : type=${decoded.runtimeType}, '
            'début=${body.substring(0, body.length.clamp(0, 400))}');
      }
      return decoded;
    } on FormatException {
      _log('${params['action'] ?? 'auth'} : JSON invalide, '
          'début=${body.substring(0, body.length.clamp(0, 400))}');
      throw XtreamException('Réponse illisible du serveur (JSON invalide).');
    }
  }

  /// Normalise une réponse "liste" : certains panneaux renvoient un objet
  /// indexé (`{"0": {...}, "1": {...}}`) au lieu d'un tableau.
  static List<dynamic> _asList(dynamic data) {
    if (data is List) return data;
    if (data is Map) return data.values.toList();
    return const [];
  }

  /// Vérifie les identifiants et renvoie les infos du compte.
  /// Lève [XtreamException] si le compte est refusé.
  Future<XtreamAccountInfo> authenticate() async {
    final data = await _get(const {});
    if (data is! Map || data['user_info'] == null) {
      throw XtreamException('Serveur inattendu (pas une API Xtream Codes ?).');
    }
    final info = data['user_info'] as Map;
    final auth = info['auth'];
    if (auth == 0 || auth == '0') {
      throw XtreamException('Identifiant ou mot de passe incorrect.');
    }
    final rawStatus = '${info['status'] ?? ''}';
    final status = rawStatus.toLowerCase();
    if (status.isNotEmpty && status != 'active') {
      throw XtreamException('Compte $rawStatus.');
    }
    final expiresAt = _parseEpoch('${info['exp_date'] ?? ''}');
    if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
      throw XtreamException('Abonnement expiré.');
    }
    return XtreamAccountInfo(
      status: rawStatus.isEmpty ? null : rawStatus,
      expiresAt: expiresAt,
      isTrial: '${info['is_trial'] ?? ''}' == '1',
      maxConnections: int.tryParse('${info['max_connections'] ?? ''}'),
      activeConnections: int.tryParse('${info['active_cons'] ?? ''}'),
      createdAt: _parseEpoch('${info['created_at'] ?? ''}'),
    );
  }

  Future<List<Channel>> fetchLiveChannels() => _fetchStreams(
        categoriesAction: 'get_live_categories',
        streamsAction: 'get_live_streams',
        urlSegment: 'live',
        ext: _liveExt,
        kind: MediaKind.live,
      );

  Future<List<Channel>> fetchMovies() => _fetchStreams(
        categoriesAction: 'get_vod_categories',
        streamsAction: 'get_vod_streams',
        urlSegment: 'movie',
        ext: null, // fourni par `container_extension`
        kind: MediaKind.movie,
      );

  Future<List<Channel>> _fetchStreams({
    required String categoriesAction,
    required String streamsAction,
    required String urlSegment,
    required String? ext,
    required MediaKind kind,
  }) async {
    final categoriesRaw = await _get({'action': categoriesAction});
    final categoryNames = _categoryMap(categoriesRaw);
    final categoryRank = _categoryRank(categoriesRaw);
    final streams = _asList(await _get({'action': streamsAction}));

    final result = <Channel>[];
    for (final s in streams) {
      if (s is! Map) continue;
      final id = '${s['stream_id']}';
      if (id.isEmpty || id == 'null') continue;
      final effExt = ext ??
          ('${s['container_extension'] ?? ''}'.isEmpty
              ? 'mp4'
              : '${s['container_extension']}');
      final name = '${s['name'] ?? ''}'.trim();
      result.add(
        Channel(
          id: '${urlSegment}_$id',
          name: name.isEmpty ? 'Sans nom' : name,
          url: '$_host/$urlSegment/$_user/$_pass/$id.$effExt',
          number: int.tryParse('${s['num'] ?? ''}'),
          logo: _nullIfEmpty('${s['stream_icon'] ?? ''}'),
          group: categoryNames['${s['category_id']}'] ?? 'Non classé',
          epgChannelId: _nullIfEmpty('${s['epg_channel_id'] ?? ''}'),
          streamId: id,
          kind: kind,
          rating: _parseRating(s['rating']),
          year: _parseYear('${s['year'] ?? s['releaseDate'] ?? ''}'),
          addedAt: _parseEpoch('${s['added'] ?? ''}'),
        ),
      );
    }
    _sortByCategory(result, categoryRank, (c) => c.groupOrDefault,
        categoryNames);
    _log('$streamsAction : ${result.length} éléments');
    return result;
  }

  /// `{category_id: rang}` dans l'ordre renvoyé par le panel (= ordre source).
  static Map<String, int> _categoryRank(dynamic decoded) {
    final out = <String, int>{};
    var i = 0;
    for (final c in _asList(decoded)) {
      if (c is Map) out['${c['category_id']}'] = i++;
    }
    return out;
  }

  /// Tri **stable** par ordre de catégorie de la source (les non classées à la
  /// fin). On retrouve le rang via le nom de catégorie -> id.
  static void _sortByCategory<T>(
    List<T> items,
    Map<String, int> rankById,
    String Function(T) groupNameOf,
    Map<String, String> namesById,
  ) {
    if (rankById.isEmpty) return;
    const big = 1 << 20;
    final rankByName = <String, int>{};
    namesById.forEach((id, name) {
      rankByName.putIfAbsent(name, () => rankById[id] ?? big);
    });
    final indexed = [
      for (var i = 0; i < items.length; i++) (item: items[i], i: i),
    ];
    indexed.sort((a, b) {
      final ra = rankByName[groupNameOf(a.item)] ?? big;
      final rb = rankByName[groupNameOf(b.item)] ?? big;
      if (ra != rb) return ra.compareTo(rb);
      return a.i.compareTo(b.i); // stable
    });
    for (var i = 0; i < items.length; i++) {
      items[i] = indexed[i].item;
    }
  }

  /// Liste des séries (catalogue seulement, sans les épisodes).
  Future<List<Series>> fetchSeries() async {
    final categoriesRaw = await _get({'action': 'get_series_categories'});
    final categoryNames = _categoryMap(categoriesRaw);
    final categoryRank = _categoryRank(categoriesRaw);
    final list = _asList(await _get({'action': 'get_series'}));

    final result = <Series>[];
    for (final s in list) {
      if (s is! Map) continue;
      final id = '${s['series_id']}';
      if (id.isEmpty || id == 'null') continue;
      final name = '${s['name'] ?? ''}'.trim();
      result.add(
        Series(
          id: 'series_$id',
          seriesId: id,
          name: name.isEmpty ? 'Sans nom' : name,
          cover: _nullIfEmpty('${s['cover'] ?? ''}'),
          backdrop: _firstBackdrop(s['backdrop_path']),
          group: categoryNames['${s['category_id']}'] ?? 'Non classé',
          plot: _nullIfEmpty('${s['plot'] ?? ''}'),
          genre: _nullIfEmpty('${s['genre'] ?? ''}'),
          cast: _nullIfEmpty('${s['cast'] ?? ''}'),
          director: _nullIfEmpty('${s['director'] ?? ''}'),
          rating: _parseRating(s['rating']),
          year: _parseYear('${s['releaseDate'] ?? s['release_date'] ?? ''}'),
          addedAt: _parseEpoch('${s['last_modified'] ?? ''}'),
        ),
      );
    }
    _sortByCategory(result, categoryRank, (s) => s.groupOrDefault, categoryNames);
    _log('get_series : ${result.length} séries');
    return result;
  }

  static Map<String, String> _categoryMap(dynamic decoded) {
    final out = <String, String>{};
    for (final c in _asList(decoded)) {
      if (c is Map) {
        final name = '${c['category_name'] ?? ''}'.trim();
        out['${c['category_id']}'] = name.isEmpty ? 'Non classé' : name;
      }
    }
    return out;
  }

  static String? _nullIfEmpty(String? v) =>
      (v == null || v.isEmpty || v == 'null') ? null : v;

  static double? _parseRating(dynamic v) {
    final d = double.tryParse('$v');
    if (d == null || d <= 0) return null;
    return d > 10 ? d / 10 : d; // certains panels notent sur 100
  }

  static int? _parseYear(String v) {
    final m = RegExp(r'(19|20)\d{2}').firstMatch(v);
    return m == null ? null : int.tryParse(m.group(0)!);
  }

  static DateTime? _parseEpoch(String v) {
    final ts = int.tryParse(v);
    if (ts == null || ts <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts * 1000);
  }

  static String? _firstBackdrop(dynamic v) {
    if (v is List && v.isNotEmpty) return _nullIfEmpty('${v.first}');
    return _nullIfEmpty('$v');
  }

  /// « En cours / à suivre » d'une chaîne (2 programmes). Renvoie `[]` si
  /// indisponible. `streamId` = `Channel.streamId`.
  Future<List<EpgEntry>> shortEpg(String streamId) async {
    try {
      final data = await _get({
        'action': 'get_short_epg',
        'stream_id': streamId,
        'limit': '4',
      });
      final list = data is Map ? data['epg_listings'] : data;
      if (list is! List) return const [];
      final out = <EpgEntry>[];
      for (final e in list) {
        if (e is! Map) continue;
        final start = _parseEpoch('${e['start_timestamp'] ?? ''}');
        final stop = _parseEpoch('${e['stop_timestamp'] ?? ''}');
        if (start == null) continue;
        out.add(EpgEntry(
          title: _decodeMaybeB64('${e['title'] ?? ''}'),
          description: _decodeMaybeB64('${e['description'] ?? ''}'),
          start: start,
          stop: stop ?? start.add(const Duration(minutes: 30)),
        ));
      }
      out.sort((a, b) => a.start.compareTo(b.start));
      return out;
    } catch (_) {
      return const [];
    }
  }

  static String _decodeMaybeB64(String s) {
    try {
      final decoded = utf8.decode(base64.decode(s));
      // heuristique : si ça donne du texte lisible on garde
      if (decoded.runes.every((r) => r >= 9)) return decoded;
    } catch (_) {}
    return s;
  }

  /// Épisodes d'une série, à plat, groupés par « Saison N ».
  Future<List<Channel>> fetchSeriesEpisodes(String seriesId) async {
    final info = await _get({
      'action': 'get_series_info',
      'series_id': seriesId,
    });
    if (info is! Map) return const [];
    final episodes = info['episodes'];
    if (episodes is! Map) return const [];

    final result = <Channel>[];
    for (final entry in episodes.entries) {
      final season = int.tryParse('${entry.key}') ?? 0;
      for (final e in _asList(entry.value)) {
        if (e is! Map) continue;
        final id = '${e['id']}';
        if (id.isEmpty || id == 'null') continue;
        final ext = '${e['container_extension'] ?? ''}'.isEmpty
            ? 'mp4'
            : '${e['container_extension']}';
        final epNum = int.tryParse('${e['episode_num'] ?? ''}');
        final title = ('${e['title'] ?? ''}').trim().isEmpty
            ? 'Épisode ${epNum ?? id}'
            : '${e['title']}'.trim();
        result.add(
          Channel(
            id: 'episode_$id',
            name: epNum == null ? title : 'E${epNum.toString().padLeft(2, '0')} · $title',
            url: '$_host/series/$_user/$_pass/$id.$ext',
            number: epNum,
            group: 'Saison $season',
            kind: MediaKind.series,
          ),
        );
      }
    }
    result.sort((a, b) {
      final s = a.groupOrDefault.compareTo(b.groupOrDefault);
      return s != 0 ? s : (a.number ?? 0).compareTo(b.number ?? 0);
    });
    return result;
  }

  static String _humanError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Le serveur ne répond pas (délai dépassé).';
      case DioExceptionType.connectionError:
        return 'Impossible de joindre le serveur. Vérifie l\'adresse et le port.';
      case DioExceptionType.badResponse:
        return 'Erreur serveur (HTTP ${e.response?.statusCode}).';
      case DioExceptionType.badCertificate:
        return 'Certificat HTTPS refusé par le serveur.';
      default:
        return e.message ?? 'Erreur réseau inconnue.';
    }
  }
}
