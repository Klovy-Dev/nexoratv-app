import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'features/home/home_screen.dart';
import 'services/data_migration.dart';
import 'services/single_instance.dart';
import 'state/settings_provider.dart';
import 'theme.dart';
import 'widgets/nav.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // Catalogues avec des milliers de jaquettes : on borne le cache image.
  PaintingBinding.instance.imageCache
    ..maximumSize = 600
    ..maximumSizeBytes = 220 << 20; // ~220 Mo

  final isDesktop =
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  // Renommage iptv_player -> NexoraTV : recopie unique de l'ancien profil.
  await DataMigration.runIfNeeded();

  if (isDesktop) {
    await windowManager.ensureInitialized();
    // Une seule fenêtre à la fois (abonnements souvent limités à 1 connexion).
    if (!await SingleInstance.acquire()) {
      exit(0);
    }
  }

  MediaKit.ensureInitialized();

  if (isDesktop) {
    const options = WindowOptions(
      size: Size(1180, 760),
      minimumSize: Size(900, 560),
      center: true,
      title: 'NexoraTV',
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const ProviderScope(child: NexoraApp()));
}

class NexoraApp extends ConsumerWidget {
  const NexoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsProvider).value?.themeMode ?? AppThemeMode.dark;
    return MaterialApp(
      title: 'NexoraTV',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(mode),
      navigatorObservers: [routeObserver],
      home: const _SplashGate(child: HomeScreen()),
    );
  }
}

/// Retire l'écran de démarrage natif une fois la première frame rendue.
class _SplashGate extends StatefulWidget {
  const _SplashGate({required this.child});
  final Widget child;

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
