import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/series.dart';
import '../../services/playlist_service.dart';
import '../../services/storage/parental_repository.dart';
import '../../state/category_prefs_provider.dart';
import '../../state/channels_provider.dart';
import '../../state/parental_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/nav.dart';
import '../../widgets/pin_dialog.dart';
import '../catalog/poster_card.dart';
import '../detail/media_detail_screen.dart';

/// Grille des séries (utilisée dans la coquille).
class SeriesBrowser extends ConsumerStatefulWidget {
  const SeriesBrowser({super.key, required this.sourceId});
  final String sourceId;

  @override
  ConsumerState<SeriesBrowser> createState() => _SeriesBrowserState();
}

class _SeriesBrowserState extends ConsumerState<SeriesBrowser> {
  final _controller = TextEditingController();
  final _grid = ScrollController();
  Timer? _debounce;
  String _query = '';
  String? _group;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _grid.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      final q = v.trim().toLowerCase();
      if (q != _query && mounted) setState(() => _query = q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pl = ref.watch(currentPlaylistProvider);
    return switch (pl) {
      AsyncData(:final value) => _content(context, value.series),
      AsyncError() => const Center(child: Text('Erreur de chargement.')),
      _ => const LoadingView(label: 'Chargement des séries…'),
    };
  }

  Widget _content(BuildContext context, List<Series> all) {
    if (all.isEmpty) {
      return const Center(child: Text('Aucune série sur ce compte.'));
    }
    final catPrefs = ref.watch(categoryPrefsProvider).value;
    final parental = ref.watch(parentalValueProvider);
    final merge = ref.watch(
        settingsValueProvider.select((s) => s.mergeSimilarCategories));
    String key(String raw) => merge ? mergedQualityCategory(raw) : raw;
    final hidden = <String>{};
    final groups = <({String name, String label, int count})>[];
    for (final g in groupCountsOf(all.map((s) => key(s.groupOrDefault)))) {
      if (parental.hideAdult && isAdultCategory(g.name)) {
        hidden.add(g.name);
        continue;
      }
      final p = catPrefs?[widget.sourceId]?['series']?[g.name];
      if (p?.hidden == true) {
        hidden.add(g.name);
        continue;
      }
      final locked = parental.isLocked(widget.sourceId, 'series', g.name);
      final renamed = p?.renamedTo?.trim();
      groups.add((
        name: g.name,
        label: '${locked ? '🔒 ' : ''}'
            '${(renamed?.isNotEmpty ?? false) ? renamed! : prettyCategory(g.name)}',
        count: g.count,
      ));
    }

    final recent = mostRecent<Series>(
        all, (s) => s.addedAt, (s) => int.tryParse(s.seriesId), 40);
    final showRecent = recent.length >= 3;

    Iterable<Series> visible;
    if (_group == '__recent__') {
      visible = recent.take(40);
    } else {
      visible = all.where((s) {
        if (_group != null) return key(s.groupOrDefault) == _group;
        return !hidden.contains(key(s.groupOrDefault));
      });
    }
    if (_query.isNotEmpty) {
      visible = visible.where((s) => s.name.toLowerCase().contains(_query));
    }
    final list = visible.toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Rechercher une série…',
            ),
            onChanged: _onChanged,
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              _chip('Toutes (${all.length})', _group == null,
                  () => setState(() => _group = null)),
              if (showRecent)
                _chip('✨ Ajoutées récemment (${recent.length.clamp(0, 40)})',
                    _group == '__recent__',
                    () => setState(() => _group = '__recent__')),
              for (final g in groups)
                _chip('${g.label} (${g.count})', _group == g.name,
                    () => _selectGroup(g.name, parental)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('Aucune série.'))
              : Scrollbar(
                  controller: _grid,
                  child: GridView.builder(
                    controller: _grid,
                    padding: const EdgeInsets.all(14),
                    gridDelegate: PosterCard.gridDelegate,
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final s = list[i];
                      return PosterCard(
                        title: s.name,
                        imageUrl: s.cover,
                        year: s.year,
                        rating: s.rating,
                        heroTag: 'poster_${widget.sourceId}_${s.id}',
                        onTap: () => pushFade(
                          context,
                          MediaDetailScreen.series(
                              sourceId: widget.sourceId, series: s),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _selectGroup(String cat, ParentalSettings parental) async {
    if (parental.isLocked(widget.sourceId, 'series', cat)) {
      final ok = await askPin(context,
          verify: (p) => ref.read(parentalValueProvider).checkPin(p));
      if (!ok) return;
    }
    setState(() => _group = cat);
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: ChoiceChip(
            label: Text(label), selected: sel, onSelected: (_) => onTap()),
      );
}
