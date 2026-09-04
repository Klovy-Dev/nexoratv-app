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
import '../catalog/category_panel.dart';
import '../catalog/poster_card.dart';
import '../detail/media_detail_screen.dart';

/// Grille des séries (utilisée dans la coquille) — même mise en page que les
/// films : panneau de catégories à gauche sur desktop, grille de jaquettes.
class SeriesBrowser extends ConsumerStatefulWidget {
  const SeriesBrowser({super.key, required this.sourceId});
  final String sourceId;

  @override
  ConsumerState<SeriesBrowser> createState() => _SeriesBrowserState();
}

class _SeriesBrowserState extends ConsumerState<SeriesBrowser> {
  final _controller = TextEditingController();
  final _grid = ScrollController();
  final _panel = ScrollController();
  Timer? _debounce;
  String _query = '';
  String? _group;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _grid.dispose();
    _panel.dispose();
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
        all, (s) => s.addedAt, (s) => int.tryParse(s.seriesId), kRecentCount);
    final showRecent = recent.length >= 3;

    Iterable<Series> visibleSrc;
    if (_group == kRecentGroup) {
      visibleSrc = recent.take(kRecentCount);
    } else {
      visibleSrc = all.where((s) {
        if (_group != null) return key(s.groupOrDefault) == _group;
        return !hidden.contains(key(s.groupOrDefault));
      });
    }
    if (_query.isNotEmpty) {
      visibleSrc =
          visibleSrc.where((s) => s.name.toLowerCase().contains(_query));
    }
    final list = visibleSrc.toList();

    final isWide = MediaQuery.sizeOf(context).width >= 900;

    final panel = CategoryPanel(
      groups: groups,
      total: all.length,
      selected: _group,
      wide: isWide,
      showRecent: showRecent,
      recentCount: recent.length.clamp(0, kRecentCount),
      controller: isWide ? _panel : null,
      onSelect: (g) => _selectGroup(g, parental),
    );

    final gridColumn = Column(
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
        if (!isWide) SizedBox(height: 46, child: panel),
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
                        synopsis: (s.plot?.trim().isNotEmpty ?? false)
                            ? s.plot
                            : s.genre,
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

    if (!isWide) return gridColumn;
    return Row(
      children: [
        SizedBox(width: 250, child: panel),
        const VerticalDivider(width: 1),
        Expanded(child: gridColumn),
      ],
    );
  }

  Future<void> _selectGroup(String? cat, ParentalSettings parental) async {
    if (cat != null &&
        cat != kRecentGroup &&
        parental.isLocked(widget.sourceId, 'series', cat)) {
      final ok = await askPin(context,
          verify: (p) => ref.read(parentalValueProvider).checkPin(p));
      if (!ok) return;
    }
    setState(() => _group = cat);
  }
}
