import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/channel.dart';

/// Un élément de « Ma liste » (film ou série à voir plus tard).
class WatchlistItem {
  WatchlistItem({
    required this.sourceId,
    required this.id,
    required this.name,
    required this.url,
    this.logo,
    this.kind = MediaKind.movie,
    this.seriesId,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  final String sourceId;
  final String id;
  final String name;
  final String url;
  final String? logo;
  final MediaKind kind;
  final String? seriesId;
  final DateTime addedAt;

  String get key => '$sourceId::$id';

  Channel toChannel() =>
      Channel(id: id, name: name, url: url, logo: logo, kind: kind);

  Map<String, dynamic> toJson() => {
        'sourceId': sourceId,
        'id': id,
        'name': name,
        'url': url,
        'logo': logo,
        'kind': kind.name,
        'seriesId': seriesId,
        'addedAt': addedAt.millisecondsSinceEpoch,
      };

  factory WatchlistItem.fromJson(Map<String, dynamic> j) => WatchlistItem(
        sourceId: j['sourceId'] as String,
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        url: j['url'] as String? ?? '',
        logo: j['logo'] as String?,
        kind: MediaKind.values.firstWhere((k) => k.name == j['kind'],
            orElse: () => MediaKind.movie),
        seriesId: j['seriesId'] as String?,
        addedAt: DateTime.fromMillisecondsSinceEpoch(
            (j['addedAt'] as num?)?.toInt() ?? 0),
      );
}

class WatchlistRepository {
  static const _key = 'watchlist_v1';

  Future<List<WatchlistItem>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return [];
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => WatchlistItem.fromJson(e as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<WatchlistItem> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  Future<void> add(WatchlistItem item) async {
    final list = await load()..removeWhere((e) => e.key == item.key);
    list.insert(0, item);
    await _write(list);
  }

  Future<void> remove(String sourceId, String id) async {
    final list = await load()
      ..removeWhere((e) => e.key == '$sourceId::$id');
    await _write(list);
  }
}
