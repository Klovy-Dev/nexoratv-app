import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../state/library.dart';
import '../state/settings.dart';
import 'theme.dart';
import 'title_bar.dart';
import 'widgets.dart';

/// Lecteur partagé, réglé selon les paramètres (tampon, décodage matériel).
(Player, VideoController) createPlayer(Settings settings) {
  final player = Player(
    configuration: PlayerConfiguration(
      bufferSize: settings.bufferMb * 1024 * 1024,
      title: 'NexoraTV',
    ),
  );
  final controller = VideoController(
    player,
    configuration: VideoControllerConfiguration(
      enableHardwareAcceleration: settings.hardwareDecoding,
    ),
  );
  return (player, controller);
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
