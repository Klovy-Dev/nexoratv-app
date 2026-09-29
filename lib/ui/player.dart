import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../state/library.dart';
import '../state/settings.dart';
import 'library_widgets.dart';
import 'theme.dart';
import 'title_bar.dart';
import 'tv_text_field.dart';
import 'widgets.dart';

/// Télé (Android) : commandes à la télécommande au lieu des commandes
/// tactiles de media_kit.
final _tv = Platform.isAndroid;

/// Lecteur partagé, réglé selon les paramètres (tampon, décodage matériel).
(Player, VideoController) createPlayer(Settings settings) {
  final player = Player(
    configuration: PlayerConfiguration(
      bufferSize: settings.bufferMb * 1024 * 1024,
      title: 'NexoraTV',
    ),
  );
  _tuneNative(player);
  final controller = VideoController(
    player,
    configuration: VideoControllerConfiguration(
      enableHardwareAcceleration: settings.hardwareDecoding,
      // Fire TV Stick / box : MediaCodec, le processeur ne suit pas une
      // chaîne FHD en logiciel (image au ralenti). « auto-safe », le défaut
      // de media_kit, ne le choisit pas toujours.
      hwdec: Platform.isAndroid
          ? (settings.hardwareDecoding ? 'mediacodec-copy' : 'no')
          : null,
    ),
  );
  return (player, controller);
}

/// Réglages libmpv que media_kit ne met pas par défaut (repris de la 1.x,
/// validés sur Fire TV Stick) : gros cache, reconnexion HTTP, et sur Android
/// des images sautées plutôt qu'une vidéo qui prend du retard.
void _tuneNative(Player player) {
  final native = player.platform;
  if (native is! NativePlayer) return;
  final props = <String, String>{
    // Lecture ~30 s d'avance : encaisse les à-coups réseau et les serveurs
    // qui limitent le débit.
    'cache': 'yes',
    'cache-secs': '30',
    'demuxer-readahead-secs': '30',
    // En manque de données : courte pause le temps de refaire 2 s de réserve,
    // plutôt qu'un hoquet permanent.
    'cache-pause': 'yes',
    'cache-pause-wait': '2',
    'cache-pause-initial': 'yes',
    // FFmpeg se reconnecte tout seul quand le flux HTTP décroche.
    'stream-lavf-o':
        'reconnect=1,reconnect_at_eof=1,reconnect_streamed=1,'
        'reconnect_on_network_error=1,reconnect_delay_max=5',
    if (Platform.isAndroid) ...{
      'framedrop': 'vo',
      'vd-lavc-fast': 'yes',
      'vd-lavc-skiploopfilter': 'nonkey',
    },
  };
  for (final e in props.entries) {
    unawaited(native.setProperty(e.key, e.value));
  }
}

/// URL d'une chaîne selon le format choisi (Xtream : .ts ↔ .m3u8).
String liveUrl(String url, LiveFormat format) {
  if (format == LiveFormat.hls &&
      url.contains('/live/') &&
      url.endsWith('.ts')) {
    return '${url.substring(0, url.length - 3)}.m3u8';
  }
  return url;
}

/// Contrôles desktop aux couleurs NexoraTV.
MaterialDesktopVideoControlsThemeData playerControlsTheme({
  List<Widget> topButtonBar = const [],
  List<Widget>? bottomButtonBar,
  bool seekBar = true,
  Map<ShortcutActivator, VoidCallback>? shortcuts,
}) => MaterialDesktopVideoControlsThemeData(
  displaySeekBar: seekBar,
  seekBarPositionColor: Nx.accent,
  seekBarThumbColor: Nx.accent,
  volumeBarActiveColor: Nx.accent,
  volumeBarThumbColor: Nx.accent,
  hideMouseOnControlsRemoval: true,
  keyboardShortcuts: shortcuts,
  topButtonBar: topButtonBar,
  bottomButtonBar:
      bottomButtonBar ??
      const [
        MaterialDesktopSkipPreviousButton(),
        MaterialDesktopPlayOrPauseButton(),
        MaterialDesktopSkipNextButton(),
        MaterialDesktopVolumeButton(),
        MaterialDesktopPositionIndicator(),
        Spacer(),
        MaterialDesktopFullscreenButton(),
      ],
  bufferingIndicatorBuilder: (_) =>
      const CircularProgressIndicator(color: Nx.accent, strokeWidth: 3),
);

