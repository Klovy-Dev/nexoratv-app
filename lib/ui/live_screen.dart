import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/models.dart';
import '../state/app_state.dart';
import 'player.dart';
import 'theme.dart';
import 'widgets.dart';

/// TV en direct : catégories | chaînes | lecteur intégré.
/// Clavier : ↑ ↓ (ou Page ↑ ↓) pour zapper, F plein écran, Espace pause,
/// M couper le son.
class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key});

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  late final Player _player = createPlayer();
  late final VideoController _video = VideoController(_player);
  final _videoKey = GlobalKey<VideoState>();
  StreamSubscription<String>? _errors;

  String? _categoryId;
  String _query = '';
  LiveChannel? _current;
  bool _failed = false;

  /// Chaînes affichées (catégorie + recherche), pour le zapping.
  List<LiveChannel> _visible = const [];

  @override
  void initState() {
    super.initState();
    _errors = _player.stream.error.listen((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _errors?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _play(LiveChannel channel) {
    setState(() {
      _current = channel;
      _failed = false;
    });
    _player.open(Media(channel.url));
  }

  void _zap(int delta) {
    final list = _visible;
    if (list.isEmpty) return;
    final i = _current == null ? -1 : list.indexWhere((c) => c.id == _current!.id);
    final next = i < 0 ? 0 : (i + delta) % list.length;
    _play(list[next]);
  }

  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
        const SingleActivator(LogicalKeyboardKey.space): () => _player.playOrPause(),
        const SingleActivator(LogicalKeyboardKey.keyF): () => _videoKey.currentState?.toggleFullscreen(),
        const SingleActivator(LogicalKeyboardKey.escape): () => _videoKey.currentState?.exitFullscreen(),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _zap(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _zap(1),
        const SingleActivator(LogicalKeyboardKey.pageUp): () => _zap(-1),
        const SingleActivator(LogicalKeyboardKey.pageDown): () => _zap(1),
        const SingleActivator(LogicalKeyboardKey.channelUp): () => _zap(-1),
        const SingleActivator(LogicalKeyboardKey.channelDown): () => _zap(1),
        const SingleActivator(LogicalKeyboardKey.keyM): () =>
            _player.setVolume(_player.state.volume > 0 ? 0 : 100),
      };

  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(liveChannelsProvider);
    final categories = ref.watch(liveCategoriesProvider).value ?? const <Category>[];

    return channels.when(
      loading: () => const LoadingView(label: 'Chargement des chaînes…'),
      error: (e, _) => MessageView(
        icon: Icons.wifi_off_rounded,
        title: 'Chaînes indisponibles',
        message: errorText(e),
        action: FilledButton(
          onPressed: () => ref.invalidate(liveChannelsProvider),
          child: const Text('Réessayer'),
        ),
      ),
      data: (all) {
        final q = _query.trim().toLowerCase();
        _visible = [
          for (final c in all)
            if ((_categoryId == null || c.categoryId == _categoryId) &&
                (q.isEmpty || c.name.toLowerCase().contains(q)))
              c,
        ];
        final counts = <String, int>{};
        for (final c in all) {
          counts[c.categoryId] = (counts[c.categoryId] ?? 0) + 1;
        }
        final names = {for (final c in categories) c.id: c.name};

        if (all.isEmpty) {
          return const MessageView(
            icon: Icons.live_tv_rounded,
            title: 'Aucune chaîne',
            message: 'Cette source ne propose pas de TV en direct.',
          );
        }

        return Row(children: [
          SizedBox(
            width: 250,
            child: _CategoryPane(
              categories: [for (final c in categories) if ((counts[c.id] ?? 0) > 0) c],
              counts: counts,
              total: all.length,
              selected: _categoryId,
              onSelect: (id) => setState(() => _categoryId = id),
            ),
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 340,
            child: _ChannelPane(
              channels: _visible,
              current: _current,
              onSearch: (v) => setState(() => _query = v),
              onPlay: _play,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _playerPane(names)),
        ]);
      },
    );
  }

  Widget _playerPane(Map<String, String> categoryNames) {
    final current = _current;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Nx.radius),
            child: ColoredBox(
              color: Colors.black,
              child: Stack(fit: StackFit.expand, children: [
                MaterialDesktopVideoControlsTheme(
                  normal: playerControlsTheme(seekBar: false, shortcuts: _shortcuts, bottomButtonBar: _liveButtons),
                  fullscreen: playerControlsTheme(
                    seekBar: false,
                    shortcuts: _shortcuts,
                    bottomButtonBar: _liveButtons,
                    topButtonBar: [
                      if (current != null)
                        Text(current.name, style: const TextStyle(fontFamily: Nx.display, fontSize: 18)),
                    ],
                  ),
                  child: Video(key: _videoKey, controller: _video),
                ),
                if (current == null)
                  const IgnorePointer(
                    child: MessageView(
                      icon: Icons.live_tv_rounded,
                      title: 'Choisissez une chaîne',
                      message: 'Cliquez sur une chaîne dans la liste pour la regarder ici.',
                    ),
                  ),
                if (_failed)
                  Container(
                    color: Colors.black.withValues(alpha: 0.75),
                    child: MessageView(
                      icon: Icons.signal_wifi_statusbar_connected_no_internet_4_rounded,
                      title: 'Flux indisponible',
                      message: 'Cette chaîne ne répond pas pour le moment.',
                      action: OutlinedButton(
                        onPressed: current == null ? null : () => _play(current),
                        child: const Text('Réessayer'),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 22),
        if (current != null)
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 52,
                height: 52,
                child: NetImage(current.logo, label: current.name, fit: BoxFit.contain, cacheWidth: 120),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(current.name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(
                  categoryNames[current.categoryId] ?? current.categoryId,
                  style: const TextStyle(color: Nx.muted),
                ),
              ]),
            ),
            IconButton.outlined(
              tooltip: 'Chaîne précédente (↑)',
              onPressed: () => _zap(-1),
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: 'Chaîne suivante (↓)',
              onPressed: () => _zap(1),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Plein écran (F)',
              onPressed: () => _videoKey.currentState?.enterFullscreen(),
              icon: const Icon(Icons.fullscreen_rounded),
            ),
          ]),
        const SizedBox(height: 18),
        const Text(
          '↑ ↓ changer de chaîne  ·  F plein écran  ·  Espace pause  ·  M couper le son  ·  Double-clic plein écran',
          style: TextStyle(color: Nx.muted, fontSize: 12.5),
        ),
      ]),
    );
  }

  List<Widget> get _liveButtons => [
        const MaterialDesktopPlayOrPauseButton(),
        const MaterialDesktopVolumeButton(),
        const Spacer(),
        MaterialDesktopCustomButton(
          icon: const Icon(Icons.keyboard_arrow_up_rounded),
          onPressed: () => _zap(-1),
        ),
        MaterialDesktopCustomButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onPressed: () => _zap(1),
        ),
        const MaterialDesktopFullscreenButton(),
      ];
}

