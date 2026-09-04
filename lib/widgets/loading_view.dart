import 'package:flutter/material.dart';

/// Écran de chargement plein cadre : barre de progression fine + libellé,
/// façon « Chargement des chaînes TV… ». Utilisé pendant le (re)chargement
/// du catalogue et sur les écrans de sources.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Chargement…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: onSurface.withValues(alpha: .12),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: onSurface.withValues(alpha: .75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
