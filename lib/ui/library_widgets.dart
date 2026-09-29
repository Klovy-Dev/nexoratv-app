import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/library.dart';
import 'theme.dart';

/// Étoile favori (film, série ou chaîne de la source active).
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.kind, required this.id});

  final MediaKind kind;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(libraryProvider.select((l) => l.isFavorite(kind, id)));
    return IconButton.outlined(
      tooltip: on ? 'Retirer des favoris' : 'Ajouter aux favoris',
      isSelected: on,
      onPressed: () =>
          ref.read(libraryProvider.notifier).toggleFavorite(kind, id),
      icon: const Icon(Icons.star_outline_rounded),
      selectedIcon: const Icon(Icons.star_rounded, color: Nx.warning),
    );
  }
}

/// « 1 h 05 » / « 12:34 ».
String formatPosition(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '$h h ${m.toString().padLeft(2, '0')}';
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Fine barre d'avancement (bas des vignettes « en cours »).
class WatchBar extends StatelessWidget {
  const WatchBar({super.key, required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 4,
    child: Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0x66000000)),
        FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: fraction.clamp(0, 1),
          child: const ColoredBox(color: Nx.accent),
        ),
      ],
    ),
  );
}
