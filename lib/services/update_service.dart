import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.currentVersion,
    this.notes,
    this.downloadUrl,
    this.mandatory = false,
  });

  final String version;
  final String currentVersion;
  final String? notes;
  final String? downloadUrl;
  final bool mandatory;
}

/// Vérifie et applique les mises à jour à partir d'un manifeste JSON distant.
///
/// Format courant — un bloc par plateforme, versions indépendantes :
/// ```json
/// {
///   "windows": {
///     "version": "2.1.0",
///     "url": "https://…/NexoraTV-Setup-2.1.0.exe",
///     "notes": "…",
///     "mandatory": false
///   },
///   "android": {
///     "version": "1.5.0",
///     "url": "https://…/NexoraTV-1.5.0.apk",
///     "notes": "…",
///     "mandatory": false
///   }
/// }
/// ```
///
/// Ancien format (toujours accepté en repli) : champs `version`, `windows_url`,
/// `android_url`, `notes`, `mandatory` à plat.
class UpdateService {
  UpdateService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(minutes: 5),
            ));

  final Dio _dio;

  Future<String> currentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '1.0.0';
    }
  }

  /// Renvoie une [UpdateInfo] si une version plus récente est disponible,
  /// sinon `null`. Ne lève pas : renvoie `null` en cas d'erreur réseau.
  Future<UpdateInfo?> check(String manifestUrl) async {
    if (manifestUrl.trim().isEmpty) return null;
    // iOS : les mises à jour passent par l'App Store / TestFlight, pas par
    // notre manifeste. On n'affiche donc aucune bannière de MAJ interne.
    if (Platform.isIOS) return null;
    final current = await currentVersion();
    try {
      final res = await _dio.get<dynamic>(
        manifestUrl,
        options: Options(responseType: ResponseType.plain),
      );
      return parseManifest(
        '${res.data}',
        currentVersion: current,
        isAndroid: Platform.isAndroid,
      );
    } catch (_) {
      return null;
    }
  }

  /// Extrait l'entrée de mise à jour applicable pour la plateforme courante,
  /// ou `null` si le manifeste est illisible / pas plus récent. Séparé de
  /// [check] pour être testable sans réseau.
  @visibleForTesting
  static UpdateInfo? parseManifest(
    String json, {
    required String currentVersion,
    required bool isAndroid,
  }) {
    final Map<String, dynamic> map;
    try {
      map = jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }

    final block = map[isAndroid ? 'android' : 'windows'];
    final String latest;
    final String? url;
    final String? notes;
    final bool mandatory;
    if (block is Map<String, dynamic>) {
      // Format par plateforme.
      latest = '${block['version'] ?? ''}'.trim();
      url = block['url'] as String?;
      notes = (block['notes'] as String?)?.trim();
      mandatory = block['mandatory'] == true;
    } else {
      // Ancien format à plat.
      latest = '${map['version'] ?? ''}'.trim();
      url = (isAndroid ? map['android_url'] : map['windows_url']) as String?;
      notes = (map['notes'] as String?)?.trim();
      mandatory = map['mandatory'] == true;
    }

    if (latest.isEmpty || !_isNewer(latest, currentVersion)) return null;
    return UpdateInfo(
      version: latest,
      currentVersion: currentVersion,
      notes: notes,
      downloadUrl: url,
      mandatory: mandatory,
    );
  }

  /// Télécharge le paquet et lance l'installeur / l'APK.
  /// [onProgress] reçoit une valeur 0..1 (ou -1 si taille inconnue).
  Future<void> downloadAndInstall(
    UpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    final url = info.downloadUrl;
    if (url == null || url.isEmpty) {
      throw const UpdateException('Aucun lien de téléchargement fourni.');
    }

    final dir = await getDownloadsDirectory() ??
        await getApplicationSupportDirectory();
    final name = Uri.parse(url).pathSegments.isNotEmpty
        ? Uri.parse(url).pathSegments.last
        : (Platform.isAndroid
            ? 'NexoraTV-${info.version}.apk'
            : 'NexoraTV-${info.version}.zip');
    final path = '${dir.path}${Platform.pathSeparator}$name';

    try {
      await _dio.download(
        url,
        path,
        onReceiveProgress: (received, total) => onProgress?.call(
            total > 0 ? received / total : -1),
      );
    } on DioException catch (e) {
      throw UpdateException('Téléchargement impossible : ${e.message}');
    }

    // Windows : installeur Inno Setup -> installation silencieuse + relance.
    if (Platform.isWindows && path.toLowerCase().endsWith('.exe')) {
      await Process.start(
        path,
        ['/SILENT', '/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS', '/NORESTART'],
        mode: ProcessStartMode.detached,
      );
      return;
    }

    // Android : OpenFilex déclenche l'installeur d'APK.
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw UpdateException(
            'Fichier téléchargé dans "$path" mais impossible de l\'ouvrir.');
      }
    }
  }

  /// Ouvre simplement la page de téléchargement dans le navigateur.
  Future<void> openInBrowser(UpdateInfo info) async {
    final url = info.downloadUrl;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  static bool _isNewer(String remote, String local) {
    List<int> parse(String v) => v
        .split(RegExp(r'[.\-+]'))
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final r = parse(remote), l = parse(local);
    for (var i = 0; i < r.length || i < l.length; i++) {
      final rv = i < r.length ? r[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (rv != lv) return rv > lv;
    }
    return false;
  }
}

class UpdateException implements Exception {
  const UpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}
