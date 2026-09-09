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

/// Rangée (tuile de liste) navigable à la télécommande avec une surbrillance
/// franche, lisible en usage « 10 pieds » : fond plein teinté + barre d'accent
/// à gauche + léger agrandissement quand l'élément a le focus (D-pad) ou le
/// survol souris. OK/Entrée/Espace déclenchent [onTap].
class TvFocusableRow extends StatefulWidget {
  const TvFocusableRow({
    super.key,
    required this.child,
    this.onTap,
    this.autofocus = false,
    this.focusNode,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<TvFocusableRow> createState() => _TvFocusableRowState();
}

class _TvFocusableRowState extends State<TvFocusableRow> {
  bool _active = false;

  void _set(bool v) {
    if (_active != v) setState(() => _active = v);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: widget.onTap != null,
      onShowFocusHighlight: _set,
      onShowHoverHighlight: _set,
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          transform: _active
              ? (Matrix4.identity()..scaleByDouble(1.015, 1.015, 1.015, 1))
              : Matrix4.identity(),
          transformAlignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: _active
                ? scheme.primary.withValues(alpha: .20)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: _active ? scheme.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
