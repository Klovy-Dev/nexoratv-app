import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'state/app_state.dart';
import 'state/settings.dart';
import 'ui/home_screen.dart';
import 'ui/onboarding.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    // Pas de nouvelle tentative automatique des chargements en erreur : les
    // écrans proposent un bouton « Réessayer ».
    retry: (_, _) => null,
    child: const NexoraApp(),
  ));
}

class NexoraApp extends StatelessWidget {
  const NexoraApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'NexoraTV',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const _Root(),
      );
}

class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    if (!app.ready) {
      return const Scaffold(body: Center(child: Brand(size: 34)));
    }
    if (!app.loggedIn && app.sources.isEmpty) return const WelcomeScreen();
    return const HomeScreen();
  }
}
