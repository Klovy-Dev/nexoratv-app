import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/updater.dart';
import 'theme.dart';
import 'toast.dart';
import 'widgets.dart';

/// Vérifie les mises à jour et propose d'installer la nouvelle version.
/// [silent] : au démarrage, rien n'est affiché si l'appli est à jour ou si
/// la vérification échoue. Sinon, une erreur est relancée (le bouton
/// « Rechercher » l'affiche au milieu de l'écran).
Future<void> checkForUpdate(BuildContext context, {bool silent = false}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final AppUpdate? update;
  try {
    update = await Updater.check();
  } catch (_) {
    if (silent) return;
    rethrow;
  }
  if (update == null) {
    if (!silent) {
      showToastIn(
        overlay,
        'NexoraTV est à jour (version ${await Updater.currentVersion()}).',
      );
    }
    return;
  }
  if (!context.mounted) return;
  // Pas d'attente : le bouton qui a lancé la recherche redevient libre.
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: !update.mandatory,
      builder: (_) => _UpdateDialog(update: update!),
    ),
  );
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.update});
  final AppUpdate update;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double? _progress;
  String? _error;

  Future<void> _install() async {
    final u = widget.update;
    // Android : l'APK s'ouvre dans le navigateur (installation par Android).
    if (!Platform.isWindows) {
      await launchUrl(Uri.parse(u.url), mode: LaunchMode.externalApplication);
      return;
    }
    setState(() {
      _downloading = true;
      _progress = null;
      _error = null;
    });
    try {
      final file = await Updater.download(u, (p) {
        if (mounted) setState(() => _progress = p);
      });
      await Updater.install(file);
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.update;
    final notes = u.notes?.trim();
    return PopScope(
      canPop: !u.mandatory && !_downloading,
      child: AlertDialog(
        title: const Text('Mise à jour disponible'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'La version '),
                    TextSpan(
                      text: u.version,
                      style: const TextStyle(
                        color: Nx.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(text: ' est disponible (vous avez ${u.current}).'),
                  ],
                ),
              ),
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(notes, style: const TextStyle(color: Nx.muted)),
                  ),
                ),
              ],
              if (_downloading) ...[
                const SizedBox(height: 18),
                LinearProgressIndicator(
                  value: _progress,
                  color: Nx.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Text(
                  _progress == null
                      ? 'Téléchargement…'
                      : 'Téléchargement… ${(_progress! * 100).round()} %',
                  style: const TextStyle(color: Nx.muted, fontSize: 13),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: Nx.danger)),
              ],
            ],
          ),
        ),
        actions: [
          if (!u.mandatory && !_downloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Plus tard'),
            ),
          FilledButton(
            onPressed: _downloading ? null : _install,
            child: Text(_error == null ? 'Mettre à jour' : 'Réessayer'),
          ),
        ],
      ),
    );
  }
}
