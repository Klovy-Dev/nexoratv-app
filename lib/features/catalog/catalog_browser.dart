import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/channel.dart';
import '../../services/playlist_service.dart';
import '../../services/storage/parental_repository.dart';
import '../../state/category_prefs_provider.dart';
import '../../state/favorites_provider.dart';
import '../../state/parental_provider.dart';
import '../../state/settings_provider.dart';
import '../../state/watch_history_provider.dart';
import '../../widgets/nav.dart';
import '../../widgets/pin_dialog.dart';
import '../channels/channel_tile.dart';
import '../detail/media_detail_screen.dart';
import '../player/player_screen.dart';
import 'poster_card.dart';

/// Groupes virtuels.
const String kFavoritesGroup = '__favorites__';
const String kRecentGroup = '__recent__';

/// Nombre d'éléments affichés dans « Ajoutés récemment ».
const int kRecentCount = 40;

enum CatalogSection { live, movie }

/// Liste/grille filtrable réutilisable (TV, Films).
class CatalogBrowser extends ConsumerStatefulWidget {
  const CatalogBrowser({
    super.key,
    required this.items,
    required this.sourceId,
    this.section = CatalogSection.live,
    this.onOpen,
    this.enableFavorites = false,
    this.allowGrid = false,
    this.startInGrid = false,
    this.emptyLabel = 'Aucun élément.',
  });

  final List<Channel> items;
  final String sourceId;
  final CatalogSection section;
  final void Function(List<Channel> visible, int index)? onOpen;
  final bool enableFavorites;
  final bool allowGrid;
  final bool startInGrid;
  final String emptyLabel;

  @override
  ConsumerState<CatalogBrowser> createState() => _CatalogBrowserState();
}

class _CatalogBrowserState extends ConsumerState<CatalogBrowser> {
  final _searchController = TextEditingController();
  final _listController = ScrollController();
  final _panelController = ScrollController();
  Timer? _debounce;

  String _query = '';
  String? _group;
  bool _merge = false;
  late bool _grid = widget.startInGrid && widget.allowGrid;

  late List<String> _lowerNames;
  late List<({String name, int count})> _groups;
  late bool _hasRecent;
  late List<Channel> _recent;

  /// Clé de regroupement d'une catégorie (fusionne les variantes de qualité
  /// si l'option est active).
  String _key(String raw) => _merge ? mergedQualityCategory(raw) : raw;

  String get _sectionKey =>
      widget.section == CatalogSection.movie ? 'movie' : 'live';

  @override
  void initState() {
    super.initState();
    _rebuildIndex();
  }

  @override
  void didUpdateWidget(CatalogBrowser old) {
    super.didUpdateWidget(old);
    if (!identical(old.items, widget.items)) {
      _rebuildIndex();
      _group = null;
    }
  }

