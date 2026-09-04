import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mots-clés qui identifient une catégorie « adulte ».
final _adultRe = RegExp(
  r'\b(xxx|adult|adulte|porn|18\+|\+18|hot|hentai|erotic|erotique)\b',
  caseSensitive: false,
);

bool isAdultCategory(String name) => _adultRe.hasMatch(name);

class ParentalSettings {
  const ParentalSettings({
    this.enabled = false,
    this.pinHash,
    this.hideAdult = true,
    this.locked = const {},
  });

  final bool enabled;
  final String? pinHash;

  /// Masquer entièrement les catégories adultes (indépendant du PIN).
  final bool hideAdult;

  /// Catégories verrouillées : clés `"sourceId::section::catégorie"`.
  final Set<String> locked;

  bool get hasPin => pinHash != null && pinHash!.isNotEmpty;

  bool checkPin(String pin) => hasPin && _hash(pin) == pinHash;

  bool isLocked(String sourceId, String section, String category) =>
      enabled && locked.contains('$sourceId::$section::$category');

  ParentalSettings copyWith({
    bool? enabled,
    String? pinHash,
    bool? hideAdult,
    Set<String>? locked,
  }) =>
      ParentalSettings(
        enabled: enabled ?? this.enabled,
        pinHash: pinHash ?? this.pinHash,
        hideAdult: hideAdult ?? this.hideAdult,
        locked: locked ?? this.locked,
      );

  static String _hash(String pin) =>
      sha256.convert(utf8.encode('nexora::$pin')).toString();

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'pinHash': pinHash,
        'hideAdult': hideAdult,
        'locked': locked.toList(),
      };

  factory ParentalSettings.fromJson(Map<String, dynamic> j) => ParentalSettings(
        enabled: j['enabled'] == true,
        pinHash: j['pinHash'] as String?,
        hideAdult: j['hideAdult'] != false,
        locked: {...(j['locked'] as List? ?? const []).map((e) => '$e')},
      );
}

class ParentalRepository {
  static const _key = 'parental_v1';

  Future<ParentalSettings> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return const ParentalSettings();
    try {
      return ParentalSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ParentalSettings();
    }
  }

  Future<void> save(ParentalSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(s.toJson()));
  }

  String hashPin(String pin) => ParentalSettings._hash(pin);
}
