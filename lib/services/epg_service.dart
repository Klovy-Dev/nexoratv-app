import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/epg_entry.dart';
import '../models/playlist_source.dart';
import 'net_config.dart';
import 'xmltv_parser.dart';

/// Récupère et met en cache le guide XMLTV complet d'une source Xtream.
class EpgService {
  EpgService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(minutes: 3),
              headers: {'User-Agent': runtimeUserAgent},
            ));

  final Dio _dio;
  static const _cacheTtl = Duration(hours: 3);

  Future<File> _cacheFile(String sourceId) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/epg_cache');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}/$sourceId.json.gz');
  }

  /// `{channelId: [programmes]}`. Cache disque gzippé (3 h).
  Future<Map<String, List<EpgEntry>>> guide(PlaylistSource source) async {
    if (source.kind != SourceKind.xtream) return const {};
    final file = await _cacheFile(source.id);

    // cache frais ?
    try {
      if (file.existsSync() &&
          DateTime.now().difference(file.lastModifiedSync()) < _cacheTtl) {
        return _decodeCache(utf8.decode(gzip.decode(await file.readAsBytes())));
      }
    } catch (_) {}

    // téléchargement
    try {
      final host = source.host!.replaceAll(RegExp(r'/+$'), '');
      final res = await _dio.get<String>(
        '$host/xmltv.php',
        queryParameters: {
          'username': source.username,
          'password': source.password,
        },
        options: Options(responseType: ResponseType.plain),
      );
      final body = res.data ?? '';
      if (!body.contains('<tv') && !body.contains('<programme')) {
        return await _fallbackToStale(file);
      }
      final guide = parseXmltv(body);
      // écrit le cache (compact)
      await file.writeAsBytes(
        gzip.encode(utf8.encode(_encodeCache(guide))),
        flush: true,
      );
      return guide;
    } catch (_) {
      return await _fallbackToStale(file);
    }
  }

  Future<Map<String, List<EpgEntry>>> _fallbackToStale(File file) async {
    try {
      if (file.existsSync()) {
        return _decodeCache(
            utf8.decode(gzip.decode(await file.readAsBytes())));
      }
    } catch (_) {}
    return const {};
  }

  static String _encodeCache(Map<String, List<EpgEntry>> g) => jsonEncode({
        for (final e in g.entries)
          e.key: [
            for (final p in e.value)
              [
                p.title,
                p.description,
                p.start.millisecondsSinceEpoch,
                p.stop.millisecondsSinceEpoch,
              ]
          ]
      });

  static Map<String, List<EpgEntry>> _decodeCache(String s) {
    final map = jsonDecode(s) as Map<String, dynamic>;
    return {
      for (final e in map.entries)
        e.key: [
          for (final p in (e.value as List))
            EpgEntry(
              title: '${p[0]}',
              description: '${p[1]}',
              start: DateTime.fromMillisecondsSinceEpoch(p[2] as int),
              stop: DateTime.fromMillisecondsSinceEpoch(p[3] as int),
            )
        ]
    };
  }
}
