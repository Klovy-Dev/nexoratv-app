import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/channel.dart';
import '../services/storage/watch_history_repository.dart';
import 'providers.dart';

class WatchHistoryNotifier extends AsyncNotifier<List<WatchEntry>> {
  @override
  Future<List<WatchEntry>> build() =>
      ref.watch(watchHistoryRepositoryProvider).load();

  Future<void> record({
    required String sourceId,
    required Channel channel,
    required int positionMs,
    required int durationMs,
  }) async {
    final entry = WatchEntry(
      sourceId: sourceId,
      channelId: channel.id,
      name: channel.name,
      url: channel.url,
      logo: channel.logo,
      group: channel.group,
      kind: channel.kind,
      positionMs: positionMs,
      durationMs: durationMs,
      updatedAt: DateTime.now(),
    );
    await ref.read(watchHistoryRepositoryProvider).upsert(entry);
    state = AsyncData(await ref.read(watchHistoryRepositoryProvider).load());
  }

  Future<void> forget(String sourceId, String channelId) async {
    await ref
        .read(watchHistoryRepositoryProvider)
        .remove(sourceId, channelId);
    state = AsyncData(await ref.read(watchHistoryRepositoryProvider).load());
  }

  Future<void> clearAll() async {
    await ref.read(watchHistoryRepositoryProvider).clear();
    state = const AsyncData([]);
  }

  int? resumePositionMs(String sourceId, String channelId) {
    final list = state.value ?? const [];
    for (final e in list) {
      if (e.key == '$sourceId::$channelId') {
        return e.resumable ? e.positionMs : null;
      }
    }
    return null;
  }
}

final watchHistoryProvider =
    AsyncNotifierProvider<WatchHistoryNotifier, List<WatchEntry>>(
        WatchHistoryNotifier.new);

/// Les entrées « à reprendre » (VOD entamée), les plus récentes d'abord.
final continueWatchingProvider = Provider<List<WatchEntry>>((ref) {
  final all = ref.watch(watchHistoryProvider).value ?? const [];
  return [for (final e in all) if (e.resumable) e];
});

/// Les films / épisodes terminés (rangée « Revoir »), les plus récents d'abord.
final watchedProvider = Provider<List<WatchEntry>>((ref) {
  final all = ref.watch(watchHistoryProvider).value ?? const [];
  return [for (final e in all) if (e.finished) e];
});
