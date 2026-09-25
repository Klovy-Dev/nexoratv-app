import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';

/// Erreur affichable telle quelle à l'utilisateur.
class AppException implements Exception {
  AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

Future<http.Response> httpGet(
  Uri uri, {
  Map<String, String>? headers,
  Duration timeout = const Duration(seconds: 30),
}) => _guard(
  () => http.get(uri, headers: {'User-Agent': kUserAgent, ...?headers}),
  timeout,
);

Future<http.Response> httpPostJson(
  Uri uri,
  String body, {
  Map<String, String>? headers,
  Duration timeout = const Duration(seconds: 20),
}) => _guard(
  () => http.post(
    uri,
    headers: {
      'User-Agent': kUserAgent,
      'Content-Type': 'application/json',
      ...?headers,
    },
    body: body,
  ),
  timeout,
);

Future<http.Response> _guard(
  Future<http.Response> Function() send,
  Duration timeout,
) async {
  try {
    return await send().timeout(timeout);
  } on TimeoutException {
    throw AppException('Le serveur ne répond pas (délai dépassé).');
  } on SocketException {
    throw AppException(
      'Connexion impossible : vérifiez votre accès à Internet.',
    );
  } on HandshakeException {
    throw AppException('Connexion sécurisée impossible avec ce serveur.');
  } on http.ClientException {
    throw AppException('Connexion impossible au serveur.');
  }
}

/// Mémorise le résultat d'un chargement ; un échec n'est pas mémorisé
/// (le prochain appel réessaie).
class Memo<T> {
  Future<T>? _future;

  Future<T> call(Future<T> Function() load) {
    final existing = _future;
    if (existing != null) return existing;
    final future = load();
    _future = future;
    future.then(
      (_) {},
      onError: (Object _) {
        if (identical(_future, future)) _future = null;
      },
    );
    return future;
  }
}

/// Lecture tolérante des champs JSON des panels IPTV (types incohérents).
String? jsonStr(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty || s == 'null' ? null : s;
}

double? jsonNum(Object? v) => v == null ? null : double.tryParse(v.toString());
