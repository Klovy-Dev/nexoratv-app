import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../../models/channel.dart';
import '../../models/playlist_source.dart';
import '../../models/series.dart';
import '../playlist_service.dart';

/// Cache disque des playlists, par source. Le contenu est **gzippé** (~15 Mo →
/// ~2 Mo) et les identifiants de la source sont remplacés par des marqueurs
/// (`NEXORA_U` / `NEXORA_P`) : le fichier ne contient jamais tes accès en clair.
///
/// La décompression + `jsonDecode` + construction des ~34 000 objets se fait
/// dans un **isolate** (`Isolate.run`) : sur un CPU lent (Fire TV Stick) ce
/// travail bloquait le thread UI plusieurs dizaines de secondes → l'app était
/// tuée par Android pour non-réponse (ANR).
class PlaylistCache {
  static const Duration maxAge = Duration(hours: 12);

  /// Incrémenter à chaque changement de format.
  /// v9 : `plot` / `genre` sur les films (Channel).
  static const int _schema = 9;
  static const _uMarker = 'NEXORA_U';
  static const _pMarker = 'NEXORA_P';

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
      final bytes = await file.readAsBytes();
      final u = source.kind == SourceKind.xtream ? (source.username ?? '') : '';
      final p = source.kind == SourceKind.xtream ? (source.password ?? '') : '';
      // Hors du thread UI : ~34k objets à construire sur Fire TV Stick.
      return await Isolate.run(() => _decodeInIsolate(bytes, u, p));
    } catch (_) {
      return null;
    }
  }

  static ({LoadedPlaylist playlist, DateTime savedAt})? _decodeInIsolate(
      Uint8List bytes, String username, String password) {
    var content = utf8.decode(gzip.decode(bytes));
    if (username.isNotEmpty) content = content.replaceAll(_uMarker, username);
    if (password.isNotEmpty) content = content.replaceAll(_pMarker, password);
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
  }

  Future<void> write(PlaylistSource source, LoadedPlaylist playlist) async {
    try {
      final u = source.kind == SourceKind.xtream ? (source.username ?? '') : '';
      final p = source.kind == SourceKind.xtream ? (source.password ?? '') : '';
      // Encodage + gzip également hors du thread UI.
      final gz = await Isolate.run(
          () => _encodeInIsolate(playlist, u, p));
      final file = await _file(source.id);
      await file.writeAsBytes(gz, flush: true);
    } catch (_) {
      // best-effort
    }
  }

  static Uint8List _encodeInIsolate(
      LoadedPlaylist playlist, String username, String password) {
    var content = jsonEncode({
      'schema': _schema,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
      'live': [for (final c in playlist.live) c.toJson()],
      'movies': [for (final c in playlist.movies) c.toJson()],
      'series': [for (final s in playlist.series) s.toJson()],
    });
    if (username.isNotEmpty) content = content.replaceAll(username, _uMarker);
    if (password.isNotEmpty) content = content.replaceAll(password, _pMarker);
    return Uint8List.fromList(gzip.encode(utf8.encode(content)));
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
