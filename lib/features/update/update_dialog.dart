import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/update_service.dart';
import '../../state/update_provider.dart';

/// Boîte de dialogue « Mise à jour disponible » avec téléchargement + install.
class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({super.key, required this.info});
  final UpdateInfo info;

  static Future<void> show(BuildContext context, UpdateInfo info) =>
      showDialog<void>(
        context: context,
        barrierDismissible: !info.mandatory,
        builder: (_) => UpdateDialog(info: info),
      );

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  bool _busy = false;
  double _progress = 0;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(updateServiceProvider).downloadAndInstall(
            widget.info,
            onProgress: (p) => setState(() => _progress = p),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.info;
    return AlertDialog(
      title: const Text('Mise à jour disponible'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NexoraTV ${i.version} — tu as la ${i.currentVersion}.'),
          const SizedBox(height: 4),
          const Text(
            'L\'app se fermera pour installer, puis se relancera.',
            style: TextStyle(fontSize: 12),
          ),
          if (i.notes != null && i.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(child: Text(i.notes!)),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
                value: _progress >= 0 ? _progress : null),
            const SizedBox(height: 4),
            Text(_progress >= 0
                ? '${(_progress * 100).round()} %'
                : 'Téléchargement…'),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
      actions: [
        if (!i.mandatory && !_busy)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Plus tard'),
          ),
        if (!_busy)
          TextButton(
            onPressed: () => ref.read(updateServiceProvider).openInBrowser(i),
            child: const Text('Ouvrir le lien'),
          ),
        FilledButton(
          onPressed: _busy ? null : _install,
          child: const Text('Installer'),
        ),
      ],
    );
  }
}
