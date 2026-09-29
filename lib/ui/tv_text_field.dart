import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Touches « OK » d'une télécommande (et Entrée d'un clavier).
final tvSelectKeys = {
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.gameButtonA,
};

/// Champ de saisie utilisable à la télécommande.
///
/// Sur Android (Fire TV, Android TV, box), un [TextField] ouvre le clavier
/// dès qu'il reçoit le focus : impossible de passer sur un champ sans que le
/// clavier surgisse, et les flèches restent coincées dedans. Ici, le focus
/// se pose sur un cadre autour du champ : **OK** ouvre le clavier, **Retour**
/// (ou ↑ ↓) le referme et rend la main à la navigation.
///
/// Ailleurs (Windows), c'est un [TextField] normal.
class TvTextField extends StatefulWidget {
  const TvTextField({
    super.key,
    this.controller,
    this.decoration = const InputDecoration(),
    this.autofocus = false,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.style,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final InputDecoration decoration;
  final bool autofocus;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> with WidgetsBindingObserver {
  static final _tv = Platform.isAndroid;

  /// Cadre qui reçoit le focus de la télécommande.
  late final _outer = FocusNode(
    debugLabel: 'tv-field',
    onKeyEvent: _onOuterKey,
  );

  /// Le vrai champ : hors du parcours au D-pad, il n'a le focus que pendant
  /// la saisie.
  late final _inner = FocusNode(
    debugLabel: 'tv-field-input',
    skipTraversal: _tv,
    onKeyEvent: _tv ? _onInnerKey : null,
  );

  bool _outerFocused = false;
  double _lastInset = 0;

  @override
  void initState() {
    super.initState();
    if (_tv) {
      WidgetsBinding.instance.addObserver(this);
      _outer.addListener(() {
        if (mounted) setState(() => _outerFocused = _outer.hasPrimaryFocus);
      });
    }
  }

  @override
  void dispose() {
    if (_tv) WidgetsBinding.instance.removeObserver(this);
    _outer.dispose();
    _inner.dispose();
    super.dispose();
  }

  /// Clavier refermé par Retour (la touche va au clavier, pas à l'appli) :
  /// on rend le focus au cadre pour que les flèches naviguent à nouveau.
  @override
  void didChangeMetrics() {
    final view = View.maybeOf(context);
    if (view == null) return;
    final inset = view.viewInsets.bottom;
    if (_inner.hasFocus && _lastInset > 0 && inset == 0) _leaveInput();
    _lastInset = inset;
  }

  void _openKeyboard() {
    _inner.requestFocus();
    // Déjà focalisé (clavier fermé à la main) : on le rouvre explicitement.
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  void _leaveInput() {
    if (_inner.hasFocus) _outer.requestFocus();
  }

  KeyEventResult _onOuterKey(FocusNode node, KeyEvent e) {
    if (!_tv || !tvSelectKeys.contains(e.logicalKey)) {
      return KeyEventResult.ignored;
    }
    if (e is KeyDownEvent) _openKeyboard();
    return KeyEventResult.handled;
  }

  /// Pendant la saisie, clavier fermé : ↑ ↓ et Retour sortent du champ
  /// (sinon les flèches déplacent le curseur et on reste bloqué dedans).
  KeyEventResult _onInnerKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape) {
      _leaveInput();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      _leaveInput();
      _outer.focusInDirection(
        key == LogicalKeyboardKey.arrowUp
            ? TraversalDirection.up
            : TraversalDirection.down,
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: widget.controller,
      focusNode: _inner,
      // Sur télé, jamais de clavier au démarrage : le focus va au cadre.
      autofocus: !_tv && widget.autofocus,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      style: widget.style,
      decoration: widget.decoration,
      onChanged: widget.onChanged,
      onSubmitted: (v) {
        if (_tv) _leaveInput();
        widget.onSubmitted?.call(v);
      },
    );
    if (!_tv) return field;

    return Focus(
      focusNode: _outer,
      autofocus: widget.autofocus,
      child: AnimatedContainer(
        duration: Nx.fast,
        curve: Nx.ease,
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Nx.radiusSm),
          border: Border.all(
            color: _outerFocused ? Nx.accent : Colors.transparent,
            width: 2.5,
          ),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Nx.radiusSm),
          boxShadow: [
            if (_outerFocused)
              BoxShadow(
                color: Nx.accent.withValues(alpha: 0.3),
                spreadRadius: 3,
              ),
          ],
        ),
        child: field,
      ),
    );
  }
}
