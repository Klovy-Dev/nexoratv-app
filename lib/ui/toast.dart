import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets.dart';

enum ToastKind { success, info, error }

/// Message court au milieu de l'écran (« Cache des images vidé », « NexoraTV
/// est à jour »…) : apparaît en zoom + fondu, puis s'efface tout seul.
void showToast(
  BuildContext context,
  String message, {
  ToastKind kind = ToastKind.success,
}) => showToastIn(Overlay.of(context, rootOverlay: true), message, kind: kind);

/// Variante à utiliser après un `await` (l'overlay est lu avant).
void showToastIn(
  OverlayState overlay,
  String message, {
  ToastKind kind = ToastKind.success,
}) {
  // Un seul message à la fois : le nouveau remplace l'ancien.
  _current?.remove();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(
      message: message,
      kind: kind,
      onDone: () {
        if (identical(_current, entry)) _current = null;
        entry.remove();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

OverlayEntry? _current;

class _Toast extends StatefulWidget {
  const _Toast({
    required this.message,
    required this.kind,
    required this.onDone,
  });

  final String message;
  final ToastKind kind;
  final VoidCallback onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 220),
  );
  Timer? _hold;
  bool _removed = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
    // Une erreur reste un peu plus longtemps à l'écran.
    _hold = Timer(
      widget.kind == ToastKind.error
          ? const Duration(milliseconds: 3400)
          : const Duration(milliseconds: 2200),
      () async {
        if (!mounted) return;
        await _c.reverse();
        if (mounted && !_removed) {
          _removed = true;
          widget.onDone();
        }
      },
    );
  }

  @override
  void dispose() {
    _hold?.cancel();
    _c.dispose();
    super.dispose();
  }

  (IconData, Color) get _look => switch (widget.kind) {
    ToastKind.success => (Icons.check_rounded, Nx.success),
    ToastKind.info => (Icons.info_outline_rounded, Nx.accent),
    ToastKind.error => (Icons.error_outline_rounded, Nx.danger),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _look;
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    final pop = CurvedAnimation(
      parent: _c,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
    // L'icône arrive juste après la carte, avec un petit rebond.
    final iconPop = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.35, 1, curve: Curves.elasticOut),
      reverseCurve: Curves.easeIn,
    );
    return IgnorePointer(
      child: Center(
        child: FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: Tween(begin: 0.86, end: 1.0).animate(pop),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.fromLTRB(18, 16, 22, 16),
                decoration: BoxDecoration(
                  color: Nx.surface2,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 40,
                      offset: const Offset(0, 18),
                    ),
                    BoxShadow(
                      color: color.withValues(alpha: 0.18),
                      blurRadius: 30,
                      spreadRadius: -6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: iconPop,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 22),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          color: Nx.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Phase { idle, busy, done, failed }

/// Bouton d'action animé : léger enfoncement au clic, roue pendant
/// l'action, puis coche verte (ou croix rouge) avant de revenir au libellé.
/// Si [onPressed] lève une erreur, elle s'affiche au milieu de l'écran.
class ActionButton extends StatefulWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = false,
  });

  final String label;
  final IconData? icon;
  final Future<void> Function() onPressed;
  final bool filled;

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  _Phase _phase = _Phase.idle;
  bool _pressed = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    final overlay = Overlay.of(context, rootOverlay: true);
    _reset?.cancel();
    setState(() => _phase = _Phase.busy);
    // Durée minimale : la roue doit se voir, même pour une action instantanée.
    final minimum = Future<void>.delayed(const Duration(milliseconds: 450));
    _Phase result;
    try {
      await widget.onPressed();
      result = _Phase.done;
    } catch (e) {
      result = _Phase.failed;
      showToastIn(overlay, errorText(e), kind: ToastKind.error);
    }
    await minimum;
    if (!mounted) return;
    setState(() => _phase = result);
    _reset = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _phase = _Phase.idle);
    });
  }

  @override
  Widget build(BuildContext context) {
    final busy = _phase == _Phase.busy;
    final color = switch (_phase) {
      _Phase.done => Nx.success,
      _Phase.failed => Nx.danger,
      _ => null,
    };
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 18),
          const SizedBox(width: 8),
        ],
        Text(widget.label),
      ],
    );
    // Le libellé reste en place (invisible) : le bouton ne change pas de
    // largeur pendant l'animation.
    final child = Stack(
      alignment: Alignment.center,
      children: [
        AnimatedOpacity(
          opacity: _phase == _Phase.idle ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: label,
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (w, a) => ScaleTransition(
            scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
            child: FadeTransition(opacity: a, child: w),
          ),
          child: switch (_phase) {
            _Phase.idle => const SizedBox.shrink(key: ValueKey(0)),
            _Phase.busy => const SizedBox.square(
              key: ValueKey(1),
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            _Phase.done => const Icon(
              Icons.check_rounded,
              key: ValueKey(2),
              color: Nx.success,
              size: 22,
            ),
            _Phase.failed => const Icon(
              Icons.close_rounded,
              key: ValueKey(3),
              color: Nx.danger,
              size: 22,
            ),
          },
        ),
      ],
    );
    final onPressed = busy ? null : _run;
    final style = color == null
        ? null
        : (widget.filled
              ? FilledButton.styleFrom(
                  backgroundColor: color.withValues(alpha: 0.2),
                  disabledBackgroundColor: color.withValues(alpha: 0.2),
                )
              : OutlinedButton.styleFrom(side: BorderSide(color: color)));
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed && !busy ? 0.94 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.filled
            ? FilledButton(onPressed: onPressed, style: style, child: child)
            : OutlinedButton(onPressed: onPressed, style: style, child: child),
      ),
    );
  }
}
