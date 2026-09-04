import 'package:flutter/material.dart';

/// Groupes virtuels (clés spéciales de catégorie).
const String kFavoritesGroup = '__favorites__';
const String kRecentGroup = '__recent__';

/// Nombre d'éléments affichés dans « Ajoutés récemment ».
const int kRecentCount = 40;

/// Panneau de catégories partagé (Films, Séries…).
///
/// - large (`wide`) : liste verticale à gauche (avec filtre si > 12 catégories) ;
/// - étroit : bande de puces horizontale.
class CategoryPanel extends StatefulWidget {
  const CategoryPanel({
    super.key,
    required this.groups,
    required this.total,
    required this.selected,
    required this.onSelect,
    required this.wide,
    this.showFavorites = false,
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
  State<CategoryPanel> createState() => _CategoryPanelState();
}

class _CategoryPanelState extends State<CategoryPanel> {
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
