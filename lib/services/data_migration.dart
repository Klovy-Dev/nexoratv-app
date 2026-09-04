import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Migration unique des données locales.
///
/// L'app s'est d'abord appelée `iptv_player` (identifiant Windows
/// `com.gaby` / `iptv_player`), donc ses données vivaient dans
/// `%APPDATA%\com.gaby\iptv_player`. Depuis le renommage complet en
/// **NexoraTV**, `getApplicationSupportDirectory()` pointe sur
/// `%APPDATA%\NexoraTV`. Au premier lancement de la version renommée on
/// recopie l'ancien dossier (sources, prefs, mot de passe Xtream chiffré,
/// cache disque, cache images) vers le nouveau.
///
/// Idempotent : un fichier marqueur évite de recommencer, et on ne touche
/// à rien si le nouveau dossier contient déjà des préférences.
class DataMigration {
  static const _legacyVendor = 'com.gaby';
  static const _legacyProduct = 'iptv_player';
  static const _markerName = '.migrated_from_iptv_player';

  static Future<void> runIfNeeded() async {
    if (!Platform.isWindows) return;

    final appData = Platform.environment['APPDATA'];
    if (appData == null || appData.isEmpty) return;

    final legacyDir =
        Directory('$appData${Platform.pathSeparator}$_legacyVendor'
            '${Platform.pathSeparator}$_legacyProduct');
    if (!legacyDir.existsSync()) return;

    // Crée (si besoin) et retourne %APPDATA%\NexoraTV.
    final Directory newDir = await getApplicationSupportDirectory();

    final marker = File('${newDir.path}${Platform.pathSeparator}$_markerName');
    if (marker.existsSync()) return;

    final alreadyPopulated = File(
      '${newDir.path}${Platform.pathSeparator}shared_preferences.json',
    ).existsSync();

    if (!alreadyPopulated) {
      try {
        await for (final entity
            in legacyDir.list(recursive: true, followLinks: false)) {
          final rel = entity.path.substring(legacyDir.path.length + 1);
          final target = '${newDir.path}${Platform.pathSeparator}$rel';
          if (entity is Directory) {
            Directory(target).createSync(recursive: true);
          } else if (entity is File) {
            final parent = Directory(
              target.substring(0, target.lastIndexOf(Platform.pathSeparator)),
            );
            if (!parent.existsSync()) parent.createSync(recursive: true);
            entity.copySync(target);
          }
        }
      } catch (_) {
        // Migration best-effort : en cas d'échec l'app démarre avec un
        // profil vierge plutôt que de planter.
      }
    }

    try {
      marker.writeAsStringSync(DateTime.now().toIso8601String());
    } catch (_) {}
  }
}
