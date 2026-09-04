import 'package:dio/dio.dart';

import '../brand.dart';

/// Playlist assignée à une adresse MAC par le portail (`/admin/playlist`
/// sur le site).
class MacPlaylist {
  const MacPlaylist({required this.name, required this.m3uUrl, this.epgUrl});

  final String name;
  final String m3uUrl;
  final String? epgUrl;
}

/// Erreur remontée par le portail MAC : `notFound` = MAC pas (encore)
/// activé côté admin, `network` = site injoignable.
enum MacPortalErrorKind { notFound, network }

class MacPortalException implements Exception {
  const MacPortalException(this.kind, this.message);
  final MacPortalErrorKind kind;
  final String message;
  @override
  String toString() => message;
}

class MacPortalService {
  MacPortalService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 12),
            ));

  final Dio _dio;

  /// Interroge le portail pour [mac]. Lève [MacPortalException].
  Future<MacPlaylist> resolve(String mac) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        Brand.playlistApi,
        queryParameters: {'mac': mac},
      );
      final data = res.data;
      final m3uUrl = data?['m3uUrl'] as String?;
      if (data == null || m3uUrl == null || m3uUrl.isEmpty) {
        throw const MacPortalException(
            MacPortalErrorKind.notFound, 'Réponse du portail invalide.');
      }
      return MacPlaylist(
        name: (data['name'] as String?)?.trim().isNotEmpty == true
            ? data['name'] as String
            : 'Ma playlist',
        m3uUrl: m3uUrl,
        epgUrl: data['epgUrl'] as String?,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const MacPortalException(
          MacPortalErrorKind.notFound,
          'Cette adresse MAC n\'est pas encore activée. Communiquez-la au '
          'support NexoraTV pour l\'activer.',
        );
      }
      throw MacPortalException(
        MacPortalErrorKind.network,
        'Impossible de joindre le portail NexoraTV (${e.message ?? 'réseau'}).',
      );
    }
  }
}