class _CategoryPane extends StatelessWidget {
  const _CategoryPane({
    required this.categories,
    required this.counts,
    required this.total,
    required this.selected,
    required this.onSelect,
  });

  final List<Category> categories;
  final Map<String, int> counts;
  final int total;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 22, 20, 12),
          child: Text('CATÉGORIES', style: TextStyle(color: Nx.muted, fontSize: 11.5, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
            itemCount: categories.length + 1,
            itemBuilder: (_, i) {
              final cat = i == 0 ? null : categories[i - 1];
              return _PaneTile(
                label: cat?.name ?? 'Toutes les chaînes',
                trailing: '${cat == null ? total : counts[cat.id] ?? 0}',
                selected: selected == cat?.id,
                onTap: () => onSelect(cat?.id),
              );
            },
          ),
        ),
      ]);
}

class _ChannelPane extends StatelessWidget {
  const _ChannelPane({
    required this.channels,
    required this.current,
    required this.onSearch,
    required this.onPlay,
  });

  final List<LiveChannel> channels;
  final LiveChannel? current;
  final ValueChanged<String> onSearch;
  final ValueChanged<LiveChannel> onPlay;

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
          child: SearchField(hint: 'Rechercher une chaîne', onChanged: onSearch),
        ),
        Expanded(
          child: channels.isEmpty
              ? const Center(child: Text('Aucune chaîne trouvée.', style: TextStyle(color: Nx.muted)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                  itemExtent: 62,
                  itemCount: channels.length,
                  itemBuilder: (_, i) {
                    final c = channels[i];
                    final playing = c.id == current?.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: HoverCard(
                        onTap: () => onPlay(c),
                        selected: playing,
                        radius: Nx.radiusSm,
                        scale: 1,
                        lift: 0,
                        outlined: false,
                        color: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: NetImage(c.logo, label: c.name, fit: BoxFit.contain, cacheWidth: 96),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: playing ? FontWeight.w700 : FontWeight.w500,
                                color: playing ? Nx.accent : Nx.text,
                              ),
                            ),
                          ),
                          if (playing) const Icon(Icons.graphic_eq_rounded, color: Nx.accent, size: 18),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]);
}

class _PaneTile extends StatelessWidget {
  const _PaneTile({required this.label, required this.trailing, required this.selected, required this.onTap});

  final String label;
  final String trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: HoverCard(
          onTap: onTap,
          selected: selected,
          radius: Nx.radiusSm,
          scale: 1,
          lift: 0,
          outlined: false,
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Nx.text : Nx.muted,
                ),
              ),
            ),
            Text(trailing, style: const TextStyle(color: Nx.muted, fontSize: 12)),
          ]),
        ),
      );
}
