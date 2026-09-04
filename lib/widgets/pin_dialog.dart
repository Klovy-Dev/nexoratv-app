import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Demande un code PIN. Renvoie `true` si [verify] a accepté la saisie.
Future<bool> askPin(
  BuildContext context, {
  required bool Function(String) verify,
  String title = 'Code parental',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _PinDialog(title: title, verify: verify),
  );
  return ok ?? false;
}

/// Saisie d'un nouveau PIN (4 chiffres). Renvoie le PIN ou `null`.
Future<String?> createPin(BuildContext context) async {
  return showDialog<String>(
    context: context,
    builder: (_) => const _PinDialog(title: 'Nouveau code (4 chiffres)'),
  );
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.title, this.verify});
  final String title;
  final bool Function(String)? verify;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _c = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _c.text.trim();
    if (v.length < 4) {
      setState(() => _error = '4 chiffres minimum');
      return;
    }
    if (widget.verify == null) {
      Navigator.pop(context, v); // création
      return;
    }
    if (widget.verify!(v)) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _error = 'Code incorrect';
        _c.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _c,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 8,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, letterSpacing: 8),
        decoration: InputDecoration(
          counterText: '',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Valider')),
      ],
    );
  }
}
