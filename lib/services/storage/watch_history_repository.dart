import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/channel.dart';

/// Une entrée d'historique / reprise de lecture.
class WatchEntry {
  WatchEntry({
    required this.sourceId,
    required this.channelId,
    required this.name,
    required this.url,
    this.logo,
    this.group,
    this.kind = MediaKind.live,
    this.positionMs = 0,
    this.durationMs = 0,
    required this.updatedAt,
  });

  final String sourceId;
  final String channelId;
  final String name;
  final String url;
  final String? logo;
  final String? group;
  final MediaKind kind;
  final int positionMs;
  final int durationMs;
  final DateTime updatedAt;

  String get key => '$sourceId::$channelId';

  /// Progression 0..1 (0 si inconnu ou terminé).
  double get progress {
    if (durationMs <= 0) return 0;
    final p = positionMs / durationMs;
    return (p >= 0.97 || p.isNaN) ? 0 : p.clamp(0, 1);
  }

  bool get resumable => kind != MediaKind.live && progress > 0.02;

  /// Film / épisode regardé jusqu'au bout (≥ 97 %).
  bool get finished =>
      kind != MediaKind.live &&
      durationMs > 0 &&
      positionMs / durationMs >= 0.97;

  Channel toChannel() => Channel(
        id: channelId,
        name: name,
        url: url,
        logo: logo,
        group: group,
        kind: kind,
      );

  Map<String, dynamic> toJson() => {
        'sourceId': sourceId,
        'channelId': channelId,
        'name': name,
        'url': url,
        'logo': logo,
        'group': group,
        'kind': kind.name,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory WatchEntry.fromJson(Map<String, dynamic> j) => WatchEntry(
        sourceId: j['sourceId'] as String,
        channelId: j['channelId'] as String,
        name: j['name'] as String? ?? '',
        url: j['url'] as String? ?? '',
        logo: j['logo'] as String?,
        group: j['group'] as String?,
        kind: MediaKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => MediaKind.live,
        ),
        positionMs: (j['positionMs'] as num?)?.toInt() ?? 0,
        durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
            (j['updatedAt'] as num?)?.toInt() ?? 0),
      );
}

/// Historique de lecture : liste bornée, triée du plus récent au plus ancien.
class WatchHistoryRepository {
  static const _key = 'watch_history_v1';
  static const _max = 60;

  Future<List<WatchEntry>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return [];
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => WatchEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> upsert(WatchEntry entry) async {
    final list = await load();
    list.removeWhere((e) => e.key == entry.key);
    list.insert(0, entry);
    if (list.length > _max) list.removeRange(_max, list.length);
    await _write(list);
  }

  Future<void> remove(String sourceId, String channelId) async {
    final list = await load()
      ..removeWhere((e) => e.key == '$sourceId::$channelId');
    await _write(list);
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }

  Future<void> _write(List<WatchEntry> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }
}
