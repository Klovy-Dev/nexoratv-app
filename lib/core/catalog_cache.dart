import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Réponses brutes des listes Xtream (chaînes, films, séries et leurs
/// catégories) gardées sur le disque : au démarrage suivant, le catalogue
/// s'affiche tout de suite depuis ce cache pendant qu'il se met à jour en
/// fond (la nouvelle version sert au démarrage d'après).
///
/// Ces réponses ne contiennent pas les identifiants (les URL de lecture
/// sont construites par l'appli). Les playlists M3U, qui les contiennent,
/// ne sont pas mises en cache.
class CatalogCache {
  /// Au-delà, le cache est jugé trop vieux et la liste est retéléchargée
  /// avant d'être affichée.
  static const maxAge = Duration(days: 7);

  static Future<Directory> _dir(String sourceId) async {
    final base = await getApplicationSupportDirectory();
    final safe = sourceId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return Directory(
      '${base.path}${Platform.pathSeparator}catalog'
      '${Platform.pathSeparator}$safe',
    );
  }

  static Future<File> _file(String sourceId, String key) async =>
      File('${(await _dir(sourceId)).path}${Platform.pathSeparator}$key.json');

  /// Null si absent, illisible ou trop vieux.
  static Future<List<int>?> read(String sourceId, String key) async {
    try {
      final f = await _file(sourceId, key);
      if (!await f.exists()) return null;
      if (DateTime.now().difference(await f.lastModified()) > maxAge) {
        return null;
      }
      return await f.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(
    String sourceId,
    String key,
    List<int> bytes,
  ) async {
    try {
      final f = await _file(sourceId, key);
      await f.parent.create(recursive: true);
      // Écriture atomique : un fichier à moitié écrit ne doit jamais être lu.
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(f.path);
    } catch (_) {
      // Le cache n'est qu'un accélérateur : un échec d'écriture est sans gravité.
    }
  }

  /// Oublie le catalogue d'une source (rechargement forcé, source retirée).
  static Future<void> clear(String sourceId) async {
    try {
      final d = await _dir(sourceId);
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
  }
}
