import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import 'theme.dart';
import 'tv_scale.dart';

/// Vrai pendant le plein écran vidéo : la barre de titre se cache.
final videoFullscreen = ValueNotifier<bool>(false);

/// Barre de titre maison seulement sous Windows (Android n'en a pas).
bool get customTitleBar => Platform.isWindows;

/// Remplace la barre de titre Windows par la nôtre. À appeler avant
/// `runApp` : la fenêtre n'est montrée qu'à la première image.
Future<void> setupWindow() async {
  if (!customTitleBar) return;
  await windowManager.ensureInitialized();
  await windowManager.setTitleBarStyle(
    TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );
  await windowManager.setMinimumSize(const Size(1000, 640));
}

/// Plein écran vidéo (à passer à `Video.onEnterFullscreen`).
Future<void> enterVideoFullscreen() async {
  // Une infobulle encore ouverte (bouton plein écran survolé) garderait
  // l'ancienne taille de fenêtre et ferait planter la mise en page.
  Tooltip.dismissAllToolTips();
  videoFullscreen.value = true;
  if (customTitleBar) {
    await windowManager.setFullScreen(true);
  } else {
    await defaultEnterNativeFullscreen();
  }
}

/// Sortie du plein écran vidéo (à passer à `Video.onExitFullscreen`).
Future<void> exitVideoFullscreen() async {
  Tooltip.dismissAllToolTips();
  if (customTitleBar) {
    await windowManager.setFullScreen(false);
  } else {
    await defaultExitNativeFullscreen();
  }
  videoFullscreen.value = false;
}

/// Place la barre de titre au-dessus de toutes les pages
/// (`MaterialApp.builder`), sauf en plein écran vidéo. Sur une télé, met
/// l'appli à l'échelle de la fenêtre Windows ([withTvScale]).
Widget withTitleBar(BuildContext context, Widget? child) {
  final page = child ?? const SizedBox.shrink();
  if (!customTitleBar) return withTvScale(context, page);
  return Column(
    children: [
      ValueListenableBuilder<bool>(
        valueListenable: videoFullscreen,
        builder: (_, fullscreen, _) =>
            fullscreen ? const SizedBox.shrink() : const AppTitleBar(),
      ),
      Expanded(child: page),
    ],
  );
}

class AppTitleBar extends StatefulWidget {
  const AppTitleBar({super.key});

  static const height = 36.0;

  @override
  State<AppTitleBar> createState() => _AppTitleBarState();
}

class _AppTitleBarState extends State<AppTitleBar> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((m) {
      if (mounted) setState(() => _maximized = m);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) => Material(
    color: Nx.bg,
    child: Container(
      height: AppTitleBar.height,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Nx.border)),
      ),
      child: Row(
        children: [
          // Glisser pour déplacer, double-clic pour agrandir / restaurer.
          Expanded(
            child: DragToMoveArea(
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 18,
                      height: 18,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  const SizedBox(width: 9),
                  const Text(
                    'NexoraTV',
                    style: TextStyle(
                      color: Nx.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _CaptionButton(
            icon: Icons.remove_rounded,
            onTap: windowManager.minimize,
          ),
          _CaptionButton(
            icon: _maximized
                ? Icons.filter_none_rounded
                : Icons.crop_square_rounded,
            iconSize: _maximized ? 13 : 15,
            onTap: () => _maximized
                ? windowManager.unmaximize()
                : windowManager.maximize(),
          ),
          _CaptionButton(
            icon: Icons.close_rounded,
            onTap: windowManager.close,
            danger: true,
          ),
        ],
      ),
    ),
  );
}

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    required this.icon,
    required this.onTap,
    this.iconSize = 16,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;

  /// Fermer : fond rouge au survol, comme Windows.
  final bool danger;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 46,
        height: AppTitleBar.height,
        color: _hover
            ? (widget.danger
                  ? const Color(0xFFE81123)
                  : Colors.white.withValues(alpha: 0.08))
            : Colors.transparent,
        child: Icon(
          widget.icon,
          size: widget.iconSize,
          color: _hover ? Nx.text : Nx.muted,
        ),
      ),
    ),
  );
}
