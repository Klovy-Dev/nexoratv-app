import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'config.dart';
import 'http.dart';

/// Version publiée sur GitHub, plus récente que celle installée.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.url,
    required this.current,
    this.notes,
    this.mandatory = false,
    this.sha256,
  });

  final String version;
  final String url;

  /// Version installée.
  final String current;
  final String? notes;

  /// Vrai : pas de « Plus tard ».
  final bool mandatory;

  /// Empreinte SHA-256 attendue de l'installeur (hexadécimal). Si le
  /// manifeste la donne, un fichier qui ne correspond pas est refusé.
  final String? sha256;
}

/// Mises à jour depuis le manifeste GitHub ([kUpdateManifestUrl]).
class Updater {
  /// Version installée (celle du pubspec, lue dans l'exécutable).
  static Future<String> currentVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  /// Null si l'appli est à jour (ou si la plateforme n'a pas de bloc).
  static Future<AppUpdate?> check() async {
    final res = await httpGet(
      Uri.parse(kUpdateManifestUrl),
      timeout: const Duration(seconds: 15),
    );
    if (res.statusCode != 200) {
      throw AppException('Impossible de vérifier les mises à jour.');
    }
    final json = jsonDecode(utf8.decode(res.bodyBytes));
    if (json is! Map<String, Object?>) return null;
    final block = json[Platform.isWindows ? 'windows' : 'android'];
    if (block is! Map<String, Object?>) return null;

    final version = jsonStr(block['version']);
    final url = jsonStr(block['url']);
    if (version == null || url == null) return null;
    final current = await currentVersion();
    if (compareVersions(version, current) <= 0) return null;
    return AppUpdate(
      version: version,
      url: url,
      current: current,
      notes: jsonStr(block['notes']),
      mandatory: block['mandatory'] == true,
      sha256: jsonStr(block['sha256'])?.toLowerCase(),
    );
  }

  /// Télécharge l'installeur dans le dossier temporaire ; [onProgress]
  /// reçoit une valeur entre 0 et 1 (null si la taille est inconnue).
  static Future<File> download(
    AppUpdate update,
    void Function(double? progress) onProgress,
  ) async {
    final client = http.Client();
    try {
      final res = await client
          .send(http.Request('GET', Uri.parse(update.url)))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw AppException(
          'Téléchargement impossible (erreur ${res.statusCode}).',
        );
      }
      final name = Uri.parse(update.url).pathSegments.last;
      final file = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}$name',
      );
      final sink = file.openWrite();
      final digest = _DigestSink();
      final hasher = sha256.startChunkedConversion(digest);
      final total = res.contentLength;
      var received = 0;
      try {
        await for (final chunk in res.stream.timeout(
          const Duration(seconds: 30),
        )) {
          sink.add(chunk);
          hasher.add(chunk);
          received += chunk.length;
          onProgress(total == null || total == 0 ? null : received / total);
        }
      } finally {
        await sink.close();
        hasher.close();
      }
      final expected = update.sha256;
      if (expected != null && digest.value.toString() != expected) {
        await file.delete();
        throw AppException(
          'Le fichier téléchargé est corrompu ou a été modifié : '
          'installation annulée.',
        );
      }
      return file;
    } on TimeoutException {
      throw AppException('Le téléchargement ne répond plus.');
    } on SocketException {
      throw AppException(
        'Connexion impossible : vérifiez votre accès à Internet.',
      );
    } finally {
      client.close();
    }
  }

  /// Lance l'installeur puis ferme l'appli (sinon ses fichiers sont
  /// verrouillés et ne peuvent pas être remplacés).
  ///
  /// Options de l'installeur Inno Setup (installer/nexoratv.iss) : fenêtre
  /// de progression seule, pas de questions ; l'installeur relance
  /// NexoraTV à la fin.
  static Future<void> install(File installer) async {
    await Process.start(installer.path, const [
      '/SILENT',
      '/SUPPRESSMSGBOXES',
      '/NORESTART',
      '/CLOSEAPPLICATIONS',
    ], mode: ProcessStartMode.detached);
    exit(0);
  }
}

/// Compare « 2.1.0 » et « 2.0.9 » (numériques, parties manquantes = 0).
/// Positif si [a] est plus récente que [b].
int compareVersions(String a, String b) {
  List<int> parts(String v) => v
      .split('+')
      .first
      .split('.')
      .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
  final pa = parts(a);
  final pb = parts(b);
  for (var i = 0; i < pa.length || i < pb.length; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x - y;
  }
  return 0;
}

/// Reçoit l'empreinte calculée au fil du téléchargement.
class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
