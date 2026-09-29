import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'state/app_state.dart';
import 'state/settings.dart';
import 'ui/onboarding.dart';
import 'ui/shell.dart';
import 'ui/splash.dart';
import 'ui/theme.dart';
import 'ui/title_bar.dart';
import 'ui/update_dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await setupWindow();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      // Pas de nouvelle tentative automatique des chargements en erreur : les
      // écrans proposent un bouton « Réessayer ».
      retry: (_, _) => null,
      child: const NexoraApp(),
    ),
  );
}

class NexoraApp extends StatelessWidget {
  const NexoraApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'NexoraTV',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    builder: withTitleBar,
    home: const _Root(),
  );
}

class _Root extends ConsumerStatefulWidget {
  const _Root();

  @override
  ConsumerState<_Root> createState() => _RootState();
}

class _RootState extends ConsumerState<_Root> {
  /// Vrai une fois l'écran de chargement terminé (compte + catalogue).
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final Widget screen;
    if (!_loaded) {
      screen = SplashScreen(
        onDone: () {
          setState(() => _loaded = true);
          // Nouvelle version sur GitHub ? Proposée une fois l'accueil affiché.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) checkForUpdate(context, silent: true);
          });
        },
      );
    } else if (!app.loggedIn && app.sources.isEmpty) {
      screen = const WelcomeScreen();
    } else {
      screen = const AppShell();
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: screen,
    );
  }
}
