import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Carte animée au survol : soulèvement, léger zoom, bordure corail et
/// ombre (même langage que les cartes du site).
class HoverCard extends StatefulWidget {
  const HoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.radius = Nx.radius,
    this.color = Nx.surface,
    this.scale = 1.03,
    this.padding = EdgeInsets.zero,
    this.selected = false,
    this.lift = 4,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final Color color;
  final double scale;
  final EdgeInsetsGeometry padding;
  final bool selected;

  /// Soulèvement au survol, en pixels (0 pour les lignes de liste).
  final double lift;

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = _hover && widget.onTap != null;
    final highlight = active || widget.selected;
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = _pressed = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : (active ? widget.scale : 1),
          duration: Nx.fast,
          curve: Nx.ease,
          child: AnimatedContainer(
            duration: Nx.fast,
            curve: Nx.ease,
            transform: Matrix4.translationValues(0, active ? -widget.lift : 0, 0),
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.selected ? Color.alphaBlend(Nx.accent.withValues(alpha: 0.08), widget.color) : widget.color,
              borderRadius: BorderRadius.circular(widget.radius),
              border: Border.all(color: highlight ? Nx.accent.withValues(alpha: 0.7) : Nx.border),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Nx.accent.withValues(alpha: 0.18),
                        blurRadius: 28,
                        spreadRadius: -6,
                        offset: const Offset(0, 14),
                      ),
                    ]
                  : const [],
            ),
            clipBehavior: Clip.antiAlias,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Image réseau avec repli sur les initiales (logos de chaînes, affiches).
class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, required this.label, this.fit = BoxFit.cover, this.cacheWidth = 320});

  final String? url;
  final String label;
  final BoxFit fit;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final fallback = _Initials(label);
    final u = url;
    if (u == null || !u.startsWith('http')) return fallback;
    return CachedNetworkImage(
      imageUrl: u,
      fit: fit,
      memCacheWidth: cacheWidth,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, _) => const ColoredBox(color: Nx.surface2),
      errorWidget: (_, _, _) => fallback,
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final words = label.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2);
    final initials = words.map((w) => w.characters.first.toUpperCase()).join();
    return ColoredBox(
      color: Nx.surface2,
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: const TextStyle(fontFamily: Nx.display, fontWeight: FontWeight.w700, color: Nx.muted),
        ),
      ),
    );
  }
}

/// Champ de recherche compact.
class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Nx.muted),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      );
}

/// Pastille de catégorie (films / séries).
class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: HoverCard(
          onTap: onTap,
          radius: 999,
          scale: 1.04,
          selected: selected,
          color: selected ? Nx.accent : Nx.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Nx.bg : Nx.text,
            ),
          ),
        ),
      );
}

/// États de chargement / erreur / vide homogènes.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Chargement…'});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.6, color: Nx.accent)),
          const SizedBox(height: 14),
          Text(label, style: const TextStyle(color: Nx.muted)),
        ]),
      );
}

class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Nx.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Nx.accent),
              ),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(message!, textAlign: TextAlign.center, style: const TextStyle(color: Nx.muted)),
              ],
              if (action != null) ...[const SizedBox(height: 20), action!],
            ]),
          ),
        ),
      );
}

String errorText(Object error) => error.toString().replaceFirst('Exception: ', '');
