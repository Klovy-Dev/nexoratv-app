import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/playlist_source.dart';
import 'providers.dart';

@immutable
class SourcesState {
  const SourcesState({required this.sources, this.selectedId});

  final List<PlaylistSource> sources;
  final String? selectedId;

  PlaylistSource? get selected {
    for (final s in sources) {
      if (s.id == selectedId) return s;
    }
    return sources.isEmpty ? null : sources.first;
  }

  SourcesState copyWith({
    List<PlaylistSource>? sources,
    String? selectedId,
  }) =>
      SourcesState(
        sources: sources ?? this.sources,
        selectedId: selectedId ?? this.selectedId,
      );
}

/// Liste des sources + source sélectionnée, chargée puis persistée.
class SourcesNotifier extends AsyncNotifier<SourcesState> {
  @override
  Future<SourcesState> build() async {
    final repo = ref.watch(sourceRepositoryProvider);
    var sources = await repo.loadAll();

    // Migration : un « lien M3U » qui est en fait un lien Xtream `get.php`
    // est reconverti en source Xtream (sépare TV / Films / Séries).
    final migrated = sources.map((s) => s.upgradedToXtreamIfPossible()).toList();
    final changed = [
      for (var i = 0; i < sources.length; i++)
        if (sources[i].kind != migrated[i].kind) i
    ].isNotEmpty;
    if (changed) {
      sources = migrated;
      await repo.saveAll(sources);
    }

    final lastId = await repo.loadSelectedId();
    final selectedId =
        sources.any((s) => s.id == lastId) ? lastId : sources.firstOrNull?.id;
    return SourcesState(sources: sources, selectedId: selectedId);
  }

  SourcesState get _s => state.value ?? const SourcesState(sources: []);

  Future<void> add(PlaylistSource source) async {
    final next = [..._s.sources, source];
    state = AsyncData(SourcesState(sources: next, selectedId: source.id));
    final repo = ref.read(sourceRepositoryProvider);
    await repo.saveAll(next);
    await repo.saveSelectedId(source.id);
  }

  Future<void> editSource(PlaylistSource source) async {
    final next =
        _s.sources.map((s) => s.id == source.id ? source : s).toList();
    state = AsyncData(_s.copyWith(sources: next));
    await ref.read(sourceRepositoryProvider).saveAll(next);
    // La playlist en cache correspond à l'ancienne config.
    await ref.read(playlistCacheProvider).clear(source.id);
  }

  Future<void> remove(String id) async {
    final next = _s.sources.where((s) => s.id != id).toList();
    final newSelected =
        _s.selectedId == id ? next.firstOrNull?.id : _s.selectedId;
    state = AsyncData(SourcesState(sources: next, selectedId: newSelected));
    final repo = ref.read(sourceRepositoryProvider);
    await repo.saveAll(next);
    await repo.saveSelectedId(newSelected);
    await repo.deleteSecret(id);
    await ref.read(playlistCacheProvider).clear(id);
  }

  Future<void> select(String id) async {
    if (_s.selectedId == id) return;
    state = AsyncData(_s.copyWith(selectedId: id));
    await ref.read(sourceRepositoryProvider).saveSelectedId(id);
  }
}

final sourcesProvider =
    AsyncNotifierProvider<SourcesNotifier, SourcesState>(SourcesNotifier.new);

/// La source actuellement sélectionnée (ou `null`).
final selectedSourceProvider = Provider<PlaylistSource?>(
  (ref) => ref.watch(sourcesProvider).value?.selected,
);
