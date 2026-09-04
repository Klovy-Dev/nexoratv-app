import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/channel.dart';
import '../models/epg_entry.dart';
import '../services/epg_service.dart';
import 'providers.dart';
import 'settings_provider.dart';
import 'sources_provider.dart';

final epgServiceProvider = Provider((ref) => EpgService());

/// Guide XMLTV complet de la source courante : `{channelId: [programmes]}`.
final epgGuideProvider =
    FutureProvider.autoDispose<Map<String, List<EpgEntry>>>((ref) async {
  final epgEnabled =
      ref.watch(settingsValueProvider.select((s) => s.epgEnabled));
  final source = ref.watch(selectedSourceProvider);
  if (!epgEnabled || source == null) return const {};
  ref.keepAlive();
  return ref.watch(epgServiceProvider).guide(source);
});

/// Programmes d'une chaîne, en essayant plusieurs identifiants possibles.
List<EpgEntry> epgForChannel(
    Map<String, List<EpgEntry>> guide, Channel c) {
  for (final key in [c.epgChannelId, c.streamId, c.number?.toString()]) {
    if (key != null && guide[key] != null) return guide[key]!;
  }
  return const [];
}

EpgEntry? nowOn(List<EpgEntry> list) {
  for (final e in list) {
    if (e.isNow) return e;
  }
  return null;
}

EpgEntry? nextOn(List<EpgEntry> list) {
  final now = DateTime.now();
  for (final e in list) {
    if (e.start.isAfter(now)) return e;
  }
  return null;
}

/// « En cours / à suivre » d'une seule chaîne (Xtream `get_short_epg`) —
/// utilisé dans le lecteur, ne dépend pas du guide complet.
final shortEpgProvider =
    FutureProvider.family<List<EpgEntry>, String?>((ref, streamId) async {
  final epgEnabled =
      ref.watch(settingsValueProvider.select((s) => s.epgEnabled));
  if (!epgEnabled || streamId == null) return const [];
  final source = ref.watch(selectedSourceProvider);
  if (source == null) return const [];

  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 10), link.close);
  ref.onDispose(timer.cancel);

  return ref.watch(playlistServiceProvider).shortEpg(source, streamId);
});

EpgEntry? currentProgram(List<EpgEntry> list) => nowOn(list);
