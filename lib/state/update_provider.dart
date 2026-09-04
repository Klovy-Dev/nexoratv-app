import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/update_service.dart';
import 'settings_provider.dart';

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());

/// Vérification unique au démarrage (respecte le réglage `checkUpdatesOnStart`).
final startupUpdateCheckProvider = FutureProvider<UpdateInfo?>((ref) async {
  final settings = await ref.watch(settingsProvider.future);
  if (!settings.checkUpdatesOnStart) return null;
  return ref.read(updateServiceProvider).check(settings.updateManifestUrl);
});

/// Vérification manuelle (bouton dans les paramètres).
final manualUpdateCheckProvider =
    FutureProvider.autoDispose<UpdateInfo?>((ref) async {
  final settings = ref.read(settingsValueProvider);
  return ref.read(updateServiceProvider).check(settings.updateManifestUrl);
});
