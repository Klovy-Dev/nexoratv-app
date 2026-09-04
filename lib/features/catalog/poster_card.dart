import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Vignette « jaquette » réutilisable (films, séries), format 2:3.
class PosterCard extends StatefulWidget {
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
  });

  final String title;
  final String? imageUrl;
  final String? subtitle;
  final double? rating;
  final int? year;
  final double progress;
  final String? badge;
  final Object? heroTag;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onSecondary;
  final IconData? secondaryIcon;

  static const gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 156,
    childAspectRatio: 0.54,
    crossAxisSpacing: 14,
    mainAxisSpacing: 16,
  );

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final img = widget.imageUrl == null
        ? Container(
            color: scheme.surfaceContainerHighest,
            child: const Center(child: Icon(Icons.movie_outlined, size: 32)),
          )
        : CachedNetworkImage(
            imageUrl: widget.imageUrl!,
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

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AnimatedScale(
                scale: _hover ? 1.03 : 1,
                duration: const Duration(milliseconds: 150),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.heroTag != null
                          ? Hero(tag: widget.heroTag!, child: img)
                          : img,
                      if (widget.rating != null)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: _Chip(
                            icon: Icons.star,
                            label: widget.rating!.toStringAsFixed(1),
                          ),
                        ),
                      if (widget.badge != null)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: _Chip(label: widget.badge!),
                        ),
                      if (_hover && widget.onPlay != null)
                        Container(
                          color: Colors.black38,
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _RoundBtn(
                                    icon: Icons.play_arrow,
                                    onTap: widget.onPlay!),
                                if (widget.onSecondary != null) ...[
                                  const SizedBox(width: 8),
                                  _RoundBtn(
                                    icon: widget.secondaryIcon ?? Icons.add,
                                    onTap: widget.onSecondary!,
                                    filled: false,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      if (widget.progress > 0)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: LinearProgressIndicator(
                            value: widget.progress,
                            minHeight: 4,
                            backgroundColor: Colors.black45,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, height: 1.2)),
            if (widget.subtitle != null || widget.year != null)
              Text(
                [
                  if (widget.year != null) '${widget.year}',
                  if (widget.subtitle != null) widget.subtitle!,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11, color: Theme.of(context).hintColor),
              ),
          ],
        ),
      ),
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
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}
