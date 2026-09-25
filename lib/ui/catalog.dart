import 'package:flutter/material.dart';

import '../core/models.dart';
import 'theme.dart';
import 'widgets.dart';

/// Élément affichable dans une grille d'affiches (film ou série).
class PosterItem {
  const PosterItem({required this.id, required this.title, required this.categoryId, this.image, this.subtitle, this.rating});

  final String id;
  final String title;
  final String categoryId;
  final String? image;
  final String? subtitle;
  final double? rating;
}

/// Grille d'affiches avec pastilles de catégories et recherche.
class PosterCatalog extends StatefulWidget {
  const PosterCatalog({
    super.key,
    required this.title,
    required this.categories,
    required this.items,
    required this.onOpen,
    required this.searchHint,
  });

  final String title;
  final List<Category> categories;
  final List<PosterItem> items;
  final ValueChanged<PosterItem> onOpen;
  final String searchHint;

  @override
  State<PosterCatalog> createState() => _PosterCatalogState();
}

class _PosterCatalogState extends State<PosterCatalog> {
  String? _category;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final used = {for (final i in widget.items) i.categoryId};
    final categories = [for (final c in widget.categories) if (used.contains(c.id)) c];
    final q = _query.trim().toLowerCase();
    final visible = [
      for (final i in widget.items)
        if ((_category == null || i.categoryId == _category) && (q.isEmpty || i.title.toLowerCase().contains(q))) i,
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(32, 26, 32, 0),
        child: Row(children: [
          Text(widget.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(width: 12),
          Text('${visible.length}', style: const TextStyle(color: Nx.muted)),
          const Spacer(),
          SizedBox(width: 320, child: SearchField(hint: widget.searchHint, onChanged: (v) => setState(() => _query = v))),
        ]),
      ),
      SizedBox(
        height: 64,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
          children: [
            CategoryChip(label: 'Tout', selected: _category == null, onTap: () => setState(() => _category = null)),
            for (final c in categories)
              CategoryChip(label: c.name, selected: _category == c.id, onTap: () => setState(() => _category = c.id)),
          ],
        ),
      ),
      Expanded(
        child: visible.isEmpty
            ? const Center(child: Text('Aucun résultat.', style: TextStyle(color: Nx.muted)))
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(32, 12, 32, 32),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 190,
                  mainAxisSpacing: 22,
                  crossAxisSpacing: 18,
                  childAspectRatio: 0.52,
                ),
                itemCount: visible.length,
                itemBuilder: (_, i) => PosterTile(item: visible[i], onTap: () => widget.onOpen(visible[i])),
              ),
      ),
    ]);
  }
}

class PosterTile extends StatelessWidget {
  const PosterTile({super.key, required this.item, required this.onTap});

  final PosterItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: HoverCard(
            onTap: onTap,
            scale: 1.05,
            lift: 6,
            child: Stack(fit: StackFit.expand, children: [
              NetImage(item.image, label: item.title, cacheWidth: 360),
              if (item.rating != null && item.rating! > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(6)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFC542)),
                      const SizedBox(width: 3),
                      Text(item.rating!.toStringAsFixed(1), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, height: 1.3)),
        if (item.subtitle != null)
          Text(item.subtitle!, style: const TextStyle(color: Nx.muted, fontSize: 12)),
      ]);
}

/// En-tête des fiches film / série : affiche + titre + infos + actions,
/// sur fond flouté de l'image.
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    required this.title,
    required this.image,
    this.backdrop,
    this.meta = const [],
    this.plot,
    this.actions = const [],
  });

  final String title;
  final String? image;
  final String? backdrop;
  final List<String> meta;
  final String? plot;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(
          child: Opacity(opacity: 0.22, child: NetImage(backdrop ?? image, label: title, cacheWidth: 800)),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Nx.bg.withValues(alpha: 0.55), Nx.bg],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 24, 40, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconButton(
              tooltip: 'Retour',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Nx.radius),
                child: SizedBox(width: 200, height: 300, child: NetImage(image, label: title, cacheWidth: 400)),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: Theme.of(context).textTheme.displaySmall),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(meta.join('  ·  '), style: const TextStyle(color: Nx.muted)),
                  ],
                  if (plot != null) ...[
                    const SizedBox(height: 18),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Text(plot!, style: const TextStyle(height: 1.6, color: Color(0xFFD5D4CF))),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Wrap(spacing: 12, runSpacing: 12, children: actions),
                ]),
              ),
            ]),
          ]),
        ),
      ]);
}
