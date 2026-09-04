import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/channel.dart';
import '../models/epg_entry.dart';
import '../models/playlist_source.dart';
import '../models/series.dart';
import 'm3u_parser.dart';
import 'mac_portal_service.dart';
import 'net_config.dart';
import 'xtream_client.dart';

/// Les [limit] éléments les plus récents : par date d'ajout si assez d'items
/// en ont une, sinon par identifiant numérique décroissant (les IDs Xtream
/// sont incrémentaux, donc plus grand = ajouté plus tard).
List<T> mostRecent<T>(
  List<T> items,
  DateTime? Function(T) dateOf,
  int? Function(T) idOf,
  int limit,
) {
  final dated = items.where((e) => dateOf(e) != null).toList();
  if (dated.length >= 3) {
    dated.sort((a, b) => dateOf(b)!.compareTo(dateOf(a)!));
    return dated.take(limit).toList();
  }
  final withId = items.where((e) => idOf(e) != null).toList()
    ..sort((a, b) => idOf(b)!.compareTo(idOf(a)!));
  return withId.take(limit).toList();
}

/// Libellé utilisé pour les éléments sans catégorie.
const String kUncategorized = 'Non classé';

final _catPrefixRe = RegExp(
  r'^\s*(VOD|SERIES|SÉRIES|SERIE|SÉRIE|LIVE|TV|IPTV|CHAINES?|CHAÎNES?)\s*[|:>\-]+\s*',
  caseSensitive: false,
);
final _catLangRe = RegExp(
  r'^\s*(FR|VF|VOSTFR|EN|VO|AR|ES|PT|DE|IT|NL|BE)\s*[|:>\-]+\s*',
  caseSensitive: false,
);

/// Nom de catégorie « propre » pour l'affichage (le nom brut reste utilisé
/// pour le filtrage). Ex. « VOD | FR - Action » → « Action ».
String prettyCategory(String raw) {
  var s = raw.trim();
  for (var i = 0; i < 3; i++) {
    final before = s;
    s = s.replaceFirst(_catPrefixRe, '').replaceFirst(_catLangRe, '');
    if (s == before) break;
  }
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s.isEmpty ? raw : s;
}

final _qualityTagRe = RegExp(
  r'[\s|\-_]*[\(\[]?\s*'
  r'(4k|uhd|fhd|hd|sd|hevc|h265|h\.265|h264|h\.264|full\s*hd|ultra\s*hd|'
  r'1080p?|720p?|576p?|480p?|multi(?:\s*audio)?|vip|backup|\d+\s*fps)'
  r'\s*[\)\]]?\s*$',
  caseSensitive: false,
);

/// Nom de catégorie sans le suffixe de qualité, pour fusionner
/// « FR TV (SD) | FR TV (HD) | FR TV 4K » → « FR TV ». Retire jusqu'à deux
/// suffixes consécutifs (ex. « FR - Films HD MULTI »).
String mergedQualityCategory(String raw) {
  var s = raw.trim();
  for (var i = 0; i < 2; i++) {
    final next = s.replaceFirst(_qualityTagRe, '').trim();
    if (next == s || next.isEmpty) break;
    s = next;
  }
  return s.isEmpty ? raw : s;
}

/// Compte les catégories d'une liste d'items possédant un groupe.
///
/// **L'ordre de la source est conservé** : les catégories apparaissent dans
/// l'ordre où on les rencontre (les listes de chaînes/films/séries sont triées
/// par ordre de catégorie de la source en amont). « Non classé » finit toujours
/// en dernier.
List<({String name, int count})> groupCountsOf(Iterable<String> groups) {
  final counts = <String, int>{}; // LinkedHashMap : garde l'ordre d'insertion
  for (final g in groups) {
    counts.update(g, (v) => v + 1, ifAbsent: () => 1);
  }
  final ordered = [
    for (final e in counts.entries)
      if (e.key != kUncategorized) (name: e.key, count: e.value),
  ];
  final uncat = counts[kUncategorized];
  if (uncat != null) ordered.add((name: kUncategorized, count: uncat));
  return ordered;
}

