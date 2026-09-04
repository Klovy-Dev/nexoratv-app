import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/account_info.dart';

/// Mémorise la dernière info de compte connue par source (pour l'afficher
/// même hors-ligne).
class AccountInfoRepository {
  static const _key = 'account_info_v1'; // {sourceId: json}

  Future<XtreamAccountInfo?> load(String sourceId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final entry = map[sourceId];
      return entry == null
          ? null
          : XtreamAccountInfo.fromJson(entry as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String sourceId, XtreamAccountInfo info) async {
    final p = await SharedPreferences.getInstance();
    Map<String, dynamic> map = {};
    try {
      map = jsonDecode(p.getString(_key) ?? '{}') as Map<String, dynamic>;
    } catch (_) {}
    map[sourceId] = info.toJson();
    await p.setString(_key, jsonEncode(map));
  }
}
