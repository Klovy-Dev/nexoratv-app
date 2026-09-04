import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

import '../../models/channel.dart';
import '../../state/epg_provider.dart';
import '../../state/providers.dart';
import '../../state/settings_provider.dart';
import '../../state/watch_history_provider.dart';
import '../../widgets/nav.dart';

/// Lecteur plein écran basé sur media_kit (libmpv), avec commandes maison.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({
    super.key,
    required this.sourceId,
    required this.playlist,
    required this.startIndex,
  });

  final String sourceId;
  final List<Channel> playlist;
  final int startIndex;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> with RouteAware {
  late final Player _player = Player(
    configuration: PlayerConfiguration(
      title: 'NexoraTV',
      bufferSize:
          ref.read(settingsValueProvider).playerBufferMb.clamp(8, 128) *
              1024 *
              1024,
    ),
  );
  late final VideoController _controller = VideoController(_player);
  final _focusNode = FocusNode();
  final _subs = <StreamSubscription>[];
  AppLifecycleListener? _lifecycle;

  late int _index;
  int? _prevIndex;
  int _retries = 0;
  bool _buffering = true;
  bool _playing = true;
  String? _error;
  bool _controlsVisible = true;
  bool _isFullscreen = false;
  bool _pip = false;
  Rect? _prevBounds;
  Timer? _hideTimer;
  Timer? _progressTimer;
  Timer? _numberTimer;
  Timer? _retryTimer;

  int? _resumeMs;
  String _numberInput = '';
  Tracks _tracks = const Tracks();

  Channel get _current => widget.playlist[_index];
  bool get _isVod => _current.kind != MediaKind.live;
  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex.clamp(0, widget.playlist.length - 1);
    if (ref.read(settingsValueProvider).keepScreenAwake) WakelockPlus.enable();

    // Protection multi-écran : pause quand l'app passe en arrière-plan
    // (utile pour les abonnements limités à 1 connexion simultanée).
    _lifecycle = AppLifecycleListener(
      onHide: _pauseForBackground,
      onPause: _pauseForBackground,
    );

    _subs.add(_player.stream.buffering.listen((v) {
      if (mounted) setState(() => _buffering = v);
    }));
    _subs.add(_player.stream.playing.listen((v) {
      if (mounted) setState(() => _playing = v);
    }));
    _subs.add(_player.stream.error.listen((e) {
      if (!mounted) return;
      // Flux mort : tentatives silencieuses (dont un essai en .m3u8 / .ts)
      // avant d'afficher l'erreur.
      if (!_isVod && _retries < 3) {
        _retries++;
        setState(() => _buffering = true);
        _retryTimer?.cancel();
        _retryTimer = Timer(Duration(seconds: _retries * 2), () {
          if (mounted) _player.open(Media(_urlForRetry()));
        });
      } else {
        setState(() => _error = e);
      }
    }));
    _subs.add(_player.stream.tracks.listen((t) {
      if (mounted) setState(() => _tracks = t);
    }));
    _subs.add(_player.stream.completed.listen((done) {
      // Fin d'un épisode de série -> enchaîne automatiquement.
      if (done &&
          _current.kind == MediaKind.series &&
          _index < widget.playlist.length - 1) {
        _zap(1);
      }
    }));
    _subs.add(_player.stream.duration.listen((d) {
      final target = _resumeMs;
      if (target != null && d.inMilliseconds > target + 3000) {
        _resumeMs = null;
        _player.seek(Duration(milliseconds: target));
      }
    }));

    _progressTimer = Timer.periodic(
        const Duration(seconds: 10), (_) => _saveProgress());

    _openCurrent();
    _scheduleHide();
  }

  /// Sur la 2ᵉ tentative d'une chaîne live, on inverse .ts <-> .m3u8
  /// (certains flux ne marchent que dans un format).
  String _urlForRetry() {
    final u = _current.url;
    if (_retries != 2 || _isVod) return u;
    if (u.endsWith('.ts')) return '${u.substring(0, u.length - 3)}.m3u8';
    if (u.endsWith('.m3u8')) return '${u.substring(0, u.length - 5)}.ts';
    return u;
  }

  Future<void> _openCurrent() async {
    _retries = 0;
    _retryTimer?.cancel();
    setState(() {
      _error = null;
      _buffering = true;
      _numberInput = '';
    });
    ref
        .read(sourceRepositoryProvider)
        .saveLastChannel(widget.sourceId, _current.id);
    _resumeMs = _isVod
        ? ref
            .read(watchHistoryProvider.notifier)
            .resumePositionMs(widget.sourceId, _current.id)
        : null;
    // Coupe complètement le flux précédent avant d'ouvrir le nouveau : sinon
    // sur Android l'audio de l'ancienne chaîne/film continue par-dessus.
    await _player.stop();
    if (!mounted) return;
    await _player.open(Media(_current.url));
  }

  void _saveProgress() {
    if (!mounted) return;
    final pos = _player.state.position.inMilliseconds;
    final dur = _player.state.duration.inMilliseconds;
    if (pos < 3000 && !_isVod) return; // live : garde juste "récemment vu"
    ref.read(watchHistoryProvider.notifier).record(
          sourceId: widget.sourceId,
          channel: _current,
          positionMs: _isVod ? pos : 0,
          durationMs: _isVod ? dur : 0,
        );
  }

  void _zap(int delta) {
    if (widget.playlist.length < 2) return;
    _saveProgress();
    setState(() {
      _prevIndex = _index;
      _index = (_index + delta) % widget.playlist.length;
      if (_index < 0) _index += widget.playlist.length;
    });
    _openCurrent();
    _showControls();
  }

  void _lastChannel() {
    final p = _prevIndex;
    if (p == null || p == _index) return;
    _saveProgress();
    setState(() {
      _prevIndex = _index;
      _index = p;
    });
    _openCurrent();
    _showControls();
  }

  void _jumpToNumber() {
    final n = int.tryParse(_numberInput);
    setState(() => _numberInput = '');
    if (n == null) return;
    var target = widget.playlist.indexWhere((c) => c.number == n);
    if (target < 0 && n >= 1 && n <= widget.playlist.length) target = n - 1;
    if (target >= 0 && target != _index) {
      _saveProgress();
      setState(() => _index = target);
      _openCurrent();
    }
  }

  void _showControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _playing && _error == null) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  Future<void> _toggleFullscreen() async {
    if (!_isDesktop || _pip) return;
    final next = !_isFullscreen;
    await windowManager.setFullScreen(next);
    if (mounted) setState(() => _isFullscreen = next);
  }

  /// Mode « mini-lecteur » : petite fenêtre toujours au premier plan.
  Future<void> _togglePip() async {
    if (!_isDesktop) return;
    final next = !_pip;
    if (next) {
      _prevBounds = await windowManager.getBounds();
      if (_isFullscreen) {
        await windowManager.setFullScreen(false);
        _isFullscreen = false;
      }
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setMinimumSize(const Size(320, 180));
      await windowManager.setSize(const Size(440, 248));
      await windowManager.setAlignment(Alignment.bottomRight);
    } else {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setMinimumSize(const Size(900, 560));
      if (_prevBounds != null) await windowManager.setBounds(_prevBounds!);
    }
    if (mounted) setState(() => _pip = next);
  }

  Future<void> _restoreWindow() async {
    if (_isFullscreen) await windowManager.setFullScreen(false);
    if (_pip) {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setMinimumSize(const Size(900, 560));
      if (_prevBounds != null) await windowManager.setBounds(_prevBounds!);
    }
  }

  bool _exiting = false;

  Future<void> _exit() async {
    if (_exiting) return;
    _exiting = true;
    _saveProgress();
    // Stoppe la lecture AVANT de fermer l'écran : `dispose()` seul laisse
    // parfois l'audio tourner un moment sur Android.
    try {
      await _player.stop();
    } catch (_) {}
    await _restoreWindow();
    if (mounted) Navigator.of(context).pop();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final digit = _digit(key);
    if (digit != null) {
      _numberInput = (_numberInput + digit).substring(
          0, (_numberInput.length + 1).clamp(0, 4));
      setState(() {});
      _numberTimer?.cancel();
      _numberTimer = Timer(const Duration(milliseconds: 1300), _jumpToNumber);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.channelUp) {
      _zap(-1);
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.channelDown) {
      _zap(1);
    } else if (key == LogicalKeyboardKey.arrowRight && _isVod) {
      _player.seek(_player.state.position + const Duration(seconds: 10));
      _showControls();
    } else if (key == LogicalKeyboardKey.arrowLeft && _isVod) {
      _player.seek(_player.state.position - const Duration(seconds: 10));
      _showControls();
    } else if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      _player.playOrPause();
      _showControls();
    } else if (key == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
    } else if (key == LogicalKeyboardKey.keyP) {
      _togglePip();
    } else if (key == LogicalKeyboardKey.keyL ||
        key == LogicalKeyboardKey.backquote) {
      _lastChannel();
    } else if (key == LogicalKeyboardKey.enter && _numberInput.isNotEmpty) {
      _numberTimer?.cancel();
      _jumpToNumber();
    } else if (key == LogicalKeyboardKey.escape) {
      _isFullscreen ? _toggleFullscreen() : _exit();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  static String? _digit(LogicalKeyboardKey k) {
    final label = k.keyLabel;
    if (label.length == 1) {
      final c = label.codeUnitAt(0);
      if (c >= 0x30 && c <= 0x39) return label; // '0'..'9'
    }
    return null;
  }

  void _openTracksSheet() {
    _showControls();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14151A),
      builder: (_) => _TracksSheet(
        tracks: _tracks,
        current: _player.state.track,
        rate: _player.state.rate,
        showSpeed: _isVod,
        onAudio: (t) => _player.setAudioTrack(t),
        onSubtitle: (t) => _player.setSubtitleTrack(t),
        onRate: (r) => _player.setRate(r),
      ),
    );
  }

  void _pauseForBackground() {
    if (!mounted) return;
    if (ref.read(settingsValueProvider).pauseOnBackground && _playing) {
      _player.pause();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  /// Un autre écran vient de passer par-dessus le lecteur : on coupe le son
  /// pour ne pas entendre deux flux à la fois.
  @override
  void didPushNext() {
    if (mounted) _player.pause();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _lifecycle?.dispose();
    _saveProgress();
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _numberTimer?.cancel();
    _retryTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _focusNode.dispose();
    // Coupe le son immédiatement, puis libère le lecteur (dispose est async).
    try {
      _player.pause();
    } catch (_) {}
    _player.dispose();
    WakelockPlus.disable();
    _restoreWindow();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var subtitle = '${_index + 1} / ${widget.playlist.length}'
        '${_current.group == null ? '' : '  ·  ${_current.group}'}';
    if (_current.kind == MediaKind.live && _current.streamId != null) {
      final epg = ref.watch(shortEpgProvider(_current.streamId)).value ??
          const [];
      final now = currentProgram(epg);
      if (now != null) subtitle = '▶ ${now.title}';
    }
    final liveHint = _current.kind == MediaKind.live
        ? 'Si un autre appareil regarde déjà, ton abonnement peut être '
            'limité à une seule connexion simultanée.'
        : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _onKey,
          child: MouseRegion(
            onHover: (_) => _showControls(),
            child: GestureDetector(
              onTap: () => _controlsVisible
                  ? setState(() => _controlsVisible = false)
                  : _showControls(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Video(
                    controller: _controller,
                    controls: NoVideoControls,
                    fit: BoxFit.contain,
                    subtitleViewConfiguration: SubtitleViewConfiguration(
                      style: TextStyle(
                        fontSize: 32 *
                            ref.watch(settingsValueProvider).subtitleScale,
                        height: 1.4,
                        color: Colors.white,
                        backgroundColor: Colors.black54,
                      ),
                    ),
                  ),
                  if (_buffering && _error == null)
                    const Center(child: CircularProgressIndicator()),
                  if (_error != null)
                    _ErrorOverlay(
                      message: _error!,
                      hint: liveHint,
                      onRetry: _openCurrent,
                    ),
                  if (_numberInput.isNotEmpty)
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: const EdgeInsets.only(top: 60),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_numberInput,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  if (_pip)
                    Align(
                      alignment: Alignment.topRight,
                      child: IgnorePointer(
                        ignoring: !_controlsVisible,
                        child: AnimatedOpacity(
                          opacity: _controlsVisible ? 1 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close_fullscreen,
                                    color: Colors.white),
                                onPressed: _togglePip,
                              ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                                onPressed: _exit,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    _ControlsBar(
                      visible: _controlsVisible,
                      player: _player,
                      title: _current.name,
                      subtitle: subtitle,
                      playing: _playing,
                      isVod: _isVod,
                      isFullscreen: _isFullscreen,
                      showFullscreen: _isDesktop,
                      showPip: _isDesktop,
                      canZap: widget.playlist.length > 1,
                      hasTracks: _isVod ||
                          _tracks.audio.length > 2 ||
                          _tracks.subtitle.length > 2,
                      onBack: _exit,
                      onPlayPause: () {
                        _player.playOrPause();
                        _showControls();
                      },
                      onPrev: () => _zap(-1),
                      onNext: () => _zap(1),
                      onFullscreen: _toggleFullscreen,
                      onPip: _togglePip,
                      onTracks: _openTracksSheet,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne de progression VOD (position — barre — durée), intégrée à la barre
/// de commandes du bas.
class _SeekRow extends StatelessWidget {
  const _SeekRow({required this.player});
  final Player player;

  static String _fmt(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
      child: StreamBuilder<Duration>(
        stream: player.stream.position,
        builder: (context, posSnap) {
          final pos = posSnap.data ?? Duration.zero;
          final dur = player.state.duration;
          final max = dur.inMilliseconds.toDouble();
          return Row(
            children: [
              Text(_fmt(pos),
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: max <= 0
                      ? 0
                      : pos.inMilliseconds
                          .clamp(0, max.toInt())
                          .toDouble(),
                  max: max <= 0 ? 1 : max,
                  onChanged: (v) =>
                      player.seek(Duration(milliseconds: v.toInt())),
                ),
              ),
              Text(_fmt(dur),
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          );
        },
      ),
    );
  }
}

class _TracksSheet extends StatelessWidget {
  const _TracksSheet({
    required this.tracks,
    required this.current,
    required this.onAudio,
    required this.onSubtitle,
    required this.rate,
    required this.showSpeed,
    required this.onRate,
  });

  final Tracks tracks;
  final Track current;
  final double rate;
  final bool showSpeed;
  final void Function(AudioTrack) onAudio;
  final void Function(SubtitleTrack) onSubtitle;
  final void Function(double) onRate;

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          if (showSpeed) ...[
            const _SheetHeader('Vitesse de lecture'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final s in _speeds)
                    ChoiceChip(
                      label: Text(s == 1.0 ? 'Normal' : '$s×'),
                      selected: (rate - s).abs() < 0.01,
                      onSelected: (_) {
                        onRate(s);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ),
          ],
          if (tracks.audio.length > 1) ...[
            const _SheetHeader('Piste audio'),
            for (final a in tracks.audio)
              ListTile(
                dense: true,
                leading: Icon(a.id == current.audio.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked),
                title: Text(_label(a.title, a.language, a.id)),
                onTap: () {
                  onAudio(a);
                  Navigator.pop(context);
                },
              ),
          ],
          if (tracks.subtitle.length > 1) ...[
            const _SheetHeader('Sous-titres'),
            for (final s in tracks.subtitle)
              ListTile(
                dense: true,
                leading: Icon(s.id == current.subtitle.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked),
                title: Text(_label(s.title, s.language, s.id)),
                onTap: () {
                  onSubtitle(s);
                  Navigator.pop(context);
                },
              ),
          ],
        ],
      ),
    );
  }

  String _label(String? title, String? lang, String id) {
    if (id == 'no') return 'Aucun';
    if (id == 'auto') return 'Automatique';
    final parts = [
      if (title != null && title.isNotEmpty) title,
      if (lang != null && lang.isNotEmpty && lang != title) lang,
    ];
    return parts.isEmpty ? 'Piste $id' : parts.join(' · ');
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: .8,
                color: Colors.white70)),
      );
}

class _ControlsBar extends StatelessWidget {
  const _ControlsBar({
    required this.visible,
    required this.player,
    required this.title,
    required this.subtitle,
    required this.playing,
    required this.isVod,
    required this.isFullscreen,
    required this.showFullscreen,
    required this.canZap,
    required this.hasTracks,
    required this.showPip,
    required this.onBack,
    required this.onPlayPause,
    required this.onPrev,
    required this.onNext,
    required this.onFullscreen,
    required this.onPip,
    required this.onTracks,
  });

  final bool visible;
  final Player player;
  final String title;
  final String subtitle;
  final bool playing;
  final bool isVod;
  final bool isFullscreen;
  final bool showFullscreen;
  final bool showPip;
  final bool canZap;
  final bool hasTracks;
  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onFullscreen;
  final VoidCallback onPip;
  final VoidCallback onTracks;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Column(
          children: [
            _bar(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              topInset: true,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: onBack,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(subtitle,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (showPip)
                    IconButton(
                      tooltip: 'Mini-lecteur (P)',
                      icon: const Icon(Icons.picture_in_picture_alt,
                          color: Colors.white),
                      onPressed: onPip,
                    ),
                  if (hasTracks)
                    IconButton(
                      tooltip: 'Pistes / vitesse',
                      icon: const Icon(Icons.tune, color: Colors.white),
                      onPressed: onTracks,
                    ),
                ],
              ),
            ),
            const Spacer(),
            _bar(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              bottomInset: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isVod) _SeekRow(player: player),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: canZap ? 'Précédent (↑)' : null,
                        icon: const Icon(Icons.skip_previous,
                            color: Colors.white),
                        onPressed: canZap ? onPrev : null,
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                        onPressed: onPlayPause,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: canZap ? 'Suivant (↓)' : null,
                        icon: const Icon(Icons.skip_next, color: Colors.white),
                        onPressed: canZap ? onNext : null,
                      ),
                      if (showFullscreen) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Plein écran (F)',
                          icon: Icon(
                            isFullscreen
                                ? Icons.fullscreen_exit
                                : Icons.fullscreen,
                            color: Colors.white,
                          ),
                          onPressed: onFullscreen,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar({
    required Alignment begin,
    required Alignment end,
    required Widget child,
    bool topInset = false,
    bool bottomInset = false,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: begin,
            end: end,
            colors: [Colors.black.withValues(alpha: .6), Colors.transparent],
          ),
        ),
        child: SafeArea(
          top: topInset,
          bottom: bottomInset,
          child: child,
        ),
      );
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.message, required this.onRetry, this.hint});
  final String message;
  final String? hint;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, color: Colors.white, size: 44),
          const SizedBox(height: 12),
          const Text('Lecture impossible',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 4),
          Text(message,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center),
          if (hint != null) ...[
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(hint!,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