/// Résultat du chargement d'une source : direct + films + séries.
@immutable
class LoadedPlaylist {
  const LoadedPlaylist({
    required this.live,
    this.movies = const [],
    this.series = const [],
  });

  final List<Channel> live;
  final List<Channel> movies;
  final List<Series> series;

  bool get isEmpty => live.isEmpty && movies.isEmpty && series.isEmpty;

  List<({String name, int count})> liveGroups() =>
      groupCountsOf(live.map((c) => c.groupOrDefault));
  List<({String name, int count})> movieGroups() =>
      groupCountsOf(movies.map((c) => c.groupOrDefault));
  List<({String name, int count})> seriesGroups() =>
      groupCountsOf(series.map((s) => s.groupOrDefault));

  /// Films les plus récents (date `added`, sinon `stream_id` décroissant).
  List<Channel> recentMovies([int limit = 24]) => mostRecent<Channel>(
      movies, (m) => m.addedAt, (m) => int.tryParse(m.streamId ?? ''), limit);

  List<Series> recentSeries([int limit = 24]) => mostRecent<Series>(
      series, (s) => s.addedAt, (s) => int.tryParse(s.seriesId), limit);

  /// Les catégories de films les plus fournies (pour les rails par genre).
  List<String> topMovieGroups([int limit = 8]) {
    final g = movieGroups()..sort((a, b) => b.count.compareTo(a.count));
    return g.take(limit).map((e) => e.name).toList();
  }

  List<Channel> moviesInGroup(String group) =>
      movies.where((m) => m.groupOrDefault == group).toList();
  List<Series> seriesInGroup(String group) =>
      series.where((s) => s.groupOrDefault == group).toList();
}

