import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../models/channel.dart';
import '../../models/playlist_source.dart';
import '../../models/series.dart';
import '../playlist_service.dart';

/// Cache disque des playlists, par source. Le contenu est **gzippé** (~15 Mo →
/// ~2 Mo) et les identifiants de la source sont remplacés par des marqueurs
/// (`__U__` / `__P__`) : le fichier ne contient jamais tes accès en clair.
class PlaylistCache {
  static const Duration maxAge = Duration(hours: 12);

  /// Incrémenter à chaque changement de format.
  static const int _schema = 8;
  static const _uMarker = 'NEXORA_U';
  static const _pMarker = 'NEXORA_P';

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/playlist_cache');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<File> _file(String sourceId) async =>
      File('${(await _dir()).path}/$sourceId.json.gz');

  Future<({LoadedPlaylist playlist, DateTime savedAt})?> read(
      PlaylistSource source) async {
    try {
      final file = await _file(source.id);
      if (!file.existsSync()) return null;
      var content = utf8.decode(gzip.decode(await file.readAsBytes()));
      if (source.kind == SourceKind.xtream) {
        content = content
            .replaceAll(_uMarker, source.username ?? '')
            .replaceAll(_pMarker, source.password ?? '');
      }
      final map = jsonDecode(content) as Map<String, dynamic>;
      if (map['schema'] != _schema) return null;

      List<Channel> chans(String key) => [
            for (final e in (map[key] as List? ?? const []))
              Channel.fromJson(e as Map<String, dynamic>),
          ];
      return (
        playlist: LoadedPlaylist(
          live: chans('live'),
          movies: chans('movies'),
          series: [
            for (final e in (map['series'] as List? ?? const []))
              Series.fromJson(e as Map<String, dynamic>),
          ],
        ),
        savedAt: DateTime.fromMillisecondsSinceEpoch(map['savedAt'] as int),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write(PlaylistSource source, LoadedPlaylist playlist) async {
    try {
      var content = jsonEncode({
        'schema': _schema,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'live': [for (final c in playlist.live) c.toJson()],
        'movies': [for (final c in playlist.movies) c.toJson()],
        'series': [for (final s in playlist.series) s.toJson()],
      });
      if (source.kind == SourceKind.xtream) {
        final u = source.username ?? '';
        final p = source.password ?? '';
        if (u.isNotEmpty) content = content.replaceAll(u, _uMarker);
        if (p.isNotEmpty) content = content.replaceAll(p, _pMarker);
      }
      final file = await _file(source.id);
      await file.writeAsBytes(gzip.encode(utf8.encode(content)), flush: true);
    } catch (_) {
      // best-effort
    }
  }

  Future<void> clear(String sourceId) async {
    try {
      final file = await _file(sourceId);
      if (file.existsSync()) await file.delete();
      // ancien format éventuel
      final old = File(file.path.replaceAll('.gz', ''));
      if (old.existsSync()) await old.delete();
    } catch (_) {}
  }

  /// Court texte de diagnostic dans `<cache>/diag.txt`.
  Future<void> writeDiag(String content) async {
    try {
      final file = File('${(await _dir()).path}/diag.txt');
      await file.writeAsString(content, flush: true);
    } catch (_) {}
  }
}
