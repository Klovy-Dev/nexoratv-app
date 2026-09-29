import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/models.dart';
import '../state/app_state.dart';
import '../state/library.dart';
import '../state/settings.dart';
import 'library_widgets.dart';
import 'player.dart';
import 'shell.dart';
import 'theme.dart';
import 'title_bar.dart';
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
  late final (Player, VideoController) _pc = createPlayer(
    ref.read(settingsProvider),
  );
  Player get _player => _pc.$1;
  VideoController get _video => _pc.$2;
  final _videoKey = GlobalKey<VideoState>();
  final _subs = <StreamSubscription<Object?>>[];

  /// Pseudo-catégorie « Favoris » (aucun id de serveur ne ressemble à ça).
  static const _favoritesId = '__favorites__';

  String? _categoryId;
  String _query = '';
  LiveChannel? _current;
  bool _failed = false;

  // Reconnexion automatique : un flux IPTV qui décroche est relancé
  // jusqu'à [_maxRetries] fois (1 s, 2 s, 3 s) avant d'afficher l'erreur.
  static const _maxRetries = 3;
  int _retries = 0;
  bool _reconnecting = false;
  Timer? _retryTimer;

  // Guide des programmes de la chaîne en cours (en ce moment / ensuite).
  List<EpgEntry> _epg = const [];
  Timer? _epgTick;

  // Favoris : ids recalculés seulement quand la liste des favoris change.
  Set<String>? _favSource;
  Set<String> _favIds = const {};

  /// Chaînes affichées (catégorie + recherche), pour le zapping.
  List<LiveChannel> _visible = const [];

  // Noms en minuscules et compteurs par catégorie : calculés une fois par
  // liste chargée, pas à chaque reconstruction (zapping, frappe…).
  List<LiveChannel>? _indexed;
  List<String> _lowerNames = const [];
  Map<String, int> _counts = const {};

  /// Filtre (catégorie, recherche, favoris) de [_visible] ; null = à
  /// recalculer.
  (String?, String, Set<String>?)? _filterKey;
  Timer? _searchDebounce;

  /// Dernière chaîne demandée par l'accueil (voir [_startRequested]).
  String? _requested;

  /// Lignes « ##### SPORTS ##### » des fournisseurs : des intertitres, pas
  /// des chaînes (ni comptées, ni zappées, masquées pendant une recherche).
  Set<String> _separatorIds = const {};

  final _channelScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _subs
      ..add(_player.stream.error.listen((_) => _onStreamLost()))
      // Un direct qui « se termine » a en fait décroché.
      ..add(
        _player.stream.completed.listen((done) {
          if (done) _onStreamLost();
        }),
      )
      ..add(
        _player.stream.position.listen((p) {
          if (_reconnecting && p > Duration.zero && mounted) {
            setState(() => _reconnecting = false);
          }
          // Lecture stable : les prochaines coupures ont à nouveau droit à
          // toutes leurs tentatives.
          if (p > const Duration(seconds: 10)) _retries = 0;
        }),
      );
    _epgTick = Timer.periodic(const Duration(seconds: 30), (_) => _tickEpg());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _channelScroll.dispose();
    _retryTimer?.cancel();
    _epgTick?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  void _open(LiveChannel channel) => _player.open(
    Media(liveUrl(channel.url, ref.read(settingsProvider).liveFormat)),
  );

  void _onStreamLost() {
    final channel = _current;
    if (!mounted || channel == null || _failed) return;
    if (_retryTimer?.isActive ?? false) return; // tentative déjà prévue
    if (_retries >= _maxRetries) {
      setState(() {
        _reconnecting = false;
        _failed = true;
      });
      return;
    }
    _retries++;
    setState(() => _reconnecting = true);
    _retryTimer = Timer(Duration(seconds: _retries), () {
      if (mounted && identical(_current, channel)) _open(channel);
    });
  }

  Future<void> _loadEpg(LiveChannel channel) async {
    List<EpgEntry> list;
    try {
      list = await ref.read(contentProvider)?.shortEpg(channel) ?? const [];
    } catch (_) {
      list = const []; // Pas de guide : on n'affiche simplement rien.
    }
    if (mounted && identical(_current, channel)) setState(() => _epg = list);
  }

  /// Avance le guide : retire les programmes finis, recharge au besoin.
  void _tickEpg() {
    final channel = _current;
    if (!mounted || channel == null) return;
    final now = DateTime.now();
    final left = [
      for (final e in _epg)
        if (e.end.isAfter(now)) e,
    ];
    setState(() => _epg = left);
    if (left.length < 2) _loadEpg(channel);
  }

  void _syncFavorites(Set<String> favorites) {
    if (identical(favorites, _favSource)) return;
    _favSource = favorites;
    _favIds = Library(favorites: favorites).favoriteIds(MediaKind.live);
    if (_categoryId == _favoritesId) _filterKey = null;
  }

  void _index(List<LiveChannel> all) {
    if (identical(all, _indexed)) return;
    _indexed = all;
    _lowerNames = [for (final c in all) c.name.toLowerCase()];
    _separatorIds = {
      for (final c in all)
        if (isSeparatorName(c.name)) c.id,
    };
    final counts = <String, int>{};
    for (final c in all) {
      if (_separatorIds.contains(c.id)) continue;
      counts[c.categoryId] = (counts[c.categoryId] ?? 0) + 1;
    }
    _counts = counts;
    _filterKey = null;
  }

  List<LiveChannel> _filter(List<LiveChannel> all) {
    final q = _query.trim().toLowerCase();
    final favorites = _categoryId == _favoritesId ? _favIds : null;
    final key = (_categoryId, q, favorites);
    if (key == _filterKey) return _visible;
    _filterKey = key;
    // Les intertitres n'ont de sens que dans une liste complète.
    final keepSeparators = q.isEmpty && favorites == null;
    return _visible = [
      for (var i = 0; i < all.length; i++)
        if ((favorites != null
                ? favorites.contains(all[i].id)
                : _categoryId == null || all[i].categoryId == _categoryId) &&
            (q.isEmpty || _lowerNames[i].contains(q)) &&
            (keepSeparators || !_separatorIds.contains(all[i].id)))
          all[i],
    ];
  }

  /// La recherche part quand on arrête de taper, pas à chaque touche.
  void _onSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _query = value);
    });
  }

  void _play(LiveChannel channel) {
    final settings = ref.read(settingsProvider);
    final first = _current == null;
    _retryTimer?.cancel();
    _retries = 0;
    setState(() {
      _current = channel;
      _failed = false;
      _reconnecting = false;
      _epg = const [];
    });
    _open(channel);
    _loadEpg(channel);
    _revealInList(channel);
    if (first && settings.startLiveFullscreen) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _videoKey.currentState?.enterFullscreen(),
      );
    }
  }

  /// Chaîne demandée depuis l'accueil (« Vos chaînes ») : lancée dès que
  /// la liste est prête, en se plaçant dans les favoris pour que le
  /// zapping reste entre chaînes favorites.
  void _startRequested(String id, List<LiveChannel> all) {
    if (id == _requested) return; // déjà prévue pour la prochaine image
    _requested = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(navProvider.notifier).channelStarted();
      final channel = all.where((c) => c.id == id).firstOrNull;
      if (channel == null) return;
      setState(() {
        _categoryId = _favIds.contains(id) ? _favoritesId : channel.categoryId;
      });
      _play(channel);
    });
  }

  /// Chaîne précédente / suivante de la liste affichée, en sautant les
  /// intertitres.
  void _zap(int delta) {
    final list = _visible;
    if (list.isEmpty) return;
    var i = _current == null
        ? -1
        : list.indexWhere((c) => c.id == _current!.id);
    if (i < 0) i = delta > 0 ? -1 : 0;
    for (var step = 0; step < list.length; step++) {
      i = (i + delta) % list.length;
      if (!_separatorIds.contains(list[i].id)) {
        _play(list[i]);
        return;
      }
    }
  }

  /// Fait défiler la liste des chaînes jusqu'à [channel] si elle n'est pas
  /// visible (zapping au clavier, chaîne lancée depuis l'accueil).
  void _revealInList(LiveChannel channel) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_channelScroll.hasClients) return;
      final i = _visible.indexWhere((c) => c.id == channel.id);
      if (i < 0) return;
      final pos = _channelScroll.position;
      final top = i * _ChannelPane.rowExtent;
      final bottom = top + _ChannelPane.rowExtent;
      if (top >= pos.pixels && bottom <= pos.pixels + pos.viewportDimension) {
        return;
      }
      final target = (top - pos.viewportDimension / 2 + _ChannelPane.rowExtent)
          .clamp(0.0, pos.maxScrollExtent);
      _channelScroll.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Nx.ease,
      );
    });
  }

  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.space): () =>
        _player.playOrPause(),
    const SingleActivator(LogicalKeyboardKey.keyF): () =>
        _videoKey.currentState?.toggleFullscreen(),
    const SingleActivator(LogicalKeyboardKey.escape): () =>
        _videoKey.currentState?.exitFullscreen(),
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
    final categories =
        ref.watch(liveCategoriesProvider).value ?? const <Category>[];
    final favorites = ref.watch(libraryProvider.select((l) => l.favorites));
    final requested = ref.watch(navProvider.select((n) => n.channelId));

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
        _index(all);
        _syncFavorites(favorites);
        if (requested != null) _startRequested(requested, all);
        final visible = _filter(all);
        final counts = _counts;
        final names = {for (final c in categories) c.id: c.name};

        if (all.isEmpty) {
          return const MessageView(
            icon: Icons.live_tv_rounded,
            title: 'Aucune chaîne',
            message: 'Cette source ne propose pas de TV en direct.',
          );
        }

        return Row(
          children: [
            SizedBox(
              width: 250,
              child: _CategoryPane(
                categories: [
                  for (final c in categories)
                    if ((counts[c.id] ?? 0) > 0) c,
                ],
                counts: counts,
                total: all.length,
                favorites: _favIds.length,
                favoritesId: _favoritesId,
                selected: _categoryId,
                onSelect: (id) {
                  if (_channelScroll.hasClients) _channelScroll.jumpTo(0);
                  setState(() => _categoryId = id);
                },
              ),
            ),
            const VerticalDivider(width: 1),
            SizedBox(
              width: 340,
              child: _ChannelPane(
                controller: _channelScroll,
                channels: visible,
                favoriteIds: _favIds,
                current: _current,
                onSearch: _onSearch,
                onPlay: _play,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _playerPane(names)),
          ],
        );
      },
    );
  }

  Widget _playerPane(Map<String, String> categoryNames) {
    final current = _current;
    // Largeur calculée pendant la mise en page, sans reconstruire les
    // widgets (un LayoutBuilder ici faisait planter les infobulles des
    // boutons au passage en plein écran).
    return CustomSingleChildLayout(
      delegate: const _PlayerPaneLayout(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(_PlayerPaneLayout.pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _videoView(current),
            if (current != null) ...[
              const SizedBox(height: 18),
              _infoRow(current, categoryNames),
            ],
            if (current != null && _epg.isNotEmpty) ...[
              const SizedBox(height: 14),
              _EpgPanel(entries: _epg),
            ],
          ],
        ),
      ),
    );
  }

  Widget _videoView(LiveChannel? current) => AspectRatio(
    aspectRatio: 16 / 9,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(Nx.radius),
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MaterialDesktopVideoControlsTheme(
              normal: playerControlsTheme(
                seekBar: false,
                shortcuts: _shortcuts,
                bottomButtonBar: _liveButtons,
              ),
              fullscreen: playerControlsTheme(
                seekBar: false,
                shortcuts: _shortcuts,
                bottomButtonBar: _liveButtons,
                topButtonBar: [
                  if (current != null)
                    Text(
                      current.name,
                      style: const TextStyle(
                        fontFamily: Nx.display,
                        fontSize: 18,
                      ),
                    ),
                ],
              ),
              child: Video(
                key: _videoKey,
                controller: _video,
                onEnterFullscreen: enterVideoFullscreen,
                onExitFullscreen: exitVideoFullscreen,
              ),
            ),
            if (current == null)
              const IgnorePointer(
                child: MessageView(
                  icon: Icons.live_tv_rounded,
                  title: 'Choisissez une chaîne',
                  message: 'Cliquez sur une chaîne dans la liste pour la regarder ici.',
                ),
              ),
            if (_reconnecting && !_failed)
              IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Nx.accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Reconnexion… ($_retries/$_maxRetries)',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_failed)
              Container(
                color: Colors.black.withValues(alpha: 0.75),
                child: MessageView(
                  icon: Icons
                      .signal_wifi_statusbar_connected_no_internet_4_rounded,
                  title: 'Flux indisponible',
                  message:
                      'Cette chaîne ne répond pas, même après $_maxRetries tentatives de reconnexion.',
                  action: OutlinedButton(
                    onPressed: current == null ? null : () => _play(current),
                    child: const Text('Réessayer'),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _infoRow(LiveChannel current, Map<String, String> categoryNames) =>
      Row(
        children: [
          ChannelLogo(channel: current, width: 64, height: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  categoryNames[current.categoryId] ?? current.categoryId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Nx.muted, fontSize: 13.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FavoriteButton(kind: MediaKind.live, id: current.id),
          const SizedBox(width: 8),
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
          const Tooltip(
            message:
                '↑ ↓  changer de chaîne\n'
                'F  plein écran (ou double-clic)\n'
                'Espace  pause\n'
                'M  couper le son',
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.keyboard_outlined, color: Nx.muted),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Plein écran (F)',
            onPressed: () => _videoKey.currentState?.enterFullscreen(),
            icon: const Icon(Icons.fullscreen_rounded),
          ),
        ],
      );

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

/// Colonne du lecteur centrée, assez étroite pour que la vidéo, le nom de
/// la chaîne et le guide tiennent dans la hauteur sans défiler (1080p).
class _PlayerPaneLayout extends SingleChildLayoutDelegate {
  const _PlayerPaneLayout();

  static const pad = 28.0;

  /// Hauteur gardée sous la vidéo (nom de la chaîne + guide).
  static const below = 200.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) {
    final byHeight = (c.maxHeight - pad * 2 - below) * 16 / 9;
    final video = math.min(c.maxWidth - pad * 2, math.max(420.0, byHeight));
    final width = math.max(0.0, video + pad * 2);
    return BoxConstraints.tightFor(width: width, height: c.maxHeight);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      Offset((size.width - childSize.width) / 2, 0);

  @override
  bool shouldRelayout(_PlayerPaneLayout oldDelegate) => false;
}

class _CategoryPane extends StatelessWidget {
  const _CategoryPane({
    required this.categories,
    required this.counts,
    required this.total,
    required this.favorites,
    required this.favoritesId,
    required this.selected,
    required this.onSelect,
  });

  final List<Category> categories;
  final Map<String, int> counts;
  final int total;

  /// Nombre de chaînes favorites (entrée « Favoris » s'il y en a).
  final int favorites;
  final String favoritesId;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final showFavorites = favorites > 0 || selected == favoritesId;
    final head = showFavorites ? 2 : 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 22, 20, 8),
          child: _PaneTitle('Catégories'),
        ),
        Expanded(
          child: EdgeFade(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
              itemCount: categories.length + head,
              itemBuilder: (_, i) {
                if (showFavorites && i == 1) {
                  return _PaneTile(
                    label: '★ Favoris',
                    trailing: '$favorites',
                    selected: selected == favoritesId,
                    onTap: () => onSelect(favoritesId),
                  );
                }
                final cat = i == 0 ? null : categories[i - head];
                return _PaneTile(
                  label: cat?.name ?? 'Toutes les chaînes',
                  trailing: '${cat == null ? total : counts[cat.id] ?? 0}',
                  selected: selected == cat?.id,
                  onTap: () => onSelect(cat?.id),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PaneTitle extends StatelessWidget {
  const _PaneTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      color: Nx.muted,
      fontSize: 11.5,
      letterSpacing: 1.2,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _PaneTile extends StatelessWidget {
  const _PaneTile({
    required this.label,
    required this.trailing,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: ListRow(
      onTap: onTap,
      selected: selected,
      padding: const EdgeInsets.fromLTRB(9, 10, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Nx.text : Nx.muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(trailing, style: const TextStyle(color: Nx.muted, fontSize: 12)),
        ],
      ),
    ),
  );
}

/// « ##### FRANCE SPORTS ##### », « ===== NEWS ===== »… : lignes que les
/// fournisseurs glissent dans la liste pour la découper en sections.
final _separatorRe = RegExp(r'^\s*[#=*~_\-]{3,}|[#=*~_\-]{3,}\s*$');

bool isSeparatorName(String name) => _separatorRe.hasMatch(name);

/// Titre lisible d'un intertitre (sans les symboles).
String _separatorLabel(String name) {
  final t = name
      .replaceAll(RegExp(r'[#=*~_]+|-{2,}'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return t.isEmpty ? '—' : t;
}

/// Logo de chaîne dans un cadre rectangulaire (les logos sont souvent
/// larges : un carré les rendait minuscules).
class ChannelLogo extends StatelessWidget {
  const ChannelLogo({
    super.key,
    required this.channel,
    this.width = 52,
    this.height = 32,
  });

  final LiveChannel channel;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: Nx.surface2,
      borderRadius: BorderRadius.circular(6),
    ),
    child: NetImage(
      channel.logo,
      label: channel.name,
      fit: BoxFit.contain,
      cacheWidth: (width * 2.5).round(),
    ),
  );
}

class _ChannelPane extends StatelessWidget {
  const _ChannelPane({
    required this.controller,
    required this.channels,
    required this.favoriteIds,
    required this.current,
    required this.onSearch,
    required this.onPlay,
  });

  /// Hauteur fixe d'une ligne (sert aussi à faire défiler jusqu'à la
  /// chaîne en cours).
  static const rowExtent = 50.0;

  final ScrollController controller;
  final List<LiveChannel> channels;
  final Set<String> favoriteIds;
  final LiveChannel? current;
  final ValueChanged<String> onSearch;
  final ValueChanged<LiveChannel> onPlay;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
        child: SearchField(hint: 'Rechercher une chaîne', onChanged: onSearch),
      ),
      Expanded(
        child: channels.isEmpty
            ? const Center(
                child: Text(
                  'Aucune chaîne trouvée.',
                  style: TextStyle(color: Nx.muted),
                ),
              )
            : EdgeFade(
                child: ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
                  itemExtent: rowExtent,
                  itemCount: channels.length,
                  itemBuilder: (_, i) {
                    final c = channels[i];
                    if (isSeparatorName(c.name)) {
                      return _SeparatorRow(_separatorLabel(c.name));
                    }
                    final playing = c.id == current?.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: ListRow(
                        onTap: () => onPlay(c),
                        selected: playing,
                        padding: const EdgeInsets.only(left: 7, right: 10),
                        child: Row(
                          children: [
                            ChannelLogo(channel: c),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: playing
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (favoriteIds.contains(c.id))
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(
                                  Icons.star_rounded,
                                  color: Nx.warning,
                                  size: 15,
                                ),
                              ),
                            if (playing)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(
                                  Icons.graphic_eq_rounded,
                                  color: Nx.accent,
                                  size: 17,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    ],
  );
}

/// Intertitre de la liste des chaînes (non cliquable).
class _SeparatorRow extends StatelessWidget {
  const _SeparatorRow(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 6, 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Largeur bornée plutôt que Flexible : sinon le titre et le trait
        // se partagent la ligne à parts égales.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: _PaneTitle(label),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Padding(padding: EdgeInsets.only(bottom: 6), child: Divider()),
        ),
      ],
    ),
  );
}

/// Guide des programmes, compact : « En ce moment » (avec avancement) à
/// gauche, la suite à droite.
class _EpgPanel extends StatelessWidget {
  const _EpgPanel({required this.entries});

  final List<EpgEntry> entries;

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final current = entries.first.start.isAfter(now) ? null : entries.first;
    final upcoming = entries.skip(current == null ? 0 : 1).take(2).toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Nx.surface,
        borderRadius: BorderRadius.circular(Nx.radius),
        border: Border.all(color: Nx.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (current != null)
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'EN CE MOMENT',
                          style: TextStyle(
                            color: Nx.accent,
                            fontSize: 11.5,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${_hm(current.start)} – ${_hm(current.end)}',
                          style: const TextStyle(
                            color: Nx.muted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Tooltip(
                      message: current.description ?? '',
                      waitDuration: const Duration(milliseconds: 500),
                      child: Text(
                        current.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 9),
                    LinearProgressIndicator(
                      value: current.progressAt(now),
                      color: Nx.accent,
                      backgroundColor: Nx.surface2,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            if (current != null && upcoming.isNotEmpty)
              const VerticalDivider(width: 36),
            if (upcoming.isNotEmpty)
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _PaneTitle('Ensuite'),
                    for (final e in upcoming)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 48,
                              child: Text(
                                _hm(e.start),
                                style: const TextStyle(
                                  color: Nx.muted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                e.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
