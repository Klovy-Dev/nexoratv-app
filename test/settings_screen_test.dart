import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexoratv/state/settings.dart';
import 'package:nexoratv/ui/settings_screen.dart';
import 'package:nexoratv/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('chaque onglet des paramètres s’affiche sans erreur', (tester) async {
    tester.view.physicalSize = const Size(1536, 816);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    for (final tab in [SettingsTab.playback, SettingsTab.storage, SettingsTab.about]) {
      await tester.pumpWidget(ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: MaterialApp(theme: buildTheme(), home: SettingsScreen(initialTab: tab)),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab.label);
      expect(find.text(tab.label), findsWidgets);
    }
  });

  testWidgets('les réglages de lecture sont enregistrés', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);

    container.read(settingsProvider.notifier)
      ..setLiveFormat(LiveFormat.hls)
      ..setBufferMb(128)
      ..setHardwareDecoding(false);

    expect(prefs.getString('live_format'), 'hls');
    expect(prefs.getInt('buffer_mb'), 128);
    expect(prefs.getBool('hardware_decoding'), false);
  });
}
