import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../state/app_state.dart';
import 'onboarding.dart';
import 'theme.dart';
import 'widgets.dart';

/// Compte NexoraTV + liste des sources (choix de la source active).
class SourcesScreen extends ConsumerStatefulWidget {
  const SourcesScreen({super.key});

  @override
  ConsumerState<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends ConsumerState<SourcesScreen> {
  bool _syncing = false;

  Future<void> _sync() async {
    setState(() => _syncing = true);
    await ref.read(appProvider.notifier).syncAccount();
    if (mounted) setState(() => _syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final ctl = ref.read(appProvider.notifier);

    return ListView(padding: const EdgeInsets.fromLTRB(32, 26, 32, 32), children: [
      Text('Compte et sources', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 22),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Nx.surface, borderRadius: BorderRadius.circular(Nx.radius), border: Border.all(color: Nx.border)),
        child: app.loggedIn
            ? Row(children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Nx.accent.withValues(alpha: 0.15),
                  child: Text(
                    (app.user?.name.characters.firstOrNull ?? '?').toUpperCase(),
                    style: const TextStyle(color: Nx.accent, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(app.user?.name ?? 'Compte NexoraTV', style: Theme.of(context).textTheme.titleMedium),
                    Text(app.user?.email ?? '', style: const TextStyle(color: Nx.muted)),
                    if (app.accountError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(app.accountError!, style: const TextStyle(color: Nx.warning, fontSize: 13)),
                      ),
                  ]),
                ),
                OutlinedButton.icon(
                  onPressed: _syncing ? null : _sync,
                  icon: _syncing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Actualiser'),
                ),
                const SizedBox(width: 10),
                TextButton(onPressed: ctl.logout, child: const Text('Se déconnecter')),
              ])
            : Row(children: [
                const Expanded(
                  child: Text(
                    'Connectez votre compte NexoraTV pour retrouver vos abonnements automatiquement.',
                    style: TextStyle(color: Nx.muted),
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                  child: const Text('Se connecter'),
                ),
              ]),
      ),
      const SizedBox(height: 28),
      Row(children: [
        Text('Sources', style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddSourceScreen())),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Ajouter une source'),
        ),
      ]),
      const SizedBox(height: 14),
      if (app.sources.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aucune source. Connectez votre compte ou ajoutez un serveur Xtream / une playlist M3U.',
            style: TextStyle(color: Nx.muted),
          ),
        ),
      for (final s in app.sources)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SourceTile(
            source: s,
            selected: s.id == app.active?.id,
            onSelect: () => ctl.select(s.id),
            onDelete: s.fromAccount ? null : () => ctl.removeSource(s.id),
          ),
        ),
    ]);
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.source, required this.selected, required this.onSelect, this.onDelete});

  final Source source;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final kind = source.kind == SourceKind.xtream ? 'Xtream' : 'Playlist M3U';
    final origin = source.fromAccount ? 'Abonnement NexoraTV' : 'Ajoutée manuellement';
    final expiry = source.expiresAt == null ? null : 'expire le ${_frDate(source.expiresAt!)}';
    return HoverCard(
      onTap: onSelect,
      selected: selected,
      scale: 1.01,
      lift: 2,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(children: [
        Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? Nx.accent : Nx.muted),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(source.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text([origin, kind, ?expiry].join('  ·  '), style: const TextStyle(color: Nx.muted, fontSize: 13)),
          ]),
        ),
        if (!source.active)
          Container(
            margin: const EdgeInsets.only(left: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Nx.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
            child: const Text('Expiré', style: TextStyle(color: Nx.danger, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        if (onDelete != null)
          IconButton(
            tooltip: 'Supprimer',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, color: Nx.muted),
          ),
      ]),
    );
  }
}

String _frDate(String iso) {
  final p = iso.split('T').first.split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
}
