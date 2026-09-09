import 'package:flutter/material.dart';

/// Champ texte pensé pour la navigation télécommande (Android TV / Fire TV /
/// box) **et** l'usage tactile.
///
/// Problème résolu : un `TextField` classique ouvre l'IME dès qu'il **reçoit**
/// le focus (le D-pad qui passe dessus suffit), et une fois le clavier fermé la
/// touche OK ne le rouvre pas — l'utilisateur se retrouve bloqué.
///
/// Ici, seul un conteneur est atteint par le D-pad ; le champ éditable est
/// `skipTraversal` et `readOnly` tant qu'on n'a pas appuyé sur OK (ou touché le
/// champ). À ce moment `readOnly` repasse à `false` et une demande de focus à
/// la frame suivante ouvre l'IME de façon fiable, box Android comprises.
/// « Suivant » sur le clavier redescend au champ suivant (sans rouvrir l'IME) ;
/// OK le rouvre. Toute sortie du champ (clavier fermé, D-pad, focus déplacé)
/// repasse en mode navigation.
class TvTextField extends StatefulWidget {
  const TvTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.decoration,
    this.obscureText = false,
    this.keyboardType,
    this.isLast = false,
    this.autofocus = false,
    this.validator,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;

  /// Décoration personnalisée (prefixIcon, suffixIcon, bordure…). `labelText`
  /// et `hintText` sont complétés par [label] / [hint] s'ils sont absents.
  final InputDecoration? decoration;

  final bool obscureText;
  final TextInputType? keyboardType;

  /// Dernier champ d'un formulaire : action clavier « OK » au lieu de
  /// « Suivant » (pas de saut au champ suivant à la validation).
  final bool isLast;
  final bool autofocus;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  /// Appelé à la validation clavier (« OK » / « Rechercher » / « Suivant »).
  final ValueChanged<String>? onSubmitted;

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  // Cible du D-pad. Le champ éditable, lui, est `skipTraversal` : joignable
  // uniquement par une demande de focus explicite (OK / toucher).
  final _wrapperNode = FocusNode(debugLabel: 'tvtf-wrapper');
  final _fieldNode = FocusNode(debugLabel: 'tvtf-field', skipTraversal: true);

  bool _wrapperFocused = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _fieldNode.addListener(_onFieldFocusChanged);
  }

  @override
  void dispose() {
    _fieldNode.removeListener(_onFieldFocusChanged);
    _fieldNode.dispose();
    _wrapperNode.dispose();
    super.dispose();
  }

  void _onFieldFocusChanged() {
    // Filet de sécurité : quelle que soit la façon de quitter le champ, on ne
    // reste jamais coincé en mode édition.
    if (!_fieldNode.hasFocus && _editing) {
      setState(() => _editing = false);
    }
  }

  void _startEditing() {
    if (_editing) return;
    setState(() => _editing = true);
    // `readOnly` vient de passer à false : demander le focus à la frame
    // suivante ouvre l'IME de façon fiable, box Android comprises.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fieldNode.requestFocus();
    });
  }

  void _handleSubmitted(String value) {
    setState(() => _editing = false);
    _wrapperNode.requestFocus();
    widget.onSubmitted?.call(value);
    if (!widget.isLast) {
      // Redescend au focusable suivant sans ouvrir le clavier : OK le rouvrira.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _wrapperNode.nextFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = widget.decoration ?? const InputDecoration();
    final decoration = base.copyWith(
      labelText: base.labelText ?? widget.label,
      hintText: base.hintText ?? widget.hint,
    );

    return FocusableActionDetector(
      focusNode: _wrapperNode,
      autofocus: widget.autofocus,
      onShowFocusHighlight: (v) => setState(() => _wrapperFocused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _startEditing();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: _startEditing,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _wrapperFocused && !_editing
                  ? scheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _fieldNode,
            readOnly: !_editing,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            autocorrect: false,
            enableSuggestions: false,
            enableInteractiveSelection: _editing,
            textInputAction:
                widget.isLast ? TextInputAction.done : TextInputAction.next,
            onTap: _startEditing,
            onTapOutside: (_) {
              if (_editing) _fieldNode.unfocus();
            },
            onChanged: widget.onChanged,
            onFieldSubmitted: _handleSubmitted,
            validator: widget.validator,
            decoration: decoration,
          ),
        ),
      ),
    );
  }
}
