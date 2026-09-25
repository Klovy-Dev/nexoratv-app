import 'dart:convert';

import 'config.dart';
import 'http.dart';
import 'models.dart';

/// Jeton refusé (expiré, ou mot de passe changé) : il faut se reconnecter.
class SessionExpired extends AppException {
  SessionExpired() : super('Votre session a expiré, reconnectez-vous.');
}

/// API du site NexoraTV (`/api/app/*`).
class AccountApi {
  static Uri _uri(String path) => Uri.parse('$kApiBase$path');

  static Future<(String token, AccountUser user)> login(String email, String password) async {
    final res = await httpPostJson(
      _uri('/api/app/login'),
      jsonEncode({'email': email.trim(), 'password': password}),
    );
    final body = _decode(res.body);
    if (res.statusCode != 200) {
      throw AppException(body['message'] as String? ?? 'Connexion impossible (${res.statusCode}).');
    }
    final user = body['user'] as Map<String, Object?>;
    return (body['token'] as String, AccountUser(user['name'] as String, user['email'] as String));
  }

  static Future<(AccountUser user, List<AccountSubscription> subs)> me(String token) async {
    final res = await httpGet(_uri('/api/app/me'), headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 401) throw SessionExpired();
    if (res.statusCode != 200) {
      throw AppException('Le site NexoraTV ne répond pas (${res.statusCode}).');
    }
    final body = _decode(res.body);
    final user = body['user'] as Map<String, Object?>;
    final subs = (body['subscriptions'] as List? ?? const [])
        .whereType<Map<String, Object?>>()
        .map(AccountSubscription.fromJson)
        .toList();
    return (AccountUser(user['name'] as String, user['email'] as String), subs);
  }

  static Map<String, Object?> _decode(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, Object?>) return data;
    } catch (_) {}
    return const {};
  }
}
