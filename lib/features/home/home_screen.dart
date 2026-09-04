import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/epg_provider.dart';
import '../../state/settings_provider.dart';
import '../../state/sources_provider.dart';
import '../../state/update_provider.dart';
import '../shell/app_shell.dart';
import '../sources/add_source_screen.dart';
import '../update/update_dialog.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourcesAsync = ref.watch(sourcesProvider);

    // Préchargement optionnel du guide EPG complet dès l'ouverture.
    final s = ref.watch(settingsValueProvider);
    if (s.epgEnabled && s.preloadEpg) ref.watch(epgGuideProvider);

    ref.listen(startupUpdateCheckProvider, (_, next) {
      final info = next.value;
      if (info == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) UpdateDialog.show(context, info);
      });
    });

    return sourcesAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('NexoraTV')),
        body: Center(child: Text('Erreur de démarrage : $e')),
      ),
      data: (state) =>
          state.sources.isEmpty ? const _EmptyState() : const AppShell(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NexoraTV')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.live_tv_outlined, size: 72),
              const SizedBox(height: 16),
              Text('Aucune source configurée',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'Ajoute une playlist M3U ou un compte Xtream Codes pour commencer.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddSourceScreen()),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une source'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
