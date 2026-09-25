import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models.dart';

/// Persistance locale. Tout est chiffré (DPAPI sous Windows, Keystore sous
/// Android) : les sources contiennent des mots de passe.
class Storage {
  static const _secure = FlutterSecureStorage();

  static const _kToken = 'account_token';
  static const _kUser = 'account_user';
  static const _kSources = 'sources';
  static const _kActive = 'active_source';

  static Future<String?> token() => _secure.read(key: _kToken);

  static Future<AccountUser?> user() async {
    final raw = await _secure.read(key: _kUser);
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, Object?>;
    return AccountUser(j['name'] as String, j['email'] as String);
  }

  static Future<void> saveAccount(String token, AccountUser user) async {
    await _secure.write(key: _kToken, value: token);
    await _secure.write(
      key: _kUser,
      value: jsonEncode({'name': user.name, 'email': user.email}),
    );
  }

  static Future<void> clearAccount() async {
    await _secure.delete(key: _kToken);
    await _secure.delete(key: _kUser);
  }

  static Future<List<Source>> sources() async {
    final raw = await _secure.read(key: _kSources);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map<String, Object?>>()
          .map(Source.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveSources(List<Source> sources) => _secure.write(
    key: _kSources,
    value: jsonEncode([for (final s in sources) s.toJson()]),
  );

  static Future<String?> activeSourceId() => _secure.read(key: _kActive);

  static Future<void> saveActiveSourceId(String? id) => id == null
      ? _secure.delete(key: _kActive)
      : _secure.write(key: _kActive, value: id);
}
