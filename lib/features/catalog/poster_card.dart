import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../widgets/tv_focusable.dart';

/// Vignette « jaquette » réutilisable (films, séries), format 2:3.
/// Navigable au D-pad (télécommande Android TV / Fire Stick / box) : OK
/// déclenche [onTap], un anneau met en évidence la jaquette focus.
class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.title,
    required this.onTap,
    this.heroTag,
    this.imageUrl,
    this.subtitle,
    this.rating,
    this.year,
    this.progress = 0,
    this.badge,
    this.onPlay,
    this.onSecondary,
    this.secondaryIcon,
    this.synopsis,
    this.autofocus = false,
  });

  final String title;
  final String? imageUrl;
  final String? subtitle;
  final double? rating;
  final int? year;

  /// Résumé court affiché sous le titre (2 lignes max). Ignoré si vide.
  final String? synopsis;
  final double progress;
  final String? badge;
  final Object? heroTag;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onSecondary;
  final IconData? secondaryIcon;

  /// Donne le focus initial à cette jaquette (1er élément d'une grille, pour
  /// qu'un appui direct sur une flèche à l'ouverture de l'écran ait un point
  /// de départ).
  final bool autofocus;

  static const gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 156,
    childAspectRatio: 0.54,
    crossAxisSpacing: 14,
    mainAxisSpacing: 16,
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final img = imageUrl == null
        ? Container(
            color: scheme.surfaceContainerHighest,
            child: const Center(child: Icon(Icons.movie_outlined, size: 32)),
          )
        : CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            memCacheWidth: 320, // décode à la taille d'affichage
            fadeInDuration: const Duration(milliseconds: 200),
            placeholder: (_, _) =>
                Container(color: scheme.surfaceContainerHighest),
            errorWidget: (_, _, _) => Container(
              color: scheme.surfaceContainerHighest,
              child: const Center(child: Icon(Icons.movie_outlined, size: 32)),
            ),
          );

    return TvFocusable(
      autofocus: autofocus,
      onTap: onTap,
      builder: (context, focused, hovered) {
        final active = focused || hovered;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AnimatedScale(
                scale: active ? 1.05 : 1,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: tvFocusBorder(context, focused),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        heroTag != null ? Hero(tag: heroTag!, child: img) : img,
                        if (rating != null)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: _Chip(
                              icon: Icons.star,
                              label: rating!.toStringAsFixed(1),
                            ),
                          ),
                        if (badge != null)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: _Chip(label: badge!),
                          ),
                        if (active && onPlay != null)
                          Container(
                            color: Colors.black38,
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _RoundBtn(
                                      icon: Icons.play_arrow, onTap: onPlay!),
                                  if (onSecondary != null) ...[
                                    const SizedBox(width: 8),
                                    _RoundBtn(
                                      icon: secondaryIcon ?? Icons.add,
                                      onTap: onSecondary!,
                                      filled: false,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        if (progress > 0)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 4,
                              backgroundColor: Colors.black45,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, height: 1.2)),
            if (subtitle != null || year != null)
              Text(
                [
                  if (year != null) '$year',
                  ?subtitle,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11, color: Theme.of(context).hintColor),
              ),
            if ((synopsis ?? '').trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  synopsis!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.25,
                    color: Theme.of(context).hintColor.withValues(alpha: .8),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({this.icon, required this.label});
  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: Colors.amber),
              const SizedBox(width: 3),
            ],
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      );
}

/// Bouton rond « lecture »/« + » affiché au survol ou au focus de la
/// jaquette. Cliquable à la souris/tactile ; en usage clavier/D-pad, l'appui
/// sur OK va plutôt à l'action principale de [PosterCard] (voir plus haut),
/// qui ouvre la fiche — où « Lecture » est déjà le premier bouton focus.
class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap, this.filled = true});
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: filled ? scheme.primary : Colors.white24,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        canRequestFocus: false,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}
