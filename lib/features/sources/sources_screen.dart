import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/playlist_source.dart';
import '../../state/sources_provider.dart';
import 'add_source_screen.dart';

class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sourcesProvider).value;
    final sources = state?.sources ?? const <PlaylistSource>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Mes sources')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddSourceScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: sources.isEmpty
          ? const Center(child: Text('Aucune source. Appuie sur « Ajouter ».'))
          : ListView.separated(
              itemCount: sources.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final s = sources[i];
                return ListTile(
                  leading: Icon(s.isXtream ? Icons.vpn_key : Icons.link),
                  title: Text(s.name),
                  subtitle: Text(
                    s.isXtream ? '${s.host} · ${s.username}' : s.m3uUrl ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.id == state?.selectedId)
                        Icon(Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary),
                      IconButton(
                        tooltip: 'Modifier',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddSourceScreen(existing: s),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(context, ref, s),
                      ),
                    ],
                  ),
                  onTap: () {
                    ref.read(sourcesProvider.notifier).select(s.id);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    PlaylistSource s,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Supprimer « ${s.name} » ?'),
        content: const Text('Cette source sera retirée de l\'application.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(sourcesProvider.notifier).remove(s.id);
    }
  }
}