class PlayItem {
  const PlayItem(
    this.title,
    this.url, {
    this.kind,
    this.id,
    this.image,
    this.seriesId,
  });

  final String title;
  final String url;

  /// Film ou épisode : sert à la reprise de lecture (null = pas de suivi).
  final MediaKind? kind;
  final String? id;
  final String? image;
  final String? seriesId;
}

/// Lecture d'un film ou d'une suite d'épisodes (passage automatique au
/// suivant, boutons précédent / suivant).
class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key, required this.items, this.index = 0});

  final List<PlayItem> items;
  final int index;

  static Future<void> open(
    BuildContext context,
    List<PlayItem> items, {
    int index = 0,
  }) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PlayerPage(items: items, index: index),
    ),
  );

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  late final (Player, VideoController) _pc = createPlayer(
    ref.read(settingsProvider),
  );
  Player get _player => _pc.$1;
  VideoController get _controller => _pc.$2;
  late int _index = widget.index;
  final _subs = <StreamSubscription<Object?>>[];

  /// Lu une fois : `ref` n'est plus utilisable dans dispose().
  late final LibraryController _library = ref.read(libraryProvider.notifier);
  Timer? _saveTimer;

  /// Position où reprendre dès que la durée du média est connue.
  Duration? _pendingSeek;
  Duration _position = Duration.zero;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _pendingSeek = _resumeAt(_index);
    _subs
      ..add(
        _player.stream.playlist.listen((p) {
          if (!mounted || p.index == _index) return;
          _saveProgress(); // l'épisode qu'on quitte
          setState(() => _index = p.index);
          _position = Duration.zero;
          _pendingSeek = _resumeAt(p.index);
        }),
      )
      ..add(
        _player.stream.duration.listen((d) {
          final seek = _pendingSeek;
          if (d > Duration.zero && seek != null && seek < d) {
            _pendingSeek = null;
            _player.seek(seek);
          }
        }),
      )
      ..add(_player.stream.position.listen((p) => _position = p))
      ..add(
        // Un seul écran d'erreur (media_kit peut en signaler plusieurs
        // d'affilée pour une même coupure).
        _player.stream.error.listen((_) {
          if (mounted && !_failed) setState(() => _failed = true);
        }),
      );
    _open();
    _saveTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _saveProgress(),
    );
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveProgress();
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  void _open() => _player.open(
    Playlist([for (final i in widget.items) Media(i.url)], index: _index),
  );

  Duration? _resumeAt(int index) {
    final item = widget.items[index];
    if (item.kind == null || item.id == null) return null;
    return ref
        .read(libraryProvider)
        .progressFor(item.kind!, item.id!)
        ?.position;
  }

  void _saveProgress() {
    final item = widget.items[_index.clamp(0, widget.items.length - 1)];
    final duration = _player.state.duration;
    if (item.kind == null || item.id == null || _failed) return;
    _library.saveProgress(
      WatchProgress(
        kind: item.kind!,
        id: item.id!,
        title: item.title,
        image: item.image,
        seriesId: item.seriesId,
        position: _position,
        duration: duration,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Relance le média en cours là où il s'est interrompu.
  void _retry() {
    setState(() => _failed = false);
    _pendingSeek = _position > const Duration(seconds: 5) ? _position : null;
    _open();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.items[_index.clamp(0, widget.items.length - 1)].title;
    final single = widget.items.length == 1;
    final bottom = single
        ? const [
            MaterialDesktopPlayOrPauseButton(),
            MaterialDesktopVolumeButton(),
            MaterialDesktopPositionIndicator(),
            Spacer(),
            MaterialDesktopFullscreenButton(),
          ]
        : null;
    final titleText = Flexible(
      child: Text(
        title,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: Nx.display,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: MaterialDesktopVideoControlsTheme(
        normal: playerControlsTheme(
          bottomButtonBar: bottom,
          topButtonBar: [
            MaterialDesktopCustomButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 8),
            titleText,
          ],
        ),
        fullscreen: playerControlsTheme(
          bottomButtonBar: bottom,
          topButtonBar: [titleText],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_tv)
              _TvPlaybackControls(
                player: _player,
                title: title,
                enabled: !_failed,
                child: Video(
                  controller: _controller,
                  controls: NoVideoControls,
                ),
              )
            else
              Video(
                controller: _controller,
                onEnterFullscreen: enterVideoFullscreen,
                onExitFullscreen: exitVideoFullscreen,
              ),
            if (_failed)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.8),
                child: MessageView(
                  icon: Icons
                      .signal_wifi_statusbar_connected_no_internet_4_rounded,
                  title: 'Lecture interrompue',
                  message: 'Le serveur ne répond pas pour le moment. La lecture reprendra là où elle s’est arrêtée.',
                  action: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Retour'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        autofocus: true,
                        onPressed: _retry,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Films et épisodes à la télécommande : OK ou Lecture/Pause, ← → pour
/// reculer / avancer de 10 s (maintenir pour aller plus loin), CH+ CH− pour
/// l'épisode précédent / suivant, Retour pour quitter.
class _TvPlaybackControls extends StatefulWidget {
  const _TvPlaybackControls({
    required this.player,
    required this.title,
    required this.enabled,
    required this.child,
  });

  final Player player;
  final String title;

  /// Faux pendant l'écran d'erreur (ses boutons reçoivent les touches).
  final bool enabled;
  final Widget child;

  @override
  State<_TvPlaybackControls> createState() => _TvPlaybackControlsState();
}

class _TvPlaybackControlsState extends State<_TvPlaybackControls> {
  final _node = FocusNode(debugLabel: 'tv-player');
  bool _visible = true;
  Timer? _hide;
  StreamSubscription<bool>? _playing;

  @override
  void initState() {
    super.initState();
    // En pause, la barre reste affichée.
    _playing = widget.player.stream.playing.listen((playing) {
      if (!mounted) return;
      if (playing) {
        _scheduleHide();
      } else {
        _hide?.cancel();
        setState(() => _visible = true);
      }
    });
    _scheduleHide();
  }

  @override
  void didUpdateWidget(_TvPlaybackControls old) {
    super.didUpdateWidget(old);
    // Retour de l'écran d'erreur : les touches reviennent au lecteur.
    if (widget.enabled && !old.enabled) _node.requestFocus();
  }

  @override
  void dispose() {
    _hide?.cancel();
    _playing?.cancel();
    _node.dispose();
    super.dispose();
  }

  void _show() {
    setState(() => _visible = true);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted && widget.player.state.playing) {
        setState(() => _visible = false);
      }
    });
  }

  void _seek(int seconds) {
    final s = widget.player.state;
    var to = s.position + Duration(seconds: seconds);
    if (to < Duration.zero) to = Duration.zero;
    if (s.duration > Duration.zero && to > s.duration) to = s.duration;
    widget.player.seek(to);
    _show();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (!widget.enabled || e is KeyUpEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.mediaRewind) {
      _seek(-10);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.mediaFastForward) {
      _seek(10);
      return KeyEventResult.handled;
    }
    if (e is KeyRepeatEvent) {
      return tvSelectKeys.contains(k)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (tvSelectKeys.contains(k) ||
        k == LogicalKeyboardKey.mediaPlayPause ||
        k == LogicalKeyboardKey.mediaPlay ||
        k == LogicalKeyboardKey.mediaPause ||
        k == LogicalKeyboardKey.space) {
      widget.player.playOrPause();
      _show();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.mediaTrackNext ||
        k == LogicalKeyboardKey.channelDown) {
      widget.player.next();
      _show();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.mediaTrackPrevious ||
        k == LogicalKeyboardKey.channelUp) {
      widget.player.previous();
      _show();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.info) {
      _show();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _node,
    autofocus: true,
    onKeyEvent: _onKey,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        widget.player.playOrPause();
        _show();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: Nx.fast,
                child: _bar(context),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _bar(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(48, 80, 48, 36),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xE6000000), Color(0x00000000)],
      ),
    ),
    child: StreamBuilder<Duration>(
      stream: widget.player.stream.position,
      builder: (context, _) {
        final s = widget.player.state;
        final total = s.duration;
        final position = s.position;
        final fraction = total.inMilliseconds <= 0
            ? 0.0
            : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
        const time = TextStyle(
          color: Nx.text,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          fontFeatures: [FontFeature.tabularFigures()],
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  s.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Nx.text,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Text(formatPosition(position), style: time),
                const SizedBox(width: 14),
                Expanded(
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 5,
                    color: Nx.accent,
                    backgroundColor: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 14),
                Text(formatPosition(total), style: time),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'OK : pause / lecture   ·   ← → : 10 s en arrière / en avant   ·   Retour : quitter',
              style: TextStyle(color: Nx.muted, fontSize: 13),
            ),
          ],
        );
      },
    ),
  );
}