/// Erreur de chargement présentable à l'utilisateur.
class PlaylistException implements Exception {
  PlaylistException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Charge une [PlaylistSource] en [LoadedPlaylist], quel que soit son type.
class PlaylistService {
  PlaylistService({Dio? dio, MacPortalService? macPortal})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
              headers: {'User-Agent': runtimeUserAgent},
            )),
        _macPortal = macPortal ?? MacPortalService();

  final Dio _dio;
  final MacPortalService _macPortal;

  /// Si [source] a été ajoutée par activation MAC, re-résout sa playlist
  /// auprès du portail (l'admin a pu la changer). En cas d'échec réseau, on
  /// garde silencieusement la dernière URL connue plutôt que de faire
  /// échouer le chargement.
  Future<PlaylistSource> _resolveMac(
      PlaylistSource source, void Function(String) log) async {
    final mac = source.activationMac;
    if (mac == null) return source;
    try {
      final playlist = await _macPortal.resolve(mac);
      log('portail MAC : playlist "${playlist.name}" résolue');
      return source.copyWith(
        name: playlist.name,
        m3uUrl: playlist.m3uUrl,
        epgUrl: playlist.epgUrl ?? '',
      );
    } on MacPortalException catch (e) {
      if (source.m3uUrl == null || source.m3uUrl!.isEmpty) {
        throw PlaylistException(e.message);
      }
      log('portail MAC injoignable (${e.kind.name}), utilise le cache : $e');
      return source;
    }
  }

  Future<LoadedPlaylist> load(
    PlaylistSource source, {
    void Function(String)? onDiag,
  }) async {
    void log(String m) {
      debugPrint('[playlist] $m');
      onDiag?.call(m);
    }

    switch (source.kind) {
      case SourceKind.m3uUrl:
        source = await _resolveMac(source, log);
        return LoadedPlaylist(live: await _loadM3u(source.m3uUrl!));
      case SourceKind.xtream:
        final client = XtreamClient(source, onDiag: log);
        try {
          return await _loadXtream(client, source, log)
              .timeout(const Duration(seconds: 90));
        } on TimeoutException {
          client.dispose();
          throw PlaylistException(
              'Le serveur met trop de temps à répondre (il limite peut-être '
              'ton débit). Réessaie dans quelques minutes.');
        } catch (_) {
          client.dispose();
          rethrow;
        }
    }
  }

  Future<LoadedPlaylist> _loadXtream(
    XtreamClient client,
    PlaylistSource source,
    void Function(String) log,
  ) async {
    log('début du chargement de "${source.name}" (${source.host})');
    await client.authenticate();
    final live = await client.fetchLiveChannels();
    if (live.isEmpty) {
      throw PlaylistException('Aucune chaîne renvoyée par le serveur.');
    }
    List<Channel> movies = const [];
    try {
      movies = await client.fetchMovies();
    } catch (e) {
      log('films : échec — $e');
    }
    List<Series> series = const [];
    try {
      series = await client.fetchSeries();
    } catch (e) {
      log('séries : échec — $e');
    }
    log('terminé : ${live.length} chaînes · ${movies.length} films · '
        '${series.length} séries');
    return LoadedPlaylist(live: live, movies: movies, series: series);
  }

  /// Charge les épisodes d'une série (Xtream uniquement).
  Future<List<Channel>> loadEpisodes(
      PlaylistSource source, String seriesId) async {
    if (source.kind != SourceKind.xtream) return const [];
    try {
      return await XtreamClient(source).fetchSeriesEpisodes(seriesId);
    } on XtreamException catch (e) {
      throw PlaylistException(e.message);
    }
  }

  /// « En cours / à suivre » d'une chaîne (Xtream `get_short_epg`).
  Future<List<EpgEntry>> shortEpg(PlaylistSource source, String? streamId) async {
    if (source.kind != SourceKind.xtream || streamId == null) return const [];
    try {
      return await XtreamClient(source).shortEpg(streamId);
    } catch (_) {
      return const [];
    }
  }

  /// Valide rapidement une source au moment de l'ajout, sans tout télécharger.
  Future<void> validate(PlaylistSource source) async {
    switch (source.kind) {
      case SourceKind.m3uUrl:
        try {
          final res = await _dio.get<String>(
            source.m3uUrl!,
            options: Options(
              responseType: ResponseType.plain,
              headers: {'Range': 'bytes=0-4095'},
            ),
          );
          final body = res.data ?? '';
          if (!body.contains('#EXTM3U') && !body.contains('#EXTINF')) {
            throw PlaylistException(
                'Le contenu ne ressemble pas à une playlist M3U.');
          }
        } on DioException catch (e) {
          throw PlaylistException(_humanDioError(e));
        }
      case SourceKind.xtream:
        try {
          // XtreamClient gère son propre Dio (responseType.plain requis).
          await XtreamClient(source).authenticate();
        } on XtreamException catch (e) {
          throw PlaylistException(e.message);
        }
    }
  }

  /// Active une adresse MAC auprès du portail NexoraTV : résout sa playlist
  /// puis la vérifie, sans encore l'ajouter aux sources (à la charge de
  /// l'appelant). Lève [MacPortalException] (MAC inconnu / portail
  /// injoignable) ou [PlaylistException] (playlist résolue mais invalide).
  Future<PlaylistSource> activateByMac(String mac) async {
    final playlist = await _macPortal.resolve(mac);
    final source = PlaylistSource(
      name: playlist.name,
      kind: SourceKind.m3uUrl,
      m3uUrl: playlist.m3uUrl,
      epgUrl: playlist.epgUrl,
      activationMac: mac,
    );
    await validate(source);
    return source;
  }

  Future<List<Channel>> _loadM3u(String url) async {
    final String body;
    try {
      final res = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      body = res.data ?? '';
    } on DioException catch (e) {
      throw PlaylistException(_humanDioError(e));
    }
    if (body.trim().isEmpty) {
      throw PlaylistException('La playlist est vide.');
    }
    final channels = M3uParser().parse(body);
    if (channels.isEmpty) {
      throw PlaylistException('Aucune chaîne trouvée dans la playlist.');
    }
    return channels;
  }

  static String _humanDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Le serveur ne répond pas (délai dépassé).';
      case DioExceptionType.connectionError:
        return 'Impossible de joindre l\'URL. Vérifie le lien.';
      case DioExceptionType.badResponse:
        return 'Erreur serveur (HTTP ${e.response?.statusCode}).';
      default:
        return e.message ?? 'Erreur réseau inconnue.';
    }
  }
}
