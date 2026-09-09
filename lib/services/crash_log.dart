import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Journal de plantage minimal.
///
/// Capte les **exceptions Dart non gérées** (via [FlutterError.onError] et le
/// handler de `runZonedGuarded`) et les écrit dans `<appSupport>/crash.txt`,
/// consultable dans Paramètres → Diagnostic.
///
/// ⚠️ Ne capte PAS un arrêt natif du process : manque de mémoire (Low Memory
/// Killer d'Android sur Fire TV Stick), SIGSEGV d'un plugin, ANR. Pour ces
/// cas-là il faut le `adb logcat` de l'appareil.
class CrashLog {
  CrashLog._();

  static File? _file;

  static Future<void> init() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}${Platform.pathSeparator}crash.txt');
    } catch (_) {}

    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      previous?.call(details);
      _write('flutter', details.exceptionAsString(), details.stack);
    };
  }

  /// Handler à passer à `runZonedGuarded`.
  static void onZoneError(Object error, StackTrace stack) =>
      _write('zone', '$error', stack);

  static void _write(String kind, String error, StackTrace? stack) {
    final f = _file;
    if (f == null) return;
    try {
      f.writeAsStringSync(
        '${DateTime.now().toIso8601String()} [$kind] '
        '${Platform.operatingSystem} ${Platform.operatingSystemVersion}\n'
        '$error\n$stack\n\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }

  static Future<String?> lastReport() async {
    try {
      final f = _file ??
          File('${(await getApplicationSupportDirectory()).path}'
              '${Platform.pathSeparator}crash.txt');
      if (!f.existsSync()) return null;
      final txt = (await f.readAsString()).trim();
      return txt.isEmpty ? null : txt;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final f = _file;
      if (f != null && f.existsSync()) await f.delete();
    } catch (_) {}
  }
}
