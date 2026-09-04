import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/storage/category_prefs_repository.dart';
import '../../state/category_prefs_provider.dart';
import '../../state/channels_provider.dart';
import '../../state/parental_provider.dart';
import '../../state/sources_provider.dart';

class ManageCategoriesScreen extends ConsumerStatefulWidget {
  const ManageCategoriesScreen({super.key, this.lockMode = false});

  /// En mode verrouillage, l'action principale est le cadenas parental.
  final bool lockMode;

  @override
  ConsumerState<ManageCategoriesScreen> createState() =>
      _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState
    extends ConsumerState<ManageCategoriesScreen> {
  int _tab = 0; // 0 TV · 1 Films · 2 Séries
  static const _sections = ['live', 'movie', 'series'];

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(selectedSourceProvider);
    final pl = ref.watch(currentPlaylistProvider)?.value;
    ref.watch(categoryPrefsProvider); // rebuild quand les prefs changent
    final parental = ref.watch(parentalValueProvider);

    if (source == null || pl == null) {
      return const Scaffold(
        body: Center(child: Text('Charge d\'abord une source.')),
      );
    }

    final groups = switch (_tab) {
      0 => pl.liveGroups().map((e) => e.name).toList(),
      1 => pl.movieGroups().map((e) => e.name).toList(),
      _ => pl.seriesGroups().map((e) => e.name).toList(),
    };

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.lockMode
              ? 'Catégories à verrouiller'
              : 'Catégories')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('TV')),
                ButtonSegment(value: 1, label: Text('Films')),
                ButtonSegment(value: 2, label: Text('Séries')),
              ],
              selected: {_tab},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _tab = v.first),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: groups.length,
              itemBuilder: (context, i) {
                final name = groups[i];
                final pref = ref
                    .watch(categoryPrefsProvider.notifier)
                    .prefFor(source.id, _sections[_tab], name);
                final display = (pref.renamedTo?.trim().isNotEmpty ?? false)
                    ? '${pref.renamedTo} · ($name)'
                    : name;
                final locked =
                    parental.isLocked(source.id, _sections[_tab], name);
                if (widget.lockMode) {
                  return SwitchListTile(
                    dense: true,
                    title: Text(display,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    value: locked,
                    onChanged: (_) => ref
                        .read(parentalProvider.notifier)
                        .toggleLock(source.id, _sections[_tab], name),
                  );
                }
                return ListTile(
                  title: Text(display,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  leading: IconButton(
                    icon: Icon(pref.hidden
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => ref
                        .read(categoryPrefsProvider.notifier)
                        .setPref(source.id, _sections[_tab], name,
                            pref.copyWith(hidden: !pref.hidden)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (locked)
                        const Icon(Icons.lock, size: 16, color: Colors.orange),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _rename(source.id, name, pref),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(
      String sourceId, String name, CategoryPref pref) async {
    final c = TextEditingController(text: pref.renamedTo ?? '');
    final r = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Renommer « $name »'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'Laisser vide = nom original'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, c.text.trim()),
              child: const Text('OK')),
        ],
      ),
    );
    if (r != null) {
      await ref.read(categoryPrefsProvider.notifier).setPref(
            sourceId,
            _sections[_tab],
            name,
            pref.copyWith(renamedTo: r.isEmpty ? '' : r),
          );
    }
  }
}
