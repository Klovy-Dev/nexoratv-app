import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'state/app_state.dart';
import 'ui/onboarding.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  // Pas de nouvelle tentative automatique des chargements en erreur : les
  // écrans proposent un bouton « Réessayer ».
  runApp(ProviderScope(retry: (_, _) => null, child: const NexoraApp()));
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
    return const Shell();
  }
}
