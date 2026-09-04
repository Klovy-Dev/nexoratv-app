import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
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
/// Format attendu du manifeste :
/// ```json
/// {
///   "version": "1.1.0",
///   "notes": "…",
///   "windows_url": "https://…/NexoraTV-1.1.0-windows-x64.zip",
///   "android_url":  "https://…/nexoratv-1.1.0.apk",
///   "mandatory": false
/// }
/// ```
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
    final current = await currentVersion();
    try {
      final res = await _dio.get<dynamic>(
        manifestUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final map = jsonDecode('${res.data}') as Map<String, dynamic>;
      final latest = '${map['version'] ?? ''}'.trim();
      if (latest.isEmpty || !_isNewer(latest, current)) return null;
      final url = Platform.isAndroid
          ? map['android_url'] as String?
          : map['windows_url'] as String?;
      return UpdateInfo(
        version: latest,
        currentVersion: current,
        notes: (map['notes'] as String?)?.trim(),
        downloadUrl: url,
        mandatory: map['mandatory'] == true,
      );
    } catch (_) {
      return null;
    }
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
