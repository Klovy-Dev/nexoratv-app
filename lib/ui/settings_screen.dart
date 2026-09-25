import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../state/app_state.dart';
import '../state/settings.dart';
import 'sources_screen.dart';
import 'theme.dart';

const kAppVersion = '2.0.0';

enum SettingsTab {
  sources('Compte et sources', Icons.manage_accounts_rounded),
  playback('Lecture', Icons.play_circle_outline_rounded),
  storage('Données', Icons.storage_rounded),
  about('À propos', Icons.info_outline_rounded);

  const SettingsTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.initialTab = SettingsTab.sources});

  final SettingsTab initialTab;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Row(children: [
          Container(
            width: 260,
            decoration: const BoxDecoration(color: Nx.bgSoft, border: Border(right: BorderSide(color: Nx.border))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Row(children: [
                  IconButton(
                    tooltip: 'Retour',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 6),
                  Text('Paramètres', style: Theme.of(context).textTheme.titleLarge),
                ]),
              ),
              for (final t in SettingsTab.values)
                _TabItem(tab: t, selected: t == _tab, onTap: () => setState(() => _tab = t)),
            ]),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey(_tab),
                child: switch (_tab) {
                  SettingsTab.sources => const SourcesScreen(),
                  SettingsTab.playback => const _PlaybackPanel(),
                  SettingsTab.storage => const _StoragePanel(),
                  SettingsTab.about => const _AboutPanel(),
                },
              ),
            ),
          ),
        ]),
      );
}

class _TabItem extends StatefulWidget {
  const _TabItem({required this.tab, required this.selected, required this.onTap});

  final SettingsTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    final color = sel ? Nx.accent : (_hover ? Nx.text : Nx.muted);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: Nx.fast,
          curve: Nx.ease,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          transform: Matrix4.translationValues(_hover && !sel ? 4 : 0, 0, 0),
          decoration: BoxDecoration(
            color: sel ? Nx.accent.withValues(alpha: 0.1) : (_hover ? Nx.surface : Colors.transparent),
            borderRadius: BorderRadius.circular(Nx.radiusSm),
          ),
          child: Row(children: [
            Icon(widget.tab.icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(widget.tab.label, style: TextStyle(color: sel ? Nx.text : color, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

/* ---------- Panneaux ---------- */

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(32, 26, 32, 32),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 22),
          ...children,
        ],
      );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(color: Nx.surface, borderRadius: BorderRadius.circular(Nx.radius), border: Border.all(color: Nx.border)),
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 20, endIndent: 20),
            children[i],
          ],
        ]),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.subtitle, required this.trailing});

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: Nx.muted, fontSize: 13)),
            ]),
          ),
          const SizedBox(width: 20),
          trailing,
        ]),
      );
}

class _PlaybackPanel extends ConsumerWidget {
  const _PlaybackPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctl = ref.read(settingsProvider.notifier);
    return _Panel(title: 'Lecture', children: [
      _Group(children: [
        _Row(
          title: 'Format des chaînes en direct',
          subtitle: 'MPEG-TS convient à la plupart des serveurs. Essayez HLS si les chaînes coupent ou ne démarrent pas.',
          trailing: SegmentedButton<LiveFormat>(
            segments: const [
              ButtonSegment(value: LiveFormat.ts, label: Text('MPEG-TS')),
              ButtonSegment(value: LiveFormat.hls, label: Text('HLS')),
            ],
            selected: {s.liveFormat},
            onSelectionChanged: (v) => ctl.setLiveFormat(v.first),
          ),
        ),
        _Row(
          title: 'Mémoire tampon',
          subtitle: 'Plus elle est grande, mieux la lecture encaisse les coupures réseau (utilise plus de mémoire).',
          trailing: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 32, label: Text('32 Mo')),
              ButtonSegment(value: 64, label: Text('64 Mo')),
              ButtonSegment(value: 128, label: Text('128 Mo')),
            ],
            selected: {s.bufferMb},
            onSelectionChanged: (v) => ctl.setBufferMb(v.first),
          ),
        ),
        _Row(
          title: 'Décodage matériel',
          subtitle: 'Utilise la carte graphique pour décoder la vidéo. Désactivez en cas d’image noire ou saccadée.',
          trailing: Switch(value: s.hardwareDecoding, onChanged: ctl.setHardwareDecoding),
        ),
        _Row(
          title: 'Plein écran automatique',
          subtitle: 'Passe en plein écran dès qu’on lance une chaîne en direct.',
          trailing: Switch(value: s.startLiveFullscreen, onChanged: ctl.setStartLiveFullscreen),
        ),
      ]),
      const Text(
        'Les réglages de lecture s’appliquent à la prochaine ouverture du lecteur.',
        style: TextStyle(color: Nx.muted, fontSize: 13),
      ),
      const SizedBox(height: 18),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(onPressed: ctl.reset, child: const Text('Rétablir les réglages par défaut')),
      ),
    ]);
  }
}

class _StoragePanel extends ConsumerStatefulWidget {
  const _StoragePanel();

  @override
  ConsumerState<_StoragePanel> createState() => _StoragePanelState();
}

class _StoragePanelState extends ConsumerState<_StoragePanel> {
  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) => _Panel(title: 'Données', children: [
        _Group(children: [
          _Row(
            title: 'Recharger les listes',
            subtitle: 'Télécharge à nouveau les chaînes, films et séries de la source active.',
            trailing: OutlinedButton(
              onPressed: () {
                ref.invalidate(contentProvider);
                _toast('Les listes seront rechargées à la prochaine ouverture.');
              },
              child: const Text('Recharger'),
            ),
          ),
          _Row(
            title: 'Vider le cache des images',
            subtitle: 'Supprime les logos et affiches enregistrés sur ce PC (ils se re-téléchargent au besoin).',
            trailing: OutlinedButton(
              onPressed: () async {
                await DefaultCacheManager().emptyCache();
                PaintingBinding.instance.imageCache.clear();
                _toast('Cache des images vidé.');
              },
              child: const Text('Vider'),
            ),
          ),
        ]),
      ]);
}

class _AboutPanel extends StatelessWidget {
  const _AboutPanel();

  @override
  Widget build(BuildContext context) => const _Panel(title: 'À propos', children: [
        _Group(children: [
          _Row(title: 'Version', subtitle: 'NexoraTV pour Windows', trailing: Text(kAppVersion, style: TextStyle(fontWeight: FontWeight.w700))),
          _Row(title: 'Site', subtitle: 'Compte, abonnements et assistance', trailing: SelectableText(kApiBase)),
        ]),
      ]);
}