  void _rebuildIndex() {
    _lowerNames = [for (final c in widget.items) c.name.toLowerCase()];
    _groups = groupCountsOf(widget.items.map((c) => _key(c.groupOrDefault)));
    _recent = mostRecent(widget.items, (c) => c.addedAt,
        (c) => int.tryParse(c.streamId ?? ''), kRecentCount);
    _hasRecent =
        _recent.length >= 3 && widget.section == CatalogSection.movie;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _listController.dispose();
    _panelController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      final q = value.trim().toLowerCase();
      if (q != _query && mounted) setState(() => _query = q);
    });
  }

  List<Channel> _computeVisible(Set<String> favorites) {
    if (_group == kRecentGroup) {
      final q = _query;
      return q.isEmpty
          ? _recent
          : _recent
              .where((c) => c.name.toLowerCase().contains(q))
              .toList();
    }
    final items = widget.items;
    final result = <Channel>[];
    for (var i = 0; i < items.length; i++) {
      final c = items[i];
      if (_group == kFavoritesGroup) {
        if (!favorites.contains(FavoriteKey.of(widget.sourceId, c.id))) continue;
      } else if (_group != null && _key(c.groupOrDefault) != _group) {
        continue;
      }
      if (_query.isNotEmpty && !_lowerNames[i].contains(_query)) continue;
      result.add(c);
    }
    return result;
  }

  double _progressFor(String channelId) {
    final hist = ref.read(watchHistoryProvider).value ?? const [];
    for (final e in hist) {
      if (e.key == '${widget.sourceId}::$channelId') return e.progress;
    }
    return 0;
  }

  void _open(List<Channel> visible, int i) {
    if (widget.onOpen != null) {
      widget.onOpen!(visible, i);
      return;
    }
    final c = visible[i];
    if (widget.section == CatalogSection.movie) {
      pushFade(context, MediaDetailScreen.movie(sourceId: widget.sourceId, movie: c));
    } else {
      pushFade(
        context,
        PlayerScreen(
            sourceId: widget.sourceId, playlist: visible, startIndex: i),
      );
    }
  }

  Future<void> _selectGroup(String? g) async {
    final parental = ref.read(parentalValueProvider);
    if (g != null &&
        g != kFavoritesGroup &&
        g != kRecentGroup &&
        parental.isLocked(widget.sourceId, _sectionKey, g)) {
      final ok = await askPin(context,
          verify: (p) => ref.read(parentalValueProvider).checkPin(p));
      if (!ok) return;
    }
    setState(() => _group = g);
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);
    ref.watch(watchHistoryProvider);
    final catPrefs = ref.watch(categoryPrefsProvider).value;
    final parental = ref.watch(parentalValueProvider);

    final merge = ref.watch(
        settingsValueProvider.select((s) => s.mergeSimilarCategories));
    if (merge != _merge) {
      _merge = merge;
      _groups = groupCountsOf(widget.items.map((c) => _key(c.groupOrDefault)));
      if (_group != null &&
          _group != kFavoritesGroup &&
          _group != kRecentGroup) {
        _group = null;
      }
    }

    // Applique masquage + renommage des catégories + contrôle parental.
    final visibleGroups = <({String name, String label, int count})>[];
    final hidden = <String>{};
    for (final g in _groups) {
      if (parental.hideAdult && isAdultCategory(g.name)) {
        hidden.add(g.name);
        continue;
      }
      final p = catPrefs?[widget.sourceId]?[_sectionKey]?[g.name];
      if (p?.hidden == true) {
        hidden.add(g.name);
        continue;
      }
      final locked =
          parental.isLocked(widget.sourceId, _sectionKey, g.name);
      final renamed = p?.renamedTo?.trim();
      visibleGroups.add((
        name: g.name,
        label: '${locked ? '🔒 ' : ''}'
            '${(renamed?.isNotEmpty ?? false) ? renamed! : prettyCategory(g.name)}',
        count: g.count,
      ));
    }

    var visible = _computeVisible(favorites);
    if (hidden.isNotEmpty && _group == null) {
      visible = visible.where((c) => !hidden.contains(c.groupOrDefault)).toList();
    }

    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final total = widget.items.length;

    final panel = _GroupPanel(
      groups: visibleGroups,
      total: total,
      selected: _group,
      wide: isWide,
      showFavorites: widget.enableFavorites,
      showRecent: _hasRecent,
      recentCount: _recent.length,
      controller: isWide ? _panelController : null,
      onSelect: _selectGroup,
    );

    final listColumn = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Rechercher…',
                    suffixIcon: ValueListenableBuilder(
                      valueListenable: _searchController,
                      builder: (_, value, _) => value.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            ),
                    ),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              if (widget.allowGrid)
                IconButton(
                  tooltip: _grid ? 'Vue liste' : 'Vue jaquettes',
                  icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
                  onPressed: () => setState(() => _grid = !_grid),
                ),
            ],
          ),
        ),
        if (!isWide) SizedBox(height: 46, child: panel),
        const Divider(height: 1),
        Expanded(
          child: visible.isEmpty
              ? Center(child: Text(widget.emptyLabel))
              : _grid
                  ? Scrollbar(
                      controller: _listController,
                      child: GridView.builder(
                        controller: _listController,
                        padding: const EdgeInsets.all(14),
                        gridDelegate: PosterCard.gridDelegate,
                        itemCount: visible.length,
                        itemBuilder: (context, i) {
                          final c = visible[i];
                          return PosterCard(
                            title: c.name,
                            imageUrl: c.logo,
                            year: c.year,
                            rating: c.rating,
                            heroTag: 'poster_${widget.sourceId}_${c.id}',
                            progress: _progressFor(c.id),
                            onTap: () => _open(visible, i),
                            onPlay: widget.section == CatalogSection.movie
                                ? () => pushFade(
                                      context,
                                      PlayerScreen(
                                        sourceId: widget.sourceId,
                                        playlist: [c],
                                        startIndex: 0,
                                      ),
                                    )
                                : null,
                          );
                        },
                      ),
                    )
                  : Scrollbar(
                      controller: _listController,
                      child: ListView.builder(
                        controller: _listController,
                        itemCount: visible.length,
                        itemExtent: 56,
                        itemBuilder: (context, i) {
                          final c = visible[i];
                          return ChannelTile(
                            channel: c,
                            showFavorite: widget.enableFavorites,
                            isFavorite: favorites.contains(
                                FavoriteKey.of(widget.sourceId, c.id)),
                            onToggleFavorite: () => ref
                                .read(favoritesProvider.notifier)
                                .toggle(widget.sourceId, c.id),
                            onTap: () => _open(visible, i),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );

    if (!isWide) return listColumn;
    return Row(
      children: [
        SizedBox(width: 250, child: panel),
        const VerticalDivider(width: 1),
        Expanded(child: listColumn),
      ],
    );
  }
}

class _GroupPanel extends StatefulWidget {
  const _GroupPanel({
    required this.groups,
    required this.total,
    required this.selected,
    required this.onSelect,
    required this.wide,
    required this.showFavorites,
    this.showRecent = false,
    this.recentCount = 0,
    this.controller,
  });

  final List<({String name, String label, int count})> groups;
  final int total;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final bool wide;
  final bool showFavorites;
  final bool showRecent;
  final int recentCount;
  final ScrollController? controller;

  @override
  State<_GroupPanel> createState() => _GroupPanelState();
}

class _GroupPanelState extends State<_GroupPanel> {
  String _filter = '';

  /// Entrées "épinglées" en tête : Tout, Favoris, puis Ajoutés récemment.
  List<({String? key, IconData icon, String label, int? count})> get _leading =>
      [
        (key: null, icon: Icons.grid_view, label: 'Tout', count: widget.total),
        if (widget.showFavorites)
          (
            key: kFavoritesGroup,
            icon: Icons.star,
            label: 'Favoris',
            count: null
          ),
        if (widget.showRecent)
          (
            key: kRecentGroup,
            icon: Icons.auto_awesome_outlined,
            label: '✨ Ajoutés récemment',
            count: widget.recentCount,
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final onSelect = widget.onSelect;
    final controller = widget.controller;
    final lead = _leading;
    final groups = _filter.isEmpty
        ? widget.groups
        : widget.groups
            .where((g) => g.label.toLowerCase().contains(_filter))
            .toList();

    if (!widget.wide) {
      return ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final l in lead)
            _chip(
              context,
              l.count == null ? l.label : '${l.label} (${l.count})',
              selected == l.key,
              () => onSelect(l.key),
            ),
          for (final g in groups)
            _chip(context, '${g.label} (${g.count})', selected == g.name,
                () => onSelect(g.name)),
        ],
      );
    }
    return Column(
      children: [
        if (widget.groups.length > 12)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.filter_list, size: 18),
                hintText: 'Filtrer les catégories',
              ),
              onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
            ),
          ),
        Expanded(
          child: Scrollbar(
            controller: controller,
            child: ListView.builder(
              controller: controller,
              itemCount: lead.length + groups.length,
              itemBuilder: (context, i) {
                if (i < lead.length) {
                  final l = lead[i];
                  return _row(context, l.icon, l.label, l.count,
                      selected == l.key, () => onSelect(l.key));
                }
                final g = groups[i - lead.length];
                return _row(context, Icons.folder_outlined, g.label, g.count,
                    selected == g.name, () => onSelect(g.name));
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(BuildContext c, String label, bool sel, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: ChoiceChip(
            label: Text(label), selected: sel, onSelected: (_) => onTap()),
      );

  Widget _row(BuildContext c, IconData icon, String label, int? count, bool sel,
          VoidCallback onTap) =>
      ListTile(
        leading: Icon(icon, size: 20),
        title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: count == null ? null : Text('$count'),
        selected: sel,
        selectedTileColor:
            Theme.of(c).colorScheme.primary.withValues(alpha: .14),
        onTap: onTap,
      );
}
