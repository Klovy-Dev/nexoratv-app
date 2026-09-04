import 'package:flutter/material.dart';

/// Rend n'importe quel widget navigable à la télécommande (Android TV,
/// Fire Stick, box Android) : focus au D-pad (flèches), activation par
/// OK/Entrée/Espace, et état de focus exposé au [builder] pour dessiner un
/// indicateur visuel clair (obligatoire en usage 10 pieds — le survol
/// souris ne suffit pas). Fonctionne aussi normalement à la souris/tactile.
class TvFocusable extends StatefulWidget {
  const TvFocusable({
    super.key,
    required this.builder,
    this.onTap,
    this.autofocus = false,
    this.focusNode,
  });

  /// `(context, focused, hovered)`.
  final Widget Function(BuildContext, bool, bool) builder;
  final VoidCallback? onTap;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: widget.onTap != null,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      mouseCursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onTap?.call();
          return null;
        }),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: widget.builder(context, _focused, _hovered),
      ),
    );
  }
}

/// Décoration d'anneau de focus cohérente dans toute l'app — appliquer en
/// [BoxDecoration.border] (ou fusionner avec `copyWith`) quand `focused`.
Border? tvFocusBorder(BuildContext context, bool focused, {double width = 3}) {
  if (!focused) return null;
  return Border.all(color: Theme.of(context).colorScheme.primary, width: width);
}
