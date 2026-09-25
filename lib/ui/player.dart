import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'theme.dart';

/// Lecteur partagé : gros tampon pour encaisser les à-coups des serveurs IPTV.
Player createPlayer() => Player(
      configuration: const PlayerConfiguration(bufferSize: 64 * 1024 * 1024, title: 'NexoraTV'),
    );

/// Contrôles desktop aux couleurs NexoraTV.
MaterialDesktopVideoControlsThemeData playerControlsTheme({
  List<Widget> topButtonBar = const [],
  List<Widget>? bottomButtonBar,
  bool seekBar = true,
  Map<ShortcutActivator, VoidCallback>? shortcuts,
}) =>
    MaterialDesktopVideoControlsThemeData(
      displaySeekBar: seekBar,
      seekBarPositionColor: Nx.accent,
      seekBarThumbColor: Nx.accent,
      volumeBarActiveColor: Nx.accent,
      volumeBarThumbColor: Nx.accent,
      hideMouseOnControlsRemoval: true,
      keyboardShortcuts: shortcuts,
      topButtonBar: topButtonBar,
      bottomButtonBar: bottomButtonBar ??
          const [
            MaterialDesktopSkipPreviousButton(),
            MaterialDesktopPlayOrPauseButton(),
            MaterialDesktopSkipNextButton(),
            MaterialDesktopVolumeButton(),
            MaterialDesktopPositionIndicator(),
            Spacer(),
            MaterialDesktopFullscreenButton(),
          ],
      bufferingIndicatorBuilder: (_) => const CircularProgressIndicator(color: Nx.accent, strokeWidth: 3),
    );

class PlayItem {
  const PlayItem(this.title, this.url);
  final String title;
  final String url;
}

/// Lecture d'un film ou d'une suite d'épisodes (passage automatique au
/// suivant, boutons précédent / suivant).
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.items, this.index = 0});

  final List<PlayItem> items;
  final int index;

  static Future<void> open(BuildContext context, List<PlayItem> items, {int index = 0}) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerPage(items: items, index: index)));

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player _player = createPlayer();
  late final VideoController _controller = VideoController(_player);
  late int _index = widget.index;
  final _subs = <StreamSubscription<Object?>>[];

  @override
  void initState() {
    super.initState();
    _subs
      ..add(_player.stream.playlist.listen((p) {
        if (mounted && p.index != _index) setState(() => _index = p.index);
      }))
      ..add(_player.stream.error.listen((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lecture impossible pour le moment. Réessayez dans un instant.')),
        );
      }));
    _player.open(Playlist([for (final i in widget.items) Media(i.url)], index: widget.index));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
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
        style: const TextStyle(fontFamily: Nx.display, fontSize: 18, fontWeight: FontWeight.w600),
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
        fullscreen: playerControlsTheme(bottomButtonBar: bottom, topButtonBar: [titleText]),
        child: Video(controller: _controller),
      ),
    );
  }
}
