import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/net_config.dart';
import '../services/storage/settings_repository.dart';
import 'providers.dart';

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final s = await ref.watch(settingsRepositoryProvider).load();
    runtimeUserAgent = s.effectiveUserAgent;
    return s;
  }

  Future<void> patch(AppSettings Function(AppSettings) mutate) async {
    final next = mutate(state.value ?? const AppSettings());
    state = AsyncData(next);
    runtimeUserAgent = next.effectiveUserAgent;
    await ref.read(settingsRepositoryProvider).save(next);
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

/// Accès synchrone avec valeurs par défaut (pour la logique non-UI).
final settingsValueProvider = Provider<AppSettings>(
  (ref) => ref.watch(settingsProvider).value ?? const AppSettings(),
);
