import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Adresse MAC virtuelle, stable par installation — sert d'identifiant pour
/// le portail d'activation (`Brand.playlistApi`), comme un boîtier MAG.
/// Générée une fois puis conservée dans les préférences locales.
class DeviceMac {
  static const _key = 'device_mac';

  /// Préfixe OUI générique utilisé par de nombreux émulateurs IPTV.
  static const _oui = '00:1A:79';

  static Future<String> getOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null && existing.isNotEmpty) return existing;
    final mac = _generate();
    await prefs.setString(_key, mac);
    return mac;
  }

  static String _generate() {
    final rnd = Random.secure();
    final bytes = List.generate(
        3, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0'));
    return '$_oui:${bytes.join(':')}'.toUpperCase();
  }
}
