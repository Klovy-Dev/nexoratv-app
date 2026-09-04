import 'dart:convert';

import '../models/channel.dart';

/// Parseur de playlists M3U / M3U8 (format étendu `#EXTM3U`).
///
/// Gère les attributs usuels des lignes `#EXTINF` (`tvg-id`, `tvg-logo`,
/// `tvg-chno`, `group-title`, ...), la directive `#EXTGRP`, et ignore les
/// options de lecture (`#EXTVLCOPT`, `#KODIPROP`, ...).
class M3uParser {
  static final _attrRegExp = RegExp(r'([\w-]+)="([^"]*)"');

  List<Channel> parse(String content) {
    final lines = const LineSplitter().convert(content);
    final channels = <Channel>[];

    String? pendingName;
    String? pendingLogo;
    String? pendingGroup;
    String? pendingEpgId;
    int? pendingNumber;

    void reset() {
      pendingName = null;
      pendingLogo = null;
      pendingGroup = null;
      pendingEpgId = null;
      pendingNumber = null;
    }

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        final commaIdx = line.indexOf(',');
        final attrPart = commaIdx == -1 ? line : line.substring(0, commaIdx);
        final displayName =
            commaIdx == -1 ? '' : line.substring(commaIdx + 1).trim();

        final attrs = <String, String>{};
        for (final m in _attrRegExp.allMatches(attrPart)) {
          attrs[m.group(1)!.toLowerCase()] = m.group(2)!;
        }

        pendingName = displayName.isNotEmpty
            ? displayName
            : (attrs['tvg-name'] ?? 'Sans nom');
        pendingLogo = _nullIfEmpty(attrs['tvg-logo']);
        pendingGroup = _nullIfEmpty(attrs['group-title']);
        pendingEpgId = _nullIfEmpty(attrs['tvg-id']);
        pendingNumber = int.tryParse(attrs['tvg-chno'] ?? '');
      } else if (line.startsWith('#EXTGRP:')) {
        pendingGroup = _nullIfEmpty(line.substring('#EXTGRP:'.length).trim());
      } else if (line.startsWith('#')) {
        continue; // autres directives ignorées
      } else {
        final url = line;
        channels.add(
          Channel(
            id: _stableId(url),
            name: pendingName ?? url,
            url: url,
            number: pendingNumber,
            logo: pendingLogo,
            group: pendingGroup ?? 'Non classé',
            epgChannelId: pendingEpgId,
            kind: MediaKind.live,
          ),
        );
        reset();
      }
    }

    return channels;
  }

  static String? _nullIfEmpty(String? v) =>
      (v == null || v.isEmpty) ? null : v;

  /// Identifiant déterministe basé sur l'URL (FNV-1a 32 bits).
  static String _stableId(String url) {
    var hash = 0x811c9dc5;
    for (final codeUnit in url.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return 'm3u_${hash.toRadixString(16)}';
  }
}
