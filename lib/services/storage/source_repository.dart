import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/playlist_source.dart';

/// Persistance des sources IPTV, de la source sélectionnée et de la dernière
/// chaîne ouverte par source.
///
/// Le **mot de passe Xtream** est mis dans le trousseau système
/// (`flutter_secure_storage`) quand c'est possible ; en cas d'indisponibilité
/// du trousseau, on retombe sur le stockage classique (dégradé mais
/// fonctionnel).
class SourceRepository {
  static const _sourcesKey = 'playlist_sources_v1';
  static const _selectedKey = 'selected_source_v1';
  static const _lastChannelKey = 'last_channel_v1';

  final _secure = const FlutterSecureStorage();
  bool _secureOk = true;

  String _pwKey(String sourceId) => 'xtream_pw_$sourceId';

  Future<bool> _writeSecret(String id, String value) async {
    if (!_secureOk) return false;
    try {
      await _secure.write(key: _pwKey(id), value: value);
      return true;
    } catch (e) {
      debugPrint('secure_storage indisponible : $e');
      _secureOk = false;
      return false;
    }
  }

  Future<String?> _readSecret(String id) async {
    if (!_secureOk) return null;
    try {
      return await _secure.read(key: _pwKey(id));
    } catch (e) {
      _secureOk = false;
      return null;
    }
  }

  Future<List<PlaylistSource>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sourcesKey);
    if (raw == null || raw.isEmpty) return [];
    List<PlaylistSource> sources;
    try {
      sources = (jsonDecode(raw) as List)
          .map((e) => PlaylistSource.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }

    var changed = false;
    final result = <PlaylistSource>[];
    for (final s in sources) {
      if (s.kind != SourceKind.xtream) {
        result.add(s);
        continue;
      }
      if (s.password != null && s.password!.isNotEmpty) {
        // Mot de passe présent dans le JSON : on tente de le déplacer.
        if (await _writeSecret(s.id, s.password!)) changed = true;
        result.add(s);
      } else {
        final pw = await _readSecret(s.id);
        result.add(s.copyWith(password: pw ?? ''));
      }
    }
    if (changed) await saveAll(result);
    return result;
  }

  Future<void> saveAll(List<PlaylistSource> sources) async {
    final prefs = await SharedPreferences.getInstance();
    final sanitized = <PlaylistSource>[];
    for (final s in sources) {
      if (s.kind == SourceKind.xtream &&
          s.password != null &&
          s.password!.isNotEmpty &&
          await _writeSecret(s.id, s.password!)) {
        sanitized.add(s.copyWith(password: '')); // retiré du JSON
      } else {
        sanitized.add(s); // trousseau indisponible : reste dans le JSON
      }
    }
    await prefs.setString(
      _sourcesKey,
      jsonEncode(sanitized.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> deleteSecret(String sourceId) async {
    try {
      await _secure.delete(key: _pwKey(sourceId));
    } catch (_) {}
  }

  Future<String?> loadSelectedId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedKey);
  }

  Future<void> saveSelectedId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_selectedKey);
    } else {
      await prefs.setString(_selectedKey, id);
    }
  }

  Future<Map<String, String>> loadLastChannels() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastChannelKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, '$v'));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveLastChannel(String sourceId, String channelId) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await loadLastChannels()..[sourceId] = channelId;
    await prefs.setString(_lastChannelKey, jsonEncode(map));
  }
}
